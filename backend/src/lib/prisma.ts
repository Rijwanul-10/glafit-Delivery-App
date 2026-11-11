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
    pgPool = new Pool({ connectionString: env.databaseUrl });
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

