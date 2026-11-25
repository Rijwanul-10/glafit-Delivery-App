import { Router } from 'express';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth } from '../middleware/auth.js';
import { mapsService } from '../services/mapsService.js';
import { resolveZoneByCoords } from '../services/zoneService.js';
import { paymentService } from '../services/paymentService.js';
import { geoMatchService } from '../services/geoMatchService.js';
import { getIO } from '../realtime/socketServer.js';
import { firebaseService } from '../services/firebaseService.js';
import { generateReceiptPdf } from '../services/pdfService.js';

export const rideRouter = Router();

const FLEET_TIERS = [
  { id: '2BEE_EV_SOLO', name: '2Bee EV Solo Bike', subtitle: 'Glafit GFR-02 EV · Solo Commute', baseBdt: 40, perKmBdt: 18, minBdt: 85, etaOffsetMins: 0 },
  { id: '2BEE_EV_EXPRESS', name: '2Bee EV Express Bike', subtitle: 'Glafit LOM Priority · Instant Dispatch', baseBdt: 55, perKmBdt: 22, minBdt: 110, etaOffsetMins: 1 },
] as const;

// Public Route Estimation: Allows users to calculate fare & route freely
rideRouter.post(
  '/estimate',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      pickupLat: z.number(),
      pickupLng: z.number(),
      pickupZoneId: z.string().nullable().optional(),
      dropoffLat: z.number(),
      dropoffLng: z.number(),
      dropoffZoneId: z.string().nullable().optional(),
      promoCode: z.string().nullable().optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const [route, originZone, destinationZone] = await Promise.all([
      mapsService.estimateRoute(parsed.pickupLat, parsed.pickupLng, parsed.dropoffLat, parsed.dropoffLng),
      resolveZoneByCoords(prisma, parsed.pickupLat, parsed.pickupLng, parsed.pickupZoneId ?? undefined),
      resolveZoneByCoords(prisma, parsed.dropoffLat, parsed.dropoffLng, parsed.dropoffZoneId ?? undefined),
    ]);

    const promoDiscount = parsed.promoCode?.toUpperCase() === '2BEE10' ? 10 : 0;
    const tiers = FLEET_TIERS.map((t) => {
      const rawFare = Math.max(t.minBdt, Math.round(t.baseBdt + route.distanceKm * t.perKmBdt));
      return {
        ...t,
        grossFareBdt: rawFare,
        discountBdt: promoDiscount,
        totalFareBdt: Math.max(0, rawFare - promoDiscount),
        etaMins: route.etaMins + t.etaOffsetMins,
      };
    });

    res.json({
      ok: true,
      distanceKm: route.distanceKm,
      etaMins: route.etaMins,
      polyline: route.polyline,
      originZone,
      destinationZone,
      tiers,
    });
  }),
);

// Protected actions: Booking EV rides, live in-trip tracking, cancellation, driver rating
rideRouter.use(requireAuth);

rideRouter.post(
  '/request',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      fleetTier: z.enum(['2BEE_EV_SOLO', '2BEE_EV_EXPRESS', 'ECO_AUTO', 'COMFORT_SEDAN']).default('2BEE_EV_SOLO'),
      pickupAddress: z.string().min(2),
      pickupLat: z.number(),
      pickupLng: z.number(),
      pickupZoneId: z.string().nullable().optional(),
      dropoffAddress: z.string().min(2),
      dropoffLat: z.number(),
      dropoffLng: z.number(),
      dropoffZoneId: z.string().nullable().optional(),
      promoCode: z.string().nullable().optional(),
      paymentMethod: z.enum(['COD', 'STRIPE_SANDBOX']),
      stripePaymentIntentId: z.string().nullable().optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const [route, originZone, destinationZone] = await Promise.all([
      mapsService.estimateRoute(parsed.pickupLat, parsed.pickupLng, parsed.dropoffLat, parsed.dropoffLng),
      resolveZoneByCoords(prisma, parsed.pickupLat, parsed.pickupLng, parsed.pickupZoneId ?? undefined),
      resolveZoneByCoords(prisma, parsed.dropoffLat, parsed.dropoffLng, parsed.dropoffZoneId ?? undefined),
    ]);

    const tier = FLEET_TIERS.find((t) => t.id === parsed.fleetTier) ?? FLEET_TIERS[0];
    const baseFareBdt = tier.baseBdt;
    const distanceFareBdt = Math.round(route.distanceKm * tier.perKmBdt);
    const gross = Math.max(tier.minBdt, baseFareBdt + distanceFareBdt);
    const discountBdt = parsed.promoCode?.toUpperCase() === '2BEE10' ? 10 : 0;
    const totalFareBdt = Math.max(0, gross - discountBdt);
    const riderPayoutBdt = Math.round(totalFareBdt * 0.85);

    let stripeIntentId: string | null = parsed.stripePaymentIntentId ?? null;
    let paymentStatus: 'PENDING' | 'PAID' = 'PENDING';
    if (parsed.paymentMethod === 'STRIPE_SANDBOX') {
      if (!stripeIntentId) {
        const intent = await paymentService.createStripeSandboxIntent({
          amountBdt: totalFareBdt,
          serviceType: 'RIDE',
          referenceCode: `RIDE-${Date.now().toString().slice(-5)}`,
          userId: req.auth!.userId,
        });
        stripeIntentId = intent.paymentIntentId;
      }
      const verified = await paymentService.confirmSandboxIntent(stripeIntentId);
      if (!verified.paid) throw new HttpError(402, 'PAYMENT_FAILED', 'Stripe payment not confirmed');
      paymentStatus = 'PAID';
    }

    const trip = await prisma.rideTrip.create({
      data: {
        tripCode: `RIDE-${Math.floor(1000 + Math.random() * 9000)}`,
        userId: req.auth!.userId,
        fleetTier: parsed.fleetTier,
        pickupAddress: parsed.pickupAddress,
        pickupZoneId: originZone.id,
        pickupLat: parsed.pickupLat,
        pickupLng: parsed.pickupLng,
        dropoffAddress: parsed.dropoffAddress,
        dropoffZoneId: destinationZone.id,
        dropoffLat: parsed.dropoffLat,
        dropoffLng: parsed.dropoffLng,
        distanceKm: route.distanceKm,
        etaMins: route.etaMins + tier.etaOffsetMins,
        paymentMethod: parsed.paymentMethod,
        paymentStatus,
        stripeIntentId,
        promoCode: discountBdt > 0 ? parsed.promoCode?.toUpperCase() : null,
        baseFareBdt,
        distanceFareBdt,
        discountBdt,
        totalFareBdt,
        riderPayoutBdt,
        startPin: String(Math.floor(1000 + Math.random() * 9000)),
      },
    });

    await prisma.chatThread.create({
      data: { serviceType: 'RIDE', orderId: trip.id, clientId: req.auth!.userId },
    });

    // 1) Zone A -> Zone B Multi-Service Matcher (ONLY for 2-wheel EV Solo rides matching active NORMAL front-carrier parcel!)
    const msCorridorRiders =
      parsed.fleetTier === '2BEE_EV_SOLO'
        ? await geoMatchService.findMultiServiceRidersForCorridor(originZone.id, destinationZone.id)
        : [];
    for (const slot of msCorridorRiders) {
      getIO()?.to(`rider:${slot.riderId}`).emit('rider:ride_addon_offer', {
        tripId: trip.id,
        tripCode: trip.tripCode,
        pickupZoneId: originZone.id,
        dropoffZoneId: destinationZone.id,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
        payoutBdt: trip.riderPayoutBdt,
        countdownSeconds: 12,
        corridorMatched: true,
      });
    }

    // 2) Standard Redis GEO nearby online riders
    const nearbyRiders = await geoMatchService.findNearbyRiders('ride', parsed.pickupLat, parsed.pickupLng, 8);
    for (const hit of nearbyRiders) {
      getIO()?.to(`rider:${hit.riderId}`).emit('rider:incoming_offer', {
        serviceType: 'RIDE',
        id: trip.id,
        code: trip.tripCode,
        pickupAddress: trip.pickupAddress,
        dropoffAddress: trip.dropoffAddress,
        payoutBdt: trip.riderPayoutBdt,
        distanceKm: trip.distanceKm,
        etaMins: trip.etaMins,
        countdownSeconds: 15,
      });
    }
    if (nearbyRiders.length > 0) {
      void prisma.riderProfile
        .findMany({ where: { id: { in: nearbyRiders.map((h) => h.riderId) } }, select: { userId: true } })
        .then((rows) =>
          Promise.all(
            rows.map((r) =>
              firebaseService.sendPushToUser(
                r.userId,
                {
                  title: `New EV Ride Offer (${trip.tripCode})`,
                  body: `${trip.pickupAddress} → ${trip.dropoffAddress} · ৳${trip.riderPayoutBdt}`,
                  data: { type: 'RIDE_OFFER', tripId: trip.id },
                  channelId: 'rider_offers_urgent',
                },
                'RIDER',
              ),
            ),
          ),
        );
    }

    res.status(201).json({
      ok: true,
      trip: sanitizeRideForClient(trip),
      matchedCorridorRidersCount: msCorridorRiders.length,
      nearbyRidersCount: nearbyRiders.length,
    });
  }),
);

/**
 * STRICT PRIVACY ISOLATION: Ride Passenger never sees parcel / multi-service batch info!
 */
export function sanitizeRideForClient(trip: {
  id: string;
  tripCode: string;
  fleetTier: string;
  pickupAddress: string;
  pickupZoneId: string;
  pickupLat: number;
  pickupLng: number;
  dropoffAddress: string;
  dropoffZoneId: string;
  dropoffLat: number;
  dropoffLng: number;
  distanceKm: number;
  etaMins: number;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  baseFareBdt: number;
  distanceFareBdt: number;
  discountBdt: number;
  totalFareBdt: number;
  startPin: string;
  tipBdt: number;
  rating: number | null;
  createdAt: Date;
  updatedAt?: Date;
  rider?: {
    rating: number;
    vehicleBrandModel: string | null;
    plateNo: string | null;
    currentLat: number | null;
    currentLng: number | null;
    user: { fullName: string; phone: string; avatarUrl: string | null };
  } | null;
}) {
  return {
    id: trip.id,
    tripCode: trip.tripCode,
    fleetTier: trip.fleetTier,
    pickupAddress: trip.pickupAddress,
    pickupZoneId: trip.pickupZoneId,
    pickupLat: trip.pickupLat,
    pickupLng: trip.pickupLng,
    dropoffAddress: trip.dropoffAddress,
    dropoffZoneId: trip.dropoffZoneId,
    dropoffLat: trip.dropoffLat,
    dropoffLng: trip.dropoffLng,
    distanceKm: trip.distanceKm,
    etaMins: trip.etaMins,
    status: trip.status,
    paymentMethod: trip.paymentMethod,
    paymentStatus: trip.paymentStatus,
    baseFareBdt: trip.baseFareBdt,
    distanceFareBdt: trip.distanceFareBdt,
    discountBdt: trip.discountBdt,
    totalFareBdt: trip.totalFareBdt,
    startPin: trip.startPin,
    tipBdt: trip.tipBdt,
    rating: trip.rating,
    createdAt: trip.createdAt,
    updatedAt: trip.updatedAt ?? trip.createdAt,
    driver: trip.rider
      ? {
          name: trip.rider.user.fullName,
          phone: trip.rider.user.phone,
          avatarUrl: trip.rider.user.avatarUrl,
          rating: trip.rider.rating,
          vehicle: trip.rider.vehicleBrandModel,
          plateNo: trip.rider.plateNo,
          lat: trip.rider.currentLat,
          lng: trip.rider.currentLng,
        }
      : null,
  };
}

rideRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({
      where: { id: String(req.params.id) },
      include: {
        rider: {
          include: { user: { select: { fullName: true, phone: true, avatarUrl: true } } },
        },
      },
    });
    if (!trip || trip.userId !== req.auth!.userId) {
      throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride trip not found');
    }
    res.json({ ok: true, trip: sanitizeRideForClient(trip) });
  }),
);

rideRouter.post(
  '/:id/cancel',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.userId !== req.auth!.userId) {
      throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (!['MATCHING', 'RIDER_ASSIGNED'].includes(trip.status)) {
      throw new HttpError(400, 'CANNOT_CANCEL', 'Ride already started or finished');
    }
    const updated = await prisma.rideTrip.update({
      where: { id: trip.id },
      data: {
        status: 'CANCELLED',
        paymentStatus: trip.paymentStatus === 'PAID' ? 'REFUNDED' : trip.paymentStatus,
      },
    });
    res.json({ ok: true, trip: sanitizeRideForClient(updated) });
  }),
);

rideRouter.post(
  '/:id/cancel-delayed-driver',
  asyncHandler(async (req, res) => {
    const { reason } = z
      .object({
        reason: z.string().min(1).default('Driver delayed to reach pickup location'),
      })
      .parse(req.body);
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({
      where: { id: String(req.params.id) },
      include: {
        rider: {
          include: { user: { select: { fullName: true, phone: true, avatarUrl: true } } },
        },
      },
    });
    if (!trip || trip.userId !== req.auth!.userId) {
      throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (trip.status !== 'RIDER_ASSIGNED') {
      throw new HttpError(
        400,
        'CANNOT_CANCEL_DRIVER',
        trip.status === 'ARRIVED_PICKUP'
          ? 'Driver has already arrived at your location'
          : 'Driver cancellation only allowed while driver is en-route',
      );
    }
    const previousRiderId = trip.riderId;
    const updated = await prisma.rideTrip.update({
      where: { id: trip.id },
      data: {
        riderId: null,
        status: 'MATCHING',
      },
      include: {
        rider: {
          include: { user: { select: { fullName: true, phone: true, avatarUrl: true } } },
        },
      },
    });

    if (previousRiderId) {
      getIO()?.to(`rider:${previousRiderId}`).emit('rider:job_cancelled_by_client', {
        serviceType: 'RIDE',
        tripId: trip.id,
        tripCode: trip.tripCode,
        reason,
      });
    }

    getIO()?.to(`tracking:ride:${trip.id}`).emit('ride:status', {
      tripId: trip.id,
      status: 'MATCHING',
      reason,
    });

    res.json({ ok: true, trip: sanitizeRideForClient(updated), reason });
  }),
);

rideRouter.post(
  '/:id/rate',
  asyncHandler(async (req, res) => {
    const { rating, tipBdt, tags, comment } = z
      .object({
        rating: z.number().int().min(1).max(5),
        tipBdt: z.number().min(0).max(2000).default(0),
        tags: z.array(z.string()).default([]),
        comment: z.string().max(300).optional(),
      })
      .parse(req.body);
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.userId !== req.auth!.userId) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');

    const updated = await prisma.rideTrip.update({
      where: { id: trip.id },
      data: { rating, tipBdt },
    });
    await prisma.review.create({
      data: {
        userId: req.auth!.userId,
        serviceType: 'RIDE',
        orderId: trip.id,
        rating,
        riderRating: rating,
        tagsJson: tags,
        comment,
      },
    });

    if (tipBdt > 0 && trip.riderId) {
      const rider = await prisma.riderProfile.findUnique({ where: { id: trip.riderId } });
      if (rider) {
        const w = await prisma.walletAccount.upsert({
          where: { userId_role: { userId: rider.userId, role: 'RIDER' } },
          update: { balanceBdt: { increment: tipBdt } },
          create: { userId: rider.userId, role: 'RIDER', balanceBdt: tipBdt },
        });
        await prisma.walletTransaction.create({
          data: {
            walletId: w.id,
            type: 'BONUS',
            amountBdt: tipBdt,
            referenceCode: trip.tripCode,
            description: `Ride tip for ${trip.tripCode}`,
          },
        });
      }
    }
    res.json({ ok: true, trip: sanitizeRideForClient(updated) });
  }),
);

rideRouter.get(
  '/:id/pdf',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.userId !== req.auth!.userId) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    const pdf = await generateReceiptPdf({
      title: `Ride Invoice — ${trip.fleetTier.replace(/_/g, ' ')}`,
      subtitle: '2Bee Zero-Emission Ride',
      referenceCode: trip.tripCode,
      lines: [
        { label: 'Pickup', value: trip.pickupAddress },
        { label: 'Dropoff', value: trip.dropoffAddress },
        { label: 'Distance', value: `${trip.distanceKm} km` },
        { label: 'Base Fare', value: `৳${trip.baseFareBdt}` },
        { label: 'Distance Fare', value: `৳${trip.distanceFareBdt}` },
        { label: 'Discount', value: `-৳${trip.discountBdt}` },
      ],
      totalLabel: `Total (${trip.paymentMethod})`,
      totalValue: `৳${trip.totalFareBdt}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${trip.tripCode}.pdf"`);
    res.send(pdf);
  }),
);

