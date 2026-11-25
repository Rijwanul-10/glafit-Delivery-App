import fs from 'node:fs';
import path from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaPGlite } from 'pglite-prisma-adapter';
import { Pool } from 'pg';
import { env } from '../config/env.js';

let prismaInstance: PrismaClient | null = null;
let pgliteInstance: PGlite | null = null;
let pgPool: Pool | null = null;

const DEVICE_PUSH_TOKEN_DDL = `
  CREATE TABLE IF NOT EXISTS "DevicePushToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "role" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "DevicePushToken_pkey" PRIMARY KEY ("id")
  );
  CREATE UNIQUE INDEX IF NOT EXISTS "DevicePushToken_token_key" ON "DevicePushToken"("token");
  CREATE INDEX IF NOT EXISTS "DevicePushToken_userId_role_idx" ON "DevicePushToken"("userId", "role");
`;

function resolveInitSqlPath(): string {
  const candidates = [
    path.resolve(process.cwd(), 'prisma/init.sql'),
    path.resolve(process.cwd(), 'backend/prisma/init.sql'),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  throw new Error('Could not locate prisma/init.sql. Run "npm run prisma:sql" in backend/.');
}

export async function initPrisma(options?: { pglitePath?: string }): Promise<PrismaClient> {
  if (prismaInstance) {
    return prismaInstance;
  }

  if (env.dbMode === 'postgres' && !options?.pglitePath) {
    pgPool = new Pool({
      connectionString: env.databaseUrl,
      ssl:
        env.databaseUrl.includes('localhost') || env.databaseUrl.includes('127.0.0.1')
          ? undefined
          : { rejectUnauthorized: false },
    });
    try {
      const existing = await pgPool.query<{ tbl: string | null }>(`SELECT to_regclass('public."User"') AS tbl`);
      if (!existing.rows[0]?.tbl) {
        const sql = fs.readFileSync(resolveInitSqlPath(), 'utf8');
        await pgPool.query(sql);
        console.info('[2Bee Postgres] Bootstrapped initial schema from prisma/init.sql');
      } else {
        const pushTbl = await pgPool.query<{ tbl: string | null }>(
          `SELECT to_regclass('public."DevicePushToken"') AS tbl`,
        );
        if (!pushTbl.rows[0]?.tbl) {
          await pgPool.query(DEVICE_PUSH_TOKEN_DDL);
        }
      }
    } catch (err) {
      const e = err as { code?: string; message?: string };
      if ((e.code === 'ENOTFOUND' || e.code === 'ENETUNREACH') && env.databaseUrl.includes('.supabase.co')) {
        console.error(
          '[2Bee Postgres] Cannot reach Supabase direct host (IPv6-only). On Render / IPv4 networks, use Supabase Session Pooler URI (aws-0-<region>.pooler.supabase.com:5432) from Supabase Connect -> Session Pooler.',
        );
      }
      throw err;
    }
    const adapter = new PrismaPg(pgPool);
    prismaInstance = new PrismaClient({ adapter });
    await prismaInstance.$connect();
    return prismaInstance;
  }

  const targetDir = options?.pglitePath ?? (env.nodeEnv === 'test' ? 'memory://' : env.pgliteDataDir);
  if (targetDir !== 'memory://' && !fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }
  pgliteInstance = new PGlite(targetDir);
  await pgliteInstance.waitReady;

  const existing = await pgliteInstance.query<{ tbl: string | null }>(`SELECT to_regclass('public."User"') AS tbl`);
  if (!existing.rows[0]?.tbl) {
    const sql = fs.readFileSync(resolveInitSqlPath(), 'utf8');
    await pgliteInstance.exec(sql);
  } else {
    const pushTbl = await pgliteInstance.query<{ tbl: string | null }>(
      `SELECT to_regclass('public."DevicePushToken"') AS tbl`,
    );
    if (!pushTbl.rows[0]?.tbl) {
      await pgliteInstance.exec(DEVICE_PUSH_TOKEN_DDL);
    }
  }

  const adapter = new PrismaPGlite(pgliteInstance);
  prismaInstance = new PrismaClient({ adapter });
  await prismaInstance.$connect();
  return prismaInstance;
}

export function getPrisma(): PrismaClient {
  if (!prismaInstance) {
    throw new Error('Prisma client not initialized. Call await initPrisma() first.');
  }
  return prismaInstance;
}

export async function closePrisma(): Promise<void> {
  if (prismaInstance) {
    await prismaInstance.$disconnect();
    prismaInstance = null;
  }
  if (pgPool) {
    await pgPool.end();
    pgPool = null;
  }
  if (pgliteInstance) {
    await pgliteInstance.close();
    pgliteInstance = null;
  }
}
