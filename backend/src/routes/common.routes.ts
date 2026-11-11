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

commonRouter.use('/', protectedCommon);

