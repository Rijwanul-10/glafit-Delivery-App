import crypto from 'node:crypto';
import { env } from '../config/env.js';

export interface SmsProvider {
  sendOtp(phone: string, code: string, purpose: string): Promise<{ delivered: boolean; devHint?: string }>;
  sendAlert(phone: string, message: string): Promise<{ delivered: boolean }>;
}

/**
 * 100% Free local Mock/Console SMS OTP adapter.
 * Logs OTP & alerts to stdout and hashes challenges securely with SHA-256.
 * Swap cleanly for SSL Wireless / GreenWeb / Twilio in production via SMS_PROVIDER.
 */
class FreeMockSmsProvider implements SmsProvider {
  async sendOtp(phone: string, code: string, purpose: string) {
    console.info(`[2Bee SMS][OTP][${purpose}] -> ${phone}: ${code}`);
    return {
      delivered: true,
      devHint: env.nodeEnv !== 'production' ? code : undefined,
    };
  }

  async sendAlert(phone: string, message: string) {
    console.info(`[2Bee SMS][ALERT] -> ${phone}: ${message}`);
    return { delivered: true };
  }
}

export const smsProvider: SmsProvider = new FreeMockSmsProvider();

export function generateOtpCode(): string {
  if (env.nodeEnv !== 'production' && env.devStaticOtp && /^\d{6}$/.test(env.devStaticOtp)) {
    return env.devStaticOtp;
  }
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function hashOtp(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

