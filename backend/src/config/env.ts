import dotenv from 'dotenv';

dotenv.config();

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 4000),
  appName: process.env.APP_NAME ?? '2Bee',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((s) => s.trim()),

  // Database mode: 'pglite' (embedded PostgreSQL WASM, zero setup) or 'postgres' (external PostgreSQL)
  dbMode: (process.env.DB_MODE ?? 'pglite').toLowerCase() as 'pglite' | 'postgres',
  pgliteDataDir: process.env.PGLITE_DATA_DIR ?? './.pglite',
  databaseUrl: process.env.DATABASE_URL ?? 'postgresql://postgres:postgres@localhost:5432/twobee_dev?schema=public',

  // Redis GEO + H3 planned index
  redisUrl: process.env.REDIS_URL ?? '',
  geoBackend: (process.env.GEO_BACKEND ?? 'auto').toLowerCase() as 'auto' | 'redis' | 'memory',
  h3Resolution: Number(process.env.H3_RESOLUTION ?? 8),

  // JWT & Compliance rules
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET ?? 'twobee_dev_access_secret_min_32_characters_long_key',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET ?? 'twobee_dev_refresh_secret_min_32_characters_long_key',
  jwtRoleSecret: process.env.JWT_ROLE_SECRET ?? 'twobee_dev_role_secret_min_32_characters_long_key',
  roleInactivityMinutes: Number(process.env.ROLE_INACTIVITY_MINUTES ?? 15),
  payoutChangeHoldHours: Number(process.env.PAYOUT_CHANGE_HOLD_HOURS ?? 48),

  // Free SMS OTP
  smsProvider: process.env.SMS_PROVIDER ?? 'mock',
  devStaticOtp: process.env.DEV_STATIC_OTP ?? '123456',

  // Payments: COD + Online (Stripe Sandbox); MFS preview-only
  paymentMode: process.env.PAYMENT_MODE ?? 'stripe_sandbox',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY ?? '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET ?? '',
  stripeCurrency: process.env.STRIPE_CURRENCY ?? 'usd',
  bdtToUsdRate: Number(process.env.BDT_TO_USD_RATE ?? 0.0084),
  mfsLiveEnabled: process.env.MFS_LIVE_ENABLED === 'true',

  // Storage & Maps
  osrmBaseUrl: process.env.OSRM_BASE_URL ?? 'https://router.project-osrm.org',
  localUploadDir: process.env.LOCAL_UPLOAD_DIR ?? './uploads',
  signedUrlSecret: process.env.SIGNED_URL_SECRET ?? 'twobee_dev_signed_secret_change_in_prod',

  // Admin seed
  adminSeedEmail: process.env.ADMIN_SEED_EMAIL ?? 'admin@2bee.app',
  adminSeedPassword: process.env.ADMIN_SEED_PASSWORD ?? 'Admin@2BeeDev!',
};

