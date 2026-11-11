import { Router } from 'express';
import type { Prisma } from '@prisma/client';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth } from '../middleware/auth.js';
import { paymentService } from '../services/paymentService.js';
import { resolveZoneByCoords } from '../services/zoneService.js';
import { getIO } from '../realtime/socketServer.js';
import { generateReceiptPdf } from '../services/pdfService.js';

export const foodRouter = Router();
foodRouter.use(requireAuth);

function startOfToday(): Date {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function isPastCutoff(cutoffHHMM: string | null): boolean {
  if (!cutoffHHMM || !/^\d{2}:\d{2}$/.test(cutoffHHMM)) return false;
  const [h, m] = cutoffHHMM.split(':').map(Number);
  const now = new Date();
  return now.getHours() > h || (now.getHours() === h && now.getMinutes() > m);
}

foodRouter.get(
  '/restaurants',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const q = ((req.query.q as string) ?? '').trim().toLowerCase();
    const typeFilter = (req.query.type as string | undefined)?.toUpperCase();

    const merchants = await prisma.merchantProfile.findMany({
      where: {
        kycStatus: 'APPROVED',
        ...(typeFilter === 'PHYSICAL' || typeFilter === 'HOME_KITCHEN' ? { merchantType: typeFilter } : {}),
      },
      include: {
        promotions: { where: { isActive: true } },
        menuItems: { where: { inStock: true }, take: 5 },
      },
      orderBy: { rating: 'desc' },
    });

    const todayCounts = await prisma.foodOrder.groupBy({
      by: ['merchantId'],
      where: { createdAt: { gte: startOfToday() }, status: { notIn: ['REJECTED', 'CANCELLED'] } },
      _count: { id: true },
    });
    const countMap = new Map(todayCounts.map((c) => [c.merchantId, c._count.id]));

    const filtered = merchants
      .filter((m) => {
        if (!q) return true;
        const nameMatch = m.businessName.toLowerCase().includes(q);
        const cuisineMatch = JSON.stringify(m.cuisinesJson).toLowerCase().includes(q);
        const itemMatch = m.menuItems.some((i) => i.name.toLowerCase().includes(q));
        return nameMatch || cuisineMatch || itemMatch;
      })
      .map((m) => {
        const todayOrders = countMap.get(m.id) ?? 0;
        const hkQuotaFull = m.merchantType === 'HOME_KITCHEN' && m.dailyOrderLimit !== null && todayOrders >= m.dailyOrderLimit;
        const hkPastCutoff = m.merchantType === 'HOME_KITCHEN' && isPastCutoff(m.dailyCutoffTime);
        return {
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
          isStoreOpen: m.isStoreOpen && !hkQuotaFull && !hkPastCutoff,
          hygieneConfirmed: m.hygieneConfirmed,
          hygieneScore: m.hygieneScore,
          dailyOrderLimit: m.merchantType === 'HOME_KITCHEN' ? m.dailyOrderLimit : null,
          remainingDailySlots:
            m.merchantType === 'HOME_KITCHEN' && m.dailyOrderLimit !== null
              ? Math.max(0, m.dailyOrderLimit - todayOrders)
              : null,
          dailyCutoffTime: m.merchantType === 'HOME_KITCHEN' ? m.dailyCutoffTime : null,
          coverImageUrl: m.coverImageUrl,
          promos: m.promotions,
        };
      });

    res.json({ ok: true, restaurants: filtered });
  }),
);

foodRouter.get(
  '/restaurants/:id',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const merchant = await prisma.merchantProfile.findUnique({
      where: { id: String(req.params.id) },
      include: {
        categories: {
          orderBy: { sortOrder: 'asc' },
          include: { items: true },
        },
        promotions: { where: { isActive: true } },
        reviews: {
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { user: { select: { fullName: true } } },
        },
      },
    });
    if (!merchant) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Restaurant not found');

    const todayOrders = await prisma.foodOrder.count({
      where: { merchantId: merchant.id, createdAt: { gte: startOfToday() }, status: { notIn: ['REJECTED', 'CANCELLED'] } },
    });

    res.json({
      ok: true,
      merchant: {
        ...merchant,
        todayOrderCount: todayOrders,
        remainingDailySlots:
          merchant.merchantType === 'HOME_KITCHEN' && merchant.dailyOrderLimit !== null
            ? Math.max(0, merchant.dailyOrderLimit - todayOrders)
            : null,
      },
    });
  }),
);

/**
 * POST /api/v1/food/orders/checkout
 * Supports COD & Online (Stripe Sandbox); validates Home Kitchen daily quota & cutoff!
 */
foodRouter.post(
  '/orders/checkout',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      merchantId: z.string().min(1),
      items: z
        .array(
          z.object({
            menuItemId: z.string().min(1),
            quantity: z.number().int().min(1).max(25),
            selectedOptions: z.array(z.object({ group: z.string(), name: z.string(), extraBdt: z.number().default(0) })).default([]),
          }),
        )
        .min(1),
      deliveryAddress: z.string().min(3),
      deliveryZoneId: z.string().optional(),
      deliveryLat: z.number().default(23.7937),
      deliveryLng: z.number().default(90.4066),
      scheduleMode: z.enum(['NOW', 'SCHEDULED']).default('NOW'),
      scheduledFor: z.string().datetime().optional(),
      cookingNote: z.string().max(300).optional(),
      riderNote: z.string().max(300).optional(),
      promoCode: z.string().optional(),
      paymentMethod: z.enum(['COD', 'STRIPE_SANDBOX']),
      stripePaymentIntentId: z.string().optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();

    const merchant = await prisma.merchantProfile.findUnique({ where: { id: parsed.merchantId } });
    if (!merchant || merchant.kycStatus !== 'APPROVED') {
      throw new HttpError(404, 'MERCHANT_UNAVAILABLE', 'Restaurant is not approved or unavailable');
    }
    if (!merchant.isStoreOpen || (merchant.pausedUntil && merchant.pausedUntil.getTime() > Date.now())) {
      throw new HttpError(400, 'STORE_CLOSED', 'Store is currently closed or paused');
    }

    if (merchant.merchantType === 'HOME_KITCHEN') {
      const todayCount = await prisma.foodOrder.count({
        where: { merchantId: merchant.id, createdAt: { gte: startOfToday() }, status: { notIn: ['REJECTED', 'CANCELLED'] } },
      });
      if (merchant.dailyOrderLimit !== null && todayCount >= merchant.dailyOrderLimit) {
        throw new HttpError(400, 'HOME_KITCHEN_QUOTA_FULL', 'Daily home kitchen order limit reached');
      }
      if (isPastCutoff(merchant.dailyCutoffTime)) {
        throw new HttpError(400, 'HOME_KITCHEN_CUTOFF_PASSED', `Order cutoff time (${merchant.dailyCutoffTime}) has passed`);
      }
    }

    const menuItemIds = parsed.items.map((i) => i.menuItemId);
    const dbItems = await prisma.menuItem.findMany({
      where: { id: { in: menuItemIds }, merchantId: merchant.id },
    });
    const itemMap = new Map(dbItems.map((i) => [i.id, i]));

    let subtotalBdt = 0;
    const orderLines: Prisma.FoodOrderItemCreateWithoutOrderInput[] = [];

    for (const line of parsed.items) {
      const dbItem = itemMap.get(line.menuItemId);
      if (!dbItem || !dbItem.inStock) {
        throw new HttpError(400, 'ITEM_UNAVAILABLE', `Menu item ${line.menuItemId} is unavailable`);
      }
      if (merchant.merchantType === 'HOME_KITCHEN' && !dbItem.availableTonight) {
        throw new HttpError(400, 'ITEM_UNAVAILABLE', `${dbItem.name} is sold out for tonight`);
      }
      const extras = line.selectedOptions.reduce((sum, o) => sum + (o.extraBdt || 0), 0);
      const unitPrice = dbItem.priceBdt + extras;
      const lineTotal = unitPrice * line.quantity;
      subtotalBdt += lineTotal;
      orderLines.push({
        menuItemId: dbItem.id,
        itemName: dbItem.name,
        unitPriceBdt: unitPrice,
        quantity: line.quantity,
        selectedOptionsJson: line.selectedOptions,
        lineTotalBdt: lineTotal,
      });
    }

    if (subtotalBdt < merchant.minOrderBdt) {
      throw new HttpError(400, 'BELOW_MIN_ORDER', `Minimum order is ৳${merchant.minOrderBdt}`);
    }

    const pricing = (await prisma.appPricingConfig.findUnique({ where: { id: 'default' } })) ?? {
      foodCommissionRate: 0.15,
      foodDeliveryFeeBdt: merchant.deliveryFeeBdt,
      foodPackagingFeeBdt: 15,
      foodServiceFeeBdt: 10,
    };

    let discountBdt = 0;
    let appliedPromo: string | null = null;
    if (parsed.promoCode) {
      const promo = await prisma.promotion.findFirst({
        where: { merchantId: merchant.id, promoCode: parsed.promoCode.toUpperCase(), isActive: true },
      });
      if (promo && subtotalBdt >= promo.minOrderBdt) {
        appliedPromo = promo.promoCode;
        if (promo.discountType === 'PERCENTAGE') {
          discountBdt = Math.round((subtotalBdt * promo.discountValue) / 100);
        } else if (promo.discountType === 'FLAT_BDT') {
          discountBdt = promo.discountValue;
        } else if (promo.discountType === 'FREE_DELIVERY') {
          discountBdt = merchant.deliveryFeeBdt;
        }
      }
    }

    const deliveryFeeBdt = merchant.deliveryFeeBdt;
    const packagingFeeBdt = pricing.foodPackagingFeeBdt;
    const serviceFeeBdt = pricing.foodServiceFeeBdt;
    const totalBdt = Math.max(0, subtotalBdt + deliveryFeeBdt + packagingFeeBdt + serviceFeeBdt - discountBdt);
    const commissionBdt = Number((subtotalBdt * pricing.foodCommissionRate).toFixed(2));
    const zone = await resolveZoneByCoords(prisma, parsed.deliveryLat, parsed.deliveryLng, parsed.deliveryZoneId);

    let stripeIntentId: string | null = parsed.stripePaymentIntentId ?? null;
    let paymentStatus: 'PENDING' | 'PAID' = 'PENDING';
    if (parsed.paymentMethod === 'STRIPE_SANDBOX') {
      if (!stripeIntentId) {
        const intent = await paymentService.createStripeSandboxIntent({
          amountBdt: totalBdt,
          serviceType: 'FOOD',
          referenceCode: `FOOD-${Date.now().toString().slice(-5)}`,
          userId: req.auth!.userId,
        });
        stripeIntentId = intent.paymentIntentId;
      }
      const verified = await paymentService.confirmSandboxIntent(stripeIntentId);
      if (!verified.paid) throw new HttpError(402, 'PAYMENT_FAILED', 'Stripe Sandbox payment failed');
      paymentStatus = 'PAID';
    }

    const orderCode = `FOOD-${Math.floor(1000 + Math.random() * 9000)}`;
    const deliveryPin = String(Math.floor(1000 + Math.random() * 9000));
    const acceptExpiresAt = new Date(Date.now() + 60 * 1000);

    const order = await prisma.foodOrder.create({
      data: {
        orderCode,
        userId: req.auth!.userId,
        merchantId: merchant.id,
        paymentMethod: parsed.paymentMethod,
        paymentStatus,
        stripeIntentId,
        deliveryAddress: parsed.deliveryAddress,
        deliveryZoneId: zone.id,
        deliveryLat: parsed.deliveryLat,
        deliveryLng: parsed.deliveryLng,
        scheduleMode: parsed.scheduleMode,
        scheduledFor: parsed.scheduledFor ? new Date(parsed.scheduledFor) : null,
        cookingNote: parsed.cookingNote,
        riderNote: parsed.riderNote,
        promoCode: appliedPromo,
        subtotalBdt,
        deliveryFeeBdt,
        packagingFeeBdt,
        serviceFeeBdt,
        discountBdt,
        commissionBdt,
        totalBdt,
        acceptExpiresAt,
        deliveryPin,
        items: { create: orderLines },
      },
      include: { items: true, merchant: true },
    });

    await prisma.chatThread.create({
      data: { serviceType: 'FOOD', orderId: order.id, clientId: req.auth!.userId },
    });

    getIO()?.to(`merchant:${merchant.id}`).emit('merchant:new_order', {
      orderId: order.id,
      orderCode: order.orderCode,
      totalBdt: order.totalBdt,
      itemsCount: order.items.length,
      expiresAt: acceptExpiresAt.toISOString(),
    });

    res.status(201).json({ ok: true, order });
  }),
);

foodRouter.post(
  '/stripe-intent',
  asyncHandler(async (req, res) => {
    const { amountBdt } = z.object({ amountBdt: z.number().positive() }).parse(req.body);
    const intent = await paymentService.createStripeSandboxIntent({
      amountBdt,
      serviceType: 'FOOD',
      referenceCode: `FD-PRE-${Date.now().toString().slice(-5)}`,
      userId: req.auth!.userId,
    });
    res.json({ ok: true, ...intent });
  }),
);

foodRouter.get(
  '/orders/:id',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({
      where: { id: String(req.params.id) },
      include: {
        items: true,
        merchant: {
          select: {
            id: true,
            businessName: true,
            merchantType: true,
            address: true,
            lat: true,
            lng: true,
            contactPhone: true,
          },
        },
        rider: {
          include: { user: { select: { fullName: true, phone: true, avatarUrl: true } } },
        },
      },
    });
    if (!order || order.userId !== req.auth!.userId) {
      throw new HttpError(404, 'ORDER_NOT_FOUND', 'Food order not found');
    }
    res.json({ ok: true, order });
  }),
);

foodRouter.post(
  '/orders/:id/rate',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      restaurantRating: z.number().int().min(1).max(5),
      riderRating: z.number().int().min(1).max(5).optional(),
      tipBdt: z.number().min(0).max(2000).default(0),
      tags: z.array(z.string()).default([]),
      comment: z.string().max(400).optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
    if (!order || order.userId !== req.auth!.userId) {
      throw new HttpError(404, 'ORDER_NOT_FOUND', 'Food order not found');
    }
    const review = await prisma.review.create({
      data: {
        merchantId: order.merchantId,
        userId: req.auth!.userId,
        serviceType: 'FOOD',
        orderId: order.id,
        rating: parsed.restaurantRating,
        riderRating: parsed.riderRating,
        tagsJson: parsed.tags,
        comment: parsed.comment,
      },
    });

    if (parsed.tipBdt > 0 && order.riderId) {
      const rider = await prisma.riderProfile.findUnique({ where: { id: order.riderId } });
      if (rider) {
        const w = await prisma.walletAccount.upsert({
          where: { userId_role: { userId: rider.userId, role: 'RIDER' } },
          update: { balanceBdt: { increment: parsed.tipBdt } },
          create: { userId: rider.userId, role: 'RIDER', balanceBdt: parsed.tipBdt },
        });
        await prisma.walletTransaction.create({
          data: {
            walletId: w.id,
            type: 'BONUS',
            amountBdt: parsed.tipBdt,
            referenceCode: order.orderCode,
            description: `Customer tip for ${order.orderCode}`,
          },
        });
      }
    }
    res.status(201).json({ ok: true, review });
  }),
);

foodRouter.get(
  '/orders/:id/pdf',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const order = await prisma.foodOrder.findUnique({
      where: { id: String(req.params.id) },
      include: { merchant: true, items: true },
    });
    if (!order || order.userId !== req.auth!.userId) {
      throw new HttpError(404, 'ORDER_NOT_FOUND', 'Order not found');
    }
    const pdf = await generateReceiptPdf({
      title: `Food Receipt — ${order.merchant.businessName}`,
      subtitle: '2Bee Food Delivery',
      referenceCode: order.orderCode,
      lines: [
        ...order.items.map((i) => ({ label: `${i.quantity}x ${i.itemName}`, value: `৳${i.lineTotalBdt.toFixed(0)}` })),
        { label: 'Delivery Fee', value: `৳${order.deliveryFeeBdt.toFixed(0)}` },
        { label: 'Packaging & Service Fee', value: `৳${(order.packagingFeeBdt + order.serviceFeeBdt).toFixed(0)}` },
        { label: 'Discount', value: `-৳${order.discountBdt.toFixed(0)}` },
      ],
      totalLabel: `Total (${order.paymentMethod})`,
      totalValue: `৳${order.totalBdt.toFixed(0)}`,
    });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${order.orderCode}.pdf"`);
    res.send(pdf);
  }),
);
