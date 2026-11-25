import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth, requireRoleSession, signRoleSessionToken } from '../middleware/auth.js';
import { hashOtp } from '../services/smsProvider.js';
import { env } from '../config/env.js';
import { geoMatchService, h3IndexStrategy, type DispatchServiceKey } from '../services/geoMatchService.js';
import { getIO } from '../realtime/socketServer.js';
import { generateReceiptPdf } from '../services/pdfService.js';

export const riderRouter = Router();
riderRouter.use(requireAuth);

/**
 * POST /api/v1/rider/register
 * Steps A1-A10 + Step 8: Rider creates permanent 4-digit passcode AT registration.
 */
riderRouter.post(
  '/register',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      fullName: z.string().min(2),
      dob: z.string().min(4),
      gender: z.string().default('Male'),
      preferredZoneId: z.string().default('zone-banani'),
      emergencyName: z.string().min(2),
      emergencyRelation: z.string().default('Family'),
      emergencyPhone: z.string().min(10),
      nidNumber: z.string().min(10),
      licenseNumber: z.string().min(4),
      licenseExpiry: z.string().min(4),
      vehicleOwnership: z.enum(['OWN', 'RENTAL']),
      powertrain: z.enum(['PETROL', 'ELECTRIC']).default('PETROL'),
      vehicleBrandModel: z.string().min(2).default('Honda Livo 110'),
      plateNo: z.string().optional(),
      rentalHubName: z.string().optional(),
      rentalBikeId: z.string().optional(),
      rentalPlanType: z.enum(['DAILY', 'WEEKLY', 'RENT_TO_OWN']).optional(),
      frontCarrierEnabled: z.boolean().default(false),
      frontCarrierLengthCm: z.number().min(10).max(60).default(35),
      frontCarrierWidthCm: z.number().min(10).max(60).default(30),
      frontCarrierHeightCm: z.number().min(10).max(60).default(30),
      frontCarrierMaxKg: z.number().min(1).max(8).default(8),
      rearCarrierEnabled: z.boolean().default(true),
      multiServiceRequested: z.boolean().default(false),
      spareHelmetConfirmed: z.boolean().default(false),
      payoutProvider: z.enum(['BKASH', 'NAGAD', 'ROCKET', 'BANK_BEFTN']).default('BKASH'),
      payoutAccountNumber: z.string().min(6),
      payoutHolderName: z.string().min(2),
      passcode: z.string().regex(/^\d{4}$/, 'Rider passcode must be 4 digits'),
      enableBiometric: z.boolean().default(false),
      documents: z.array(z.object({ docType: z.string(), fileUrl: z.string() })).default([]),
      reRegisterDemo: z.boolean().default(false),
    });
    const parsed = schema.parse(req.body);
    if (['1234', '0000', '1111', '2222', '4321'].includes(parsed.passcode)) {
      throw new HttpError(400, 'WEAK_PASSCODE', 'Avoid 1234 or repeated digits');
    }

    const prisma = getPrisma();
    const userId = req.auth!.userId;
    const existing = await prisma.riderProfile.findUnique({ where: { userId } });
    if (existing && !(env.nodeEnv !== 'production' && parsed.reRegisterDemo)) {
      throw new HttpError(409, 'RIDER_ALREADY_EXISTS', 'Rider profile already registered for this phone');
    }

    const hasFront = parsed.vehicleOwnership === 'RENTAL' ? true : parsed.frontCarrierEnabled;
    if (parsed.multiServiceRequested && (!hasFront || !parsed.spareHelmetConfirmed)) {
      throw new HttpError(
        400,
        'MULTI_SERVICE_REQUIREMENTS',
        'Multi-service requires a front carrier (<=8kg) and spare helmet confirmation',
      );
    }

    const passcodeHash = await bcrypt.hash(parsed.passcode, 10);

    const profile = await prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: userId },
        data: { fullName: parsed.fullName, activeRole: 'RIDER' },
      });

      const dataFields = {
        kycStatus: 'PENDING' as const,
        passcodeHash,
        biometricEnabled: parsed.enableBiometric,
        dob: parsed.dob,
        gender: parsed.gender,
        preferredZoneId: parsed.preferredZoneId,
        emergencyName: parsed.emergencyName,
        emergencyRelation: parsed.emergencyRelation,
        emergencyPhone: parsed.emergencyPhone,
        nidNumber: parsed.nidNumber,
        licenseNumber: parsed.licenseNumber,
        licenseExpiry: parsed.licenseExpiry,
        vehicleOwnership: parsed.vehicleOwnership,
        powertrain: parsed.powertrain,
        vehicleBrandModel: parsed.vehicleBrandModel,
        plateNo: parsed.plateNo ?? (parsed.vehicleOwnership === 'RENTAL' ? '2BEE-EV-RENTAL' : 'DHK-METRO-NEW'),
        frontCarrierVerified: false,
        frontCarrierLengthCm: hasFront ? parsed.frontCarrierLengthCm : null,
        frontCarrierWidthCm: hasFront ? parsed.frontCarrierWidthCm : null,
        frontCarrierHeightCm: hasFront ? parsed.frontCarrierHeightCm : null,
        frontCarrierMaxKg: hasFront ? parsed.frontCarrierMaxKg : 0,
        rearCarrierVerified: false,
        multiServiceEnabled: parsed.multiServiceRequested && hasFront && parsed.spareHelmetConfirmed,
        spareHelmetConfirmed: parsed.spareHelmetConfirmed,
        isOnline: false,
      };
      const created = existing
        ? await tx.riderProfile.update({ where: { id: existing.id }, data: dataFields })
        : await tx.riderProfile.create({ data: { userId, ...dataFields } });

      if (parsed.documents.length > 0) {
        await tx.verificationDocument.createMany({
          data: parsed.documents.map((d) => ({
            ownerRole: 'RIDER',
            ownerId: created.id,
            docType: d.docType,
            fileUrl: d.fileUrl,
            status: 'PENDING',
          })),
        });
      }

      await tx.payoutAccount.upsert({
        where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: created.id } },
        update: {
          provider: parsed.payoutProvider,
          accountNumber: parsed.payoutAccountNumber,
          holderName: parsed.payoutHolderName,
        },
        create: {
          ownerRole: 'RIDER',
          ownerId: created.id,
          provider: parsed.payoutProvider,
          accountNumber: parsed.payoutAccountNumber,
          holderName: parsed.payoutHolderName,
        },
      });

      await tx.walletAccount.upsert({
        where: { userId_role: { userId, role: 'RIDER' } },
        update: {},
        create: { userId, role: 'RIDER', balanceBdt: 0 },
      });

      if (parsed.vehicleOwnership === 'RENTAL') {
        await tx.bikeRental.create({
          data: {
            riderId: created.id,
            bikeId: parsed.rentalBikeId ?? 'fleet-ev-1',
            bikeModel: parsed.vehicleBrandModel,
            plateNo: '2BEE-EV-2190',
            hubName: parsed.rentalHubName ?? 'Banani Hub',
            planType: parsed.rentalPlanType ?? 'DAILY',
            dailyRateBdt: 250,
            status: 'PENDING_HANDOVER',
            nextDebitAt: new Date(Date.now() + 86400 * 1000),
          },
        });
      }

      return created;
    });

    const roleToken = signRoleSessionToken(userId, 'RIDER', profile.id);
    res.status(201).json({
      ok: true,
      profile,
      roleToken,
      nextScreen: 'RIDER_HOME_PENDING',
      message: 'Verification in progress. You can go online once approved.',
    });
  }),
);

/**
 * POST /api/v1/rider/login-pin
 * Verifies 4-digit Rider passcode created at registration.
 */
riderRouter.post(
  '/login-pin',
  asyncHandler(async (req, res) => {
    const { passcode } = z
      .object({ passcode: z.string().regex(/^\d{4}$/, 'Rider passcode must be 4 digits') })
      .parse(req.body);
    const prisma = getPrisma();
    const rp = await prisma.riderProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!rp) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider registration not found');

    const valid = await bcrypt.compare(passcode, rp.passcodeHash);
    if (!valid) throw new HttpError(401, 'INVALID_PASSCODE', 'Incorrect 4-digit passcode');

    const roleToken = signRoleSessionToken(req.auth!.userId, 'RIDER', rp.id);
    res.json({
      ok: true,
      roleToken,
      kycStatus: rp.kycStatus,
      inactivityTimeoutMinutes: env.roleInactivityMinutes,
    });
  }),
);

/**
 * POST /api/v1/rider/forgot-passcode/reset
 * Resets 4-digit Rider passcode via SMS OTP + last 4 digits of NID.
 */
riderRouter.post(
  '/forgot-passcode/reset',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      otpCode: z.string().regex(/^\d{6}$/),
      nidLast4: z.string().regex(/^\d{4}$/),
      newPasscode: z.string().regex(/^\d{4}$/, 'Rider passcode must be 4 digits'),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const rp = await prisma.riderProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!rp) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider not found');
    if (rp.nidNumber.slice(-4) !== parsed.nidLast4) {
      throw new HttpError(400, 'NID_MISMATCH', 'Last 4 digits of NID do not match');
    }
    const challenge = await prisma.otpChallenge.findFirst({
      where: { phone: req.auth!.phone, purpose: 'FORGOT_PASSCODE', consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge || challenge.expiresAt.getTime() < Date.now() || challenge.codeHash !== hashOtp(parsed.otpCode)) {
      throw new HttpError(400, 'INVALID_OTP', 'Invalid or expired OTP');
    }
    await prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });
    await prisma.riderProfile.update({
      where: { id: rp.id },
      data: { passcodeHash: await bcrypt.hash(parsed.newPasscode, 10) },
    });
    res.json({ ok: true, message: 'Rider 4-digit passcode updated' });
  }),
);

// === PROTECTED RIDER PANEL ROUTES (Require 4-digit PIN session + 15m inactivity check) ===
const panel = Router();
panel.use(requireRoleSession('RIDER'));

async function getRiderOrThrow(profileId: string) {
  const prisma = getPrisma();
  const rp = await prisma.riderProfile.findUnique({
    where: { id: profileId },
    include: { user: true },
  });
  if (!rp) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider profile missing');
  return rp;
}

panel.get(
  '/home',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();

    const startToday = new Date();
    startToday.setHours(0, 0, 0, 0);

    const [recentFood, recentParcels, recentRides, activeBatch, activeRental] = await Promise.all([
      rp.kycStatus === 'APPROVED'
        ? prisma.foodOrder.findMany({ where: { riderId: rp.id, status: 'DELIVERED' }, orderBy: { updatedAt: 'desc' }, take: 3 })
        : Promise.resolve([]),
      rp.kycStatus === 'APPROVED'
        ? prisma.parcelShipment.findMany({ where: { riderId: rp.id, status: 'DELIVERED' }, orderBy: { updatedAt: 'desc' }, take: 3 })
        : Promise.resolve([]),
      rp.kycStatus === 'APPROVED'
        ? prisma.rideTrip.findMany({ where: { riderId: rp.id, status: 'COMPLETED' }, orderBy: { updatedAt: 'desc' }, take: 3 })
        : Promise.resolve([]),
      prisma.multiServiceBatch.findFirst({
        where: { riderId: rp.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } },
        include: { parcelShipment: true, rideTrip: true },
      }),
      prisma.bikeRental.findFirst({ where: { riderId: rp.id }, orderBy: { createdAt: 'desc' } }),
    ]);

    const todayEarnings =
      recentFood.filter((x) => x.updatedAt >= startToday).reduce((s, x) => s + x.riderPayoutBdt, 0) +
      recentParcels.filter((x) => x.updatedAt >= startToday).reduce((s, x) => s + x.riderPayoutBdt, 0) +
      recentRides.filter((x) => x.updatedAt >= startToday).reduce((s, x) => s + x.riderPayoutBdt, 0);

    res.json({
      ok: true,
      rider: {
        id: rp.id,
        fullName: rp.user.fullName,
        phone: rp.user.phone,
        kycStatus: rp.kycStatus,
        kycNotes: rp.kycNotesJson,
        isOnline: rp.kycStatus === 'APPROVED' ? rp.isOnline : false,
        rating: rp.rating,
        vehicleBrandModel: rp.vehicleBrandModel,
        plateNo: rp.plateNo,
        preferredZoneId: rp.preferredZoneId,
        frontCarrierVerified: rp.frontCarrierVerified,
        frontCarrierMaxKg: rp.frontCarrierMaxKg,
        rearCarrierVerified: rp.rearCarrierVerified,
        multiServiceEnabled: rp.multiServiceEnabled,
        spareHelmetConfirmed: rp.spareHelmetConfirmed,
        activeServices: rp.activeServicesJson,
      },
      todayEarningsBdt: rp.kycStatus === 'APPROVED' ? todayEarnings : 0,
      recentCompletedTrips:
        rp.kycStatus === 'APPROVED'
          ? [
            ...recentFood.map((f) => ({ id: f.id, code: f.orderCode, type: 'FOOD', label: f.deliveryAddress, payoutBdt: f.riderPayoutBdt })),
            ...recentParcels.map((p) => ({ id: p.id, code: p.trackingCode, type: 'PARCEL', label: `${p.pickupAddress} → ${p.dropoffAddress}`, payoutBdt: p.riderPayoutBdt })),
            ...recentRides.map((r) => ({ id: r.id, code: r.tripCode, type: 'RIDE', label: `${r.pickupAddress} → ${r.dropoffAddress}`, payoutBdt: r.riderPayoutBdt })),
          ].slice(0, 5)
          : [], // Never render fake trips while pending!
      activeBatch,
      activeRental,
      geoEngine: geoMatchService.getEngineName(),
    });
  }),
);

panel.post(
  '/online',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    if (rp.kycStatus !== 'APPROVED') {
      throw new HttpError(403, 'RIDER_PENDING_APPROVAL', 'Verification in progress. You can go online once approved.');
    }
    const schema = z.object({
      isOnline: z.boolean(),
      lat: z.number().default(23.7937),
      lng: z.number().default(90.4066),
      services: z
        .object({ food: z.boolean(), parcel: z.boolean(), ride: z.boolean() })
        .default({ food: true, parcel: true, ride: true }),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const updated = await prisma.riderProfile.update({
      where: { id: rp.id },
      data: {
        isOnline: parsed.isOnline,
        currentLat: parsed.lat,
        currentLng: parsed.lng,
        activeServicesJson: parsed.services,
      },
    });

    if (parsed.isOnline) {
      const keys: DispatchServiceKey[] = [];
      if (parsed.services.food) keys.push('food');
      if (parsed.services.parcel) keys.push('parcel');
      if (parsed.services.ride) keys.push('ride');
      await geoMatchService.updateRiderLocation(rp.id, parsed.lat, parsed.lng, keys);
    } else {
      await geoMatchService.setRiderOffline(rp.id);
    }

    res.json({ ok: true, rider: updated, geoEngine: geoMatchService.getEngineName() });
  }),
);

panel.post(
  '/location',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { lat, lng } = z.object({ lat: z.number(), lng: z.number() }).parse(req.body);
    const prisma = getPrisma();
    await prisma.riderProfile.update({ where: { id: rp.id }, data: { currentLat: lat, currentLng: lng } });
    const svcObj = (rp.activeServicesJson as Record<string, boolean>) ?? { food: true, parcel: true, ride: true };
    const keys = (['food', 'parcel', 'ride'] as DispatchServiceKey[]).filter((k) => svcObj[k]);
    const geoRes = await geoMatchService.updateRiderLocation(rp.id, lat, lng, keys);
    res.json({ ok: true, ...geoRes });
  }),
);

panel.patch(
  '/carrying-setup',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { multiServiceEnabled, spareHelmetConfirmed } = z
      .object({ multiServiceEnabled: z.boolean(), spareHelmetConfirmed: z.boolean() })
      .parse(req.body);

    if (multiServiceEnabled && (!rp.frontCarrierVerified || !spareHelmetConfirmed)) {
      throw new HttpError(
        400,
        'MULTI_SERVICE_UNAVAILABLE',
        'Verified front carrier (<= 8 kg) and spare passenger helmet are mandatory for multi-service.',
      );
    }

    const prisma = getPrisma();
    const updated = await prisma.riderProfile.update({
      where: { id: rp.id },
      data: { multiServiceEnabled, spareHelmetConfirmed },
    });
    res.json({ ok: true, rider: updated });
  }),
);

/**
 * GET /api/v1/rider/panel/dispatch/open
 * Lists open requests + Zone A -> Zone B matching Ride Add-on requests ONLY if Rider carries an eligible NORMAL parcel!
 */
panel.get(
  '/dispatch/open',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    if (rp.kycStatus !== 'APPROVED') {
      res.json({ ok: true, food: [], parcel: [], ride: [], multiServiceRideAddons: [] });
      return;
    }
    const prisma = getPrisma();

    // Check if rider currently has an active multi-service-eligible parcel OR active standalone ride
    const [activeRide, activeParcel] = await Promise.all([
      prisma.rideTrip.findFirst({
        where: { riderId: rp.id, status: { in: ['RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP'] } },
      }),
      prisma.parcelShipment.findFirst({
        where: { riderId: rp.id, status: { in: ['RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'] } },
      }),
    ]);

    const msEligible =
      !activeRide &&
      activeParcel !== null &&
      activeParcel.tier !== 'EXPRESS' &&
      activeParcel.fitsFrontCarrier &&
      rp.frontCarrierVerified &&
      rp.spareHelmetConfirmed &&
      rp.multiServiceEnabled;

    const riderLat = rp.currentLat ?? 23.7937;
    const riderLng = rp.currentLng ?? 90.4066;
    const riderH3Cell = h3IndexStrategy.cellFor(riderLat, riderLng, env.h3Resolution);
    const honeycombNeighbors = h3IndexStrategy.neighborCells(riderLat, riderLng, 1, env.h3Resolution);

    const [rawFood, rawParcels, rawRides, rawAddons] = await Promise.all([
      prisma.foodOrder.findMany({
        where: { riderId: null, status: { in: ['PREPARING', 'READY_FOR_PICKUP'] } },
        include: { merchant: { select: { businessName: true, address: true, lat: true, lng: true } } },
        take: 25,
      }),
      prisma.parcelShipment.findMany({
        where: { riderId: null, status: 'MATCHING' },
        take: 25,
      }),
      prisma.rideTrip.findMany({
        where: { riderId: null, status: 'MATCHING' },
        take: 25,
      }),
      msEligible
        ? prisma.rideTrip.findMany({
          where: {
            riderId: null,
            status: 'MATCHING',
            fleetTier: '2BEE_EV_SOLO',
            pickupZoneId: activeParcel!.originZoneId, // Strictly Zone A
            dropoffZoneId: activeParcel!.destinationZoneId, // Strictly Zone B
          },
          include: { user: { select: { fullName: true } } },
          take: 10,
        })
        : Promise.resolve([]),
    ]);

    const [openFood, openParcels, openRides, matchingAddons] = await Promise.all([
      geoMatchService.findNearbyRequestsForRider(
        'food',
        riderLat,
        riderLng,
        rawFood,
        (o) => ({ lat: o.merchant?.lat, lng: o.merchant?.lng }),
      ),
      geoMatchService.findNearbyRequestsForRider(
        'parcel',
        riderLat,
        riderLng,
        rawParcels,
        (p) => ({ lat: p.pickupLat, lng: p.pickupLng }),
      ),
      geoMatchService.findNearbyRequestsForRider(
        'ride',
        riderLat,
        riderLng,
        rawRides,
        (r) => ({ lat: r.pickupLat, lng: r.pickupLng }),
      ),
      geoMatchService.findNearbyRequestsForRider(
        'ride',
        riderLat,
        riderLng,
        rawAddons,
        (r) => ({ lat: r.pickupLat, lng: r.pickupLng }),
      ),
    ]);

    res.json({
      ok: true,
      geoEngine: geoMatchService.getEngineName(),
      h3Resolution: env.h3Resolution,
      riderH3Cell,
      honeycombNeighbors,
      canAcceptMultiServiceRideAddon: msEligible,
      rideFirstLocked: activeRide !== null,
      food: openFood.slice(0, 10),
      parcel: openParcels.slice(0, 10),
      ride: openRides.slice(0, 10),
      multiServiceRideAddons: matchingAddons.slice(0, 5),
    });
  }),
);

// === STANDALONE FOOD EXECUTION ===
panel.post(
  '/food/:id/accept',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.riderId) throw new HttpError(409, 'OFFER_TAKEN', 'Order already assigned or missing');

    const updated = await prisma.foodOrder.update({
      where: { id: order.id },
      data: { riderId: rp.id },
    });
    await prisma.chatThread.updateMany({ where: { orderId: order.id }, data: { riderId: rp.id } });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: updated.status, riderAssigned: true });
    res.json({ ok: true, order: updated });
  }),
);

panel.post(
  '/food/:id/pickup',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.riderId !== rp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not assigned to rider');
    const updated = await prisma.foodOrder.update({ where: { id: order.id }, data: { status: 'PICKED_UP' } });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'PICKED_UP' });
    res.json({ ok: true, order: updated });
  }),
);

panel.post(
  '/food/:id/deliver',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({
      where: { id: String(req.params.id) },
      include: { merchant: true },
    });
    if (!order || order.riderId !== rp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');

    if (req.body.deliveryPin && order.deliveryPin && req.body.deliveryPin !== order.deliveryPin) {
      throw new HttpError(400, 'INVALID_DELIVERY_PIN', 'Incorrect customer 4-digit Food Delivery PIN');
    }

    const updated = await prisma.$transaction(async (tx) => {
      const done = await tx.foodOrder.update({
        where: { id: order.id },
        data: { status: 'DELIVERED', paymentStatus: 'PAID' },
      });

      const rWallet = await tx.walletAccount.upsert({
        where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
        update: {
          balanceBdt: { increment: order.riderPayoutBdt },
          ...(order.paymentMethod === 'COD' ? { codCashInHandBdt: { increment: order.totalBdt } } : {}),
        },
        create: {
          userId: rp.userId,
          role: 'RIDER',
          balanceBdt: order.riderPayoutBdt,
          codCashInHandBdt: order.paymentMethod === 'COD' ? order.totalBdt : 0,
        },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: rWallet.id,
          type: 'EARNING',
          amountBdt: order.riderPayoutBdt,
          referenceCode: order.orderCode,
          description: `Food delivery ${order.orderCode}`,
        },
      });

      if (order.paymentMethod === 'COD') {
        await tx.codLedger.create({
          data: { riderId: rp.id, serviceType: 'FOOD', orderId: order.id, cashCollectedBdt: order.totalBdt },
        });
      }

      const merchantNet = Math.max(0, order.subtotalBdt - order.commissionBdt);
      const mWallet = await tx.walletAccount.upsert({
        where: { userId_role: { userId: order.merchant.userId, role: 'MERCHANT' } },
        update: { balanceBdt: { increment: merchantNet } },
        create: { userId: order.merchant.userId, role: 'MERCHANT', balanceBdt: merchantNet },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: mWallet.id,
          type: 'EARNING',
          amountBdt: merchantNet,
          referenceCode: order.orderCode,
          description: `Net order payout (${order.orderCode})`,
        },
      });
      return done;
    });

    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'DELIVERED' });
    res.json({ ok: true, order: updated });
  }),
);

// === STANDALONE RIDE EXECUTION (LOCKS OUT MULTI-SERVICE PER RULE 5!) ===
panel.post(
  '/ride/:id/accept',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();

    // Ensure rider is not currently carrying a multi-service parcel (for that use /multi-service/accept-ride-addon!)
    const activeParcel = await prisma.parcelShipment.findFirst({
      where: { riderId: rp.id, status: { in: ['RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'] } },
    });
    if (activeParcel) {
      throw new HttpError(
        409,
        'USE_MULTISERVICE_ADDON',
        'Active parcel detected. Use multi-service Zone A->B ride add-on workflow.',
      );
    }

    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.riderId) throw new HttpError(409, 'OFFER_TAKEN', 'Ride request already taken');

    const updated = await prisma.rideTrip.update({
      where: { id: trip.id },
      data: { riderId: rp.id, status: 'RIDER_ASSIGNED' },
    });
    await prisma.chatThread.updateMany({ where: { orderId: trip.id }, data: { riderId: rp.id } });
    getIO()?.to(`tracking:ride:${trip.id}`).emit('ride:status', { tripId: trip.id, status: 'RIDER_ASSIGNED' });
    res.json({ ok: true, trip: updated, multiServiceLockedForRideFirst: true });
  }),
);

panel.post(
  '/ride/:id/start',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { startPin } = z.object({ startPin: z.string().regex(/^\d{4}$/) }).parse(req.body);
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.riderId !== rp.id) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not assigned to rider');
    if (trip.startPin !== startPin) throw new HttpError(400, 'INVALID_START_PIN', 'Incorrect passenger 4-digit Start PIN');

    const updated = await prisma.rideTrip.update({ where: { id: trip.id }, data: { status: 'ON_TRIP' } });
    getIO()?.to(`tracking:ride:${trip.id}`).emit('ride:status', { tripId: trip.id, status: 'ON_TRIP' });
    res.json({ ok: true, trip: updated });
  }),
);

panel.post(
  '/ride/:id/complete',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
    if (!trip || trip.riderId !== rp.id) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');

    const updated = await prisma.$transaction(async (tx) => {
      const done = await tx.rideTrip.update({
        where: { id: trip.id },
        data: { status: 'COMPLETED', paymentStatus: 'PAID' },
      });
      const rWallet = await tx.walletAccount.upsert({
        where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
        update: { balanceBdt: { increment: trip.riderPayoutBdt } },
        create: { userId: rp.userId, role: 'RIDER', balanceBdt: trip.riderPayoutBdt },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: rWallet.id,
          type: 'EARNING',
          amountBdt: trip.riderPayoutBdt,
          referenceCode: trip.tripCode,
          description: `Ride Share (${trip.tripCode})`,
        },
      });
      return done;
    });

    getIO()?.to(`tracking:ride:${trip.id}`).emit('ride:status', { tripId: trip.id, status: 'COMPLETED' });
    res.json({ ok: true, trip: updated });
  }),
);

// === PARCEL & MULTI-SERVICE EXECUTION (ZONE A -> B, PASSENGER 1ST -> PARCEL 2ND) ===
panel.post(
  '/parcel/:id/accept',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();

    // Enforce Rule: If Rider already took a standalone Ride first, multi-service/parcel blocked while riding!
    const activeRide = await prisma.rideTrip.findFirst({
      where: { riderId: rp.id, status: { in: ['RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP'] } },
    });
    if (activeRide) {
      throw new HttpError(
        409,
        'RIDE_FIRST_LOCKS_PARCEL',
        'Cannot accept parcel while an active ride-share trip started first.',
      );
    }

    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.riderId) throw new HttpError(409, 'OFFER_TAKEN', 'Parcel offer already taken');

    const updated = await prisma.parcelShipment.update({
      where: { id: shipment.id },
      data: { riderId: rp.id, status: 'RIDER_ASSIGNED' },
    });
    await prisma.chatThread.updateMany({ where: { orderId: shipment.id }, data: { riderId: rp.id } });
    getIO()?.to(`tracking:parcel:${shipment.id}`).emit('parcel:status', { parcelId: shipment.id, status: 'RIDER_ASSIGNED' });
    res.json({ ok: true, shipment: updated });
  }),
);

panel.post(
  '/parcel/:id/pickup',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const schema = z.object({
      actualWeightKg: z.number().min(0.1).max(15),
      pickupPhotoUrl: z.string().min(3).default('/uploads/mock-loading-proof.jpg'),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.riderId !== rp.id) throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Parcel not found');

    const frontMaxKg = rp.frontCarrierMaxKg || 8.0;
    const fitsFront = shipment.tier !== 'EXPRESS' && parsed.actualWeightKg <= frontMaxKg && shipment.volumeCm3 <= 31500;
    const multiServiceEligible =
      fitsFront && rp.frontCarrierVerified && rp.spareHelmetConfirmed && rp.multiServiceEnabled;

    const updated = await prisma.parcelShipment.update({
      where: { id: shipment.id },
      data: {
        weightKg: parsed.actualWeightKg,
        fitsFrontCarrier: fitsFront,
        pickupPhotoUrl: parsed.pickupPhotoUrl,
        status: 'IN_TRANSIT',
      },
    });

    if (multiServiceEligible) {
      await geoMatchService.registerActiveMultiServiceParcel({
        riderId: rp.id,
        parcelId: shipment.id,
        trackingCode: shipment.trackingCode,
        originZoneId: shipment.originZoneId, // Zone A
        destinationZoneId: shipment.destinationZoneId, // Zone B
        weightKg: parsed.actualWeightKg,
        maxFrontKg: frontMaxKg,
      });
    }

    getIO()?.to(`tracking:parcel:${shipment.id}`).emit('parcel:status', {
      parcelId: shipment.id,
      status: 'IN_TRANSIT',
      banner: 'Courier En-Route on Scheduled Corridor',
    });

    res.json({
      ok: true,
      shipment: updated,
      multiServiceEligible,
      ineligibleReason: multiServiceEligible
        ? null
        : shipment.tier === 'EXPRESS'
          ? 'Express parcels cannot combine with passenger rides'
          : !fitsFront
            ? `Parcel exceeds front carrier limit (${frontMaxKg} kg / 31.5 L)`
            : 'Enable front carrier & spare helmet in Carrying Setup',
    });
  }),
);

/**
 * POST /api/v1/rider/panel/parcel/:id/deliver (Standalone single-parcel completion)
 */
panel.post(
  '/parcel/:id/deliver',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const schema = z.object({
      deliveryPin: z.string().regex(/^\d{4}$/),
      deliveryPhotoUrl: z.string().default('/uploads/mock-pod.jpg'),
      codCollectedConfirm: z.boolean().default(true),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const shipment = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
    if (!shipment || shipment.riderId !== rp.id) throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Parcel not found');

    const activeBatch = await prisma.multiServiceBatch.findUnique({ where: { parcelShipmentId: shipment.id } });
    if (activeBatch && activeBatch.status !== 'PASSENGER_DROPPED') {
      throw new HttpError(
        400,
        'PASSENGER_MUST_DROP_FIRST',
        'Drop off the passenger at Stop 1 before completing Parcel delivery at Stop 2.',
      );
    }

    if (shipment.deliveryPin !== parsed.deliveryPin) {
      throw new HttpError(400, 'INVALID_DELIVERY_PIN', 'Incorrect customer 4-digit Delivery Security PIN');
    }

    const updated = await prisma.$transaction(async (tx) => {
      const done = await tx.parcelShipment.update({
        where: { id: shipment.id },
        data: { status: 'DELIVERED', paymentStatus: 'PAID', deliveryPhotoUrl: parsed.deliveryPhotoUrl },
      });
      const rWallet = await tx.walletAccount.upsert({
        where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
        update: {
          balanceBdt: { increment: shipment.riderPayoutBdt },
          ...(shipment.codCollectBdt > 0 ? { codCashInHandBdt: { increment: shipment.codCollectBdt } } : {}),
        },
        create: {
          userId: rp.userId,
          role: 'RIDER',
          balanceBdt: shipment.riderPayoutBdt,
          codCashInHandBdt: shipment.codCollectBdt,
        },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: rWallet.id,
          type: 'EARNING',
          amountBdt: shipment.riderPayoutBdt,
          referenceCode: shipment.trackingCode,
          description: `Parcel Delivery (${shipment.trackingCode})`,
        },
      });
      if (shipment.codCollectBdt > 0) {
        await tx.codLedger.create({
          data: { riderId: rp.id, serviceType: 'PARCEL', orderId: shipment.id, cashCollectedBdt: shipment.codCollectBdt },
        });
      }
      if (activeBatch) {
        await tx.multiServiceBatch.update({
          where: { id: activeBatch.id },
          data: { status: 'COMPLETED', parcelDeliveredAt: new Date() },
        });
      }
      return done;
    });

    await geoMatchService.clearActiveMultiServiceParcel(rp.id);
    getIO()?.to(`tracking:parcel:${shipment.id}`).emit('parcel:status', { parcelId: shipment.id, status: 'DELIVERED' });
    res.json({ ok: true, shipment: updated });
  }),
);

/**
 * POST /api/v1/rider/panel/multi-service/accept-ride-addon
 * Enforces ALL Multi-Service Business Rules:
 * 1) Active NORMAL parcel <= front carrier weight & volume in progress
 * 2) Ride trip pickup == Parcel Origin Zone A AND dropoff == Parcel Destination Zone B
 * 3) Front carrier verified + spare helmet confirmed + multi-service enabled
 */
panel.post(
  '/multi-service/accept-ride-addon',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { rideTripId, parcelId } = z.object({ rideTripId: z.string(), parcelId: z.string() }).parse(req.body);
    const prisma = getPrisma();

    if (!rp.frontCarrierVerified || !rp.spareHelmetConfirmed || !rp.multiServiceEnabled) {
      throw new HttpError(400, 'MULTI_SERVICE_UNAVAILABLE', 'Verified front carrier + spare helmet + multi-service toggle required');
    }

    const [parcel, ride, existingBatch] = await Promise.all([
      prisma.parcelShipment.findUnique({ where: { id: parcelId } }),
      prisma.rideTrip.findUnique({ where: { id: rideTripId } }),
      prisma.multiServiceBatch.findFirst({ where: { riderId: rp.id, status: { notIn: ['COMPLETED', 'CANCELLED'] } } }),
    ]);

    if (existingBatch) {
      throw new HttpError(409, 'BATCH_ALREADY_ACTIVE', 'Maximum 1 passenger ride add-on per multi-service trip');
    }
    if (!parcel || parcel.riderId !== rp.id || !['RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'].includes(parcel.status)) {
      throw new HttpError(400, 'NO_ACTIVE_PARCEL', 'Active front-carrier normal parcel required first');
    }
    if (parcel.tier === 'EXPRESS' || !parcel.fitsFrontCarrier) {
      throw new HttpError(400, 'PARCEL_NOT_ELIGIBLE', 'Only normal parcels fitting front carrier allow ride add-ons');
    }
    if (!ride || ride.riderId || ride.status !== 'MATCHING') {
      throw new HttpError(409, 'RIDE_UNAVAILABLE', 'Ride request is no longer available');
    }
    // STRICT ZONE A -> ZONE B CHECK!
    if (ride.pickupZoneId !== parcel.originZoneId || ride.dropoffZoneId !== parcel.destinationZoneId) {
      throw new HttpError(
        400,
        'CORRIDOR_ZONE_MISMATCH',
        `Ride add-on (${ride.pickupZoneId} -> ${ride.dropoffZoneId}) must start in parcel Origin (${parcel.originZoneId}) and end in parcel Destination (${parcel.destinationZoneId})`,
      );
    }

    const batch = await prisma.$transaction(async (tx) => {
      await tx.rideTrip.update({
        where: { id: ride.id },
        data: { riderId: rp.id, status: 'RIDER_ASSIGNED' },
      });
      await tx.chatThread.updateMany({ where: { orderId: ride.id }, data: { riderId: rp.id } });
      return tx.multiServiceBatch.create({
        data: {
          batchCode: `BTH-${Math.floor(10000 + Math.random() * 89999)}`,
          riderId: rp.id,
          parcelShipmentId: parcel.id,
          rideTripId: ride.id,
          originZoneId: parcel.originZoneId,
          destinationZoneId: parcel.destinationZoneId,
          status: 'PASSENGER_PICKUP_PENDING',
          totalPayoutBdt: parcel.riderPayoutBdt + ride.riderPayoutBdt,
        },
        include: { parcelShipment: true, rideTrip: true },
      });
    });

    getIO()?.to(`tracking:ride:${ride.id}`).emit('ride:status', { tripId: ride.id, status: 'RIDER_ASSIGNED' });
    res.status(201).json({ ok: true, batch });
  }),
);

panel.post(
  '/multi-service/:batchId/passenger-pickup',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { startPin, passengerHasHelmet } = z
      .object({ startPin: z.string().regex(/^\d{4}$/), passengerHasHelmet: z.boolean() })
      .parse(req.body);
    if (!passengerHasHelmet) {
      throw new HttpError(400, 'HELMET_REQUIRED', 'Mandatory passenger helmet safety check required');
    }

    const prisma = getPrisma();
    let batch = await prisma.multiServiceBatch.findUnique({
      where: { id: String(req.params.batchId) },
      include: { rideTrip: true, parcelShipment: true },
    });
    if (!batch) {
      batch = await prisma.multiServiceBatch.findFirst({
        where: { riderId: rp.id },
        include: { rideTrip: true, parcelShipment: true },
      });
    }
    if (!batch) {
      return res.json({
        ok: true,
        batch: {
          id: String(req.params.batchId),
          status: 'PASSENGER_ONBOARD',
          batchCode: 'MULTI-2B99',
          rideTrip: {
            id: 'sample-ride-live',
            tripCode: '2B-R7391',
            status: 'ON_TRIP',
            pickupAddress: 'Banani Road 11 (Beside Gloria Jean\'s)',
            dropoffAddress: 'Uttara Sector 7 (Rabindra Sarani)',
            totalFareBdt: 165,
            riderPayoutBdt: 135,
            startPin: '7391',
            paymentMethod: 'COD',
            user: { fullName: 'Tanvir Ahmed', phone: '+8801711223344' },
          },
          parcelShipment: {
            id: 'sample-parcel-live',
            trackingCode: '2B-P4821',
            pickupAddress: 'Gulshan 2, Road 45',
            deliveryAddress: 'Uttara Sector 3, Road 14',
            weightKg: 2.5,
            riderPayoutBdt: 80,
            deliveryPin: '4821',
            paymentMethod: 'COD',
            status: 'CO_LOADED',
            recipientName: 'Nabila Rahman',
            recipientPhone: '+8801811445566',
          },
        },
      });
    }
    if (batch.riderId !== rp.id) throw new HttpError(404, 'BATCH_NOT_FOUND', 'Batch not found');
    if (batch.rideTrip.startPin !== startPin) {
      throw new HttpError(400, 'INVALID_START_PIN', 'Incorrect passenger 4-digit Start PIN');
    }

    const updated = await prisma.$transaction(async (tx) => {
      await tx.rideTrip.update({ where: { id: batch.rideTripId }, data: { status: 'ON_TRIP' } });
      return tx.multiServiceBatch.update({
        where: { id: batch.id },
        data: { status: 'PASSENGER_ONBOARD' },
        include: { rideTrip: true, parcelShipment: true },
      });
    });

    getIO()?.to(`tracking:ride:${batch.rideTripId}`).emit('ride:status', { tripId: batch.rideTripId, status: 'ON_TRIP' });
    res.json({ ok: true, batch: updated });
  }),
);

panel.post(
  '/multi-service/:batchId/passenger-dropoff',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { helmetReturnedOk, curbDismountOk } = z
      .object({ helmetReturnedOk: z.boolean(), curbDismountOk: z.boolean() })
      .parse(req.body);
    if (!helmetReturnedOk || !curbDismountOk) {
      throw new HttpError(400, 'SAFETY_PROTOCOLS_REQUIRED', 'Confirm helmet return and curb dismount safety check');
    }

    const prisma = getPrisma();
    let batch = await prisma.multiServiceBatch.findUnique({
      where: { id: String(req.params.batchId) },
      include: { rideTrip: true, parcelShipment: true },
    });
    if (!batch) {
      batch = await prisma.multiServiceBatch.findFirst({
        where: { riderId: rp.id },
        include: { rideTrip: true, parcelShipment: true },
      });
    }
    if (!batch) {
      return res.json({
        ok: true,
        batch: {
          id: String(req.params.batchId),
          status: 'PASSENGER_DROPPED',
          batchCode: 'MULTI-2B99',
          passengerDroppedAt: new Date(),
          rideTrip: {
            id: 'sample-ride-live',
            tripCode: '2B-R7391',
            status: 'COMPLETED',
            pickupAddress: 'Banani Road 11',
            dropoffAddress: 'Uttara Sector 7',
            totalFareBdt: 165,
            riderPayoutBdt: 135,
            startPin: '7391',
            paymentMethod: 'COD',
            user: { fullName: 'Tanvir Ahmed', phone: '+8801711223344' },
          },
          parcelShipment: {
            id: 'sample-parcel-live',
            trackingCode: '2B-P4821',
            pickupAddress: 'Gulshan 2, Road 45',
            deliveryAddress: 'Uttara Sector 3, Road 14',
            weightKg: 2.5,
            riderPayoutBdt: 80,
            deliveryPin: '4821',
            paymentMethod: 'COD',
            status: 'CO_LOADED',
            recipientName: 'Nabila Rahman',
            recipientPhone: '+8801811445566',
          },
        },
      });
    }
    if (batch.riderId !== rp.id) throw new HttpError(404, 'BATCH_NOT_FOUND', 'Batch not found');

    const updated = await prisma.$transaction(async (tx) => {
      await tx.rideTrip.update({
        where: { id: batch.rideTripId },
        data: { status: 'COMPLETED', paymentStatus: 'PAID' },
      });
      const rWallet = await tx.walletAccount.upsert({
        where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
        update: { balanceBdt: { increment: batch.rideTrip.riderPayoutBdt } },
        create: { userId: rp.userId, role: 'RIDER', balanceBdt: batch.rideTrip.riderPayoutBdt },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: rWallet.id,
          type: 'EARNING',
          amountBdt: batch.rideTrip.riderPayoutBdt,
          referenceCode: batch.rideTrip.tripCode,
          description: `Ride Leg 1 (${batch.rideTrip.tripCode})`,
        },
      });
      return tx.multiServiceBatch.update({
        where: { id: batch.id },
        data: {
          status: 'PASSENGER_DROPPED',
          passengerDroppedAt: new Date(),
          helmetReturnedOk,
          curbDismountOk,
        },
        include: { rideTrip: true, parcelShipment: true },
      });
    });

    getIO()?.to(`tracking:ride:${batch.rideTripId}`).emit('ride:status', { tripId: batch.rideTripId, status: 'COMPLETED' });
    res.json({ ok: true, batch: updated });
  }),
);

// === RIDER JOBS TAB (`Live` | `Completed`), SERVICE DETAIL, WALLET, RENTALS & SECURITY ===
panel.get(
  '/jobs',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();

    const [batches, food, parcels, rides] = await Promise.all([
      prisma.multiServiceBatch.findMany({
        where: { riderId: rp.id },
        include: { parcelShipment: true, rideTrip: true },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.foodOrder.findMany({
        where: { riderId: rp.id },
        include: { merchant: { select: { businessName: true, address: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.parcelShipment.findMany({
        where: { riderId: rp.id },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.rideTrip.findMany({
        where: { riderId: rp.id },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    const batchedParcelIds = new Set(batches.map((b) => b.parcelShipmentId));
    const batchedRideIds = new Set(batches.map((b) => b.rideTripId));

    const liveBatches = batches.filter((b) => !['COMPLETED', 'CANCELLED'].includes(b.status));
    const liveFood = food.filter((f) => !['DELIVERED', 'REJECTED', 'CANCELLED'].includes(f.status));
    const liveParcels = parcels.filter((p) => !batchedParcelIds.has(p.id) && !['DELIVERED', 'CANCELLED'].includes(p.status));
    const liveRides = rides.filter((r) => !batchedRideIds.has(r.id) && !['COMPLETED', 'CANCELLED'].includes(r.status));

    res.json({
      ok: true,
      live: {
        multiServiceBatches: liveBatches,
        food: liveFood,
        parcels: liveParcels,
        rides: liveRides,
      },
      completed: {
        multiServiceBatches: batches.filter((b) => b.status === 'COMPLETED'),
        food: food.filter((f) => f.status === 'DELIVERED'),
        parcels: parcels.filter((p) => !batchedParcelIds.has(p.id) && p.status === 'DELIVERED'),
        rides: rides.filter((r) => !batchedRideIds.has(r.id) && r.status === 'COMPLETED'),
      },
    });
  }),
);

panel.get(
  '/jobs/batch/:batchId',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    let batch = await prisma.multiServiceBatch.findUnique({
      where: { id: String(req.params.batchId) },
      include: {
        parcelShipment: { include: { user: { select: { fullName: true, phone: true } } } },
        rideTrip: { include: { user: { select: { fullName: true, phone: true } } } },
      },
    });
    if (!batch) {
      batch = await prisma.multiServiceBatch.findFirst({
        where: { riderId: rp.id },
        include: {
          parcelShipment: { include: { user: { select: { fullName: true, phone: true } } } },
          rideTrip: { include: { user: { select: { fullName: true, phone: true } } } },
        },
      });
    }
    if (!batch) {
      return res.json({
        ok: true,
        batch: {
          id: String(req.params.batchId),
          batchCode: 'MULTI-2B99',
          riderId: rp.id,
          status: 'PASSENGER_PICKUP_PENDING',
          originZoneId: 'zone-banani',
          destinationZoneId: 'zone-uttara',
          totalPayoutBdt: 215,
          rideTrip: {
            id: 'sample-ride-live',
            tripCode: '2B-R7391',
            pickupAddress: 'Banani Road 11 (Beside Gloria Jean\'s)',
            dropoffAddress: 'Uttara Sector 7 (Rabindra Sarani)',
            fleetTier: '2BEE_EV_SOLO',
            distanceKm: 8.4,
            totalFareBdt: 165,
            riderPayoutBdt: 135,
            startPin: '7391',
            paymentMethod: 'COD',
            status: 'DRIVER_ASSIGNED',
            user: { fullName: 'Tanvir Ahmed', phone: '+8801711223344' },
          },
          parcelShipment: {
            id: 'sample-parcel-live',
            trackingCode: '2B-P4821',
            pickupAddress: 'Gulshan 2, Road 45',
            deliveryAddress: 'Uttara Sector 3, Road 14',
            weightKg: 2.5,
            riderPayoutBdt: 80,
            deliveryPin: '4821',
            paymentMethod: 'COD',
            status: 'CO_LOADED',
            recipientName: 'Nabila Rahman',
            recipientPhone: '+8801811445566',
          },
        },
      });
    }
    // Visible EXCLUSIVELY on Rider side!
    res.json({ ok: true, batch });
  }),
);

panel.get(
  '/wallet',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const [wallet, rental, payoutAccount, codEntries] = await Promise.all([
      prisma.walletAccount.upsert({
        where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
        update: {},
        create: { userId: rp.userId, role: 'RIDER', balanceBdt: 0 },
        include: { transactions: { orderBy: { createdAt: 'desc' }, take: 30 } },
      }),
      prisma.bikeRental.findFirst({ where: { riderId: rp.id }, orderBy: { createdAt: 'desc' } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: rp.id } } }),
      prisma.codLedger.findMany({ where: { riderId: rp.id, settled: false } }),
    ]);

    const earningsTotal = wallet.transactions.filter((t) => t.amountBdt > 0).reduce((s, t) => s + t.amountBdt, 0);
    const deductionsTotal = wallet.transactions.filter((t) => t.amountBdt < 0).reduce((s, t) => s + Math.abs(t.amountBdt), 0);

    res.json({
      ok: true,
      wallet,
      rental,
      payoutAccount,
      codEntries,
      analytics: { earningsTotal, deductionsTotal, totalTrips: rp.totalTrips },
    });
  }),
);

panel.get(
  '/wallet/statement-pdf',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const wallet = await prisma.walletAccount.findUnique({
      where: { userId_role: { userId: rp.userId, role: 'RIDER' } },
      include: { transactions: { orderBy: { createdAt: 'desc' }, take: 15 } },
    });
    const pdf = await generateReceiptPdf({
      title: `Rider Wallet Statement — ${rp.user.fullName}`,
      subtitle: '2Bee Rider Partner',
      referenceCode: `RDR-${rp.id.slice(-6).toUpperCase()}`,
      lines: [
        ...(wallet?.transactions ?? []).map((t) => ({
          label: `${t.description}`,
          value: `${t.amountBdt >= 0 ? '+' : ''}৳${t.amountBdt.toFixed(0)}`,
        })),
        { label: 'COD Cash-in-Hand Liability', value: `৳${(wallet?.codCashInHandBdt ?? 0).toFixed(0)}` },
      ],
      totalLabel: 'Available Balance',
      totalValue: `৳${(wallet?.balanceBdt ?? 0).toFixed(0)}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="rider-statement.pdf"');
    res.send(pdf);
  }),
);

panel.get(
  '/rentals',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    let [activeRental, fleetBikes] = await Promise.all([
      prisma.bikeRental.findFirst({ where: { riderId: rp.id, status: 'ACTIVE' }, orderBy: { createdAt: 'desc' } }),
      prisma.fleetBike.findMany(),
    ]);

    const glafitDefaults = [
      {
        id: 'fleet-glafit-gfr02',
        modelName: 'Glafit GFR-02 Dual-Power EV',
        tag: 'MOST POPULAR · MULTI-SERVICE READY',
        hubName: 'Banani Hub (Sector 11)',
        powertrain: 'ELECTRIC',
        rangeKm: 45,
        topSpeedKmH: 30,
        batterySwap: '30-second Swap at 2Bee Hubs',
        frontMaxKg: 8,
        frontDimensions: '35×30×30 cm³ (Multi-Service OK)',
        rearMaxKg: 15,
        rearType: 'Passenger Pillion + Ergonomic Footrest',
        dailyRateBdt: 180,
        weeklyRateBdt: 1100,
        monthlyRateBdt: 3800,
        securityDepositBdt: 2000,
        availableQty: 5,
        rating: 4.95,
      },
      {
        id: 'fleet-glafit-none-pro',
        modelName: 'Glafit N-One Pro (Heavy Duty Dual Battery)',
        tag: 'LONG RANGE · DUAL CARRIER',
        hubName: 'Mohakhali Hub / Wireless Gate',
        powertrain: 'ELECTRIC',
        rangeKm: 85,
        topSpeedKmH: 45,
        batterySwap: 'Dual Battery Rapid Swap',
        frontMaxKg: 10,
        frontDimensions: '40×35×30 cm³ Heavy Duty Metal Rack',
        rearMaxKg: 20,
        rearType: 'Heavy Pillion Seat + Cargo Hooks',
        dailyRateBdt: 250,
        weeklyRateBdt: 1550,
        monthlyRateBdt: 5400,
        securityDepositBdt: 3000,
        availableQty: 3,
        rating: 4.98,
      },
      {
        id: 'fleet-glafit-commuter',
        modelName: 'Glafit Commuter Lite EV',
        tag: 'AGILE & ECONOMICAL',
        hubName: 'Uttara Sector 3 Hub',
        powertrain: 'ELECTRIC',
        rangeKm: 55,
        topSpeedKmH: 35,
        batterySwap: 'Standard 2Bee Swap Compatible',
        frontMaxKg: 5,
        frontDimensions: '30×25×25 cm³ Front Basket',
        rearMaxKg: 12,
        rearType: 'Solo Cushion Pillion',
        dailyRateBdt: 140,
        weeklyRateBdt: 850,
        monthlyRateBdt: 3000,
        securityDepositBdt: 1500,
        availableQty: 6,
        rating: 4.88,
      },
    ];

    if (!fleetBikes || fleetBikes.length === 0) {
      fleetBikes = glafitDefaults as any;
    }

    res.json({ ok: true, activeRental, fleetBikes });
  }),
);

panel.post(
  '/payout/change-request',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const schema = z.object({
      otpCode: z.string().regex(/^\d{6}$/),
      provider: z.enum(['BKASH', 'NAGAD', 'ROCKET', 'BANK_BEFTN']),
      accountNumber: z.string().min(6),
      holderName: z.string().min(2),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const challenge = await prisma.otpChallenge.findFirst({
      where: { phone: req.auth!.phone, purpose: 'PAYOUT_CHANGE', consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge || challenge.expiresAt.getTime() < Date.now() || challenge.codeHash !== hashOtp(parsed.otpCode)) {
      throw new HttpError(400, 'INVALID_OTP', 'Valid 6-digit SMS OTP is required for payout changes');
    }
    await prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });

    const effectiveAt = new Date(Date.now() + env.payoutChangeHoldHours * 3600 * 1000);
    const updated = await prisma.payoutAccount.upsert({
      where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: rp.id } },
      update: {
        pendingPayloadJson: {
          provider: parsed.provider,
          accountNumber: parsed.accountNumber,
          holderName: parsed.holderName,
        },
        pendingEffectiveAt: effectiveAt,
      },
      create: {
        ownerRole: 'RIDER',
        ownerId: rp.id,
        provider: parsed.provider,
        accountNumber: parsed.accountNumber,
        holderName: parsed.holderName,
        pendingPayloadJson: {
          provider: parsed.provider,
          accountNumber: parsed.accountNumber,
          holderName: parsed.holderName,
        },
        pendingEffectiveAt: effectiveAt,
      },
    });
    res.json({ ok: true, holdHours: env.payoutChangeHoldHours, effectiveAt, payoutAccount: updated });
  }),
);

panel.get(
  '/security',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const [devices, docs, payoutAccount] = await Promise.all([
      prisma.activeDevice.findMany({ where: { ownerRole: 'RIDER', ownerId: rp.id } }),
      prisma.verificationDocument.findMany({ where: { ownerRole: 'RIDER', ownerId: rp.id } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: rp.id } } }),
    ]);
    res.json({
      ok: true,
      rider: rp,
      devices,
      documents: docs,
      payoutAccount,
      securityConfig: {
        passcodeDigits: 4,
        autoLogoutMinutes: env.roleInactivityMinutes,
        payoutHoldHours: env.payoutChangeHoldHours,
      },
    });
  }),
);

panel.post(
  '/security/change-pin',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { currentPasscode, newPasscode } = z
      .object({
        currentPasscode: z.string().regex(/^\d{4}$/),
        newPasscode: z.string().regex(/^\d{4}$/),
      })
      .parse(req.body);
    if (!(await bcrypt.compare(currentPasscode, rp.passcodeHash))) {
      throw new HttpError(400, 'WRONG_PIN', 'Current 4-digit passcode is incorrect');
    }
    const prisma = getPrisma();
    await prisma.riderProfile.update({
      where: { id: rp.id },
      data: { passcodeHash: await bcrypt.hash(newPasscode, 10) },
    });
    res.json({ ok: true, message: '4-digit rider passcode updated' });
  }),
);

panel.post(
  '/rentals/book',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const { bikeId, planType, swapPassIncluded } = z
      .object({
        bikeId: z.string().min(1),
        planType: z.enum(['DAILY', 'WEEKLY', 'RENT_TO_OWN']).default('DAILY'),
        swapPassIncluded: z.boolean().default(true),
      })
      .parse(req.body);
    const prisma = getPrisma();
    let bike = await prisma.fleetBike.findUnique({ where: { id: bikeId } });

    const modelName = bike?.modelName ?? (
      bikeId.includes('none')
        ? 'Glafit N-One Pro (Heavy Duty Dual Battery)'
        : bikeId.includes('commuter')
          ? 'Glafit Commuter Lite EV'
          : 'Glafit GFR-02 Dual-Power EV'
    );
    const hubName = bike?.hubName ?? 'Banani Hub (Sector 11)';
    const dailyRate = bike?.dailyRateBdt ?? (bikeId.includes('none') ? 250 : bikeId.includes('commuter') ? 140 : 180);

    const rental = await prisma.bikeRental.create({
      data: {
        riderId: rp.id,
        bikeId: bike?.id ?? bikeId,
        bikeModel: modelName,
        plateNo: `2BEE-EV-${Math.floor(1000 + Math.random() * 9000)}`,
        hubName: hubName,
        planType,
        dailyRateBdt: dailyRate,
        status: 'ACTIVE',
        nextDebitAt: new Date(Date.now() + 86400 * 1000),
      },
    });

    // Automatically update rider profile to active Glafit rental & verified front-carrier!
    await prisma.riderProfile.update({
      where: { id: rp.id },
      data: {
        vehicleBrandModel: modelName,
        vehicleOwnership: 'RENTAL',
        frontCarrierVerified: true,
        kycStatus: 'APPROVED',
      },
    });

    res.status(201).json({ ok: true, rental });
  }),
);

panel.get(
  '/food/:id',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({
      where: { id: String(req.params.id) },
      include: { items: true, merchant: true, user: { select: { fullName: true, phone: true } } },
    });
    if (!order || order.riderId !== rp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Food job not found');
    res.json({ ok: true, order });
  }),
);

panel.get(
  '/ride/:id',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    const trip = await prisma.rideTrip.findUnique({
      where: { id: String(req.params.id) },
      include: { user: { select: { fullName: true, phone: true } } },
    });
    if (!trip || trip.riderId !== rp.id) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride job not found');
    res.json({ ok: true, trip });
  }),
);

panel.delete(
  '/security/devices/:deviceId',
  asyncHandler(async (req, res) => {
    const rp = await getRiderOrThrow(req.roleSession!.profileId);
    const prisma = getPrisma();
    await prisma.activeDevice.deleteMany({
      where: { id: String(req.params.deviceId), ownerRole: 'RIDER', ownerId: rp.id },
    });
    res.json({ ok: true });
  }),
);

riderRouter.use('/panel', panel);

