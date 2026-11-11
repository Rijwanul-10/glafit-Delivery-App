import { Redis } from 'ioredis';
import { latLngToCell, gridDisk } from 'h3-js';
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
}

/**
 * Planned hyper-scale spatial index adapter (Uber H3 hexagonal grid).
 * Already wired so hyper-scale H3 bucketing can replace/augment Redis GEO keys
 * without changing dispatch callers.
 */
export interface H3IndexStrategy {
  cellFor(lat: number, lng: number, resolution?: number): string;
  neighborCells(lat: number, lng: number, kRings?: number, resolution?: number): string[];
}

export const h3IndexStrategy: H3IndexStrategy = {
  cellFor(lat: number, lng: number, resolution = env.h3Resolution): string {
    return latLngToCell(lat, lng, resolution);
  },
  neighborCells(lat: number, lng: number, kRings = 1, resolution = env.h3Resolution): string[] {
    const origin = latLngToCell(lat, lng, resolution);
    return gridDisk(origin, kRings);
  },
};

/**
 * Hybrid Redis GEO + Memory fallback geospatial & Zone A -> Zone B multi-service matcher.
 * Production uses Redis GEOADD / GEORADIUSBYMEMBER / GEORADIUS + EX 30 TTL heartbeats.
 */
class GeoMatchService {
  private redis: Redis | null = null;
  private redisReady = false;

  // In-memory store mirroring Redis GEO + 30s heartbeat TTL + Zone A->B Sets
  private memCoords = new Map<string, { lat: number; lng: number; services: Set<DispatchServiceKey>; expiresAt: number }>();
  private memMultiServiceParcels = new Map<string, ActiveMultiServiceSlot>(); // riderId -> slot

  async init(): Promise<void> {
    if (env.geoBackend === 'memory' || !env.redisUrl) {
      return;
    }
    try {
      const client = new Redis(env.redisUrl, {
        maxRetriesPerRequest: 1,
        connectTimeout: 1500,
        lazyConnect: true,
      });
      await client.connect();
      await client.ping();
      this.redis = client;
      this.redisReady = true;
      console.info('[2Bee GeoMatchService] Connected to Redis GEO backend');
    } catch (err) {
      console.warn('[2Bee GeoMatchService] Redis unreachable; using in-memory GEO fallback:', (err as Error).message);
      this.redisReady = false;
    }
  }

  getEngineName(): 'redis-geo' | 'memory-geo-fallback' {
    return this.redisReady && this.redis ? 'redis-geo' : 'memory-geo-fallback';
  }

  async updateRiderLocation(
    riderId: string,
    lat: number,
    lng: number,
    services: DispatchServiceKey[],
  ): Promise<{ h3Cell: string; engine: string }> {
    const h3Cell = h3IndexStrategy.cellFor(lat, lng);
    if (this.redisReady && this.redis) {
      const pipe = this.redis.pipeline();
      const allServices: DispatchServiceKey[] = ['food', 'parcel', 'ride'];
      for (const svc of allServices) {
        const key = `geo:riders:${svc}`;
        if (services.includes(svc)) {
          pipe.geoadd(key, lng, lat, riderId);
        } else {
          pipe.zrem(key, riderId);
        }
      }
      // Future H3 index key planned for hyper-scale bucketing
      pipe.set(`rider:h3:${riderId}`, h3Cell, 'EX', 30);
      pipe.set(`rider:heartbeat:${riderId}`, `${lat},${lng}`, 'EX', 30);
      await pipe.exec();
    } else {
      this.memCoords.set(riderId, {
        lat,
        lng,
        services: new Set(services),
        expiresAt: Date.now() + 30_000,
      });
    }
    return { h3Cell, engine: this.getEngineName() };
  }

  async setRiderOffline(riderId: string): Promise<void> {
    if (this.redisReady && this.redis) {
      await Promise.all([
        this.redis.zrem('geo:riders:food', riderId),
        this.redis.zrem('geo:riders:parcel', riderId),
        this.redis.zrem('geo:riders:ride', riderId),
        this.redis.del(`rider:heartbeat:${riderId}`, `rider:h3:${riderId}`),
      ]);
    }
    this.memCoords.delete(riderId);
    await this.clearActiveMultiServiceParcel(riderId);
  }

  async findNearbyRiders(
    service: DispatchServiceKey,
    lat: number,
    lng: number,
    radiusKm = 8,
  ): Promise<NearbyRiderHit[]> {
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
        hits.push({
          riderId,
          lat: nLat,
          lng: nLng,
          distanceKm: Number(distStr),
          h3Cell: h3IndexStrategy.cellFor(nLat, nLng),
        });
      }
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
      if (dist <= radiusKm) {
        hits.push({
          riderId,
          lat: pos.lat,
          lng: pos.lng,
          distanceKm: dist,
          h3Cell: h3IndexStrategy.cellFor(pos.lat, pos.lng),
        });
      }
    }
    hits.sort((a, b) => a.distanceKm - b.distanceKm);
    return hits;
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

