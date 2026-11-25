import crypto from 'node:crypto';
import Stripe from 'stripe';
import { env } from '../config/env.js';

export interface OnlinePaymentIntentResult {
  mode: 'stripe_live_test' | 'stripe_sandbox_local';
  paymentIntentId: string;
  clientSecret: string;
  amountBdt: number;
  stripeAmountCents: number;
  currency: string;
  publishableHint: string;
}

export interface MfsOptionMeta {
  code: 'BKASH' | 'NAGAD' | 'ROCKET';
  label: string;
  liveEnabled: boolean;
  statusNote: string;
}

const stripeClient = env.stripeSecretKey
  ? new Stripe(env.stripeSecretKey)
  : null;

/**
 * Dual-Option Payment Service:
 * 1) COD / Cash (always functional)
 * 2) Online via Free Stripe Sandbox (uses Stripe SDK test keys if supplied, or deterministic local Stripe sandbox tokens when sk_test is empty so zero cost/keys needed to test!)
 * MFS options (bKash / Nagad / Rocket) remain visible UI preview choices per user direction.
 */
export const paymentService = {
  getAvailableMethods() {
    return {
      workingMethods: [
        { code: 'COD', label: 'Cash on Delivery / Cash', functional: true },
        {
          code: 'STRIPE_SANDBOX',
          label: 'Online Payment (Stripe Sandbox Card)',
          functional: true,
          publishableKey: env.stripePublishableKey || null,
          testCardHint: '4242 4242 4242 4242 · Exp 12/30 · CVC 424',
        },
      ],
      mfsPreviewOptions: [
        {
          code: 'BKASH',
          label: 'bKash',
          liveEnabled: env.mfsLiveEnabled,
          statusNote: env.mfsLiveEnabled ? 'Active' : 'UI Preview (Live integration scheduled)',
        },
        {
          code: 'NAGAD',
          label: 'Nagad',
          liveEnabled: env.mfsLiveEnabled,
          statusNote: env.mfsLiveEnabled ? 'Active' : 'UI Preview (Live integration scheduled)',
        },
        {
          code: 'ROCKET',
          label: 'Rocket',
          liveEnabled: env.mfsLiveEnabled,
          statusNote: env.mfsLiveEnabled ? 'Active' : 'UI Preview (Live integration scheduled)',
        },
      ] satisfies MfsOptionMeta[],
    };
  },

  async createStripeSandboxIntent(params: {
    amountBdt: number;
    serviceType: 'FOOD' | 'PARCEL' | 'RIDE' | 'WALLET_TOPUP';
    referenceCode: string;
    userId: string;
  }): Promise<OnlinePaymentIntentResult> {
    const usdCents = Math.max(50, Math.round(params.amountBdt * env.bdtToUsdRate * 100));

    if (stripeClient) {
      const intent = await stripeClient.paymentIntents.create({
        amount: usdCents,
        currency: env.stripeCurrency,
        automatic_payment_methods: { enabled: true },
        metadata: {
          serviceType: params.serviceType,
          referenceCode: params.referenceCode,
          userId: params.userId,
          amountBdt: String(params.amountBdt),
        },
      });
      return {
        mode: 'stripe_live_test',
        paymentIntentId: intent.id,
        clientSecret: intent.client_secret ?? '',
        amountBdt: params.amountBdt,
        stripeAmountCents: usdCents,
        currency: env.stripeCurrency,
        publishableHint: 'Configured with Stripe Sandbox API key',
      };
    }

    const suffix = crypto.randomBytes(8).toString('hex');
    const paymentIntentId = `pi_2bee_sandbox_${suffix}`;
    return {
      mode: 'stripe_sandbox_local',
      paymentIntentId,
      clientSecret: `${paymentIntentId}_secret_${crypto.randomBytes(8).toString('hex')}`,
      amountBdt: params.amountBdt,
      stripeAmountCents: usdCents,
      currency: env.stripeCurrency,
      publishableHint: 'Local Stripe Sandbox Simulator (Zero API key required)',
    };
  },

  async confirmSandboxIntent(paymentIntentId: string): Promise<{ paid: boolean; trxId: string }> {
    if (stripeClient && !paymentIntentId.startsWith('pi_2bee_sandbox_')) {
      const intent = await stripeClient.paymentIntents.retrieve(paymentIntentId);
      return {
        paid: intent.status === 'succeeded' || intent.status === 'requires_capture',
        trxId: intent.id,
      };
    }
    return {
      paid: paymentIntentId.startsWith('pi_'),
      trxId: `TRX-2B-${paymentIntentId.slice(-6).toUpperCase()}`,
    };
  },

  verifyWebhookEvent(rawBody: Buffer | string, signature?: string) {
    if (!stripeClient || !env.stripeWebhookSecret || !signature) {
      return null;
    }
    return stripeClient.webhooks.constructEvent(rawBody, signature, env.stripeWebhookSecret);
  },
};

