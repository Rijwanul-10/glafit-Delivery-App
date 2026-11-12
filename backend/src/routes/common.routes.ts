import fs from 'node:fs';
import path from 'node:path';
import { Router } from 'express';
import multer from 'multer';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth } from '../middleware/auth.js';
import { mapsService } from '../services/mapsService.js';
import { paymentService } from '../services/paymentService.js';
import { getIO } from '../realtime/socketServer.js';
import { env } from '../config/env.js';

export const commonRouter = Router();

commonRouter.get('/payment-methods', (_req, res) => {
  res.json({ ok: true, ...paymentService.getAvailableMethods() });
});

commonRouter.get(
  '/places/search',
  asyncHandler(async (req, res) => {
    const q = String(req.query.q ?? '');
    const places = await mapsService.searchPlaces(q);
    res.json({ ok: true, places });
  }),
);

// Protected common endpoints
const protectedCommon = Router();
protectedCommon.use(requireAuth);

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    const dir = path.resolve(process.cwd(), env.localUploadDir);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (_req, file, cb) => {
    const safeExt = path.extname(file.originalname || '.jpg').replace(/[^a-zA-Z0-9.]/g, '') || '.jpg';
    cb(null, `${Date.now()}-${Math.random().toString(36).slice(2, 8)}${safeExt}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 15 * 1024 * 1024 },
});

protectedCommon.post(
  '/uploads',
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new HttpError(400, 'NO_FILE', 'Upload field "file" is required');
    }
    res.status(201).json({
      ok: true,
      url: `/uploads/${req.file.filename}`,
      originalName: req.file.originalname,
      sizeBytes: req.file.size,
    });
  }),
);

protectedCommon.get(
  '/notifications',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const role = (req.query.role as string | undefined)?.toUpperCase();
    const items = await prisma.notificationItem.findMany({
      where: {
        userId: req.auth!.userId,
        ...(role === 'CLIENT' || role === 'RIDER' || role === 'MERCHANT' ? { role } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    res.json({ ok: true, items, unreadCount: items.filter((i) => !i.isRead).length });
  }),
);

protectedCommon.post(
  '/notifications/read-all',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    await prisma.notificationItem.updateMany({
      where: { userId: req.auth!.userId, isRead: false },
      data: { isRead: true },
    });
    res.json({ ok: true });
  }),
);

protectedCommon.get(
  '/chat/:serviceType/:orderId',
  asyncHandler(async (req, res) => {
    const prisma = getPrisma();
    const thread = await prisma.chatThread.findUnique({
      where: { orderId: String(req.params.orderId) },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!thread) throw new HttpError(404, 'THREAD_NOT_FOUND', 'Chat thread not found');
    res.json({ ok: true, thread });
  }),
);

protectedCommon.post(
  '/chat/:threadId/messages',
  asyncHandler(async (req, res) => {
    const { body, senderRole } = z
      .object({
        body: z.string().min(1).max(1000),
        senderRole: z.enum(['CLIENT', 'RIDER', 'MERCHANT']).default('CLIENT'),
      })
      .parse(req.body);
    const prisma = getPrisma();
    const msg = await prisma.chatMessage.create({
      data: {
        threadId: String(req.params.threadId),
        senderId: req.auth!.userId,
        senderRole,
        body,
      },
    });
    getIO()?.to(`chat:${msg.threadId}`).emit('chat:message', msg);
    res.status(201).json({ ok: true, message: msg });
  }),
);

protectedCommon.post(
  '/sos',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      role: z.enum(['CLIENT', 'RIDER', 'MERCHANT']),
      orderId: z.string().optional(),
      lat: z.number(),
      lng: z.number(),
      note: z.string().optional(),
    });
    const parsed = schema.parse(req.body);
    const prisma = getPrisma();
    const incident = await prisma.sosIncident.create({
      data: { userId: req.auth!.userId, ...parsed },
    });
    res.status(201).json({
      ok: true,
      incident,
      emergencyHotline: '999',
      dispatchHotline: '16216',
    });
  }),
);

// Non-production solo preview simulation routes (lets a single browser user advance order/dispatch steps live)
if (env.nodeEnv !== 'production') {
  protectedCommon.post(
    '/demo/advance-food/:id',
    asyncHandler(async (req, res) => {
      const prisma = getPrisma();
      const order = await prisma.foodOrder.findUnique({ where: { id: String(req.params.id) } });
      if (!order) throw new HttpError(404, 'ORDER_NOT_FOUND', 'Food order not found');
      const rider = await prisma.riderProfile.findFirst({ where: { kycStatus: 'APPROVED' } });
      const seq = ['PLACED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'DELIVERED'] as const;
      const idx = seq.indexOf(order.status as (typeof seq)[number]);
      const nextStatus = idx >= 0 && idx < seq.length - 1 ? seq[idx + 1] : 'DELIVERED';
      const updated = await prisma.foodOrder.update({
        where: { id: order.id },
        data: {
          status: nextStatus,
          riderId: order.riderId ?? (idx >= 2 ? rider?.id : undefined),
          prepTimeMins: order.prepTimeMins ?? 20,
        },
        include: { items: true, merchant: true, rider: { include: { user: true } } },
      });
      getIO()?.to(`tracking:food:${order.id}`).emit('order:status', { orderId: order.id, status: nextStatus });
      res.json({ ok: true, order: updated });
    }),
  );

  protectedCommon.post(
    '/demo/advance-parcel/:id',
    asyncHandler(async (req, res) => {
      const prisma = getPrisma();
      const parcel = await prisma.parcelShipment.findUnique({ where: { id: String(req.params.id) } });
      if (!parcel) throw new HttpError(404, 'PARCEL_NOT_FOUND', 'Parcel not found');
      const rider = await prisma.riderProfile.findFirst({ where: { kycStatus: 'APPROVED' } });
      const seq = ['BOOKED', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED'] as const;
      const normalized = parcel.status === 'MATCHING' ? 'BOOKED' : parcel.status;
      const idx = seq.indexOf(normalized as (typeof seq)[number]);
      const nextStatus = idx >= 0 && idx < seq.length - 1 ? seq[idx + 1] : 'DELIVERED';
      const updated = await prisma.parcelShipment.update({
        where: { id: parcel.id },
        data: {
          status: nextStatus,
          riderId: parcel.riderId ?? rider?.id,
        },
      });
      getIO()?.to(`tracking:parcel:${parcel.id}`).emit('parcel:status', { parcelId: parcel.id, status: nextStatus });
      res.json({ ok: true, shipment: updated });
    }),
  );

  protectedCommon.post(
    '/demo/advance-ride/:id',
    asyncHandler(async (req, res) => {
      const prisma = getPrisma();
      const trip = await prisma.rideTrip.findUnique({ where: { id: String(req.params.id) } });
      if (!trip) throw new HttpError(404, 'RIDE_NOT_FOUND', 'Ride not found');
      const rider = await prisma.riderProfile.findFirst({ where: { kycStatus: 'APPROVED' } });
      const seq = ['MATCHING', 'RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP', 'COMPLETED'] as const;
      const idx = seq.indexOf(trip.status as (typeof seq)[number]);
      const nextStatus = idx >= 0 && idx < seq.length - 1 ? seq[idx + 1] : 'COMPLETED';
      const updated = await prisma.rideTrip.update({
        where: { id: trip.id },
        data: {
          status: nextStatus,
          riderId: trip.riderId ?? rider?.id,
        },
      });
      getIO()?.to(`tracking:ride:${trip.id}`).emit('ride:status', { tripId: trip.id, status: nextStatus });
      res.json({ ok: true, trip: updated });
    }),
  );

  protectedCommon.post(
    '/demo/seed-dispatch',
    asyncHandler(async (_req, res) => {
      const prisma = getPrisma();
      const client = await prisma.user.findFirst({ orderBy: { createdAt: 'asc' } });
      if (!client) throw new HttpError(400, 'NO_USER', 'No client user seeded');

      const existingParcel = await prisma.parcelShipment.findFirst({ where: { status: { in: ['BOOKED', 'MATCHING'] } } });
      let parcel = existingParcel;
      if (!parcel) {
        parcel = await prisma.parcelShipment.create({
          data: {
            trackingCode: `2B-P${Math.floor(1000 + Math.random() * 9000)}`,
            userId: client.id,
            tier: 'NORMAL_ECO',
            packageSizeClass: 'SMALL',
            category: 'Documents',
            weightKg: 2.0,
            lengthCm: 30,
            widthCm: 20,
            heightCm: 15,
            volumeCm3: 9000,
            fitsFrontCarrier: true,
            isProtected: true,
            protectionFeeBdt: 15,
            senderName: client.fullName ?? 'Tanvir Ahmed',
            senderPhone: client.phone,
            pickupAddress: 'Road 11, Banani',
            originZoneId: 'zone-banani',
            pickupLat: 23.7937,
            pickupLng: 90.4066,
            recipientName: 'Farhana Yasmin',
            recipientPhone: '+8801811111111',
            dropoffAddress: 'Road 13, Sector 7, Uttara',
            destinationZoneId: 'zone-uttara',
            dropoffLat: 23.8726,
            dropoffLng: 90.3983,
            distanceKm: 9.2,
            deliveryPin: '4821',
            deliveryChargeBdt: 95,
            riderPayoutBdt: 80,
            codCollectBdt: 500,
            paymentMethod: 'COD',
            paymentStatus: 'PENDING',
            status: 'MATCHING',
          },
        });
      }

      const existingRide = await prisma.rideTrip.findFirst({
        where: { status: 'MATCHING', pickupZoneId: 'zone-banani', dropoffZoneId: 'zone-uttara' },
      });
      let ride = existingRide;
      if (!ride) {
        ride = await prisma.rideTrip.create({
          data: {
            tripCode: `2B-R${Math.floor(1000 + Math.random() * 9000)}`,
            userId: client.id,
            fleetTier: '2BEE_EV_SOLO',
            pickupAddress: 'Banani Road 11',
            pickupZoneId: 'zone-banani',
            pickupLat: 23.7937,
            pickupLng: 90.4066,
            dropoffAddress: 'Uttara Sector 7',
            dropoffZoneId: 'zone-uttara',
            dropoffLat: 23.8726,
            dropoffLng: 90.3983,
            distanceKm: 9.2,
            etaMins: 24,
            baseFareBdt: 35,
            distanceFareBdt: 130,
            totalFareBdt: 165,
            riderPayoutBdt: 135,
            startPin: '7391',
            paymentMethod: 'COD',
            paymentStatus: 'PENDING',
            status: 'MATCHING',
          },
        });
      }
      res.json({ ok: true, parcel, ride });
    }),
  );

  protectedCommon.post(
    '/demo/auto-verify-rider',
    asyncHandler(async (req, res) => {
      const prisma = getPrisma();
      const rp = await prisma.riderProfile.findUnique({ where: { userId: req.auth!.userId } });
      if (!rp) throw new HttpError(404, 'RIDER_NOT_FOUND', 'Rider profile not found');
      const hasFront = rp.vehicleOwnership === 'RENTAL' || (rp.frontCarrierMaxKg ?? 0) > 0;
      const updated = await prisma.riderProfile.update({
        where: { id: rp.id },
        data: {
          kycStatus: 'APPROVED',
          frontCarrierVerified: hasFront,
          rearCarrierVerified: true,
          multiServiceEnabled: hasFront && rp.spareHelmetConfirmed,
          approvedAt: rp.approvedAt ?? new Date(),
        },
      });
      res.json({ ok: true, profile: updated });
    }),
  );

  protectedCommon.post(
    '/demo/auto-verify-merchant',
    asyncHandler(async (req, res) => {
      const prisma = getPrisma();
      const mp = await prisma.merchantProfile.findUnique({ where: { userId: req.auth!.userId } });
      if (!mp) throw new HttpError(404, 'MERCHANT_NOT_FOUND', 'Merchant profile not found');
      const updated = await prisma.merchantProfile.update({
        where: { id: mp.id },
        data: {
          kycStatus: 'APPROVED',
          approvedAt: mp.approvedAt ?? new Date(),
        },
      });
      res.json({ ok: true, profile: updated });
    }),
  );
}

commonRouter.use('/', protectedCommon);

