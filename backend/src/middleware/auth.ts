import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { HttpError } from './errorHandler.js';

export interface AccessTokenPayload {
  sub: string; // userId
  phone: string;
  type: 'access';
}

export interface RoleTokenPayload {
  sub: string; // userId
  role: 'RIDER' | 'MERCHANT';
  profileId: string;
  lastActivityAt: number; // epoch ms used for 15-min inactivity rule
  type: 'role';
}

// In-memory sliding inactivity map (backed by JWT + updated on each active call)
const roleSessionActivity = new Map<string, number>();

export function signAccessToken(userId: string, phone: string): string {
  return jwt.sign({ sub: userId, phone, type: 'access' } satisfies AccessTokenPayload, env.jwtAccessSecret, {
    expiresIn: '7d',
  });
}

export function signRefreshToken(userId: string, phone: string): string {
  return jwt.sign({ sub: userId, phone, type: 'refresh' }, env.jwtRefreshSecret, { expiresIn: '30d' });
}

export function signRoleSessionToken(userId: string, role: 'RIDER' | 'MERCHANT', profileId: string): string {
  const now = Date.now();
  const sessionKey = `${userId}:${role}`;
  roleSessionActivity.set(sessionKey, now);
  return jwt.sign(
    {
      sub: userId,
      role,
      profileId,
      lastActivityAt: now,
      type: 'role',
    } satisfies RoleTokenPayload,
    env.jwtRoleSecret,
    { expiresIn: '12h' },
  );
}

export function resetRoleInactivityStore(): void {
  roleSessionActivity.clear();
}

export function touchRoleActivity(userId: string, role: 'RIDER' | 'MERCHANT', customTimestampMs?: number): void {
  roleSessionActivity.set(`${userId}:${role}`, customTimestampMs ?? Date.now());
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new HttpError(401, 'UNAUTHORIZED', 'Missing Bearer access token');
  }
  const token = header.slice('Bearer '.length).trim();
  try {
    const decoded = jwt.verify(token, env.jwtAccessSecret) as AccessTokenPayload;
    if (decoded.type !== 'access') {
      throw new HttpError(401, 'INVALID_TOKEN', 'Invalid token type');
    }
    req.auth = { userId: decoded.sub, phone: decoded.phone };
    next();
  } catch (err) {
    if (err instanceof HttpError) throw err;
    throw new HttpError(401, 'UNAUTHORIZED', 'Access token expired or invalid');
  }
}

/**
 * Enforces unlocked Rider (4-digit reg passcode) or Merchant (6-digit post-approval passcode)
 * AND enforces the 15-minute sliding inactivity auto-lock rule.
 */
export function requireRoleSession(expectedRole: 'RIDER' | 'MERCHANT') {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const roleHeader = req.headers['x-role-token'];
    const rawToken = typeof roleHeader === 'string' ? roleHeader.trim() : '';
    if (!rawToken) {
      throw new HttpError(401, 'ROLE_LOCKED', `${expectedRole} passcode verification required`);
    }
    try {
      const decoded = jwt.verify(rawToken, env.jwtRoleSecret) as RoleTokenPayload;
      if (decoded.type !== 'role' || decoded.role !== expectedRole || decoded.sub !== req.auth?.userId) {
        throw new HttpError(403, 'FORBIDDEN_ROLE', 'Role token does not match authenticated user or role');
      }

      const key = `${decoded.sub}:${expectedRole}`;
      const lastSeen = roleSessionActivity.get(key) ?? decoded.lastActivityAt;
      const idleLimitMs = env.roleInactivityMinutes * 60 * 1000;
      if (Date.now() - lastSeen > idleLimitMs) {
        roleSessionActivity.delete(key);
        throw new HttpError(401, 'ROLE_INACTIVITY_LOCKED', 'Session locked after 15 minutes of inactivity. Enter passcode again.');
      }
      roleSessionActivity.set(key, Date.now());
      req.roleSession = {
        role: expectedRole,
        profileId: decoded.profileId,
      };
      next();
    } catch (err) {
      if (err instanceof HttpError) throw err;
      throw new HttpError(401, 'ROLE_LOCKED', 'Invalid or expired role session token');
    }
  };
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction): void {
  const adminKey = req.headers['x-admin-secret'];
  const bearer = req.headers.authorization;
  if (adminKey === env.adminSeedPassword) {
    next();
    return;
  }
  if (bearer?.startsWith('Bearer ')) {
    try {
      const decoded = jwt.verify(bearer.slice(7).trim(), env.jwtAccessSecret) as { role?: string };
      if (decoded.role === 'ADMIN') {
        next();
        return;
      }
    } catch {
      // fall through
    }
  }
  throw new HttpError(403, 'ADMIN_FORBIDDEN', 'Admin credentials required');
}

