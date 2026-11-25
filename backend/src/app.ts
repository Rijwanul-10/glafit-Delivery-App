import fs from 'node:fs';
import path from 'node:path';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { env } from './config/env.js';
import { errorHandler } from './middleware/errorHandler.js';
import { authRouter } from './routes/auth.routes.js';
import { clientRouter } from './routes/client.routes.js';
import { foodRouter } from './routes/food.routes.js';
import { rideRouter } from './routes/ride.routes.js';
import { parcelRouter } from './routes/parcel.routes.js';
import { merchantRouter } from './routes/merchant.routes.js';
import { riderRouter } from './routes/rider.routes.js';
import { adminRouter } from './routes/admin.routes.js';
import { commonRouter } from './routes/common.routes.js';
import { geoMatchService } from './services/geoMatchService.js';
import { firebaseService } from './services/firebaseService.js';
import { storageService } from './services/storageService.js';

export function createExpressApp() {
  const app = express();

  app.use(helmet({ crossOriginResourcePolicy: false }));
  app.use(
    cors({
      origin: env.corsOrigins.includes('*') ? true : env.corsOrigins,
      credentials: true,
    }),
  );
  app.use(
    express.json({
      limit: '5mb',
      verify: (req, _res, buf) => {
        (req as express.Request & { rawBody?: Buffer }).rawBody = buf;
      },
    }),
  );
  app.use(express.urlencoded({ extended: true }));
  if (env.nodeEnv !== 'test') {
    app.use(morgan('dev'));
  }

  const uploadDir = path.resolve(process.cwd(), env.localUploadDir);
  if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
  app.use('/uploads', express.static(uploadDir));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      app: env.appName,
      env: env.nodeEnv,
      dbMode: env.dbMode,
      geoEngine: geoMatchService.getEngineName(),
      geoBackend: env.geoBackend,
      redisUrlConfigured: Boolean(env.redisUrl),
      geoLastError: geoMatchService.getLastError(),
      h3Resolution: env.h3Resolution,
      paymentMode: env.paymentMode,
      smsProvider: env.smsProvider,
      mapsProvider: env.mapsProvider,
      storageProvider: storageService.getProviderName(),
      firebaseConfigured: firebaseService.isConfigured(),
      fcmEnabled: env.fcmEnabled,
      timestamp: new Date().toISOString(),
    });
  });

  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/client', clientRouter);
  app.use('/api/v1/food', foodRouter);
  app.use('/api/v1/rides', rideRouter);
  app.use('/api/v1/parcels', parcelRouter);
  app.use('/api/v1/merchant', merchantRouter);
  app.use('/api/v1/rider', riderRouter);
  app.use('/api/v1/admin', adminRouter);
  app.use('/api/v1/common', commonRouter);

  app.use(errorHandler);
  return app;
}

