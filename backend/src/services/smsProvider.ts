import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { HttpError } from '../middleware/errorHandler.js';

export interface SmsProvider {
  sendOtp(phone: string, code: string, purpose: string): Promise<{ delivered: boolean; devHint?: string }>;
  sendAlert(phone: string, message: string): Promise<{ delivered: boolean; errorMessage?: string }>;
}

function buildOtpMessage(code: string, purpose: string): string {
  return `Your ${env.appName} verification code (${purpose}) is ${code}. Valid for 5 minutes.`;
}

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

class SslWirelessSmsProvider implements SmsProvider {
  async sendOtp(phone: string, code: string, purpose: string) {
    await this.sendAlert(phone, buildOtpMessage(code, purpose));
    return { delivered: true };
  }

  async sendAlert(phone: string, message: string) {
    if (!env.sslwirelessApiToken) {
      console.warn('[2Bee SMS][SSLWireless] Missing SSLWIRELESS_API_TOKEN; falling back to console log');
      console.info(`[2Bee SMS][ALERT] -> ${phone}: ${message}`);
      return { delivered: true };
    }
    const msisdn = phone.replace(/^\+/, '');
    const res = await fetch('https://smsplus.sslwireless.com/api/v3/send-sms', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_token: env.sslwirelessApiToken,
        sid: env.sslwirelessSid,
        msisdn,
        sms: message,
        csms_id: `2BEE-${Date.now()}`,
      }),
    });
    if (!res.ok) {
      console.warn('[2Bee SMS][SSLWireless] HTTP', res.status);
    }
    return { delivered: res.ok };
  }
}

class GreenWebSmsProvider implements SmsProvider {
  async sendOtp(phone: string, code: string, purpose: string) {
    await this.sendAlert(phone, buildOtpMessage(code, purpose));
    return { delivered: true };
  }

  async sendAlert(phone: string, message: string) {
    if (!env.greenwebApiToken) {
      console.warn('[2Bee SMS][GreenWeb] Missing GREENWEB_API_TOKEN; falling back to console log');
      console.info(`[2Bee SMS][ALERT] -> ${phone}: ${message}`);
      return { delivered: true };
    }
    const params = new URLSearchParams({
      token: env.greenwebApiToken,
      to: phone,
      message,
    });
    const res = await fetch(`https://api.greenweb.com.bd/api.php?${params.toString()}`, { method: 'POST' });
    return { delivered: res.ok };
  }
}

class TwilioSmsProvider implements SmsProvider {
  async sendOtp(phone: string, code: string, purpose: string) {
    if (!env.twilioAccountSid || !env.twilioAuthToken || !env.twilioFrom) {
      throw new HttpError(
        500,
        'SMS_CONFIG_MISSING',
        'Twilio credentials (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM) are not configured',
      );
    }
    const result = await this.sendAlert(phone, buildOtpMessage(code, purpose));
    if (!result.delivered) {
      throw new HttpError(
        502,
        'SMS_DELIVERY_FAILED',
        result.errorMessage ?? 'Failed to deliver OTP SMS via Twilio',
      );
    }
    return { delivered: true };
  }

  async sendAlert(phone: string, message: string) {
    if (!env.twilioAccountSid || !env.twilioAuthToken || !env.twilioFrom) {
      console.warn('[2Bee SMS][Twilio] Missing Twilio credentials; falling back to console log');
      console.info(`[2Bee SMS][ALERT] -> ${phone}: ${message}`);
      return { delivered: false, errorMessage: 'Missing Twilio credentials' };
    }
    const auth = Buffer.from(`${env.twilioAccountSid}:${env.twilioAuthToken}`).toString('base64');
    const fromKey = env.twilioFrom.trim().startsWith('MG') ? 'MessagingServiceSid' : 'From';
    const body = new URLSearchParams({ To: phone, [fromKey]: env.twilioFrom.trim(), Body: message });
    const res = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${env.twilioAccountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body,
      },
    );
    if (!res.ok) {
      let errorMessage = `Twilio HTTP ${res.status}`;
      try {
        const data = (await res.json()) as { message?: string; code?: number };
        if (data?.message) {
          errorMessage = data.code ? `Twilio (${data.code}): ${data.message}` : data.message;
        }
      } catch {
        // Keep HTTP status fallback when response is not JSON
      }
      console.warn('[2Bee SMS][Twilio] Delivery failed:', errorMessage);
      return { delivered: false, errorMessage };
    }
    return { delivered: true };
  }
}

function createSmsProvider(): SmsProvider {
  if (env.nodeEnv === 'test' || env.smsProvider === 'mock') {
    return new FreeMockSmsProvider();
  }
  switch (env.smsProvider) {
    case 'sslwireless':
      return new SslWirelessSmsProvider();
    case 'greenweb':
      return new GreenWebSmsProvider();
    case 'twilio':
      return new TwilioSmsProvider();
    default:
      return new FreeMockSmsProvider();
  }
}

export const smsProvider: SmsProvider = createSmsProvider();

export function generateOtpCode(): string {
  if (
    env.nodeEnv !== 'production' &&
    env.smsProvider === 'mock' &&
    env.devStaticOtp &&
    /^\d{6}$/.test(env.devStaticOtp)
  ) {
    return env.devStaticOtp;
  }
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function hashOtp(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}
