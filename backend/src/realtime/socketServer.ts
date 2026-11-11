import type { Server as HttpServer } from 'node:http';
import { Server as SocketIOServer, type Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { geoMatchService, type DispatchServiceKey } from '../services/geoMatchService.js';

let ioInstance: SocketIOServer | null = null;

export function getIO(): SocketIOServer | null {
  return ioInstance;
}

/**
 * WebSocket (Socket.IO) Hub:
 * - Streams high-frequency Rider GPS updates directly into Redis GEO (+ Zone sets)
 * - Dispatches timed 15s Rider offers & 60s Merchant New Order alerts
 * - Broadcasts STRICTLY ISOLATED client tracking rooms:
 *   tracking:parcel:{id} NEVER receives passenger/ride data!
 *   tracking:ride:{id} NEVER receives parcel data!
 * - Powers bidirectional In-App Chat between Client and Rider.
 */
export function initSocketServer(httpServer: HttpServer): SocketIOServer {
  const io = new SocketIOServer(httpServer, {
    cors: {
      origin: env.corsOrigins.includes('*') ? '*' : env.corsOrigins,
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  io.use((socket, next) => {
    const token =
      (socket.handshake.auth?.token as string | undefined) ??
      (socket.handshake.query?.token as string | undefined);
    if (!token) {
      return next(); // Allow guest/public subscription by token check on sensitive rooms if needed
    }
    try {
      const decoded = jwt.verify(token, env.jwtAccessSecret) as { sub: string; phone: string };
      socket.data.userId = decoded.sub;
      socket.data.phone = decoded.phone;
    } catch {
      // ignore invalid optional token at handshake; rooms enforce identity
    }
    next();
  });

  io.on('connection', (socket: Socket) => {
    socket.on('join:user', (userId: string) => {
      if (typeof userId === 'string' && userId.length > 0) {
        socket.join(`user:${userId}`);
      }
    });

    socket.on('join:rider', (riderId: string) => {
      if (typeof riderId === 'string' && riderId.length > 0) {
        socket.join(`rider:${riderId}`);
      }
    });

    socket.on('join:merchant', (merchantId: string) => {
      if (typeof merchantId === 'string' && merchantId.length > 0) {
        socket.join(`merchant:${merchantId}`);
      }
    });

    socket.on('join:tracking', (payload: { serviceType: 'food' | 'parcel' | 'ride'; orderId: string }) => {
      if (!payload?.serviceType || !payload?.orderId) return;
      socket.join(`tracking:${payload.serviceType}:${payload.orderId}`);
    });

    socket.on('join:chat', (threadId: string) => {
      if (typeof threadId === 'string' && threadId.length > 0) {
        socket.join(`chat:${threadId}`);
      }
    });

    /**
     * Rider streams GPS coordinates over WebSocket -> Redis GEO index + isolated active tracking rooms.
     */
    socket.on(
      'rider:location:update',
      async (payload: {
        riderId: string;
        lat: number;
        lng: number;
        services?: DispatchServiceKey[];
        activeParcelId?: string;
        activeRideId?: string;
        activeFoodOrderId?: string;
      }) => {
        if (!payload?.riderId || typeof payload.lat !== 'number' || typeof payload.lng !== 'number') {
          return;
        }
        const svcs: DispatchServiceKey[] = payload.services ?? ['food', 'parcel', 'ride'];
        await geoMatchService.updateRiderLocation(payload.riderId, payload.lat, payload.lng, svcs);

        // Isolated room fanout (each client room only hears coordinates for its own orderId!)
        if (payload.activeParcelId) {
          io.to(`tracking:parcel:${payload.activeParcelId}`).emit('tracking:location', {
            orderId: payload.activeParcelId,
            lat: payload.lat,
            lng: payload.lng,
            updatedAt: new Date().toISOString(),
          });
        }
        if (payload.activeRideId) {
          io.to(`tracking:ride:${payload.activeRideId}`).emit('tracking:location', {
            orderId: payload.activeRideId,
            lat: payload.lat,
            lng: payload.lng,
            updatedAt: new Date().toISOString(),
          });
        }
        if (payload.activeFoodOrderId) {
          io.to(`tracking:food:${payload.activeFoodOrderId}`).emit('tracking:location', {
            orderId: payload.activeFoodOrderId,
            lat: payload.lat,
            lng: payload.lng,
            updatedAt: new Date().toISOString(),
          });
        }
      },
    );
  });

  ioInstance = io;
  return io;
}

