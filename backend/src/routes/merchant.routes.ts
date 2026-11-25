import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth, requireRoleSession, signRoleSessionToken } from '../middleware/auth.js';
import { hashOtp } from '../services/smsProvider.js';
import { env } from '../config/env.js';
import { getIO } from '../realtime/socketServer.js';
import { generateReceiptPdf } from '../services/pdfService.js';

export const merchantRouter = Router();
merchantRouter.use(requireAuth);

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

/**
 * POST /api/v1/merchant/register
 * Physical Restaurant OR Home Kitchen registration.
 * Business Rule (2c): NO passcode created during registration!
 */
merchantRouter.post(
  '/register',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      merchantType: z.enum(['PHYSICAL', 'HOME_KITCHEN']),
      businessName: z.string().min(2),
      ownerOrCookName: z.string().min(2),
      cuisines: z.array(z.string()).default(['Bangladeshi']),
      address: z.string().min(3),
      lat: z.number().default(23.7937),
      lng: z.number().default(90.4066),
      areaZoneId: z.string().default('zone-banani'),
      contactPhone: z.string().min(10),
      contactEmail: z.string().email().optional().or(z.literal('')),
      eTin: z.string().optional(),
      tradeLicenseNo: z.string().optional(),
      nidNumber: z.string().min(10),
      fbPageUrl: z.string().optional(),
      fbVerifyToken: z.string().default('2B-4821'),
      avgPrepMins: z.number().int().min(10).max(120).default(25),
      dailyOrderLimit: z.number().int().min(1).max(200).optional(),
      dailyCutoffTime: z.string().optional(),
      hygieneConfirmed: z.boolean().default(true),
      payoutProvider: z.enum(['BKASH', 'NAGAD', 'ROCKET', 'BANK_BEFTN']).default('BKASH'),
      payoutAccountNumber: z.string().min(6),
      payoutHolderName: z.string().min(2),
      documents: z
        .array(z.object({ docType: z.string(), fileUrl: z.string() }))
        .default([]),
      reRegisterDemo: z.boolean().default(false),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const userId = req.auth!.userId;

    const existing = await prisma.merchantProfile.findUnique({ where: { userId } });
    if (existing && !(env.nodeEnv !== 'production' && parsed.reRegisterDemo)) {
      throw new HttpError(409, 'MERCHANT_ALREADY_EXISTS', 'Merchant application already exists for this phone');
    }

    if (parsed.merchantType === 'PHYSICAL' && (!parsed.eTin || !parsed.tradeLicenseNo)) {
      throw new HttpError(400, 'LEGAL_DOCS_REQUIRED', 'Physical restaurant requires e-TIN and Trade License number');
    }
    if (parsed.merchantType === 'HOME_KITCHEN' && !parsed.hygieneConfirmed) {
      throw new HttpError(400, 'HYGIENE_REQUIRED', 'Home Kitchen hygiene declaration must be accepted');
    }

    const profile = await prisma.$transaction(async (tx) => {
      const dataFields = {
        merchantType: parsed.merchantType,
        kycStatus: 'PENDING' as const,
        passcodeSet: false, // Mandatory post-approval 6-digit PIN gate!
        passcodeHash: null,
        businessName: parsed.businessName,
        ownerOrCookName: parsed.ownerOrCookName,
        cuisinesJson: parsed.cuisines,
        address: parsed.address,
        lat: parsed.lat,
        lng: parsed.lng,
        areaZoneId: parsed.areaZoneId,
        contactPhone: parsed.contactPhone,
        contactEmail: parsed.contactEmail || null,
        eTin: parsed.eTin,
        tradeLicenseNo: parsed.tradeLicenseNo,
        nidNumber: parsed.nidNumber,
        fbPageUrl: parsed.fbPageUrl,
        fbVerifyToken: parsed.fbVerifyToken,
        avgPrepMins: parsed.avgPrepMins,
        dailyOrderLimit: parsed.merchantType === 'HOME_KITCHEN' ? parsed.dailyOrderLimit ?? 15 : null,
        dailyCutoffTime: parsed.merchantType === 'HOME_KITCHEN' ? parsed.dailyCutoffTime ?? '20:00' : null,
        hygieneConfirmed: parsed.hygieneConfirmed,
        isStoreOpen: false,
      };
      const created = existing
        ? await tx.merchantProfile.update({ where: { id: existing.id }, data: dataFields })
        : await tx.merchantProfile.create({ data: { userId, ...dataFields } });

      if (parsed.documents.length > 0) {
        await tx.verificationDocument.createMany({
          data: parsed.documents.map((d) => ({
            ownerRole: 'MERCHANT',
            ownerId: created.id,
            docType: d.docType,
            fileUrl: d.fileUrl,
            status: 'PENDING',
          })),
        });
      }

      await tx.payoutAccount.upsert({
        where: { ownerRole_ownerId: { ownerRole: 'MERCHANT', ownerId: created.id } },
        update: {
          provider: parsed.payoutProvider,
          accountNumber: parsed.payoutAccountNumber,
          holderName: parsed.payoutHolderName,
        },
        create: {
          ownerRole: 'MERCHANT',
          ownerId: created.id,
          provider: parsed.payoutProvider,
          accountNumber: parsed.payoutAccountNumber,
          holderName: parsed.payoutHolderName,
        },
      });

      await tx.walletAccount.upsert({
        where: { userId_role: { userId, role: 'MERCHANT' } },
        update: {},
        create: { userId, role: 'MERCHANT', balanceBdt: 0 },
      });

      await tx.user.update({ where: { id: userId }, data: { activeRole: 'MERCHANT' } });
      return created;
    });

    res.status(201).json({
      ok: true,
      profile,
      nextScreen: 'MERCHANT_HOME_PENDING',
      message: 'Verification in progress. Store stays closed until admin approval.',
    });
  }),
);

/**
 * GET /api/v1/merchant/pending-home
 * Allowed WITHOUT passcode ONLY while merchant is PENDING or NEEDS_CHANGES (locked closed!).
 * Once APPROVED & !passcodeSet, requires 6-digit PIN setup before opening active panel!
 */
merchantRouter.get(
  '/pending-home',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({
      where: { userId: req.auth!.userId },
    });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant registration not found');

    const docs = await prisma.verificationDocument.findMany({
      where: { ownerRole: 'MERCHANT', ownerId: mp.id },
    });

    res.json({
      ok: true,
      profile: {
        id: mp.id,
        merchantType: mp.merchantType,
        businessName: mp.businessName,
        kycStatus: mp.kycStatus,
        kycNotes: mp.kycNotesJson,
        passcodeSet: mp.passcodeSet,
        requiresPostApprovalPinSetup: mp.kycStatus === 'APPROVED' && !mp.passcodeSet,
        isStoreOpen: false, // Locked closed until approved + PIN created
        dailyOrderLimit: mp.dailyOrderLimit,
        dailyCutoffTime: mp.dailyCutoffTime,
      },
      documents: docs,
    });
  }),
);

merchantRouter.post(
  '/resubmit',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      fbPageUrl: z.string().optional(),
      nidNumber: z.string().optional(),
      documents: z.array(z.object({ docType: z.string(), fileUrl: z.string() })).default([]),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant not found');

    const updated = await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: {
        kycStatus: 'PENDING',
        kycNotesJson: {},
        ...(parsed.fbPageUrl ? { fbPageUrl: parsed.fbPageUrl } : {}),
        ...(parsed.nidNumber ? { nidNumber: parsed.nidNumber } : {}),
      },
    });
    for (const d of parsed.documents) {
      await prisma.verificationDocument.create({
        data: { ownerRole: 'MERCHANT', ownerId: mp.id, docType: d.docType, fileUrl: d.fileUrl, status: 'PENDING' },
      });
    }
    res.json({ ok: true, profile: updated });
  }),
);

/**
 * POST /api/v1/merchant/post-approval/setup-pin
 * Business Rule (2b/2c): Merchant sets FIXED 6-digit passcode ONLY AFTER Admin approves!
 * Verifies SMS OTP (sent with / triggered after approval) -> sets 6-digit passcode -> returns role token.
 */
merchantRouter.post(
  '/post-approval/setup-pin',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      otpCode: z.string().regex(/^\d{6}$/, 'OTP must be 6 digits'),
      passcode: z.string().regex(/^\d{6}$/, 'Merchant passcode must be 6 digits'),
      enableBiometric: z.boolean().default(false),
      deviceName: z.string().default('2Bee Mobile'),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant not found');
    if (mp.kycStatus !== 'APPROVED') {
      throw new HttpError(403, 'NOT_APPROVED_YET', 'Passcode setup unlocks after merchant KYC approval');
    }
    if (mp.passcodeSet) {
      throw new HttpError(409, 'PIN_ALREADY_SET', 'Passcode already configured. Use Restaurant Login.');
    }

    const challenge = await prisma.otpChallenge.findFirst({
      where: { phone: req.auth!.phone, purpose: 'MERCHANT_APPROVAL_PIN', consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge || challenge.expiresAt.getTime() < Date.now() || challenge.codeHash !== hashOtp(parsed.otpCode)) {
      throw new HttpError(400, 'INVALID_OTP', 'Invalid or expired approval verification OTP');
    }
    await prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });

    const passcodeHash = await bcrypt.hash(parsed.passcode, 10);
    await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: { passcodeHash, passcodeSet: true, biometricEnabled: parsed.enableBiometric },
    });
    await prisma.activeDevice.create({
      data: {
        ownerRole: 'MERCHANT',
        ownerId: mp.id,
        deviceName: parsed.deviceName,
        deviceKey: `dev-${Date.now()}`,
      },
    });

    const roleToken = signRoleSessionToken(req.auth!.userId, 'MERCHANT', mp.id);
    res.json({ ok: true, roleToken, merchantType: mp.merchantType, businessName: mp.businessName });
  }),
);

/**
 * POST /api/v1/merchant/login-pin
 * Daily Restaurant / Home Kitchen login using 6-digit passcode.
 */
merchantRouter.post(
  '/login-pin',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      passcode: z.string().regex(/^\d{6}$/, 'Merchant passcode must be 6 digits'),
      deviceName: z.string().default('2Bee Mobile'),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant account not found');
    if (mp.kycStatus !== 'APPROVED') {
      throw new HttpError(403, 'MERCHANT_PENDING_APPROVAL', 'Merchant KYC is still awaiting approval');
    }
    if (!mp.passcodeSet || !mp.passcodeHash) {
      throw new HttpError(403, 'MERCHANT_PIN_SETUP_REQUIRED', 'Complete post-approval 6-digit passcode setup first');
    }
    const valid = await bcrypt.compare(parsed.passcode, mp.passcodeHash);
    if (!valid) throw new HttpError(401, 'INVALID_PASSCODE', 'Incorrect 6-digit passcode');

    const roleToken = signRoleSessionToken(req.auth!.userId, 'MERCHANT', mp.id);
    res.json({
      ok: true,
      roleToken,
      merchantType: mp.merchantType,
      businessName: mp.businessName,
      inactivityTimeoutMinutes: env.roleInactivityMinutes,
    });
  }),
);

/**
 * POST /api/v1/merchant/forgot-passcode/reset
 * Resets Merchant 6-digit passcode via SMS OTP + last 4 digits of Owner NID.
 */
merchantRouter.post(
  '/forgot-passcode/reset',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      otpCode: z.string().regex(/^\d{6}$/),
      nidLast4: z.string().regex(/^\d{4}$/, 'Enter last 4 digits of registered NID'),
      newPasscode: z.string().regex(/^\d{6}$/, 'Merchant passcode must be 6 digits'),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const mp = await prisma.merchantProfile.findUnique({ where: { userId: req.auth!.userId } });
    if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant account not found');

    if (mp.nidNumber.slice(-4) !== parsed.nidLast4) {
      throw new HttpError(400, 'NID_MISMATCH', 'Last 4 digits of NID do not match registered record');
    }
    const challenge = await prisma.otpChallenge.findFirst({
      where: { phone: req.auth!.phone, purpose: 'FORGOT_PASSCODE', consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });
    if (!challenge || challenge.expiresAt.getTime() < Date.now() || challenge.codeHash !== hashOtp(parsed.otpCode)) {
      throw new HttpError(400, 'INVALID_OTP', 'Invalid or expired OTP');
    }
    await prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });

    const passcodeHash = await bcrypt.hash(parsed.newPasscode, 10);
    await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: { passcodeHash, passcodeSet: true },
    });

    res.json({ ok: true, message: 'Merchant 6-digit passcode reset successfully' });
  }),
);

// === PROTECTED LIVE SPLIT MERCHANT PANEL ROUTES (Require unlocked 6-digit PIN session + 15m timer) ===
const panel = Router();
panel.use(requireRoleSession('MERCHANT'));

async function assertApprovedMerchant(profileId: string) {
  const prisma = getPrisma();
  const mp = await prisma.merchantProfile.findUnique({ where: { id: profileId } });
  if (!mp || mp.kycStatus !== 'APPROVED' || !mp.passcodeSet) {
    throw new HttpError(403, 'MERCHANT_PANEL_LOCKED', 'Merchant must be approved and have 6-digit passcode set');
  }
  return mp;
}

/**
 * GET /api/v1/merchant/panel/home
 * Split Merchant Home: Physical Restaurant metrics vs Home Kitchen Daily Batch Quota / Cutoff / Tonight Stock.
 */
panel.get(
  '/home',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const [todayOrders, pendingNewOrders, tonightItems] = await Promise.all([
      prisma.foodOrder.findMany({
        where: { merchantId: mp.id, createdAt: { gte: startOfToday() } },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.foodOrder.findMany({
        where: { merchantId: mp.id, status: 'PLACED' },
        include: { items: true },
        orderBy: { createdAt: 'desc' },
      }),
      mp.merchantType === 'HOME_KITCHEN'
        ? prisma.menuItem.findMany({ where: { merchantId: mp.id }, take: 12 })
        : Promise.resolve([]),
    ]);

    const nonRejectedCount = todayOrders.filter((o) => !['REJECTED', 'CANCELLED'].includes(o.status)).length;
    const grossSalesToday = todayOrders
      .filter((o) => o.status !== 'REJECTED' && o.status !== 'CANCELLED')
      .reduce((s, o) => s + o.subtotalBdt, 0);

    res.json({
      ok: true,
      merchant: {
        id: mp.id,
        merchantType: mp.merchantType,
        businessName: mp.businessName,
        ownerOrCookName: mp.ownerOrCookName,
        isStoreOpen: mp.isStoreOpen,
        pausedUntil: mp.pausedUntil,
        avgPrepMins: mp.avgPrepMins,
        rating: mp.rating,
        hygieneScore: mp.hygieneScore,
      },
      stats: {
        todayOrders: nonRejectedCount,
        todaySalesBdt: grossSalesToday,
        avgPrepMins: mp.avgPrepMins,
      },
      // Split Home Kitchen Panel Section
      homeKitchenPanel:
        mp.merchantType === 'HOME_KITCHEN'
          ? {
              dailyOrderLimit: mp.dailyOrderLimit ?? 15,
              usedQuota: nonRejectedCount,
              remainingQuota: Math.max(0, (mp.dailyOrderLimit ?? 15) - nonRejectedCount),
              dailyCutoffTime: mp.dailyCutoffTime ?? '20:00',
              availableTonightItems: tonightItems,
            }
          : null,
      newOrders: pendingNewOrders,
    });
  }),
);

panel.patch(
  '/store/toggle',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const schema = z.object({
      isStoreOpen: z.boolean(),
      pauseMinutes: z.number().int().min(0).max(240).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const pausedUntil = parsed.pauseMinutes && parsed.pauseMinutes > 0
      ? new Date(Date.now() + parsed.pauseMinutes * 60000)
      : null;

    const updated = await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: { isStoreOpen: parsed.isStoreOpen, pausedUntil },
    });
    res.json({ ok: true, merchant: updated });
  }),
);

panel.get(
  '/orders',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const orders = await prisma.foodOrder.findMany({
      where: { merchantId: mp.id },
      include: {
        items: true,
        rider: { include: { user: { select: { fullName: true, phone: true } } } },
        user: { select: { fullName: true, phone: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json({
      ok: true,
      newOrders: orders.filter((o) => o.status === 'PLACED'),
      preparingOrders: orders.filter((o) => o.status === 'ACCEPTED' || o.status === 'PREPARING'),
      readyOrders: orders.filter((o) => o.status === 'READY_FOR_PICKUP' || o.status === 'PICKED_UP'),
      historyOrders: orders.filter((o) => ['DELIVERED', 'REJECTED', 'CANCELLED'].includes(o.status)),
    });
  }),
);

panel.post(
  '/orders/:id/accept',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const { prepTimeMins } = z.object({ prepTimeMins: z.number().int().min(5).max(120).default(20) }).parse(req.body ?? {});
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.merchantId !== mp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');

    const updated = await prisma.foodOrder.update({
      where: { id: order.id },
      data: { status: 'PREPARING', prepTimeMins },
    });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'PREPARING', prepTimeMins });
    res.json({ ok: true, order: updated });
  }),
);

panel.post(
  '/orders/:id/reject',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const { reason } = z.object({ reason: z.string().min(2) }).parse(req.body);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.merchantId !== mp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');

    const updated = await prisma.foodOrder.update({
      where: { id: order.id },
      data: {
        status: 'REJECTED',
        rejectReason: reason,
        paymentStatus: order.paymentStatus === 'PAID' ? 'REFUNDED' : order.paymentStatus,
      },
    });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'REJECTED', reason });
    res.json({ ok: true, order: updated });
  }),
);

panel.post(
  '/orders/:id/ready',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.merchantId !== mp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');

    const updated = await prisma.foodOrder.update({
      where: { id: order.id },
      data: { status: 'READY_FOR_PICKUP' },
    });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'READY_FOR_PICKUP' });
    res.json({ ok: true, order: updated });
  }),
);

panel.post(
  '/orders/:id/handover',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.merchantId !== mp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');

    const updated = await prisma.foodOrder.update({
      where: { id: order.id },
      data: { status: 'PICKED_UP' },
    });
    getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: 'PICKED_UP' });
    res.json({ ok: true, order: updated });
  }),
);

// === MENU CRUD ===
panel.get(
  '/menu',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const categories = await prisma.menuCategory.findMany({
      where: { merchantId: mp.id },
      orderBy: { sortOrder: 'asc' },
      include: { items: true },
    });
    res.json({ ok: true, categories });
  }),
);

panel.post(
  '/menu/items',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const schema = z.object({
      categoryName: z.string().min(1).default('Signature Dishes'),
      name: z.string().min(2),
      description: z.string().max(200).optional(),
      priceBdt: z.number().positive(),
      strikePriceBdt: z.number().positive().optional(),
      prepTimeMins: z.number().int().min(5).max(120).default(20),
      imageUrl: z.string().optional().nullable(),
      isBestseller: z.boolean().default(false),
      inStock: z.boolean().default(true),
      availableTonight: z.boolean().default(true),
      optionGroups: z.array(z.any()).default([]),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    let category = await prisma.menuCategory.findFirst({
      where: { merchantId: mp.id, name: parsed.categoryName },
    });
    if (!category) {
      category = await prisma.menuCategory.create({
        data: { merchantId: mp.id, name: parsed.categoryName },
      });
    }
    const item = await prisma.menuItem.create({
      data: {
        merchantId: mp.id,
        categoryId: category.id,
        name: parsed.name,
        description: parsed.description,
        priceBdt: parsed.priceBdt,
        strikePriceBdt: parsed.strikePriceBdt,
        prepTimeMins: parsed.prepTimeMins,
        imageUrl: parsed.imageUrl,
        isBestseller: parsed.isBestseller,
        inStock: parsed.inStock,
        availableTonight: parsed.availableTonight,
        optionGroupsJson: parsed.optionGroups,
      },
    });
    res.status(201).json({ ok: true, item });
  }),
);

panel.patch(
  '/menu/items/:id',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const existing = await prisma.menuItem.findUnique({ where: { id: String(req.params.id) } });
    if (!existing || existing.merchantId !== mp.id) throw new HttpError(404, 'ITEM_NOT_FOUND', 'Item not found');

    const schema = z.object({
      name: z.string().optional(),
      priceBdt: z.number().positive().optional(),
      strikePriceBdt: z.number().positive().optional().nullable(),
      inStock: z.boolean().optional(),
      availableTonight: z.boolean().optional(),
      isBestseller: z.boolean().optional(),
      description: z.string().optional(),
      imageUrl: z.string().optional().nullable(),
      prepTimeMins: z.number().int().optional(),
    });
    const updated = await prisma.menuItem.update({
      where: { id: existing.id },
      data: schema.parse(req.body),
    });
    res.json({ ok: true, item: updated });
  }),
);

// === PROMOTIONS & REVIEWS (Restored links from Store) ===
panel.get(
  '/promotions',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const promotions = await prisma.promotion.findMany({ where: { merchantId: mp.id }, orderBy: { createdAt: 'desc' } });
    res.json({ ok: true, promotions });
  }),
);

panel.post(
  '/promotions',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const schema = z.object({
      title: z.string().min(2),
      promoCode: z.string().min(3).max(20),
      discountType: z.enum(['PERCENTAGE', 'FLAT_BDT', 'FREE_DELIVERY']),
      discountValue: z.number().min(0),
      minOrderBdt: z.number().min(0).default(0),
      daysValid: z.number().int().min(1).max(90).default(14),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const promo = await prisma.promotion.create({
      data: {
        merchantId: mp.id,
        title: parsed.title,
        promoCode: parsed.promoCode.toUpperCase(),
        discountType: parsed.discountType,
        discountValue: parsed.discountValue,
        minOrderBdt: parsed.minOrderBdt,
        endsAt: new Date(Date.now() + parsed.daysValid * 86400 * 1000),
      },
    });
    res.status(201).json({ ok: true, promo });
  }),
);

panel.get(
  '/reviews',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const reviews = await prisma.review.findMany({
      where: { merchantId: mp.id },
      include: { user: { select: { fullName: true } } },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ ok: true, rating: mp.rating, total: reviews.length, reviews });
  }),
);

panel.post(
  '/reviews/:id/reply',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const { reply } = z.object({ reply: z.string().min(2).max(400) }).parse(req.body);
    const prisma = getPrisma();
    const rev = await prisma.review.findUnique({ where: { id: String(req.params.id) } });
    if (!rev || rev.merchantId !== mp.id) throw new HttpError(404, 'REVIEW_NOT_FOUND', 'Review not found');

    const updated = await prisma.review.update({
      where: { id: rev.id },
      data: { merchantReply: reply, repliedAt: new Date() },
    });
    res.json({ ok: true, review: updated });
  }),
);

// === WALLET, EARNINGS & PAYOUT GUARD ===
panel.get(
  '/wallet',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const [wallet, orders, payoutAccount, pricing] = await Promise.all([
      prisma.walletAccount.upsert({
        where: { userId_role: { userId: req.auth!.userId, role: 'MERCHANT' } },
        update: {},
        create: { userId: req.auth!.userId, role: 'MERCHANT', balanceBdt: 0 },
        include: { transactions: { orderBy: { createdAt: 'desc' }, take: 30 } },
      }),
      prisma.foodOrder.findMany({ where: { merchantId: mp.id, status: 'DELIVERED' } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'MERCHANT', ownerId: mp.id } } }),
      prisma.appPricingConfig.findUnique({ where: { id: 'default' } }),
    ]);

    const grossSalesBdt = orders.reduce((s, o) => s + o.subtotalBdt, 0);
    const commissionBdt = orders.reduce((s, o) => s + o.commissionBdt, 0);
    res.json({
      ok: true,
      wallet,
      summary: {
        grossSalesBdt,
        commissionBdt,
        netEarningsBdt: Math.max(0, grossSalesBdt - commissionBdt),
        commissionRatePct: Math.round((pricing?.foodCommissionRate ?? 0.15) * 100),
        payoutSchedule: pricing?.payoutScheduleLabel ?? 'Every Friday at 12:00 AM GMT+6',
      },
      payoutAccount,
    });
  }),
);

panel.get(
  '/wallet/statement-pdf',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const orders = await prisma.foodOrder.findMany({ where: { merchantId: mp.id, status: 'DELIVERED' } });
    const gross = orders.reduce((s, o) => s + o.subtotalBdt, 0);
    const comm = orders.reduce((s, o) => s + o.commissionBdt, 0);

    const pdf = await generateReceiptPdf({
      title: `Merchant Payout Statement — ${mp.businessName}`,
      subtitle: `${mp.merchantType} Merchant Partner`,
      referenceCode: `STMT-${mp.id.slice(-6).toUpperCase()}`,
      lines: [
        { label: 'Delivered Orders', value: `${orders.length}` },
        { label: 'Gross Sales', value: `৳${gross.toFixed(0)}` },
        { label: 'Platform Commission (15%)', value: `-৳${comm.toFixed(0)}` },
      ],
      totalLabel: 'Net Settlement',
      totalValue: `৳${(gross - comm).toFixed(0)}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename="merchant-statement.pdf"');
    res.send(pdf);
  }),
);

/**
 * POST /api/v1/merchant/panel/payout/change-request
 * Business Rule: Payout changes require OTP + 48-hour security hold!
 */
panel.post(
  '/payout/change-request',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
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
      throw new HttpError(400, 'INVALID_OTP', 'Valid 6-digit SMS OTP is required to modify payout details');
    }
    await prisma.otpChallenge.update({ where: { id: challenge.id }, data: { consumedAt: new Date() } });

    const effectiveAt = new Date(Date.now() + env.payoutChangeHoldHours * 3600 * 1000);
    const updated = await prisma.payoutAccount.upsert({
      where: { ownerRole_ownerId: { ownerRole: 'MERCHANT', ownerId: mp.id } },
      update: {
        pendingPayloadJson: {
          provider: parsed.provider,
          accountNumber: parsed.accountNumber,
          holderName: parsed.holderName,
        },
        pendingEffectiveAt: effectiveAt,
      },
      create: {
        ownerRole: 'MERCHANT',
        ownerId: mp.id,
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
    res.json({
      ok: true,
      holdHours: env.payoutChangeHoldHours,
      effectiveAt,
      payoutAccount: updated,
    });
  }),
);

// === SPLIT STORE SETTINGS & SECURITY ===
panel.get(
  '/store',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const [staff, devices, payoutAccount] = await Promise.all([
      prisma.merchantStaff.findMany({ where: { merchantId: mp.id } }),
      prisma.activeDevice.findMany({ where: { ownerRole: 'MERCHANT', ownerId: mp.id } }),
      prisma.payoutAccount.findUnique({ where: { ownerRole_ownerId: { ownerRole: 'MERCHANT', ownerId: mp.id } } }),
    ]);
    res.json({
      ok: true,
      store: mp,
      staff,
      devices,
      payoutAccount,
      securityConfig: {
        passcodeDigits: 6,
        autoLogoutMinutes: env.roleInactivityMinutes,
        payoutHoldHours: env.payoutChangeHoldHours,
      },
    });
  }),
);

panel.patch(
  '/store/settings',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const schema = z.object({
      avgPrepMins: z.number().int().min(5).max(120).optional(),
      dailyOrderLimit: z.number().int().min(1).max(200).optional(),
      dailyCutoffTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
      hoursJson: z.record(z.string(), z.any()).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const updated = await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: parsed,
    });
    res.json({ ok: true, store: updated });
  }),
);

panel.post(
  '/security/change-pin',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const { currentPasscode, newPasscode } = z
      .object({
        currentPasscode: z.string().regex(/^\d{6}$/),
        newPasscode: z.string().regex(/^\d{6}$/, 'Merchant PIN must be 6 digits'),
      })
      .parse(req.body);
    if (!mp.passcodeHash || !(await bcrypt.compare(currentPasscode, mp.passcodeHash))) {
      throw new HttpError(400, 'WRONG_PIN', 'Current 6-digit PIN is incorrect');
    }
    const prisma = getPrisma();
    await prisma.merchantProfile.update({
      where: { id: mp.id },
      data: { passcodeHash: await bcrypt.hash(newPasscode, 10) },
    });
    res.json({ ok: true, message: '6-digit merchant passcode updated' });
  }),
);

panel.get(
  '/orders/:id/slip-pdf',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({
      where: { id: String(req.params.id) },
      include: { items: true, user: { select: { fullName: true, phone: true } } },
    });
    if (!order || order.merchantId !== mp.id) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');
    const pdf = await generateReceiptPdf({
      title: `Kitchen Slip — ${order.orderCode}`,
      subtitle: `${mp.businessName} · ${order.user.fullName}`,
      referenceCode: order.orderCode,
      lines: [
        ...order.items.map((i) => ({ label: `${i.quantity}x ${i.itemName}`, value: `৳${i.lineTotalBdt.toFixed(0)}` })),
        { label: 'Cooking Note', value: order.cookingNote || 'None' },
        { label: 'Delivery Address', value: order.deliveryAddress },
      ],
      totalLabel: `Order Total (${order.paymentMethod})`,
      totalValue: `৳${order.totalBdt.toFixed(0)}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="${order.orderCode}-slip.pdf"`);
    res.send(pdf);
  }),
);

panel.post(
  '/store/staff',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const parsed = z
      .object({
        name: z.string().min(2),
        phone: z.string().min(10),
        roleLabel: z.string().default('Kitchen Manager'),
      })
      .parse(req.body);
    const prisma = getPrisma();
    const staff = await prisma.merchantStaff.create({
      data: { merchantId: mp.id, ...parsed },
    });
    res.status(201).json({ ok: true, staff });
  }),
);

panel.delete(
  '/store/staff/:staffId',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    await prisma.merchantStaff.deleteMany({
      where: { id: String(req.params.staffId), merchantId: mp.id },
    });
    res.json({ ok: true });
  }),
);

panel.delete(
  '/security/devices/:deviceId',
  asyncHandler(async (req, res) => {
    const mp = await assertApprovedMerchant(req.roleSession!.profileId);
    const prisma = getPrisma();
    await prisma.activeDevice.deleteMany({
      where: { id: String(req.params.deviceId), ownerRole: 'MERCHANT', ownerId: mp.id },
    });
    res.json({ ok: true });
  }),
);

merchantRouter.use('/panel', panel);

