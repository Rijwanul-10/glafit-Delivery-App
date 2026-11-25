import { Redis } from 'ioredis';
import { latLngToCell, gridDisk, gridDistance } from 'h3-js';
import { env } from '../config/env.js';
import { haversineKm } from './mapsService.js';

export type DispatchServiceKey = 'food' | 'parcel' | 'ride';

export interface ActiveMultiServiceSlot {
  riderId: string;
  parcelId: string;
  trackingCode: string;
  originZoneId: string;      // Zone A
  destinationZoneId: string; // Zone B
  weightKg: number;
  maxFrontKg: number;
}

export interface NearbyRiderHit {
  riderId: string;
  lat: number;
  lng: number;
  distanceKm: number;
  h3Cell: string;
  ringDistance: number;
}

export interface HoneycombGeoMeta {
  h3Cell: string;
  h3Resolution: number;
  ringDistance: number;
  distanceKm: number;
  engine: 'redis-geo' | 'memory-geo-fallback';
}

/**
 * H3 Q6 Honeycomb spatial index adapter (Uber H3 hexagonal grid, default resolution 6).
 * Uses hexagonal cells and k-ring honeycomb expansion (gridDisk / gridDistance)
 * paired with Redis GEO (or in-memory fallback).
 */
export interface H3IndexStrategy {
  cellFor(lat: number, lng: number, resolution?: number): string;
  neighborCells(lat: number, lng: number, kRings?: number, resolution?: number): string[];
  hexRingDistance(originCell: string, targetCell: string): number;
}

export const h3IndexStrategy: H3IndexStrategy = {
  cellFor(lat: number, lng: number, resolution = env.h3Resolution): string {
    return latLngToCell(lat, lng, resolution);
  },
  neighborCells(lat: number, lng: number, kRings = 1, resolution = env.h3Resolution): string[] {
    const origin = latLngToCell(lat, lng, resolution);
    return gridDisk(origin, kRings);
  },
  hexRingDistance(originCell: string, targetCell: string): number {
    if (originCell === targetCell) return 0;
    try {
      return gridDistance(originCell, targetCell);
    } catch {
      return 99;
    }
  },
};

/**
 * Hybrid Redis GEO + H3 Q6 Honeycomb spatial matcher & Zone A -> Zone B multi-service matcher.
 * Production uses Redis GEOADD / GEORADIUS + H3 Q6 honeycomb buckets + EX 30 TTL heartbeats.
 */
class GeoMatchService {
  private redis: Redis | null = null;
  private redisReady = false;
  private lastError: string | null = null;

  // In-memory store mirroring Redis GEO + H3 Q6 buckets + 30s heartbeat TTL + Zone A->B Sets
  private memCoords = new Map<
    string,
    { lat: number; lng: number; h3Cell: string; services: Set<DispatchServiceKey>; expiresAt: number }
  >();
  private memRequests = new Map<
    string,
    { service: DispatchServiceKey; lat: number; lng: number; h3Cell: string; expiresAt: number }
  >();
  private memMultiServiceParcels = new Map<string, ActiveMultiServiceSlot>(); // riderId -> slot

  async init(): Promise<void> {
    if (env.geoBackend === 'memory') {
      this.lastError = 'GEO_BACKEND=memory forced';
      return;
    }
    if (!env.redisUrl || !env.redisUrl.trim()) {
      this.lastError = 'REDIS_URL is empty';
      return;
    }
    let cleanUrl = env.redisUrl.trim().replace(/^["']|["']$/g, '').trim();
    const cliMatch = cleanUrl.match(/(rediss?:\/\/\S+)/i);
    if (cliMatch?.[1]) {
      cleanUrl = cliMatch[1].replace(/^["']|["']$/g, '');
    }
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      this.lastError = 'Invalid REDIS_URL scheme (https REST URL pasted instead of rediss:// TCP URL)';
      console.warn('[2Bee GeoMatchService]', this.lastError);
      return;
    }
    try {
      const normalizedUrl = cleanUrl.includes('upstash.io') && cleanUrl.startsWith('redis://')
        ? cleanUrl.replace(/^redis:\/\//, 'rediss://')
        : cleanUrl;
      const isTls = normalizedUrl.startsWith('rediss://');
      const client = new Redis(normalizedUrl, {
        maxRetriesPerRequest: 2,
        connectTimeout: 8000,
        lazyConnect: true,
        ...(isTls ? { tls: { rejectUnauthorized: false } } : {}),
      });
      client.on('error', (err) => {
        this.lastError = err.message;
        console.warn('[2Bee GeoMatchService] Redis connection warning:', err.message);
      });
      client.on('ready', () => {
        this.redisReady = true;
        this.lastError = null;
      });
      client.on('end', () => {
        this.redisReady = false;
      });
      await client.connect();
      await client.ping();
      this.redis = client;
      this.redisReady = true;
      this.lastError = null;
      console.info(`[2Bee GeoMatchService] Connected to Redis GEO + H3 Q${env.h3Resolution} Honeycomb backend`);
    } catch (err) {
      this.lastError = (err as Error).message;
      console.warn('[2Bee GeoMatchService] Redis unreachable; using in-memory GEO fallback:', this.lastError);
      this.redisReady = false;
    }
  }

  getEngineName(): 'redis-geo' | 'memory-geo-fallback' {
    return this.redisReady && this.redis ? 'redis-geo' : 'memory-geo-fallback';
  }

  getLastError(): string | null {
    return this.lastError;
  }

  async updateRiderLocation(
    riderId: string,
    lat: number,
    lng: number,
    services: DispatchServiceKey[],
  ): Promise<{ h3Cell: string; engine: string }> {
    const res = env.h3Resolution;
    const h3Cell = h3IndexStrategy.cellFor(lat, lng, res);
    if (this.redisReady && this.redis) {
      const pipe = this.redis.pipeline();
      const allServices: DispatchServiceKey[] = ['food', 'parcel', 'ride'];
      for (const svc of allServices) {
        const geoKey = `geo:riders:${svc}`;
        const h3BucketKey = `h3:q${res}:riders:${h3Cell}:${svc}`;
        if (services.includes(svc)) {
          pipe.geoadd(geoKey, lng, lat, riderId);
          pipe.sadd(h3BucketKey, riderId);
          pipe.expire(h3BucketKey, 60);
        } else {
          pipe.zrem(geoKey, riderId);
          pipe.srem(h3BucketKey, riderId);
        }
      }
      pipe.set(`rider:h3:${riderId}`, h3Cell, 'EX', 30);
      pipe.set(`rider:heartbeat:${riderId}`, `${lat},${lng}`, 'EX', 30);
      await pipe.exec();
    } else {
      this.memCoords.set(riderId, {
        lat,
        lng,
        h3Cell,
        services: new Set(services),
        expiresAt: Date.now() + 30_000,
      });
    }
    return { h3Cell, engine: this.getEngineName() };
  }

  async setRiderOffline(riderId: string): Promise<void> {
    if (this.redisReady && this.redis) {
      const prevCell = await this.redis.get(`rider:h3:${riderId}`);
      const res = env.h3Resolution;
      const ops: Promise<unknown>[] = [
        this.redis.zrem('geo:riders:food', riderId),
        this.redis.zrem('geo:riders:parcel', riderId),
        this.redis.zrem('geo:riders:ride', riderId),
        this.redis.del(`rider:heartbeat:${riderId}`, `rider:h3:${riderId}`),
      ];
      if (prevCell) {
        ops.push(
          this.redis.srem(`h3:q${res}:riders:${prevCell}:food`, riderId),
          this.redis.srem(`h3:q${res}:riders:${prevCell}:parcel`, riderId),
          this.redis.srem(`h3:q${res}:riders:${prevCell}:ride`, riderId),
        );
      }
      await Promise.all(ops);
    }
    this.memCoords.delete(riderId);
    await this.clearActiveMultiServiceParcel(riderId);
  }

  async indexOpenRequest(
    service: DispatchServiceKey,
    requestId: string,
    lat: number,
    lng: number,
  ): Promise<string> {
    const res = env.h3Resolution;
    const h3Cell = h3IndexStrategy.cellFor(lat, lng, res);
    if (this.redisReady && this.redis) {
      const h3BucketKey = `h3:q${res}:requests:${h3Cell}:${service}`;
      await this.redis
        .pipeline()
        .geoadd(`geo:requests:${service}`, lng, lat, requestId)
        .sadd(h3BucketKey, requestId)
        .expire(h3BucketKey, 3600)
        .set(`req:h3:${service}:${requestId}`, h3Cell, 'EX', 3600)
        .exec();
    } else {
      this.memRequests.set(`${service}:${requestId}`, {
        service,
        lat,
        lng,
        h3Cell,
        expiresAt: Date.now() + 3_600_000,
      });
    }
    return h3Cell;
  }

  async removeOpenRequest(service: DispatchServiceKey, requestId: string): Promise<void> {
    if (this.redisReady && this.redis) {
      const res = env.h3Resolution;
      const cell = await this.redis.get(`req:h3:${service}:${requestId}`);
      const pipe = this.redis.pipeline().zrem(`geo:requests:${service}`, requestId).del(`req:h3:${service}:${requestId}`);
      if (cell) {
        pipe.srem(`h3:q${res}:requests:${cell}:${service}`, requestId);
      }
      await pipe.exec();
    }
    this.memRequests.delete(`${service}:${requestId}`);
  }

  async findNearbyRiders(
    service: DispatchServiceKey,
    lat: number,
    lng: number,
    radiusKm = 8,
    maxRing = 2,
  ): Promise<NearbyRiderHit[]> {
    const res = env.h3Resolution;
    const originCell = h3IndexStrategy.cellFor(lat, lng, res);
    const honeycombRingSet = new Set(h3IndexStrategy.neighborCells(lat, lng, maxRing, res));

    if (this.redisReady && this.redis) {
      const raw = (await this.redis.georadius(
        `geo:riders:${service}`,
        lng,
        lat,
        radiusKm,
        'km',
        'WITHDIST',
        'WITHCOORD',
        'ASC',
      )) as Array<[string, string, [string, string]]>;

      const hits: NearbyRiderHit[] = [];
      for (const [riderId, distStr, [rLng, rLat]] of raw) {
        const alive = await this.redis.exists(`rider:heartbeat:${riderId}`);
        if (!alive) continue;
        const nLat = Number(rLat);
        const nLng = Number(rLng);
        const riderCell = h3IndexStrategy.cellFor(nLat, nLng, res);
        const distKm = Number(distStr);
        if (!honeycombRingSet.has(riderCell) && distKm > radiusKm) continue;
        hits.push({
          riderId,
          lat: nLat,
          lng: nLng,
          distanceKm: distKm,
          h3Cell: riderCell,
          ringDistance: h3IndexStrategy.hexRingDistance(originCell, riderCell),
        });
      }
      hits.sort((a, b) => a.ringDistance - b.ringDistance || a.distanceKm - b.distanceKm);
      return hits;
    }

    const now = Date.now();
    const hits: NearbyRiderHit[] = [];
    for (const [riderId, pos] of this.memCoords.entries()) {
      if (pos.expiresAt < now) {
        this.memCoords.delete(riderId);
        continue;
      }
      if (!pos.services.has(service)) continue;
      const dist = haversineKm(lat, lng, pos.lat, pos.lng);
      const riderCell = pos.h3Cell || h3IndexStrategy.cellFor(pos.lat, pos.lng, res);
      if (dist <= radiusKm || honeycombRingSet.has(riderCell)) {
        hits.push({
          riderId,
          lat: pos.lat,
          lng: pos.lng,
          distanceKm: dist,
          h3Cell: riderCell,
          ringDistance: h3IndexStrategy.hexRingDistance(originCell, riderCell),
        });
      }
    }
    hits.sort((a, b) => a.ringDistance - b.ringDistance || a.distanceKm - b.distanceKm);
    return hits;
  }

  /**
   * Rider-side Q6 Honeycomb + Redis GEO request finder.
   * Expands H3 Q6 honeycomb rings around the rider (ring 0 -> ring 1 -> ring 2)
   * to discover and rank nearby Ride, Parcel, and Food delivery requests.
   */
  async findNearbyRequestsForRider<T extends { id: string }>(
    service: DispatchServiceKey,
    riderLat: number,
    riderLng: number,
    requests: T[],
    getCoords: (item: T) => { lat: number | null | undefined; lng: number | null | undefined },
    maxRing = 2,
    radiusKm = 15,
  ): Promise<Array<T & { geoMeta: HoneycombGeoMeta }>> {
    const res = env.h3Resolution;
    const engine = this.getEngineName();
    const riderCell = h3IndexStrategy.cellFor(riderLat, riderLng, res);
    const honeycombRingSet = new Set(h3IndexStrategy.neighborCells(riderLat, riderLng, maxRing, res));

    const redisDistMap = new Map<string, number>();
    if (this.redisReady && this.redis && requests.length > 0) {
      const pipe = this.redis.pipeline();
      for (const req of requests) {
        const coords = getCoords(req);
        if (coords.lat != null && coords.lng != null) {
          const cell = h3IndexStrategy.cellFor(coords.lat, coords.lng, res);
          pipe.geoadd(`geo:requests:${service}`, coords.lng, coords.lat, req.id);
          pipe.sadd(`h3:q${res}:requests:${cell}:${service}`, req.id);
          pipe.expire(`h3:q${res}:requests:${cell}:${service}`, 3600);
        }
      }
      await pipe.exec();

      const raw = (await this.redis.georadius(
        `geo:requests:${service}`,
        riderLng,
        riderLat,
        radiusKm,
        'km',
        'WITHDIST',
        'ASC',
      )) as Array<[string, string]>;
      for (const [id, distStr] of raw) {
        redisDistMap.set(id, Number(distStr));
      }
    }

    const enriched: Array<T & { geoMeta: HoneycombGeoMeta }> = [];
    for (const item of requests) {
      const coords = getCoords(item);
      if (coords.lat == null || coords.lng == null) {
        enriched.push({
          ...item,
          geoMeta: {
            h3Cell: riderCell,
            h3Resolution: res,
            ringDistance: maxRing + 1,
            distanceKm: 0,
            engine,
          },
        });
        continue;
      }

      const reqCell = h3IndexStrategy.cellFor(coords.lat, coords.lng, res);
      const ringDist = h3IndexStrategy.hexRingDistance(riderCell, reqCell);
      const distKm = redisDistMap.get(item.id) ?? Number(haversineKm(riderLat, riderLng, coords.lat, coords.lng).toFixed(2));

      if (honeycombRingSet.has(reqCell) || ringDist <= maxRing || distKm <= radiusKm) {
        enriched.push({
          ...item,
          geoMeta: {
            h3Cell: reqCell,
            h3Resolution: res,
            ringDistance: ringDist,
            distanceKm: distKm,
            engine,
          },
        });
      }
    }

    enriched.sort((a, b) => a.geoMeta.ringDistance - b.geoMeta.ringDistance || a.geoMeta.distanceKm - b.geoMeta.distanceKm);
    return enriched;
  }

  /**
   * Registers a Rider actively carrying a qualifying NORMAL front-carrier parcel from Zone A -> Zone B.
   * Allows Zone A -> Zone B ride-share requests to match this rider.
   */
  async registerActiveMultiServiceParcel(slot: ActiveMultiServiceSlot): Promise<void> {
    if (this.redisReady && this.redis) {
      const corridorKey = `ms:zone:${slot.originZoneId}:${slot.destinationZoneId}`;
      await this.redis
        .pipeline()
        .sadd(corridorKey, slot.riderId)
        .set(`rider:ms:active:${slot.riderId}`, JSON.stringify(slot), 'EX', 43200)
        .exec();
    } else {
      this.memMultiServiceParcels.set(slot.riderId, slot);
    }
  }

  async clearActiveMultiServiceParcel(riderId: string): Promise<void> {
    if (this.redisReady && this.redis) {
      const existingRaw = await this.redis.get(`rider:ms:active:${riderId}`);
      if (existingRaw) {
        const existing = JSON.parse(existingRaw) as ActiveMultiServiceSlot;
        await this.redis.srem(`ms:zone:${existing.originZoneId}:${existing.destinationZoneId}`, riderId);
      }
      await this.redis.del(`rider:ms:active:${riderId}`);
    }
    this.memMultiServiceParcels.delete(riderId);
  }

  /**
   * Matches only riders who:
   * 1) Started with an active eligible NORMAL front-carrier parcel (Parcel-first!)
   * 2) Parcel goes Zone A -> Zone B AND this Ride request starts in Zone A AND ends in Zone B.
   */
  async findMultiServiceRidersForCorridor(
    pickupZoneId: string,
    dropoffZoneId: string,
  ): Promise<ActiveMultiServiceSlot[]> {
    if (this.redisReady && this.redis) {
      const riderIds = await this.redis.smembers(`ms:zone:${pickupZoneId}:${dropoffZoneId}`);
      const results: ActiveMultiServiceSlot[] = [];
      for (const id of riderIds) {
        const raw = await this.redis.get(`rider:ms:active:${id}`);
        if (raw) {
          results.push(JSON.parse(raw) as ActiveMultiServiceSlot);
        }
      }
      return results;
    }

    const matches: ActiveMultiServiceSlot[] = [];
    for (const slot of this.memMultiServiceParcels.values()) {
      if (slot.originZoneId === pickupZoneId && slot.destinationZoneId === dropoffZoneId) {
        matches.push(slot);
      }
    }
    return matches;
  }

  async close(): Promise<void> {
    if (this.redis) {
      await this.redis.quit();
      this.redis = null;
      this.redisReady = false;
    }
  }
}

export const geoMatchService = new GeoMatchService();
