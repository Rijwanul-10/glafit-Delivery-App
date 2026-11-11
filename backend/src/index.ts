import http from 'node:http';
import { env } from './config/env.js';
import { initPrisma, getPrisma } from './lib/prisma.js';
import { geoMatchService } from './services/geoMatchService.js';
import { initSocketServer } from './realtime/socketServer.js';
import { createExpressApp } from './app.js';
import { runSeed } from './prisma/seed.js';

async function bootstrap() {
  await initPrisma();
  await geoMatchService.init();

  const prisma = getPrisma();
  const zoneCount = await prisma.zone.count();
  if (zoneCount === 0) {
    console.info('[2Bee Boot] Empty database detected — seeding starter Dhaka ecosystem...');
    await runSeed();
  }

  const app = createExpressApp();
  const httpServer = http.createServer(app);
  initSocketServer(httpServer);

  httpServer.listen(env.port, '0.0.0.0', () => {
    console.info(
      `[2Bee API] Listening on http://0.0.0.0:${env.port} (local: http://localhost:${env.port}) | DB=${env.dbMode} | GEO=${geoMatchService.getEngineName()}`,
    );
  });
}

bootstrap().catch((err) => {
  console.error('[2Bee Boot] Fatal startup error:', err);
  process.exit(1);
});

