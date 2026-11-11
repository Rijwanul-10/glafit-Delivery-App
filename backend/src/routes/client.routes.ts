import { Router } from 'express';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth } from '../middleware/auth.js';
import { paymentService } from '../services/paymentService.js';

export const clientRouter = Router();
clientRouter.use(requireAuth);

/**
 * GET /api/v1/client/home
 * Serves unified Client Home (zones, service cards, trending kitchens, promos).
 */
clientRouter.get(
  '/home',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const userId = req.auth!.userId;

    const [user, zones, merchants, savedAddresses, activeFood, activeParcels, activeRides] =
      await Promise.all([
        prisma.user.findUnique({ where: { id: userId } }),
        prisma.zone.findMany({ orderBy: { name: 'asc' } }),
        prisma.merchantProfile.findMany({
          where: { kycStatus: 'APPROVED' },
          include: {
            promotions: { where: { isActive: true }, take: 1 },
            menuItems: { where: { isBestseller: true, inStock: true }, take: 2 },
          },
          orderBy: { rating: 'desc' },
          take: 10,
        }),
        prisma.savedAddress.findMany({ where: { userId } }),
        prisma.foodOrder.count({
          where: { userId, status: { in: ['PLACED', 'ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP'] } },
        }),
        prisma.parcelShipment.count({
          where: { userId, status: { in: ['BOOKED', 'MATCHING', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT'] } },
        }),
        prisma.rideTrip.count({
          where: { userId, status: { in: ['MATCHING', 'RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP'] } },
        }),
      ]);

    res.json({
      ok: true,
      greetingName: user?.fullName ?? 'Customer',
      zones,
      savedAddresses,
      activeSummary: {
        food: activeFood,
        parcel: activeParcels,
        ride: activeRides,
        totalActive: activeFood + activeParcels + activeRides,
      },
      trendingMerchants: merchants.map((m) => ({
        id: m.id,
        businessName: m.businessName,
        merchantType: m.merchantType,
        cuisines: m.cuisinesJson,
        areaZoneId: m.areaZoneId,
        rating: m.rating,
        reviewCount: m.reviewCount,
        avgPrepMins: m.avgPrepMins,
        deliveryFeeBdt: m.deliveryFeeBdt,
        minOrderBdt: m.minOrderBdt,
        isStoreOpen: m.isStoreOpen,
        coverImageUrl: m.coverImageUrl,
        promoBadge: m.promotions[0]?.promoCode ?? null,
        featuredItems: m.menuItems,
      })),
    });
  }),
);

clientRouter.get(
  '/profile',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const userId = req.auth!.userId;
    const [user, savedAddresses, favCount] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId } }),
      prisma.savedAddress.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } }),
      prisma.favoriteEntry.count({ where: { userId } }),
    ]);
    res.json({ ok: true, user, savedAddresses, favoritesCount: favCount });
  }),
);

clientRouter.patch(
  '/profile',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      fullName: z.string().min(2).max(80).optional(),
      email: z.string().email().optional().or(z.literal('')),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const user = await prisma.user.update({
      where: { id: req.auth!.userId },
      data: {
        ...(parsed.fullName ? { fullName: parsed.fullName } : {}),
        ...(parsed.email !== undefined ? { email: parsed.email || null } : {}),
      },
    });
    res.json({ ok: true, user });
  }),
);

/**
 * GET /api/v1/client/wallet
 */
clientRouter.get(
  '/wallet',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const userId = req.auth!.userId;
    const wallet = await prisma.walletAccount.upsert({
      where: { userId_role: { userId, role: 'CLIENT' } },
      update: {},
      create: { userId, role: 'CLIENT', balanceBdt: 0 },
      include: { transactions: { orderBy: { createdAt: 'desc' }, take: 30 } },
    });
    const vouchers = await prisma.promotion.findMany({
      where: { isActive: true },
      include: { merchant: { select: { businessName: true } } },
      take: 8,
    });
    res.json({
      ok: true,
      wallet,
      paymentMethods: paymentService.getAvailableMethods(),
      vouchers,
    });
  }),
);

clientRouter.post(
  '/wallet/topup/stripe-intent',
  asyncHandler(async (req, res) => {
    const { amountBdt } = z.object({ amountBdt: z.number().min(50).max(50000) }).parse(req.body);
    const intent = await paymentService.createStripeSandboxIntent({
      amountBdt,
      serviceType: 'WALLET_TOPUP',
      referenceCode: `WLT-${Date.now().toString().slice(-6)}`,
      userId: req.auth!.userId,
    });
    res.json({ ok: true, ...intent });
  }),
);

clientRouter.post(
  '/wallet/topup/confirm',
  asyncHandler(async (req, res) => {
    const { paymentIntentId, amountBdt } = z
      .object({ paymentIntentId: z.string().min(5), amountBdt: z.number().min(50).max(50000) })
      .parse(req.body);
    const confirmed = await paymentService.confirmSandboxIntent(paymentIntentId);
    if (!confirmed.paid) {
      throw new HttpError(402, 'PAYMENT_FAILED', 'Stripe Sandbox payment was not completed');
    }
    const prisma = getPrisma();
    const userId = req.auth!.userId;
    const wallet = await prisma.$transaction(async (tx) => {
      const acc = await tx.walletAccount.upsert({
        where: { userId_role: { userId, role: 'CLIENT' } },
        update: { balanceBdt: { increment: amountBdt } },
        create: { userId, role: 'CLIENT', balanceBdt: amountBdt },
      });
      await tx.walletTransaction.create({
        data: {
          walletId: acc.id,
          type: 'TOPUP',
          amountBdt,
          referenceCode: confirmed.trxId,
          description: '2Bee Wallet Top-up (Stripe Sandbox)',
        },
      });
      return acc;
    });
    res.json({ ok: true, wallet, trxId: confirmed.trxId });
  }),
);

clientRouter.get(
  '/addresses',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const items = await prisma.savedAddress.findMany({ where: { userId: req.auth!.userId } });
    res.json({ ok: true, items });
  }),
);

clientRouter.post(
  '/addresses',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      label: z.string().min(1).max(32),
      address: z.string().min(3),
      zoneId: z.string().default('zone-banani'),
      lat: z.number(),
      lng: z.number(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const address = await prisma.savedAddress.create({
      data: { userId: req.auth!.userId, ...parsed },
    });
    res.status(201).json({ ok: true, address });
  }),
);

clientRouter.delete(
  '/addresses/:id',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    await prisma.savedAddress.deleteMany({
      where: { id: String(req.params.id), userId: req.auth!.userId },
    });
    res.json({ ok: true });
  }),
);

clientRouter.get(
  '/favorites',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const favs = await prisma.favoriteEntry.findMany({ where: { userId: req.auth!.userId } });
    const restaurantIds = favs.filter((f) => f.targetType === 'RESTAURANT').map((f) => f.targetId);
    const dishIds = favs.filter((f) => f.targetType === 'DISH').map((f) => f.targetId);

    const [restaurants, dishes] = await Promise.all([
      restaurantIds.length
        ? prisma.merchantProfile.findMany({ where: { id: { in: restaurantIds } } })
        : [],
      dishIds.length
        ? prisma.menuItem.findMany({
            where: { id: { in: dishIds } },
            include: { merchant: { select: { id: true, businessName: true } } },
          })
        : [],
    ]);
    res.json({ ok: true, restaurants, dishes });
  }),
);

clientRouter.post(
  '/favorites/toggle',
  asyncHandler(async (req, res) => {
    const { targetType, targetId } = z
      .object({ targetType: z.enum(['RESTAURANT', 'DISH']), targetId: z.string().min(1) })
      .parse(req.body);
    const prisma = getPrisma();
    const existing = await prisma.favoriteEntry.findUnique({
      where: {
        userId_targetType_targetId: {
          userId: req.auth!.userId,
          targetType,
          targetId,
        },
      },
    });
    if (existing) {
      await prisma.favoriteEntry.delete({ where: { id: existing.id } });
      res.json({ ok: true, favorited: false });
      return;
    }
    await prisma.favoriteEntry.create({
      data: { userId: req.auth!.userId, targetType, targetId },
    });
    res.json({ ok: true, favorited: true });
  }),
);

/**
 * GET /api/v1/client/activity
 * Unified Client Activity across ALL services (Food | Parcel | Ride).
 * STRICT ISOLATION: Parcel & Ride DTOs never expose multi-service batch info!
 */
clientRouter.get(
  '/activity',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const userId = req.auth!.userId;
    const typeFilter = (req.query.type as string | undefined)?.toUpperCase() ?? 'ALL';

    const [foodOrders, parcelShipments, rideTrips] = await Promise.all([
      typeFilter === 'ALL' || typeFilter === 'FOOD'
        ? prisma.foodOrder.findMany({
            where: { userId },
            include: { merchant: { select: { businessName: true, coverImageUrl: true } }, items: true },
            orderBy: { createdAt: 'desc' },
          })
        : [],
      typeFilter === 'ALL' || typeFilter === 'PARCEL'
        ? prisma.parcelShipment.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
          })
        : [],
      typeFilter === 'ALL' || typeFilter === 'RIDE'
        ? prisma.rideTrip.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
          })
        : [],
    ]);

    const feed = [
      ...foodOrders.map((f) => ({
        id: f.id,
        code: f.orderCode,
        serviceType: 'FOOD' as const,
        title: f.merchant.businessName,
        subtitle: `${f.items.length} item(s) · ${f.deliveryAddress}`,
        amountBdt: f.totalBdt,
        status: f.status,
        isActive: !['DELIVERED', 'REJECTED', 'CANCELLED'].includes(f.status),
        createdAt: f.createdAt,
      })),
      ...parcelShipments.map((p) => ({
        id: p.id,
        code: p.trackingCode,
        serviceType: 'PARCEL' as const,
        title: `Parcel to ${p.recipientName}`,
        subtitle: `${p.pickupAddress} → ${p.dropoffAddress}`,
        amountBdt: p.deliveryChargeBdt,
        status: p.status,
        isActive: !['DELIVERED', 'CANCELLED', 'RETURNED'].includes(p.status),
        createdAt: p.createdAt,
      })),
      ...rideTrips.map((r) => ({
        id: r.id,
        code: r.tripCode,
        serviceType: 'RIDE' as const,
        title: `${r.fleetTier.replace(/_/g, ' ')} Ride`,
        subtitle: `${r.pickupAddress} → ${r.dropoffAddress}`,
        amountBdt: r.totalFareBdt,
        status: r.status,
        isActive: !['COMPLETED', 'CANCELLED'].includes(r.status),
        createdAt: r.createdAt,
      })),
    ].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

    res.json({
      ok: true,
      active: feed.filter((x) => x.isActive),
      past: feed.filter((x) => !x.isActive),
    });
  }),
);

