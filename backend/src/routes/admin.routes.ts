import { Router } from 'express';
import type { Prisma } from '@prisma/client';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { env } from '../config/env.js';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAdmin } from '../middleware/auth.js';
import { smsProvider } from '../services/smsProvider.js';
import { firebaseService } from '../services/firebaseService.js';
import { storageService } from '../services/storageService.js';

export const adminRouter = Router();

function signAdminToken(sub: string, email: string): string {
  return jwt.sign({ sub, email, role: 'ADMIN' }, env.jwtAccessSecret, { expiresIn: '8h' });
}

async function recordAudit(params: {
  actorId?: string;
  action: string;
  entityType: string;
  entityId: string;
  meta?: Record<string, unknown>;
}) {
  try {
    const prisma = getPrisma();
    await prisma.auditLog.create({
      data: {
        actorId: params.actorId ?? 'admin',
        actorRole: 'ADMIN',
        action: params.action,
        entityType: params.entityType,
        entityId: params.entityId,
        metaJson: (params.meta ?? {}) as Prisma.InputJsonValue,
      },
    });
  } catch {
    // Non-fatal audit write
  }
}

function toCsv(rows: Array<Record<string, unknown>>): string {
  if (rows.length === 0) return '\uFEFFempty\n';
  const headers = Object.keys(rows[0]);
  const esc = (v: unknown) => {
    const s = v === null || v === undefined ? '' : String(v);
    return `"${s.replace(/"/g, '""')}"`;
  };
  const body = rows.map((r) => headers.map((h) => esc(r[h])).join(',')).join('\n');
  return `\uFEFF${headers.join(',')}\n${body}\n`;
}

// === PUBLIC ADMIN AUTH ENDPOINTS ===
adminRouter.post(
  '/auth/login',
  asyncHandler(async (req, res) => {
    const { email, password } = z
      .object({ email: z.string().email(), password: z.string().min(4) })
      .parse(req.body);
    const cleanEmail = email.trim().toLowerCase();
    if (!env.adminEmails.includes(cleanEmail) || password !== env.adminSeedPassword) {
      throw new HttpError(401, 'ADMIN_INVALID_CREDENTIALS', 'Invalid admin email or password');
    }
    const token = signAdminToken(`admin:${cleanEmail}`, cleanEmail);
    await recordAudit({ actorId: cleanEmail, action: 'ADMIN_LOGIN', entityType: 'Admin', entityId: cleanEmail });
    res.json({ ok: true, accessToken: token, admin: { email: cleanEmail, role: 'ADMIN' } });
  }),
);

adminRouter.post(
  '/auth/firebase',
  asyncHandler(async (req, res) => {
    const { idToken } = z.object({ idToken: z.string().min(20) }).parse(req.body);
    let decoded;
    try {
      decoded = await firebaseService.verifyIdToken(idToken);
    } catch (err) {
      throw new HttpError(401, 'FIREBASE_AUTH_FAILED', (err as Error).message || 'Invalid Firebase ID token');
    }
    const email = (decoded.email ?? '').toLowerCase();
    const isAllowed = Boolean(decoded.admin) || (email.length > 0 && env.adminEmails.includes(email));
    if (!isAllowed) {
      throw new HttpError(403, 'ADMIN_NOT_AUTHORIZED', 'Firebase account is not in ADMIN_EMAILS allowlist');
    }
    const token = signAdminToken(decoded.uid, email || decoded.uid);
    await recordAudit({ actorId: email || decoded.uid, action: 'ADMIN_FIREBASE_LOGIN', entityType: 'Admin', entityId: decoded.uid });
    res.json({ ok: true, accessToken: token, admin: { uid: decoded.uid, email, role: 'ADMIN' } });
  }),
);

// All routes below require Admin credentials
adminRouter.use(requireAdmin);

adminRouter.post(
  '/fcm-token',
  asyncHandler(async (req, res) => {
    const { token, platform } = z
      .object({ token: z.string().min(10), platform: z.enum(['WEB', 'ANDROID', 'IOS']).default('WEB') })
      .parse(req.body);
    const saved = await firebaseService.registerPushToken({
      userId: null,
      role: 'ADMIN',
      platform,
      token,
    });
    res.json({ ok: true, id: saved.id });
  }),
);

// === OVERVIEW & LIVE RADAR ===
adminRouter.get(
  '/overview',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      totalUsers,
      onlineRiders,
      openMerchants,
      pendingRiders,
      pendingMerchants,
      activeSos,
      foodAgg,
      rideAgg,
      parcelAgg,
      activeFood,
      activeRides,
      activeParcels,
      unsettledCod,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.riderProfile.count({ where: { isOnline: true } }),
      prisma.merchantProfile.count({ where: { isStoreOpen: true, kycStatus: 'APPROVED' } }),
      prisma.riderProfile.count({ where: { kycStatus: { in: ['PENDING', 'NEEDS_CHANGES'] } } }),
      prisma.merchantProfile.count({ where: { kycStatus: { in: ['PENDING', 'NEEDS_CHANGES'] } } }),
      prisma.sosIncident.count({ where: { status: 'ACTIVE' } }),
      prisma.foodOrder.aggregate({
        where: { status: { notIn: ['REJECTED', 'CANCELLED'] } },
        _sum: { totalBdt: true, commissionBdt: true },
        _count: { id: true },
      }),
      prisma.rideTrip.aggregate({
        where: { status: { not: 'CANCELLED' } },
        _sum: { totalFareBdt: true, riderPayoutBdt: true },
        _count: { id: true },
      }),
      prisma.parcelShipment.aggregate({
        where: { status: { not: 'CANCELLED' } },
        _sum: { deliveryChargeBdt: true, riderPayoutBdt: true },
        _count: { id: true },
      }),
      prisma.foodOrder.count({ where: { status: { in: ['PLACED', 'ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP'] } } }),
      prisma.rideTrip.count({ where: { status: { in: ['MATCHING', 'RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP'] } } }),
      prisma.parcelShipment.count({ where: { status: { in: ['BOOKED', 'MATCHING', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'] } } }),
      prisma.codLedger.aggregate({ where: { settled: false }, _sum: { cashCollectedBdt: true } }),
    ]);

    const foodGmv = foodAgg._sum.totalBdt ?? 0;
    const rideGmv = rideAgg._sum.totalFareBdt ?? 0;
    const parcelGmv = parcelAgg._sum.deliveryChargeBdt ?? 0;

    res.json({
      ok: true,
      kpis: {
        totalUsers,
        onlineRiders,
        openMerchants,
        pendingKycTotal: pendingRiders + pendingMerchants,
        pendingRiders,
        pendingMerchants,
        activeSos,
        activeOperations: { food: activeFood, rides: activeRides, parcels: activeParcels },
        gmvTotalBdt: foodGmv + rideGmv + parcelGmv,
        foodCommissionBdt: foodAgg._sum.commissionBdt ?? 0,
        unsettledCodBdt: unsettledCod._sum.cashCollectedBdt ?? 0,
        counts: {
          foodOrders: foodAgg._count.id,
          rideTrips: rideAgg._count.id,
          parcelShipments: parcelAgg._count.id,
        },
      },
      integrations: firebaseService.getStatus(),
    });
  }),
);

adminRouter.get(
  '/live-radar',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const [riders, sos, activeFood, activeRides, activeParcels] = await Promise.all([
      prisma.riderProfile.findMany({
        where: { isOnline: true },
        include: { user: { select: { fullName: true, phone: true } } },
      }),
      prisma.sosIncident.findMany({
        where: { status: { not: 'RESOLVED' } },
        include: { user: { select: { fullName: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.foodOrder.findMany({
        where: { status: { in: ['PLACED', 'ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP'] } },
        take: 25,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.rideTrip.findMany({
        where: { status: { in: ['MATCHING', 'RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP'] } },
        take: 25,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.parcelShipment.findMany({
        where: { status: { in: ['BOOKED', 'MATCHING', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'] } },
        take: 25,
        orderBy: { createdAt: 'desc' },
      }),
    ]);
    res.json({ ok: true, riders, sos, activeFood, activeRides, activeParcels });
  }),
);

// === KYC QUEUE & VERIFICATION ===
adminRouter.get(
  '/kyc/pending',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const [riders, merchants] = await Promise.all([
      prisma.riderProfile.findMany({
        where: { kycStatus: { in: ['PENDING', 'NEEDS_CHANGES'] } },
        include: { user: { select: { fullName: true, phone: true } } },
      }),
      prisma.merchantProfile.findMany({
        where: { kycStatus: { in: ['PENDING', 'NEEDS_CHANGES'] } },
        include: { user: { select: { fullName: true, phone: true } } },
      }),
    ]);
    res.json({ ok: true, riders, merchants });
  }),
);

adminRouter.get(
  '/kyc/riders/:riderId',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const riderId = String(req.params.riderId);
    const rider = await prisma.riderProfile.findUnique({
      where: { id: riderId },
      include: { user: true, rentals: true },
    });
    if (!rider) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider not found');
    const [documents, payoutAccount] = await Promise.all([
      prisma.verificationDocument.findMany({ where: { ownerRole: 'RIDER', ownerId: rider.id } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: rider.id } } }),
    ]);
    res.json({ ok: true, rider, documents, payoutAccount });
  }),
);

adminRouter.get(
  '/kyc/merchants/:merchantId',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const merchantId = String(req.params.merchantId);
    const merchant = await prisma.merchantProfile.findUnique({
      where: { id: merchantId },
      include: { user: true },
    });
    if (!merchant) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant not found');
    const [documents, payoutAccount] = await Promise.all([
      prisma.verificationDocument.findMany({ where: { ownerRole: 'MERCHANT', ownerId: merchant.id } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'MERCHANT', ownerId: merchant.id } } }),
    ]);
    res.json({ ok: true, merchant, documents, payoutAccount });
  }),
);

adminRouter.get(
  '/documents/:docId/signed-url',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const doc = await prisma.verificationDocument.findUnique({ where: { id: String(req.params.docId) } });
    if (!doc) throw new HttpError(404, 'DOCUMENT_NOT_FOUND', 'Verification document not found');
    const signedUrl = await storageService.getSignedReadUrl(doc.fileUrl, 300);
    await recordAudit({
      action: 'VIEW_KYC_DOCUMENT',
      entityType: 'VerificationDocument',
      entityId: doc.id,
      meta: { docType: doc.docType, ownerRole: doc.ownerRole, ownerId: doc.ownerId },
    });
    res.json({ ok: true, signedUrl, expiresInSeconds: 300 });
  }),
);

/**
 * POST /api/v1/admin/kyc/rider/:riderId/decision
 */
adminRouter.post(
  '/kyc/rider/:riderId/decision',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      decision: z.enum(['APPROVED', 'NEEDS_CHANGES', 'REJECTED']),
      frontCarrierVerified: z.boolean().optional(),
      rearCarrierVerified: z.boolean().optional(),
      notes: z.record(z.string(), z.string()).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const rp = await prisma.riderProfile.findUnique({
      where: { id: String(req.params.riderId) },
      include: { user: true },
    });
    if (!rp) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider not found');

    const updated = await prisma.riderProfile.update({
      where: { id: rp.id },
      data: {
        kycStatus: parsed.decision,
        kycNotesJson: parsed.notes ?? {},
        ...(parsed.decision === 'APPROVED'
          ? {
              approvedAt: new Date(),
              frontCarrierVerified: parsed.frontCarrierVerified ?? rp.frontCarrierLengthCm !== null,
              rearCarrierVerified: parsed.rearCarrierVerified ?? true,
            }
          : {}),
      },
    });

    const title =
      parsed.decision === 'APPROVED'
        ? 'Rider KYC Approved!'
        : parsed.decision === 'NEEDS_CHANGES'
          ? 'Rider KYC Needs Changes'
          : 'Rider Application Rejected';
    const body =
      parsed.decision === 'APPROVED'
        ? 'You are approved! You can now go online from Rider Home.'
        : 'Please review the flagged items in your Rider application.';

    await prisma.notificationItem.create({
      data: { userId: rp.userId, role: 'RIDER', category: 'SYSTEM', title, body },
    });
    await smsProvider.sendAlert(rp.user.phone, `2Bee Rider status updated: ${parsed.decision}`);
    void firebaseService.sendPushToUser(rp.userId, { title, body, data: { type: 'KYC_DECISION', role: 'RIDER' } }, 'RIDER');
    await recordAudit({ action: `RIDER_KYC_${parsed.decision}`, entityType: 'RiderProfile', entityId: rp.id, meta: parsed.notes });

    res.json({ ok: true, rider: updated });
  }),
);

/**
 * POST /api/v1/admin/kyc/merchant/:merchantId/decision
 * When APPROVED: Sends approval notice to phone; Merchant must log in & create fixed 6-digit passcode!
 */
adminRouter.post(
  '/kyc/merchant/:merchantId/decision',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      decision: z.enum(['APPROVED', 'NEEDS_CHANGES', 'REJECTED']),
      notes: z.record(z.string(), z.string()).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({
      where: { id: String(req.params.merchantId) },
      include: { user: true },
    });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant not found');

    const updated = await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: {
        kycStatus: parsed.decision,
        kycNotesJson: parsed.notes ?? {},
        ...(parsed.decision === 'APPROVED' ? { approvedAt: new Date() } : {}),
      },
    });

    const title = parsed.decision === 'APPROVED' ? 'Merchant Verification Approved!' : 'Merchant Verification Update';
    const body =
      parsed.decision === 'APPROVED'
        ? 'Your store is approved! Verify phone OTP & set your 6-digit passcode to open your merchant panel.'
        : 'Review requested KYC updates.';

    await prisma.notificationItem.create({
      data: { userId: mp.userId, role: 'MERCHANT', category: 'SYSTEM', title, body },
    });

    if (parsed.decision === 'APPROVED') {
      await smsProvider.sendAlert(
        mp.user.phone,
        `2Bee Merchant Approved! Login with your phone and set your permanent 6-digit passcode to unlock ${mp.businessName}.`,
      );
    }
    void firebaseService.sendPushToUser(mp.userId, { title, body, data: { type: 'KYC_DECISION', role: 'MERCHANT' } }, 'MERCHANT');
    await recordAudit({ action: `MERCHANT_KYC_${parsed.decision}`, entityType: 'MerchantProfile', entityId: mp.id, meta: parsed.notes });

    res.json({ ok: true, merchant: updated });
  }),
);

// === USERS, RIDERS, MERCHANTS DIRECTORIES ===
adminRouter.get(
  '/users',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const q = String(req.query.q ?? '').trim();
    const users = await prisma.user.findMany({
      where: q
        ? {
            OR: [
              { phone: { contains: q, mode: 'insensitive' } },
              { fullName: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      include: {
        riderProfile: { select: { id: true, kycStatus: true, isOnline: true } },
        merchantProfile: { select: { id: true, businessName: true, merchantType: true, kycStatus: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ ok: true, users });
  }),
);

adminRouter.get(
  '/riders',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const riders = await prisma.riderProfile.findMany({
      include: { user: { select: { fullName: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ ok: true, riders });
  }),
);

adminRouter.patch(
  '/riders/:riderId',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      isOnline: z.boolean().optional(),
      multiServiceEnabled: z.boolean().optional(),
      frontCarrierVerified: z.boolean().optional(),
      rearCarrierVerified: z.boolean().optional(),
      kycStatus: z.enum(['DRAFT', 'PENDING', 'NEEDS_CHANGES', 'APPROVED', 'REJECTED']).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const rider = await prisma.riderProfile.update({
      where: { id: String(req.params.riderId) },
      data: parsed,
    });
    await recordAudit({ action: 'UPDATE_RIDER', entityType: 'RiderProfile', entityId: rider.id, meta: parsed });
    res.json({ ok: true, rider });
  }),
);

adminRouter.get(
  '/merchants',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const merchants = await prisma.merchantProfile.findMany({
      include: { user: { select: { fullName: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ ok: true, merchants });
  }),
);

adminRouter.patch(
  '/merchants/:merchantId',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      isStoreOpen: z.boolean().optional(),
      dailyOrderLimit: z.number().int().min(1).max(500).nullable().optional(),
      dailyCutoffTime: z.string().nullable().optional(),
      deliveryFeeBdt: z.number().min(0).optional(),
      minOrderBdt: z.number().min(0).optional(),
      kycStatus: z.enum(['DRAFT', 'PENDING', 'NEEDS_CHANGES', 'APPROVED', 'REJECTED']).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const merchant = await prisma.merchantProfile.update({
      where: { id: String(req.params.merchantId) },
      data: parsed,
    });
    await recordAudit({ action: 'UPDATE_MERCHANT', entityType: 'MerchantProfile', entityId: merchant.id, meta: parsed });
    res.json({ ok: true, merchant });
  }),
);

// === ORDERS / RIDES / PARCELS / MULTI-SERVICE CONTROL ===
adminRouter.get(
  '/orders',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const [foodOrders, rideTrips, parcelShipments, multiServiceBatches] = await Promise.all([
      prisma.foodOrder.findMany({
        include: {
          user: { select: { fullName: true, phone: true } },
          merchant: { select: { businessName: true, merchantType: true } },
          rider: { include: { user: { select: { fullName: true, phone: true } } } },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.rideTrip.findMany({
        include: {
          user: { select: { fullName: true, phone: true } },
          rider: { include: { user: { select: { fullName: true, phone: true } } } },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.parcelShipment.findMany({
        include: {
          user: { select: { fullName: true, phone: true } },
          rider: { include: { user: { select: { fullName: true, phone: true } } } },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.multiServiceBatch.findMany({
        include: { parcelShipment: true, rideTrip: true, rider: { include: { user: { select: { fullName: true } } } } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);
    res.json({ ok: true, foodOrders, rideTrips, parcelShipments, multiServiceBatches });
  }),
);

// === PRICING, ZONES & FLEET ===
adminRouter.get(
  '/pricing',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const pricing = await prisma.appPricingConfig.findUnique({ where: { id: 'default' } });
    res.json({ ok: true, pricing });
  }),
);

adminRouter.patch(
  '/pricing',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      foodCommissionRate: z.number().min(0).max(0.5).optional(),
      foodDeliveryFeeBdt: z.number().min(0).optional(),
      foodPackagingFeeBdt: z.number().min(0).optional(),
      foodServiceFeeBdt: z.number().min(0).optional(),
      rideBaseFareSoloBdt: z.number().min(0).optional(),
      ridePerKmSoloBdt: z.number().min(0).optional(),
      rideMinFareSoloBdt: z.number().min(0).optional(),
      parcelNormalBaseBdt: z.number().min(0).optional(),
      parcelExpressBaseBdt: z.number().min(0).optional(),
      parcelProtectionBdt: z.number().min(0).optional(),
      parcelFrontMaxKg: z.number().min(1).max(20).optional(),
      parcelFrontMaxVolCm3: z.number().min(1000).optional(),
      payoutScheduleLabel: z.string().min(3).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const pricing = await prisma.appPricingConfig.upsert({
      where: { id: 'default' },
      update: parsed,
      create: { id: 'default', ...parsed },
    });
    await recordAudit({ action: 'UPDATE_PRICING_CONFIG', entityType: 'AppPricingConfig', entityId: 'default', meta: parsed });
    res.json({ ok: true, pricing });
  }),
);

adminRouter.get(
  '/zones',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const zones = await prisma.zone.findMany({ orderBy: { name: 'asc' } });
    res.json({ ok: true, zones });
  }),
);

adminRouter.post(
  '/zones',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      id: z.string().min(2),
      name: z.string().min(2),
      city: z.string().default('Dhaka'),
      centerLat: z.number(),
      centerLng: z.number(),
      radiusKm: z.number().positive().default(3.5),
      rateBonusBdt: z.number().default(0),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const zone = await prisma.zone.upsert({
      where: { id: parsed.id },
      update: parsed,
      create: parsed,
    });
    await recordAudit({ action: 'UPSERT_ZONE', entityType: 'Zone', entityId: zone.id, meta: parsed });
    res.status(201).json({ ok: true, zone });
  }),
);

adminRouter.get(
  '/fleet-bikes',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const [bikes, rentals] = await Promise.all([
      prisma.fleetBike.findMany(),
      prisma.bikeRental.findMany({ include: { rider: { include: { user: { select: { fullName: true, phone: true } } } } }, orderBy: { createdAt: 'desc' } }),
    ]);
    res.json({ ok: true, bikes, rentals });
  }),
);

// === FINANCE, WALLETS, COD LEDGER, SOS & AUDIT ===
adminRouter.get(
  '/cod-ledger',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const entries = await prisma.codLedger.findMany({
      include: { rider: { include: { user: { select: { fullName: true, phone: true } } } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    res.json({ ok: true, entries });
  }),
);

adminRouter.post(
  '/cod-ledger/settle',
  asyncHandler(async (req, res) => {
    const { entryIds } = z.object({ entryIds: z.array(z.string()).min(1) }).parse(req.body);
    const prisma = getPrisma();
    const entries = await prisma.codLedger.findMany({ where: { id: { in: entryIds }, settled: false } });
    await prisma.$transaction(async (tx) => {
      await tx.codLedger.updateMany({ where: { id: { in: entryIds }, settled: false }, data: { settled: true } });
      for (const e of entries) {
        const rp = await tx.riderProfile.findUnique({ where: { id: e.riderId } });
        if (rp) {
          await tx.walletAccount.updateMany({
            where: { userId: rp.userId, role: 'RIDER' },
            data: { codCashInHandBdt: { decrement: e.cashCollectedBdt } },
          });
        }
      }
    });
    await recordAudit({ action: 'SETTLE_COD_LEDGER', entityType: 'CodLedger', entityId: entryIds.join(','), meta: { count: entries.length } });
    res.json({ ok: true, settledCount: entries.length });
  }),
);

adminRouter.get(
  '/sos',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const incidents = await prisma.sosIncident.findMany({
      include: { user: { select: { fullName: true, phone: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json({ ok: true, incidents });
  }),
);

adminRouter.patch(
  '/sos/:id',
  asyncHandler(async (req, res) => {
    const { status } = z.object({ status: z.enum(['ACTIVE', 'INVESTIGATING', 'RESOLVED']) }).parse(req.body);
    const prisma = getPrisma();
    const incident = await prisma.sosIncident.update({
      where: { id: String(req.params.id) },
      data: { status },
    });
    await recordAudit({ action: 'UPDATE_SOS_STATUS', entityType: 'SosIncident', entityId: incident.id, meta: { status } });
    res.json({ ok: true, incident });
  }),
);

adminRouter.get(
  '/audit-logs',
  asyncHandler(async (_req, res) => {
    const prisma = getPrisma();
    const logs = await prisma.auditLog.findMany({ orderBy: { createdAt: 'desc' }, take: 100 });
    res.json({ ok: true, logs });
  }),
);

// === COMPREHENSIVE REPORTS (JSON & CSV EXPORT) ===
adminRouter.get(
  '/reports/:reportType',
  asyncHandler(async (req, res) => {
    const type = String(req.params.reportType).toLowerCase();
    const format = String(req.query.format ?? 'json').toLowerCase();
    const prisma = getPrisma();

    let rows: Array<Record<string, unknown>> = [];
    if (type === 'revenue' || type === 'food') {
      const orders = await prisma.foodOrder.findMany({
        include: { merchant: { select: { businessName: true, merchantType: true } } },
        orderBy: { createdAt: 'desc' },
        take: 200,
      });
      rows = orders.map((o) => ({
        orderCode: o.orderCode,
        merchant: o.merchant.businessName,
        merchantType: o.merchant.merchantType,
        status: o.status,
        paymentMethod: o.paymentMethod,
        paymentStatus: o.paymentStatus,
        subtotalBdt: o.subtotalBdt,
        deliveryFeeBdt: o.deliveryFeeBdt,
        commissionBdt: o.commissionBdt,
        discountBdt: o.discountBdt,
        totalBdt: o.totalBdt,
        createdAt: o.createdAt.toISOString(),
      }));
    } else if (type === 'rides') {
      const rides = await prisma.rideTrip.findMany({ orderBy: { createdAt: 'desc' }, take: 200 });
      rows = rides.map((r) => ({
        tripCode: r.tripCode,
        fleetTier: r.fleetTier,
        pickupZoneId: r.pickupZoneId,
        dropoffZoneId: r.dropoffZoneId,
        distanceKm: r.distanceKm,
        status: r.status,
        paymentMethod: r.paymentMethod,
        totalFareBdt: r.totalFareBdt,
        riderPayoutBdt: r.riderPayoutBdt,
        createdAt: r.createdAt.toISOString(),
      }));
    } else if (type === 'parcels') {
      const parcels = await prisma.parcelShipment.findMany({ orderBy: { createdAt: 'desc' }, take: 200 });
      rows = parcels.map((p) => ({
        trackingCode: p.trackingCode,
        tier: p.tier,
        weightKg: p.weightKg,
        fitsFrontCarrier: p.fitsFrontCarrier,
        isProtected: p.isProtected,
        status: p.status,
        deliveryChargeBdt: p.deliveryChargeBdt,
        codCollectBdt: p.codCollectBdt,
        riderPayoutBdt: p.riderPayoutBdt,
        createdAt: p.createdAt.toISOString(),
      }));
    } else if (type === 'riders') {
      const riders = await prisma.riderProfile.findMany({
        include: { user: { select: { fullName: true, phone: true } } },
      });
      rows = riders.map((r) => ({
        riderId: r.id,
        fullName: r.user.fullName,
        phone: r.user.phone,
        kycStatus: r.kycStatus,
        vehicleOwnership: r.vehicleOwnership,
        multiServiceEnabled: r.multiServiceEnabled,
        totalTrips: r.totalTrips,
        rating: r.rating,
      }));
    } else if (type === 'sos') {
      const sos = await prisma.sosIncident.findMany({
        include: { user: { select: { fullName: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      });
      rows = sos.map((s) => ({
        id: s.id,
        user: s.user.fullName,
        phone: s.user.phone,
        role: s.role,
        status: s.status,
        lat: s.lat,
        lng: s.lng,
        note: s.note ?? '',
        createdAt: s.createdAt.toISOString(),
      }));
    } else {
      throw new HttpError(400, 'INVALID_REPORT_TYPE', `Unsupported report type: ${type}`);
    }

    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="twobee-${type}-report.csv"`);
      res.send(toCsv(rows));
      return;
    }

    res.json({ ok: true, reportType: type, count: rows.length, rows });
  }),
);
