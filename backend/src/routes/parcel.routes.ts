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
import { generateReceiptPdf } from '../services/pdfService.js';

export const parcelRouter = Router();
parcelRouter.use(requireAuth);

function computeFrontCarrierFit(tier: string, weightKg: number, volumeCm3: number, maxKg: number, maxVol: number): boolean {
  // Multi-service eligibility: ONLY normal parcel (NEVER Express) fitting front carrier weight & volume
  return tier !== 'EXPRESS' && weightKg <= maxKg && volumeCm3 <= maxVol;
}

parcelRouter.post(
  '/estimate',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      pickupLat: z.number(),
      pickupLng: z.number(),
      pickupZoneId: z.string().nullable().optional(),
      dropoffLat: z.number(),
      dropoffLng: z.number(),
      dropoffZoneId: z.string().nullable().optional(),
      tier: z.enum(['NORMAL_ECO', 'NEXT_DAY', 'EXPRESS']).default('NORMAL_ECO'),
      weightKg: z.number().min(0.1).max(15).default(2.0),
      lengthCm: z.number().min(5).max(80).default(30),
      widthCm: z.number().min(5).max(80).default(20),
      heightCm: z.number().min(5).max(80).default(15),
      isProtected: z.boolean().default(false),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const [route, originZone, destinationZone, pricing] = await Promise.all([
      mapsService.estimateRoute(parsed.pickupLat, parsed.pickupLng, parsed.dropoffLat, parsed.dropoffLng),
      resolveZoneByCoords(prisma, parsed.pickupLat, parsed.pickupLng, parsed.pickupZoneId ?? undefined),
      resolveZoneByCoords(prisma, parsed.dropoffLat, parsed.dropoffLng, parsed.dropoffZoneId ?? undefined),
      prisma.appPricingConfig.findUnique({ where: { id: 'default' } }),
    ]);

    const frontMaxKg = pricing?.parcelFrontMaxKg ?? 8.0;
    const frontMaxVol = pricing?.parcelFrontMaxVolCm3 ?? 31500;
    const volumeCm3 = parsed.lengthCm * parsed.widthCm * parsed.heightCm;

    const baseFee =
      parsed.tier === 'EXPRESS'
        ? pricing?.parcelExpressBaseBdt ?? 110
        : parsed.tier === 'NEXT_DAY'
          ? 45
          : pricing?.parcelNormalBaseBdt ?? 60;
    const distanceFee = Math.round(route.distanceKm * 6);
    const weightFee = Math.max(0, Math.ceil((parsed.weightKg - 1) * 10));
    const protectionFeeBdt = parsed.isProtected ? pricing?.parcelProtectionBdt ?? 15 : 0;
    const deliveryChargeBdt = baseFee + distanceFee + weightFee + protectionFeeBdt;

    res.json({
      ok: true,
      distanceKm: route.distanceKm,
      etaText: parsed.tier === 'EXPRESS' ? '~45 mins' : parsed.tier === 'NEXT_DAY' ? 'Next Day' : '2–12 hours',
      originZone,
      destinationZone,
      volumeCm3,
      fitsFrontCarrier: computeFrontCarrierFit(parsed.tier, parsed.weightKg, volumeCm3, frontMaxKg, frontMaxVol),
      breakdown: {
        baseFee,
        distanceFee,
        weightFee,
        protectionFeeBdt,
        deliveryChargeBdt,
      },
    });
  }),
);

parcelRouter.post(
  '/book',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      tier: z.enum(['NORMAL_ECO', 'NEXT_DAY', 'EXPRESS']).default('NORMAL_ECO'),
      packageSizeClass: z.enum(['DOC', 'SMALL', 'MEDIUM', 'LARGE']).default('MEDIUM'),
      category: z.string().min(2).default('Electronics & Gadgets'),
      weightKg: z.number().min(0.1).max(15),
      lengthCm: z.number().min(5).max(80).default(30),
      widthCm: z.number().min(5).max(80).default(20),
      heightCm: z.number().min(5).max(80).default(15),
      declaredValueBdt: z.number().min(0).default(1000),
      isProtected: z.boolean().default(false),
      handlingNote: z.string().max(300).nullable().optional(),
      senderName: z.string().min(2),
      senderPhone: z.string().min(10),
      pickupAddress: z.string().min(3),
      pickupZoneId: z.string().nullable().optional(),
      pickupLat: z.number(),
      pickupLng: z.number(),
      recipientName: z.string().min(2),
      recipientPhone: z.string().min(10),
      dropoffAddress: z.string().min(3),
      dropoffZoneId: z.string().nullable().optional(),
      dropoffLat: z.number(),
      dropoffLng: z.number(),
      codCollectBdt: z.number().min(0).default(0),
      paymentMethod: z.enum(['COD', 'STRIPE_SANDBOX']),
      stripePaymentIntentId: z.string().nullable().optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const [route, originZone, destinationZone, pricing] = await Promise.all([
      mapsService.estimateRoute(parsed.pickupLat, parsed.pickupLng, parsed.dropoffLat, parsed.dropoffLng),
      resolveZoneByCoords(prisma, parsed.pickupLat, parsed.pickupLng, parsed.pickupZoneId ?? undefined),
      resolveZoneByCoords(prisma, parsed.dropoffLat, parsed.dropoffLng, parsed.dropoffZoneId ?? undefined),
      prisma.appPricingConfig.findUnique({ where: { id: 'default' } }),
    ]);

    const volumeCm3 = parsed.lengthCm * parsed.widthCm * parsed.heightCm;
    const fitsFrontCarrier = computeFrontCarrierFit(
      parsed.tier,
      parsed.weightKg,
      volumeCm3,
      pricing?.parcelFrontMaxKg ?? 8.0,
      pricing?.parcelFrontMaxVolCm3 ?? 31500,
    );

    const baseFee = parsed.tier === 'EXPRESS' ? 110 : parsed.tier === 'NEXT_DAY' ? 45 : 60;
    const distanceFee = Math.round(route.distanceKm * 6);
    const weightFee = Math.max(0, Math.ceil((parsed.weightKg - 1) * 10));
    const protectionFeeBdt = parsed.isProtected ? 15 : 0;
    const deliveryChargeBdt = baseFee + distanceFee + weightFee + protectionFeeBdt;
    const riderPayoutBdt = Math.round(deliveryChargeBdt * 0.85);

    let stripeIntentId: string | null = parsed.stripePaymentIntentId ?? null;
    let paymentStatus: 'PENDING' | 'PAID' = 'PENDING';
    if (parsed.paymentMethod === 'STRIPE_SANDBOX') {
      if (!stripeIntentId) {
        const intent = await paymentService.createStripeSandboxIntent({
          amountBdt: deliveryChargeBdt,
          serviceType: 'PARCEL',
          referenceCode: `PCL-${Date.now().toString().slice(-5)}`,
          userId: req.auth!.userId,
        });
        stripeIntentId = intent.paymentIntentId;
      }
      const verified = await paymentService.confirmSandboxIntent(stripeIntentId);
      if (!verified.paid) throw new HttpError(402, 'PAYMENT_FAILED', 'Stripe payment failed');
      paymentStatus = 'PAID';
    }

    const shipment = await prisma.parcelShipment.create({
      data: {
        trackingCode: `2B-PCL-${Math.floor(1000 + Math.random() * 9000)}`,
        userId: req.auth!.userId,
        tier: parsed.tier,
        packageSizeClass: parsed.packageSizeClass,
        category: parsed.category,
        weightKg: parsed.weightKg,
        lengthCm: parsed.lengthCm,
        widthCm: parsed.widthCm,
        heightCm: parsed.heightCm,
        volumeCm3,
        declaredValueBdt: parsed.declaredValueBdt,
        isProtected: parsed.isProtected,
        protectionFeeBdt,
        handlingNote: parsed.handlingNote,
        senderName: parsed.senderName,
        senderPhone: parsed.senderPhone,
        pickupAddress: parsed.pickupAddress,
        originZoneId: originZone.id,
        pickupLat: parsed.pickupLat,
        pickupLng: parsed.pickupLng,
        recipientName: parsed.recipientName,
        recipientPhone: parsed.recipientPhone,
        dropoffAddress: parsed.dropoffAddress,
        destinationZoneId: destinationZone.id,
        dropoffLat: parsed.dropoffLat,
        dropoffLng: parsed.dropoffLng,
        distanceKm: route.distanceKm,
        status: 'MATCHING',
        paymentMethod: parsed.paymentMethod,
        paymentStatus,
        stripeIntentId,
        deliveryChargeBdt,
        codCollectBdt: parsed.codCollectBdt,
        riderPayoutBdt,
        deliveryPin: String(Math.floor(1000 + Math.random() * 9000)),
        fitsFrontCarrier,
      },
    });

    await prisma.chatThread.create({
      data: { serviceType: 'PARCEL', orderId: shipment.id, clientId: req.auth!.userId },
    });

    const nearbyRiders = await geoMatchService.findNearbyRiders('parcel', parsed.pickupLat, parsed.pickupLng, 10);
    for (const hit of nearbyRiders) {
      getIO()?.to(`rider:${hit.riderId}`).emit('rider:incoming_offer', {
        serviceType: 'PARCEL',
        id: shipment.id,
        code: shipment.trackingCode,
        tier: shipment.tier,
        pickupAddress: shipment.pickupAddress,
        dropoffAddress: shipment.dropoffAddress,
        weightKg: shipment.weightKg,
        fitsFrontCarrier: shipment.fitsFrontCarrier,
        codCollectBdt: shipment.codCollectBdt,
        payoutBdt: shipment.riderPayoutBdt,
        countdownSeconds: 15,
      });
    }

    res.status(201).json({
      ok: true,
      shipment: sanitizeParcelForClient(shipment),
      nearbyRidersNotified: nearbyRiders.length,
    });
  }),
);

/**
 * STRICT PRIVACY ISOLATION:
 * Parcel Client NEVER sees passenger / co-ride / "Zero-Detour Multi-Route" info!
 */
export function sanitizeParcelForClient(p: {
  id: string;
  trackingCode: string;
  tier: string;
  packageSizeClass: string;
  category: string;
  weightKg: number;
  isProtected: boolean;
  senderName: string;
  pickupAddress: string;
  originZoneId: string;
  recipientName: string;
  dropoffAddress: string;
  destinationZoneId: string;
  distanceKm: number;
  status: string;
  paymentMethod: string;
  paymentStatus: string;
  deliveryChargeBdt: number;
  codCollectBdt: number;
  deliveryPin: string;
  pickupPhotoUrl: string | null;
  deliveryPhotoUrl: string | null;
  rating: number | null;
  createdAt: Date;
  rider?: {
    rating: number;
    vehicleBrandModel: string | null;
    plateNo: string | null;
    currentLat: number | null;
    currentLng: number | null;
    user: { fullName: string; phone: string; avatarUrl: string | null };
  } | null;
}) {
  const stepLabel =
    p.status === 'BOOKED' || p.status === 'MATCHING'
      ? 'Matching Dedicated 2Bee Courier'
      : p.status === 'RIDER_ASSIGNED'
        ? 'Courier Heading to Pickup'
        : p.status === 'PICKED_UP'
          ? 'Parcel Picked Up & Secured'
          : p.status === 'IN_TRANSIT'
            ? 'Courier En-Route on Scheduled Corridor'
            : p.status === 'DELIVERED'
              ? 'Delivered Successfully'
              : p.status;

  return {
    id: p.id,
    trackingCode: p.trackingCode,
    tier: p.tier,
    packageSizeClass: p.packageSizeClass,
    category: p.category,
    weightKg: p.weightKg,
    isProtected: p.isProtected,
    senderName: p.senderName,
    pickupAddress: p.pickupAddress,
    originZoneId: p.originZoneId,
    recipientName: p.recipientName,
    dropoffAddress: p.dropoffAddress,
    destinationZoneId: p.destinationZoneId,
    distanceKm: p.distanceKm,
    status: p.status,
    statusBanner: stepLabel, // Always strictly neutral parcel copy!
    paymentMethod: p.paymentMethod,
    paymentStatus: p.paymentStatus,
    deliveryChargeBdt: p.deliveryChargeBdt,
    codCollectBdt: p.codCollectBdt,
    deliveryPin: p.deliveryPin,
    pickupPhotoUrl: p.pickupPhotoUrl,
    deliveryPhotoUrl: p.deliveryPhotoUrl,
    rating: p.rating,
    createdAt: p.createdAt,
    courier: p.rider
      ? {
          name: p.rider.user.fullName,
          phone: p.rider.user.phone,
          avatarUrl: p.rider.user.avatarUrl,
          rating: p.rider.rating,
          vehicle: p.rider.vehicleBrandModel,
          plateNo: p.rider.plateNo,
          lat: p.rider.currentLat,
          lng: p.rider.currentLng,
        }
      : null,
  };
}

parcelRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const shipment = await prisma.parcelShipment.findUnique({
      where: { id: String(req.params.id) },
      include: {
        rider: {
          include: { user: { select: { fullName: true, phone: true, avatarUrl: true } } },
        },
      },
    });
    if (!shipment || shipment.userId !== req.auth!.userId) {
      throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Parcel shipment not found');
    }
    res.json({ ok: true, shipment: sanitizeParcelForClient(shipment) });
  }),
);

parcelRouter.post(
  '/:id/cancel',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.userId !== req.auth!.userId) {
      throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Parcel shipment not found');
    }
    if (!['BOOKED', 'MATCHING', 'RIDER_ASSIGNED'].includes(shipment.status)) {
      throw new HttpError(400, 'CANNOT_CANCEL', 'Parcel already picked up');
    }
    const updated = await prisma.parcelShipment.update({
      where: { id: shipment.id },
      data: {
        status: 'CANCELLED',
        paymentStatus: shipment.paymentStatus === 'PAID' ? 'REFUNDED' : shipment.paymentStatus,
      },
    });
    res.json({ ok: true, shipment: sanitizeParcelForClient(updated) });
  }),
);

parcelRouter.post(
  '/:id/rate',
  asyncHandler(async (req, res) => {
    const { rating, tipBdt, comment } = z
      .object({
        rating: z.number().int().min(1).max(5),
        tipBdt: z.number().min(0).max(2000).default(0),
        comment: z.string().max(300).optional(),
      })
      .parse(req.body);
    const prisma = getPrisma();
    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.userId !== req.auth!.userId) throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Not found');

    const updated = await prisma.parcelShipment.update({
      where: { id: shipment.id },
      data: { rating, tipBdt },
    });
    await prisma.review.create({
      data: {
        userId: req.auth!.userId,
        serviceType: 'PARCEL',
        orderId: shipment.id,
        rating,
        riderRating: rating,
        comment,
      },
    });
    res.json({ ok: true, shipment: sanitizeParcelForClient(updated) });
  }),
);

parcelRouter.get(
  '/:id/pdf',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.userId !== req.auth!.userId) throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Not found');

    const pdf = await generateReceiptPdf({
      title: `Parcel Waybill — ${shipment.trackingCode}`,
      subtitle: '2Bee Parcel Logistics',
      referenceCode: shipment.trackingCode,
      lines: [
        { label: 'Tier & Weight', value: `${shipment.tier} · ${shipment.weightKg} kg` },
        { label: 'Sender', value: `${shipment.senderName} (${shipment.pickupAddress})` },
        { label: 'Recipient', value: `${shipment.recipientName} (${shipment.dropoffAddress})` },
        { label: 'Protection Fee', value: `৳${shipment.protectionFeeBdt}` },
        { label: 'COD Goods Amount', value: `৳${shipment.codCollectBdt}` },
      ],
      totalLabel: `Delivery Charge (${shipment.paymentMethod})`,
      totalValue: `৳${shipment.deliveryChargeBdt}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${shipment.trackingCode}.pdf"`);
    res.send(pdf);
  }),
);

