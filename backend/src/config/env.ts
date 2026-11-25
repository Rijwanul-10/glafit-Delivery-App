import dotenv from 'dotenv';

dotenv.config();

export const env = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: Number(process.env.PORT ?? 4000),
  appName: process.env.APP_NAME ?? '2Bee',
  corsOrigins: (process.env.CORS_ORIGINS ?? '*').split(',').map((s) => s.trim()),

  // Database mode: 'pglite' (embedded PostgreSQL WASM, zero setup) or 'postgres' (external PostgreSQL: Supabase/Neon)
  dbMode: (process.env.DB_MODE ?? 'pglite').toLowerCase() as 'pglite' | 'postgres',
  pgliteDataDir: process.env.PGLITE_DATA_DIR ?? './.pglite',
  databaseUrl: process.env.DATABASE_URL ?? 'postgresql://postgres:postgres@localhost:5432/twobee_dev?schema=public',

  // Redis GEO & Zone A->B matching (Upstash free Redis or in-memory fallback)
  redisUrl: process.env.REDIS_URL ?? '',
  geoBackend: (process.env.GEO_BACKEND ?? 'auto').toLowerCase() as 'auto' | 'redis' | 'memory',
  h3Resolution: Number(process.env.H3_RESOLUTION ?? 8),

  // JWT & Compliance rules
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET ?? 'twobee_dev_access_secret_min_32_characters_long_key',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET ?? 'twobee_dev_refresh_secret_min_32_characters_long_key',
  jwtRoleSecret: process.env.JWT_ROLE_SECRET ?? 'twobee_dev_role_secret_min_32_characters_long_key',
  roleInactivityMinutes: Number(process.env.ROLE_INACTIVITY_MINUTES ?? 15),
  payoutChangeHoldHours: Number(process.env.PAYOUT_CHANGE_HOLD_HOURS ?? 48),

  // SMS / OTP (mock | sslwireless | greenweb | twilio)
  smsProvider: (process.env.SMS_PROVIDER ?? 'mock').toLowerCase() as 'mock' | 'sslwireless' | 'greenweb' | 'twilio',
  devStaticOtp: process.env.DEV_STATIC_OTP ?? '123456',
  sslwirelessApiToken: process.env.SSLWIRELESS_API_TOKEN ?? '',
  sslwirelessSid: process.env.SSLWIRELESS_SID ?? '2BEE',
  greenwebApiToken: process.env.GREENWEB_API_TOKEN ?? '',
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID ?? '',
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN ?? '',
  twilioFrom: process.env.TWILIO_FROM ?? '',

  // Payments: COD + Online (Stripe Sandbox); MFS preview-only
  paymentMode: process.env.PAYMENT_MODE ?? 'stripe_sandbox',
  stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY ?? '',
  stripeSecretKey: process.env.STRIPE_SECRET_KEY ?? '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET ?? '',
  stripeCurrency: process.env.STRIPE_CURRENCY ?? 'usd',
  bdtToUsdRate: Number(process.env.BDT_TO_USD_RATE ?? 0.0084),
  mfsLiveEnabled: process.env.MFS_LIVE_ENABLED === 'true',

  // Maps & Storage
  mapsProvider: (process.env.MAPS_PROVIDER ?? 'osm').toLowerCase() as 'osm' | 'barikoi' | 'google',
  osrmBaseUrl: process.env.OSRM_BASE_URL ?? 'https://router.project-osrm.org',
  barikoiApiKey: process.env.BARIKOI_API_KEY ?? '',
  googleMapsServerApiKey: process.env.GOOGLE_MAPS_SERVER_API_KEY ?? '',
  storageProvider: (process.env.STORAGE_PROVIDER ?? 'local').toLowerCase() as 'local' | 'r2' | 's3',
  localUploadDir: process.env.LOCAL_UPLOAD_DIR ?? './uploads',
  signedUrlSecret: process.env.SIGNED_URL_SECRET ?? 'twobee_dev_signed_secret_change_in_prod',
  s3Endpoint: process.env.S3_ENDPOINT ?? '',
  s3Region: process.env.S3_REGION ?? 'auto',
  s3Bucket: process.env.S3_BUCKET ?? '2bee-media',
  s3AccessKeyId: process.env.S3_ACCESS_KEY_ID ?? '',
  s3SecretAccessKey: process.env.S3_SECRET_ACCESS_KEY ?? '',
  s3PublicBaseUrl: process.env.S3_PUBLIC_BASE_URL ?? '',

  // Firebase (Auth verification + FCM Push Notifications on Spark Free Plan)
  fcmEnabled: process.env.FCM_ENABLED === 'true',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? '',
  firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL ?? '',
  firebasePrivateKey: (process.env.FIREBASE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'),

  // Admin API & Dashboard access
  adminSeedEmail: process.env.ADMIN_SEED_EMAIL ?? 'admin@2bee.app',
  adminSeedPassword: process.env.ADMIN_SEED_PASSWORD ?? 'Admin@2BeeDev!',
  adminEmails: (process.env.ADMIN_EMAILS ?? process.env.ADMIN_SEED_EMAIL ?? 'admin@2bee.app')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean),
};
