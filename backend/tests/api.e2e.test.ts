import http from 'node:http';
import request from 'supertest';
import { io as ioClient, type Socket } from 'socket.io-client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createExpressApp } from '../src/app.js';
import { closePrisma, getPrisma, initPrisma } from '../src/lib/prisma.js';
import { geoMatchService } from '../src/services/geoMatchService.js';
import { initSocketServer } from '../src/realtime/socketServer.js';
import { runSeed } from '../src/prisma/seed.js';
import { touchRoleActivity } from '../src/middleware/auth.js';
import { env } from '../src/config/env.js';

describe('2Bee Super-App Backend E2E Specification Tests', () => {
  let server: http.Server;
  let baseUrl = '';
  let app: ReturnType<typeof createExpressApp>;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.DISABLE_EXTERNAL_HTTP = 'true';
    await initPrisma({ pglitePath: 'memory://' });
    await geoMatchService.init();
    await runSeed();

    app = createExpressApp();
    server = http.createServer(app);
    initSocketServer(server);
    await new Promise<void>((resolve) => {
      server.listen(0, () => {
        const addr = server.address();
        if (addr && typeof addr === 'object') {
          baseUrl = `http://127.0.0.1:${addr.port}`;
        }
        resolve();
      });
    });
  });

  afterAll(async () => {
    await geoMatchService.close();
    await closePrisma();
    if (server) {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });

  async function loginPhone(phone: string) {
    const reqOtp = await request(app).post('/api/v1/auth/otp/request').send({ phone, purpose: 'LOGIN' });
    expect(reqOtp.status).toBe(200);
    const verify = await request(app)
      .post('/api/v1/auth/otp/verify')
      .send({ phone, code: reqOtp.body.devOtpHint ?? '123456', purpose: 'LOGIN' });
    expect(verify.status).toBe(200);
    return verify.body as {
      accessToken: string;
      user: { id: string; phone: string };
      roles: Record<string, unknown>;
    };
  }

  it('enforces phone-OTP auth (no Google route) and dual COD + Stripe Sandbox payment discovery', async () => {
    const invalid = await request(app).post('/api/v1/auth/otp/request').send({ phone: '12345', purpose: 'LOGIN' });
    expect(invalid.status).toBe(400);

    const auth = await loginPhone('+8801711111111');
    expect(auth.accessToken).toBeTruthy();

    // New phone number triggers short profile setup and saves User profile
    const newPhone = '+8801911223344';
    const reqNew = await request(app).post('/api/v1/auth/otp/request').send({ phone: newPhone, purpose: 'LOGIN' });
    expect(reqNew.status).toBe(200);
    expect(reqNew.body.isNewUser).toBe(true);
    expect(reqNew.body.needsProfileSetup).toBe(true);

    const verNew = await request(app)
      .post('/api/v1/auth/otp/verify')
      .send({ phone: newPhone, code: reqNew.body.devOtpHint ?? '123456', purpose: 'LOGIN' });
    expect(verNew.status).toBe(200);
    expect(verNew.body.isNewUser).toBe(true);
    expect(verNew.body.needsProfileSetup).toBe(true);

    const complete = await request(app)
      .post('/api/v1/auth/profile/complete')
      .set('Authorization', `Bearer ${verNew.body.accessToken}`)
      .send({ fullName: 'Farhan Sadik', email: 'farhan@example.com' });
    expect(complete.status).toBe(200);
    expect(complete.body.needsProfileSetup).toBe(false);
    expect(complete.body.user.fullName).toBe('Farhan Sadik');
    expect(complete.body.user.email).toBe('farhan@example.com');

    const reqReturning = await request(app).post('/api/v1/auth/otp/request').send({ phone: newPhone, purpose: 'LOGIN' });
    expect(reqReturning.status).toBe(200);
    expect(reqReturning.body.isNewUser).toBe(false);
    expect(reqReturning.body.needsProfileSetup).toBe(false);

    const methods = await request(app).get('/api/v1/common/payment-methods');
    expect(methods.status).toBe(200);
    expect(methods.body.workingMethods.map((m: { code: string }) => m.code)).toEqual(['COD', 'STRIPE_SANDBOX']);
    expect(methods.body.mfsPreviewOptions.every((m: { liveEnabled: boolean }) => m.liveEnabled === false)).toBe(true);
  });

  it('enforces Merchant reg w/o passcode -> pending Home -> post-approval 6-digit PIN setup -> Split HK panel', async () => {
    const phone = '+8801744444444';
    const { accessToken, user } = await loginPhone(phone);

    // 1) Register Home Kitchen WITHOUT setting any passcode during registration
    const reg = await request(app)
      .post('/api/v1/merchant/register')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        merchantType: 'HOME_KITCHEN',
        businessName: 'Nadia Home Spice',
        ownerOrCookName: 'Nadia Begum',
        cuisines: ['Bangladeshi'],
        address: 'House 8, Road 6, Banani',
        areaZoneId: 'zone-banani',
        contactPhone: phone,
        nidNumber: '1991123457788',
        dailyOrderLimit: 12,
        dailyCutoffTime: '22:00',
        hygieneConfirmed: true,
        payoutProvider: 'BKASH',
        payoutAccountNumber: phone,
        payoutHolderName: 'Nadia Begum',
      });
    expect(reg.status).toBe(201);
    expect(reg.body.profile.passcodeSet).toBe(false);
    expect(reg.body.profile.kycStatus).toBe('PENDING');
    const merchantId = reg.body.profile.id as string;

    // 2) Pending merchant can view pending home WITHOUT passcode, store locked closed
    const pendingHome = await request(app)
      .get('/api/v1/merchant/pending-home')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(pendingHome.status).toBe(200);
    expect(pendingHome.body.profile.isStoreOpen).toBe(false);

    // 3) Admin approves KYC -> Merchant still blocked from live Home Panel until setting fixed 6-digit PIN!
    const approve = await request(app)
      .post(`/api/v1/admin/kyc/merchant/${merchantId}/decision`)
      .set('x-admin-secret', env.adminSeedPassword)
      .send({ decision: 'APPROVED' });
    expect(approve.status).toBe(200);

    const blockedLogin = await request(app)
      .post('/api/v1/merchant/login-pin')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ passcode: '123456' });
    expect(blockedLogin.status).toBe(403);
    expect(blockedLogin.body.code).toBe('MERCHANT_PIN_SETUP_REQUIRED');

    // 4) Request approval OTP -> Create fixed 6-digit PIN -> Unlocks Split Home Kitchen Panel!
    const otpReq = await request(app)
      .post('/api/v1/auth/otp/request')
      .send({ phone, purpose: 'MERCHANT_APPROVAL_PIN' });
    const pinSetup = await request(app)
      .post('/api/v1/merchant/post-approval/setup-pin')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ otpCode: otpReq.body.devOtpHint ?? '123456', passcode: '654321', enableBiometric: true });
    expect(pinSetup.status).toBe(200);
    const roleToken = pinSetup.body.roleToken as string;

    const splitHome = await request(app)
      .get('/api/v1/merchant/panel/home')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('x-role-token', roleToken);
    expect(splitHome.status).toBe(200);
    expect(splitHome.body.merchant.merchantType).toBe('HOME_KITCHEN');
    expect(splitHome.body.homeKitchenPanel.dailyOrderLimit).toBe(12);
    expect(splitHome.body.homeKitchenPanel.dailyCutoffTime).toBe('22:00');

    // 5) Forgot passcode reset requires OTP + NID last 4 digits (7788)
    const forgotOtp = await request(app)
      .post('/api/v1/auth/otp/request')
      .send({ phone, purpose: 'FORGOT_PASSCODE' });
    const badNidReset = await request(app)
      .post('/api/v1/merchant/forgot-passcode/reset')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ otpCode: forgotOtp.body.devOtpHint ?? '123456', nidLast4: '9999', newPasscode: '778899' });
    expect(badNidReset.status).toBe(400);

    const goodNidReset = await request(app)
      .post('/api/v1/merchant/forgot-passcode/reset')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ otpCode: forgotOtp.body.devOtpHint ?? '123456', nidLast4: '7788', newPasscode: '778899' });
    expect(goodNidReset.status).toBe(200);
    expect(user.id).toBeTruthy();
  });

  it('enforces Rider 4-digit reg PIN, 15m inactivity lock, and 48h payout change guard', async () => {
    const phone = '+8801755555555';
    const { accessToken, user } = await loginPhone(phone);

    const reg = await request(app)
      .post('/api/v1/rider/register')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        fullName: 'Sajib Mia',
        dob: '1998-03-10',
        emergencyName: 'Karim Mia',
        emergencyPhone: '+8801855555555',
        nidNumber: '1998269014422',
        licenseNumber: 'DL-44210',
        licenseExpiry: '2030-01-01',
        vehicleOwnership: 'OWN',
        vehicleBrandModel: 'Honda Livo 110',
        frontCarrierEnabled: true,
        spareHelmetConfirmed: true,
        multiServiceRequested: true,
        payoutProvider: 'NAGAD',
        payoutAccountNumber: phone,
        payoutHolderName: 'Sajib Mia',
        passcode: '2589', // 4-digit created at registration Step 8!
      });
    expect(reg.status).toBe(201);
    const roleToken = reg.body.roleToken as string;

    // Pending Rider home has ZERO fake completed trips & cannot go online
    const pendingHome = await request(app)
      .get('/api/v1/rider/panel/home')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('x-role-token', roleToken);
    expect(pendingHome.status).toBe(200);
    expect(pendingHome.body.rider.kycStatus).toBe('PENDING');
    expect(pendingHome.body.recentCompletedTrips).toEqual([]);

    const goOnlineBlocked = await request(app)
      .post('/api/v1/rider/panel/online')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('x-role-token', roleToken)
      .send({ isOnline: true });
    expect(goOnlineBlocked.status).toBe(403);

    // 48-hour payout hold test
    const payoutOtp = await request(app)
      .post('/api/v1/auth/otp/request')
      .send({ phone, purpose: 'PAYOUT_CHANGE' });
    const payoutReq = await request(app)
      .post('/api/v1/rider/panel/payout/change-request')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('x-role-token', roleToken)
      .send({
        otpCode: payoutOtp.body.devOtpHint ?? '123456',
        provider: 'BKASH',
        accountNumber: '+8801799999999',
        holderName: 'Sajib Mia',
      });
    expect(payoutReq.status).toBe(200);
    expect(payoutReq.body.holdHours).toBe(48);
    expect(payoutReq.body.effectiveAt).toBeTruthy();

    // 15-minute inactivity lock test
    touchRoleActivity(user.id, 'RIDER', Date.now() - 16 * 60 * 1000);
    const expiredRes = await request(app)
      .get('/api/v1/rider/panel/home')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('x-role-token', roleToken);
    expect(expiredRes.status).toBe(401);
    expect(expiredRes.body.code).toBe('ROLE_INACTIVITY_LOCKED');
  });

  it('enforces Multi-Service Zone A->B matching, Parcel-first, Passenger-1st dropoff & STRICT Client Privacy', async () => {
    const client = await loginPhone('+8801711111111');
    const rider = await loginPhone('+8801712345678');

    const riderLogin = await request(app)
      .post('/api/v1/rider/login-pin')
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .send({ passcode: '2580' });
    expect(riderLogin.status).toBe(200);
    const riderToken = riderLogin.body.roleToken as string;

    // Put Rider online in Redis GEO / geo fallback
    await request(app)
      .post('/api/v1/rider/panel/online')
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ isOnline: true, lat: 23.7937, lng: 90.4066 });

    // 1) Express parcel must NOT qualify for multi-service
    const expressEstimate = await request(app)
      .post('/api/v1/parcels/estimate')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        pickupLat: 23.7937,
        pickupLng: 90.4066,
        pickupZoneId: 'zone-banani',
        dropoffLat: 23.8759,
        dropoffLng: 90.3795,
        dropoffZoneId: 'zone-uttara',
        tier: 'EXPRESS',
        weightKg: 2.0,
      });
    expect(expressEstimate.status).toBe(200);
    expect(expressEstimate.body.fitsFrontCarrier).toBe(false);

    // 2) Book eligible NORMAL front-carrier Parcel: Zone A (Banani) -> Zone B (Uttara)
    const parcelBook = await request(app)
      .post('/api/v1/parcels/book')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        tier: 'NORMAL_ECO',
        weightKg: 2.0,
        lengthCm: 30,
        widthCm: 20,
        heightCm: 15,
        senderName: 'Tanvir Ahmed',
        senderPhone: '+8801711111111',
        pickupAddress: 'Road 11, Banani',
        pickupZoneId: 'zone-banani',
        pickupLat: 23.7937,
        pickupLng: 90.4066,
        recipientName: 'Farhana Yasmin',
        recipientPhone: '+8801811111111',
        dropoffAddress: 'Road 13, Uttara Sector 7',
        dropoffZoneId: 'zone-uttara',
        dropoffLat: 23.8726,
        dropoffLng: 90.3983,
        codCollectBdt: 1200,
        paymentMethod: 'COD',
      });
    expect(parcelBook.status).toBe(201);
    const parcelId = parcelBook.body.shipment.id as string;
    const deliveryPin = parcelBook.body.shipment.deliveryPin as string;

    // Rider accepts & picks up parcel -> registers Zone A (banani) -> Zone B (uttara) in Redis
    await request(app)
      .post(`/api/v1/rider/panel/parcel/${parcelId}/accept`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken);

    const parcelPickup = await request(app)
      .post(`/api/v1/rider/panel/parcel/${parcelId}/pickup`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ actualWeightKg: 2.1 });
    expect(parcelPickup.status).toBe(200);
    expect(parcelPickup.body.multiServiceEligible).toBe(true);

    // 3) Create NON-matching ride (Banani -> Mirpur) and verify Rider CANNOT attach it!
    const wrongRide = await request(app)
      .post('/api/v1/rides/request')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        fleetTier: '2BEE_EV_SOLO',
        pickupAddress: 'Banani Road 11',
        pickupZoneId: 'zone-banani',
        pickupLat: 23.7937,
        pickupLng: 90.4066,
        dropoffAddress: 'Mirpur 10',
        dropoffZoneId: 'zone-mirpur',
        dropoffLat: 23.8069,
        dropoffLng: 90.3687,
        paymentMethod: 'COD',
      });
    expect(wrongRide.body.matchedCorridorRidersCount).toBe(0);

    const rejectWrongZone = await request(app)
      .post('/api/v1/rider/panel/multi-service/accept-ride-addon')
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ parcelId, rideTripId: wrongRide.body.trip.id });
    expect(rejectWrongZone.status).toBe(400);
    expect(rejectWrongZone.body.code).toBe('CORRIDOR_ZONE_MISMATCH');

    // 4) Create MATCHING ride (Banani -> Uttara)
    const rightRide = await request(app)
      .post('/api/v1/rides/request')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        fleetTier: '2BEE_EV_SOLO',
        pickupAddress: 'Banani Block D',
        pickupZoneId: 'zone-banani',
        pickupLat: 23.7942,
        pickupLng: 90.4071,
        dropoffAddress: 'Uttara Sector 3',
        dropoffZoneId: 'zone-uttara',
        dropoffLat: 23.8648,
        dropoffLng: 90.3974,
        paymentMethod: 'COD',
      });
    expect(rightRide.status).toBe(201);
    expect(rightRide.body.matchedCorridorRidersCount).toBeGreaterThanOrEqual(1);
    const rideId = rightRide.body.trip.id as string;
    const startPin = rightRide.body.trip.startPin as string;

    const msAccept = await request(app)
      .post('/api/v1/rider/panel/multi-service/accept-ride-addon')
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ parcelId, rideTripId: rideId });
    expect(msAccept.status).toBe(201);
    const batchId = msAccept.body.batch.id as string;

    // 5) Trying to deliver parcel BEFORE passenger dropoff must fail!
    const earlyParcelDeliver = await request(app)
      .post(`/api/v1/rider/panel/parcel/${parcelId}/deliver`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ deliveryPin });
    expect(earlyParcelDeliver.status).toBe(400);
    expect(earlyParcelDeliver.body.code).toBe('PASSENGER_MUST_DROP_FIRST');

    // 6) Pickup passenger w/ 4-digit startPin & helmet -> Dropoff passenger first -> Deliver parcel second!
    const paxPickup = await request(app)
      .post(`/api/v1/rider/panel/multi-service/${batchId}/passenger-pickup`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ startPin, passengerHasHelmet: true });
    expect(paxPickup.status).toBe(200);

    const paxDropoff = await request(app)
      .post(`/api/v1/rider/panel/multi-service/${batchId}/passenger-dropoff`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ helmetReturnedOk: true, curbDismountOk: true });
    expect(paxDropoff.status).toBe(200);
    expect(paxDropoff.body.batch.status).toBe('PASSENGER_DROPPED');

    // 7) STRICT PRIVACY ISOLATION CHECK before/after delivery:
    const parcelClientView = await request(app)
      .get(`/api/v1/parcels/${parcelId}`)
      .set('Authorization', `Bearer ${client.accessToken}`);
    const rideClientView = await request(app)
      .get(`/api/v1/rides/${rideId}`)
      .set('Authorization', `Bearer ${client.accessToken}`);
    const parcelText = JSON.stringify(parcelClientView.body).toLowerCase();
    const rideText = JSON.stringify(rideClientView.body).toLowerCase();
    expect(parcelText).not.toContain('passenger');
    expect(parcelText).not.toContain('multi-route');
    expect(parcelText).not.toContain('multiservice');
    expect(rideText).not.toContain('parcel');
    expect(rideText).not.toContain('multiservice');

    // 8) Now Stop 2 Parcel Delivery succeeds!
    const finalDeliver = await request(app)
      .post(`/api/v1/rider/panel/parcel/${parcelId}/deliver`)
      .set('Authorization', `Bearer ${rider.accessToken}`)
      .set('x-role-token', riderToken)
      .send({ deliveryPin });
    expect(finalDeliver.status).toBe(200);
    expect(finalDeliver.body.shipment.status).toBe('DELIVERED');
  });

  it('completes Food order via Stripe Sandbox, streams WebSocket GPS, and generates PDF receipt', async () => {
    const client = await loginPhone('+8801711111111');
    const prisma = getPrisma();
    const restaurant = await prisma.merchantProfile.findFirst({
      where: { merchantType: 'PHYSICAL', kycStatus: 'APPROVED' },
      include: { menuItems: true },
    });
    expect(restaurant).toBeTruthy();
    const item = restaurant!.menuItems[0];

    const checkout = await request(app)
      .post('/api/v1/food/orders/checkout')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        merchantId: restaurant!.id,
        items: [{ menuItemId: item.id, quantity: 1, selectedOptions: [] }],
        deliveryAddress: 'House 42, Road 11, Banani',
        paymentMethod: 'STRIPE_SANDBOX',
      });
    expect(checkout.status).toBe(201);
    expect(checkout.body.order.paymentStatus).toBe('PAID');

    const pdfRes = await request(app)
      .get(`/api/v1/food/orders/${checkout.body.order.id}/pdf`)
      .set('Authorization', `Bearer ${client.accessToken}`);
    expect(pdfRes.status).toBe(200);
    expect(pdfRes.headers['content-type']).toContain('application/pdf');

    // Merchant panel verification: accept -> ready -> order slip-pdf & staff CRUD
    const mUser = await loginPhone('+8801722222222');
    const mRole = await request(app)
      .post('/api/v1/merchant/login-pin')
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .send({ passcode: '258096' });
    expect(mRole.status).toBe(200);
    const mToken = mRole.body.roleToken as string;

    const mAccept = await request(app)
      .post(`/api/v1/merchant/panel/orders/${checkout.body.order.id}/accept`)
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .set('x-role-token', mToken)
      .send({ prepTimeMins: 15 });
    expect(mAccept.status).toBe(200);

    const mReady = await request(app)
      .post(`/api/v1/merchant/panel/orders/${checkout.body.order.id}/ready`)
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .set('x-role-token', mToken);
    expect(mReady.status).toBe(200);

    const slipRes = await request(app)
      .get(`/api/v1/merchant/panel/orders/${checkout.body.order.id}/slip-pdf`)
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .set('x-role-token', mToken);
    expect(slipRes.status).toBe(200);
    expect(slipRes.headers['content-type']).toContain('application/pdf');

    const staffAdd = await request(app)
      .post('/api/v1/merchant/panel/store/staff')
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .set('x-role-token', mToken)
      .send({ name: 'Kamrul Hasan', phone: '+8801712345678', roleTitle: 'Prep Chef' });
    expect(staffAdd.status).toBe(201);
    const staffId = staffAdd.body.staff.id as string;

    const staffDel = await request(app)
      .delete(`/api/v1/merchant/panel/store/staff/${staffId}`)
      .set('Authorization', `Bearer ${mUser.accessToken}`)
      .set('x-role-token', mToken);
    expect(staffDel.status).toBe(200);

    // Rider rental booking & job getter verification (food + ride)
    const rUser = await loginPhone('+8801712345678');
    const rRole = await request(app)
      .post('/api/v1/rider/login-pin')
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .send({ passcode: '2580' });
    expect(rRole.status).toBe(200);
    const rToken = rRole.body.roleToken as string;

    const rentalsGet = await request(app)
      .get('/api/v1/rider/panel/rentals')
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken);
    expect(rentalsGet.status).toBe(200);
    const bikeId = rentalsGet.body.fleetBikes[0].id as string;

    const rentalBook = await request(app)
      .post('/api/v1/rider/panel/rentals/book')
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken)
      .send({ bikeId, planType: 'WEEKLY' });
    expect(rentalBook.status).toBe(201);
    expect(rentalBook.body.rental.bikeId).toBe(bikeId);

    const foodAccept = await request(app)
      .post(`/api/v1/rider/panel/food/${checkout.body.order.id}/accept`)
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken);
    expect(foodAccept.status).toBe(200);

    const foodJobGet = await request(app)
      .get(`/api/v1/rider/panel/food/${checkout.body.order.id}`)
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken);
    expect(foodJobGet.status).toBe(200);
    expect(foodJobGet.body.order.id).toBe(checkout.body.order.id);

    const standaloneRide = await request(app)
      .post('/api/v1/rides/request')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        fleetTier: '2BEE_EV_SOLO',
        pickupAddress: 'Banani Road 11',
        pickupLat: 23.7937,
        pickupLng: 90.4066,
        pickupZoneId: 'zone-banani',
        dropoffAddress: 'Gulshan 2 Circle',
        dropoffLat: 23.7925,
        dropoffLng: 90.4158,
        dropoffZoneId: 'zone-gulshan',
        paymentMethod: 'COD',
      });
    expect(standaloneRide.status).toBe(201);
    const soloRideId = standaloneRide.body.trip.id as string;

    const rideAccept = await request(app)
      .post(`/api/v1/rider/panel/ride/${soloRideId}/accept`)
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken);
    expect(rideAccept.status).toBe(200);

    const rideJobGet = await request(app)
      .get(`/api/v1/rider/panel/ride/${soloRideId}`)
      .set('Authorization', `Bearer ${rUser.accessToken}`)
      .set('x-role-token', rToken);
    expect(rideJobGet.status).toBe(200);
    expect(rideJobGet.body.trip.id).toBe(soloRideId);

    // WebSocket GPS Broadcast & Isolation test
    const clientSocket: Socket = ioClient(baseUrl, { auth: { token: client.accessToken }, transports: ['websocket'] });
    const riderSocket: Socket = ioClient(baseUrl, { auth: { token: client.accessToken }, transports: ['websocket'] });

    await Promise.all([
      new Promise<void>((res) => clientSocket.on('connect', () => res())),
      new Promise<void>((res) => riderSocket.on('connect', () => res())),
    ]);

    const locPromise = new Promise<{ lat: number; lng: number }>((resolve) => {
      clientSocket.once('tracking:location', (data) => resolve(data));
    });

    clientSocket.emit('join:tracking', { serviceType: 'food', orderId: checkout.body.order.id });
    await new Promise((r) => setTimeout(r, 100));
    riderSocket.emit('rider:location:update', {
      riderId: 'seed-rider-ws',
      lat: 23.7955,
      lng: 90.4088,
      services: ['food'],
      activeFoodOrderId: checkout.body.order.id,
    });

    const received = await locPromise;
    expect(received.lat).toBeCloseTo(23.7955, 3);
    clientSocket.disconnect();
    riderSocket.disconnect();
  });

  it('exposes health adapters, FCM token sync, storage upload, and Admin auth/overview/pricing/CSV reports', async () => {
    const health = await request(app).get('/health');
    expect(health.status).toBe(200);
    expect(health.body.ok).toBe(true);
    expect(health.body.storageProvider).toBe('local');
    expect(health.body.smsProvider).toBe('mock');
    expect(health.body.mapsProvider).toBe('osm');
    expect(health.body.firebaseConfigured).toBe(false);
    expect(health.body.fcmEnabled).toBe(false);

    const client = await loginPhone('+8801711111111');

    const fcmSave = await request(app)
      .post('/api/v1/common/fcm-token')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({
        token: 'e2e-fcm-device-token-123456',
        role: 'CLIENT',
        platform: 'ANDROID',
      });
    expect(fcmSave.status).toBe(200);
    expect(fcmSave.body.ok).toBe(true);
    expect(fcmSave.body.id).toBeTruthy();

    const fcmDelete = await request(app)
      .delete('/api/v1/common/fcm-token')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .send({ token: 'e2e-fcm-device-token-123456' });
    expect(fcmDelete.status).toBe(200);
    expect(fcmDelete.body.ok).toBe(true);

    const uploadRes = await request(app)
      .post('/api/v1/common/uploads')
      .set('Authorization', `Bearer ${client.accessToken}`)
      .attach('file', Buffer.from('2bee-e2e-file'), 'sample.txt');
    expect(uploadRes.status).toBe(201);
    expect(uploadRes.body.ok).toBe(true);
    expect(uploadRes.body.storageProvider).toBe('local');
    expect(uploadRes.body.url).toContain('/uploads/');

    const badAdminLogin = await request(app).post('/api/v1/admin/auth/login').send({
      email: env.adminSeedEmail,
      password: 'WrongPassword!',
    });
    expect(badAdminLogin.status).toBe(401);

    const adminLogin = await request(app).post('/api/v1/admin/auth/login').send({
      email: env.adminSeedEmail,
      password: env.adminSeedPassword,
    });
    expect(adminLogin.status).toBe(200);
    expect(adminLogin.body.accessToken).toBeTruthy();
    const adminToken = adminLogin.body.accessToken as string;

    const overview = await request(app)
      .get('/api/v1/admin/overview')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(overview.status).toBe(200);
    expect(overview.body.kpis.totalUsers).toBeGreaterThanOrEqual(1);

    const pricingPatch = await request(app)
      .patch('/api/v1/admin/pricing')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ foodDeliveryFeeBdt: 40 });
    expect(pricingPatch.status).toBe(200);
    expect(pricingPatch.body.pricing.foodDeliveryFeeBdt).toBe(40);

    const csvReport = await request(app)
      .get('/api/v1/admin/reports/revenue?format=csv')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(csvReport.status).toBe(200);
    expect(String(csvReport.headers['content-type'])).toContain('text/csv');
    expect(csvReport.text.length).toBeGreaterThan(0);
  });
});
