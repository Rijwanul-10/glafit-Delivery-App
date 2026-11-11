import { Router } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { getPrisma } from '../lib/prisma.js';
import { asyncHandler, HttpError } from '../middleware/errorHandler.js';
import { requireAuth, signAccessToken, signRefreshToken } from '../middleware/auth.js';
import { generateOtpCode, hashOtp, smsProvider } from '../services/smsProvider.js';
import { env } from '../config/env.js';

export const authRouter = Router();

export function normalizeBdPhone(raw: string): string {
  const digits = raw.replace(/[^\d]/g, '');
  if (/^8801[3-9]\d{8}$/.test(digits)) return `+${digits}`;
  if (/^01[3-9]\d{8}$/.test(digits)) return `+88${digits}`;
  if (/^1[3-9]\d{8}$/.test(digits)) return `+880${digits}`;
  throw new HttpError(400, 'INVALID_PHONE', 'Enter a valid Bangladesh phone number (+8801XXXXXXXXX)');
}

async function buildRoleStateSummary(userId: string) {
  const prisma = getPrisma();
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { riderProfile: true, merchantProfile: true },
  });
  if (!user) throw new HttpError(404, 'USER_NOT_FOUND', 'User not found');

  const rp = user.riderProfile;
  const mp = user.merchantProfile;

  return {
    user: {
      id: user.id,
      phone: user.phone,
      fullName: user.fullName,
      email: user.email,
      avatarUrl: user.avatarUrl,
      activeRole: user.activeRole,
    },
    roles: {
      client: {
        registered: true,
        status: 'ACTIVE',
        requiresPasscode: false,
      },
      rider: rp
        ? {
            registered: true,
            profileId: rp.id,
            kycStatus: rp.kycStatus,
            requiresPasscode: true, // Always 4-digit created at reg Step 8
            passcodeLength: 4,
            biometricEnabled: rp.biometricEnabled,
            isOnline: rp.isOnline,
          }
        : {
            registered: false,
            kycStatus: 'NOT_STARTED',
            requiresPasscode: false,
            passcodeLength: 4,
          },
      merchant: mp
        ? {
            registered: true,
            profileId: mp.id,
            merchantType: mp.merchantType, // PHYSICAL | HOME_KITCHEN
            businessName: mp.businessName,
            kycStatus: mp.kycStatus,
            passcodeSet: mp.passcodeSet,
            passcodeLength: 6, // Always 6-digit created AFTER approval
            needsPostApprovalPinSetup: mp.kycStatus === 'APPROVED' && !mp.passcodeSet,
            requiresPasscode: mp.kycStatus === 'APPROVED' && mp.passcodeSet,
            biometricEnabled: mp.biometricEnabled,
          }
        : {
            registered: false,
            kycStatus: 'NOT_STARTED',
            passcodeSet: false,
            passcodeLength: 6,
            needsPostApprovalPinSetup: false,
            requiresPasscode: false,
          },
    },
  };
}

/**
 * POST /api/v1/auth/otp/request
 * One account per phone (OTP login only; no Google login).
 */
authRouter.post(
  '/otp/request',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      phone: z.string().min(10),
      purpose: z.enum(['LOGIN', 'FORGOT_PASSCODE', 'MERCHANT_APPROVAL_PIN', 'PAYOUT_CHANGE']).default('LOGIN'),
    });
    const parsed = schema.parse(req.body);
    const phone = normalizeBdPhone(parsed.phone);
    const prisma = getPrisma();

    const code = generateOtpCode();
    await prisma.otpChallenge.create({
      data: {
        phone,
        purpose: parsed.purpose,
        codeHash: hashOtp(code),
        expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      },
    });

    const smsRes = await smsProvider.sendOtp(phone, code, parsed.purpose);
    res.json({
      ok: true,
      phone,
      purpose: parsed.purpose,
      expiresInSeconds: 300,
      resendAfterSeconds: 30,
      ...(smsRes.devHint ? { devOtpHint: smsRes.devHint } : {}),
    });
  }),
);

/**
 * POST /api/v1/auth/otp/verify
 */
authRouter.post(
  '/otp/verify',
  asyncHandler(async (req, res) => {
    const schema = z.object({
      phone: z.string().min(10),
      code: z.string().regex(/^\d{6}$/, 'OTP must be 6 digits'),
      purpose: z.enum(['LOGIN', 'FORGOT_PASSCODE', 'MERCHANT_APPROVAL_PIN', 'PAYOUT_CHANGE']).default('LOGIN'),
      fullName: z.string().optional(),
    });
    const parsed = schema.parse(req.body);
    const phone = normalizeBdPhone(parsed.phone);
    const prisma = getPrisma();

    const challenge = await prisma.otpChallenge.findFirst({
      where: { phone, purpose: parsed.purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!challenge) {
      throw new HttpError(400, 'OTP_NOT_FOUND', 'No active OTP challenge for this phone number');
    }
    if (challenge.expiresAt.getTime() < Date.now()) {
      throw new HttpError(400, 'OTP_EXPIRED', 'OTP has expired. Request a new code.');
    }
    if (challenge.attempts >= 5) {
      throw new HttpError(429, 'OTP_TOO_MANY_ATTEMPTS', 'Too many wrong attempts. Request a new OTP.');
    }

    if (challenge.codeHash !== hashOtp(parsed.code)) {
      await prisma.otpChallenge.update({
        where: { id: challenge.id },
        data: { attempts: { increment: 1 } },
      });
      throw new HttpError(400, 'OTP_INVALID', 'Incorrect 6-digit OTP code');
    }

    await prisma.otpChallenge.update({
      where: { id: challenge.id },
      data: { consumedAt: new Date() },
    });

    let user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          phone,
          fullName: parsed.fullName?.trim() || '2Bee Customer',
          activeRole: 'CLIENT',
        },
      });
      await prisma.walletAccount.create({
        data: { userId: user.id, role: 'CLIENT', balanceBdt: 0 },
      });
    } else {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { lastActiveAt: new Date() },
      });
    }

    const summary = await buildRoleStateSummary(user.id);
    const accessToken = signAccessToken(user.id, user.phone);
    const refreshToken = signRefreshToken(user.id, user.phone);

    res.json({
      ok: true,
      accessToken,
      refreshToken,
      inactivityTimeoutMinutes: env.roleInactivityMinutes,
      ...summary,
    });
  }),
);

authRouter.get(
  '/me/roles',
  requireAuth,
  asyncHandler(async (req, res) => {
    const summary = await buildRoleStateSummary(req.auth!.userId);
    res.json({ ok: true, ...summary });
  }),
);

authRouter.post(
  '/switch-role',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { role } = z.object({ role: z.enum(['CLIENT', 'RIDER', 'MERCHANT']) }).parse(req.body);
    const prisma = getPrisma();
    await prisma.user.update({
      where: { id: req.auth!.userId },
      data: { activeRole: role, lastActiveAt: new Date() },
    });
    const summary = await buildRoleStateSummary(req.auth!.userId);
    res.json({ ok: true, ...summary });
  }),
);

export async function verifyStoredPin(rawPin: string, hash: string | null | undefined): Promise<boolean> {
  if (!hash) return false;
  return bcrypt.compare(rawPin, hash);
}

