import { env } from '../config/env.js';

export interface RouteEstimate {
  distanceKm: number;
  etaMins: number;
  polyline: Array<[number, number]>; // [lat, lng]
  provider: 'osrm' | 'haversine-fallback';
}

export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.max(0.5, Number((R * c * 1.25).toFixed(2))); // x1.25 Dhaka urban road factor
}

/**
 * Free Maps & Routing Service: OSRM + OSM Nominatim with resilient local Dhaka fallback
 * so local tests & offline demos run cleanly without API billing keys.
 */
export const mapsService = {
  async estimateRoute(
    pickupLat: number,
    pickupLng: number,
    dropoffLat: number,
    dropoffLng: number,
  ): Promise<RouteEstimate> {
    if (env.nodeEnv !== 'test' && process.env.DISABLE_EXTERNAL_HTTP !== 'true') {
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), 2500);
        const url = `${env.osrmBaseUrl}/route/v1/driving/${pickupLng},${pickupLat};${dropoffLng},${dropoffLat}?overview=full&geometries=geojson`;
        const res = await fetch(url, { signal: controller.signal });
        clearTimeout(timer);
        if (res.ok) {
          const data = (await res.json()) as {
            routes?: Array<{ distance: number; duration: number; geometry?: { coordinates: Array<[number, number]> } }>;
          };
          const route = data.routes?.[0];
          if (route) {
            return {
              distanceKm: Math.max(0.5, Number((route.distance / 1000).toFixed(2))),
              etaMins: Math.max(3, Math.ceil(route.duration / 60)),
              polyline: (route.geometry?.coordinates ?? []).map(([lng, lat]) => [lat, lng]),
              provider: 'osrm',
            };
          }
        }
      } catch {
        // Fall back smoothly when OSRM is unreachable
      }
    }

    const distanceKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
    const etaMins = Math.max(5, Math.ceil((distanceKm / 22) * 60)); // ~22 km/h urban speed
    const midLat = (pickupLat + dropoffLat) / 2;
    const midLng = (pickupLng + dropoffLng) / 2;
    return {
      distanceKm,
      etaMins,
      polyline: [
        [pickupLat, pickupLng],
        [midLat, midLng],
        [dropoffLat, dropoffLng],
      ],
      provider: 'haversine-fallback',
    };
  },

  async searchPlaces(query: string): Promise<Array<{ displayName: string; lat: number; lng: number }>> {
    const q = query.trim().toLowerCase();
    const dhakaPresets = [
      { displayName: 'Banani Road 11, Block D, Dhaka', lat: 23.7937, lng: 90.4066 },
      { displayName: 'Gulshan 2 Circle, Dhaka', lat: 23.7985, lng: 90.4152 },
      { displayName: 'Gulshan 1 Avenue, South Breeze Center', lat: 23.7798, lng: 90.4167 },
      { displayName: 'Uttara Sector 7, Rabindra Sarani', lat: 23.8726, lng: 90.3983 },
      { displayName: 'Uttara Sector 3, Friends Club Road', lat: 23.8648, lng: 90.3974 },
      { displayName: 'Dhanmondi 27, Mirpur Road, Dhaka', lat: 23.7529, lng: 90.3736 },
      { displayName: 'Mirpur 10 Roundabout, Dhaka', lat: 23.8069, lng: 90.3687 },
      { displayName: 'Mohakhali Flyover / Hub, Dhaka', lat: 23.7778, lng: 90.4023 },
      { displayName: 'Hazrat Shahjalal Airport T3, Dhaka', lat: 23.8433, lng: 90.3978 },
      { displayName: 'Motijheel Commercial Area, Dhaka', lat: 23.7330, lng: 90.4172 },
    ];
    const localHits = dhakaPresets.filter((p) => p.displayName.toLowerCase().includes(q));
    if (localHits.length > 0 || env.nodeEnv === 'test' || process.env.DISABLE_EXTERNAL_HTTP === 'true') {
      return localHits.length > 0 ? localHits : dhakaPresets.slice(0, 4);
    }
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 2500);
      const res = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&countrycodes=bd&limit=5&q=${encodeURIComponent(query)}`,
        { headers: { 'User-Agent': '2BeeApp/1.0' }, signal: controller.signal },
      );
      clearTimeout(timer);
      if (res.ok) {
        const items = (await res.json()) as Array<{ display_name: string; lat: string; lon: string }>;
        if (items.length > 0) {
          return items.map((i) => ({ displayName: i.display_name, lat: Number(i.lat), lng: Number(i.lon) }));
        }
      }
    } catch {
      // ignore network error
    }
    return dhakaPresets;
  },
};

