import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';
import { getMessaging, type SendResponse } from 'firebase-admin/messaging';
import { env } from '../config/env.js';
import { getPrisma } from '../lib/prisma.js';

let initialized = false;

function ensureFirebaseApp(): App | null {
  const existing = getApps();
  if (existing.length > 0) {
    initialized = true;
    return existing[0] ?? null;
  }
  if (!env.firebaseProjectId || !env.firebaseClientEmail || !env.firebasePrivateKey) {
    return null;
  }
  try {
    const app = initializeApp({
      credential: cert({
        projectId: env.firebaseProjectId,
        clientEmail: env.firebaseClientEmail,
        privateKey: env.firebasePrivateKey,
      }),
    });
    initialized = true;
    return app;
  } catch (err) {
    console.warn('[2Bee Firebase] Failed to initialize firebase-admin:', (err as Error).message);
    return null;
  }
}

export const firebaseService = {
  isConfigured(): boolean {
    return Boolean(env.firebaseProjectId && env.firebaseClientEmail && env.firebasePrivateKey);
  },

  getStatus() {
    const app = ensureFirebaseApp();
    return {
      configured: this.isConfigured(),
      fcmEnabled: env.fcmEnabled,
      initialized: Boolean(app) || initialized,
      projectId: env.firebaseProjectId || null,
    };
  },

  async verifyIdToken(idToken: string): Promise<DecodedIdToken> {
    const app = ensureFirebaseApp();
    if (!app) {
      throw new Error('Firebase Admin credentials are not configured on backend');
    }
    return getAuth(app).verifyIdToken(idToken);
  },

  async registerPushToken(params: {
    userId?: string | null;
    role: string;
    platform: string;
    token: string;
  }) {
    const prisma = getPrisma();
    return prisma.devicePushToken.upsert({
      where: { token: params.token },
      update: {
        userId: params.userId ?? null,
        role: params.role.toUpperCase(),
        platform: params.platform.toUpperCase(),
      },
      create: {
        userId: params.userId ?? null,
        role: params.role.toUpperCase(),
        platform: params.platform.toUpperCase(),
        token: params.token,
      },
    });
  },

  async removePushToken(token: string) {
    const prisma = getPrisma();
    await prisma.devicePushToken.deleteMany({ where: { token } });
  },

  async sendPushToTokens(
    tokens: string[],
    payload: {
      title: string;
      body: string;
      data?: Record<string, string>;
      channelId?: string;
    },
  ): Promise<{ sent: number; failed: number }> {
    const uniqueTokens = [...new Set(tokens.filter(Boolean))];
    if (uniqueTokens.length === 0 || !env.fcmEnabled) {
      return { sent: 0, failed: 0 };
    }
    const app = ensureFirebaseApp();
    if (!app) {
      return { sent: 0, failed: 0 };
    }

    try {
      const res = await getMessaging(app).sendEachForMulticast({
        tokens: uniqueTokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        android: {
          priority: 'high',
          notification: {
            channelId: payload.channelId ?? 'twobee_default',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      const invalidTokens: string[] = [];
      res.responses.forEach((r: SendResponse, idx: number) => {
        if (!r.success) {
          const code = r.error?.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            invalidTokens.push(uniqueTokens[idx]);
          }
        }
      });
      if (invalidTokens.length > 0) {
        const prisma = getPrisma();
        await prisma.devicePushToken.deleteMany({ where: { token: { in: invalidTokens } } });
      }
      return { sent: res.successCount, failed: res.failureCount };
    } catch (err) {
      console.warn('[2Bee FCM] Push error:', (err as Error).message);
      return { sent: 0, failed: uniqueTokens.length };
    }
  },

  async sendPushToUser(
    userId: string,
    payload: { title: string; body: string; data?: Record<string, string>; channelId?: string },
    role?: string,
  ): Promise<void> {
    if (!env.fcmEnabled || !this.isConfigured()) return;
    try {
      const prisma = getPrisma();
      const rows = await prisma.devicePushToken.findMany({
        where: {
          userId,
          ...(role ? { role: role.toUpperCase() } : {}),
        },
        select: { token: true },
      });
      if (rows.length > 0) {
        await this.sendPushToTokens(
          rows.map((r) => r.token),
          payload,
        );
      }
    } catch {
      // Non-fatal push error
    }
  },

  async sendPushToRole(
    role: 'CLIENT' | 'RIDER' | 'MERCHANT' | 'ADMIN',
    payload: { title: string; body: string; data?: Record<string, string>; channelId?: string },
  ): Promise<void> {
    if (!env.fcmEnabled || !this.isConfigured()) return;
    try {
      const prisma = getPrisma();
      const rows = await prisma.devicePushToken.findMany({
        where: { role },
        select: { token: true },
      });
      if (rows.length > 0) {
        await this.sendPushToTokens(
          rows.map((r) => r.token),
          payload,
        );
      }
    } catch {
      // Non-fatal push error
    }
  },
};
