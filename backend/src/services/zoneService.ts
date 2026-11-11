import type { PrismaClient } from '@prisma/client';
import { haversineKm } from './mapsService.js';

export const DEFAULT_DHAKA_ZONES = [
  { id: 'zone-banani', name: 'Banani', centerLat: 23.7937, centerLng: 90.4066, radiusKm: 2.8, rateBonusBdt: 45 },
  { id: 'zone-gulshan', name: 'Gulshan', centerLat: 23.7925, centerLng: 90.4158, radiusKm: 3.0, rateBonusBdt: 45 },
  { id: 'zone-uttara', name: 'Uttara', centerLat: 23.8759, centerLng: 90.3795, radiusKm: 4.5, rateBonusBdt: 50 },
  { id: 'zone-dhanmondi', name: 'Dhanmondi', centerLat: 23.7461, centerLng: 90.3742, radiusKm: 3.0, rateBonusBdt: 40 },
  { id: 'zone-mirpur', name: 'Mirpur', centerLat: 23.8069, centerLng: 90.3687, radiusKm: 4.0, rateBonusBdt: 35 },
  { id: 'zone-mohakhali', name: 'Mohakhali', centerLat: 23.7778, centerLng: 90.4023, radiusKm: 2.5, rateBonusBdt: 40 },
  { id: 'zone-motijheel', name: 'Motijheel', centerLat: 23.7330, centerLng: 90.4172, radiusKm: 3.5, rateBonusBdt: 40 },
];

export async function ensureDefaultZones(prisma: PrismaClient): Promise<void> {
  for (const zone of DEFAULT_DHAKA_ZONES) {
    await prisma.zone.upsert({
      where: { id: zone.id },
      update: {},
      create: zone,
    });
  }
}

export async function resolveZoneByCoords(
  prisma: PrismaClient,
  lat: number,
  lng: number,
  explicitZoneId?: string,
): Promise<{ id: string; name: string }> {
  if (explicitZoneId) {
    const exact = await prisma.zone.findUnique({ where: { id: explicitZoneId } });
    if (exact) return { id: exact.id, name: exact.name };
  }
  const zones = await prisma.zone.findMany();
  if (zones.length === 0) {
    return { id: 'zone-banani', name: 'Banani' };
  }
  let best = zones[0];
  let bestDist = Infinity;
  for (const z of zones) {
    const d = haversineKm(lat, lng, z.centerLat, z.centerLng);
    if (d < bestDist) {
      bestDist = d;
      best = z;
    }
  }
  return { id: best.id, name: best.name };
}

