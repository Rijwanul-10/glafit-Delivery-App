import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { env } from '../config/env.js';

let s3ClientInstance: S3Client | null = null;

function getS3Client(): S3Client | null {
  if (env.storageProvider === 'local') return null;
  if (!env.s3AccessKeyId || !env.s3SecretAccessKey || !env.s3Bucket) return null;
  if (!s3ClientInstance) {
    s3ClientInstance = new S3Client({
      region: env.s3Region || 'auto',
      endpoint: env.s3Endpoint || undefined,
      forcePathStyle: Boolean(env.s3Endpoint),
      credentials: {
        accessKeyId: env.s3AccessKeyId,
        secretAccessKey: env.s3SecretAccessKey,
      },
    });
  }
  return s3ClientInstance;
}

export interface StoredFileResult {
  key: string;
  url: string;
  provider: 'local' | 'r2' | 's3';
}

export const storageService = {
  getProviderName(): 'local' | 'r2' | 's3' {
    return getS3Client() ? env.storageProvider : 'local';
  },

  async uploadFile(params: {
    buffer: Buffer;
    originalName: string;
    mimeType?: string;
    folder?: string;
    isPrivate?: boolean;
  }): Promise<StoredFileResult> {
    const safeExt = path.extname(params.originalName || '.jpg').replace(/[^a-zA-Z0-9.]/g, '') || '.jpg';
    const fileName = `${Date.now()}-${crypto.randomBytes(4).toString('hex')}${safeExt}`;
    const folder = (params.folder ?? (params.isPrivate ? 'private/kyc' : 'public')).replace(/^\/+|\/+$/g, '');
    const key = `${folder}/${fileName}`;

    const s3 = getS3Client();
    if (s3) {
      await s3.send(
        new PutObjectCommand({
          Bucket: env.s3Bucket,
          Key: key,
          Body: params.buffer,
          ContentType: params.mimeType ?? 'application/octet-stream',
        }),
      );
      const url =
        !params.isPrivate && env.s3PublicBaseUrl
          ? `${env.s3PublicBaseUrl.replace(/\/+$/, '')}/${key}`
          : `s3://${env.s3Bucket}/${key}`;
      return { key, url, provider: env.storageProvider };
    }

    const dir = path.resolve(process.cwd(), env.localUploadDir);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const flatName = `${folder.replace(/\//g, '_')}_${fileName}`;
    fs.writeFileSync(path.join(dir, flatName), params.buffer);
    return {
      key: flatName,
      url: `/uploads/${flatName}`,
      provider: 'local',
    };
  },

  async getSignedReadUrl(storedUrlOrKey: string, ttlSeconds = 300): Promise<string> {
    const s3 = getS3Client();
    if (s3) {
      let key = storedUrlOrKey;
      const prefix = `s3://${env.s3Bucket}/`;
      if (key.startsWith(prefix)) {
        key = key.slice(prefix.length);
      } else if (env.s3PublicBaseUrl && key.startsWith(env.s3PublicBaseUrl)) {
        key = key.slice(env.s3PublicBaseUrl.replace(/\/+$/, '').length + 1);
      }
      if (!key.startsWith('http')) {
        return getSignedUrl(
          s3,
          new GetObjectCommand({ Bucket: env.s3Bucket, Key: key }),
          { expiresIn: ttlSeconds },
        );
      }
    }
    return storedUrlOrKey;
  },
};
