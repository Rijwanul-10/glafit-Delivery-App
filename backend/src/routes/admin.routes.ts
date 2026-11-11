import { Router } from 'express';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAdmin } from '../middleware/auth.js';
import { smsProvider } from '../services/smsProvider.js';

export const adminRouter = Router();
adminRouter.use(requireAdmin);

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

    await prisma.notificationItem.create({
      data: {
        userId: rp.userId,
        role: 'RIDER',
        category: 'SYSTEM',
        title:
          parsed.decision === 'APPROVED'
            ? 'Rider KYC Approved!'
            : parsed.decision === 'NEEDS_CHANGES'
              ? 'Rider KYC Needs Changes'
              : 'Rider Application Rejected',
        body:
          parsed.decision === 'APPROVED'
            ? 'You are approved! You can now go online from Rider Home.'
            : 'Please review the flagged items in your Rider application.',
      },
    });
    await smsProvider.sendAlert(rp.user.phone, `2Bee Rider status updated: ${parsed.decision}`);

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

    await prisma.notificationItem.create({
      data: {
        userId: mp.userId,
        role: 'MERCHANT',
        category: 'SYSTEM',
        title:
          parsed.decision === 'APPROVED'
            ? 'Merchant Verification Approved!'
            : 'Merchant Verification Update',
        body:
          parsed.decision === 'APPROVED'
            ? 'Your store is approved! Verify phone OTP & set your 6-digit passcode to open your merchant panel.'
            : 'Review requested KYC updates.',
      },
    });

    if (parsed.decision === 'APPROVED') {
      await smsProvider.sendAlert(
        mp.user.phone,
        `2Bee Merchant Approved! Login with your phone and set your permanent 6-digit passcode to unlock ${mp.businessName}.`,
      );
    }

    res.json({ ok: true, merchant: updated });
  }),
);

