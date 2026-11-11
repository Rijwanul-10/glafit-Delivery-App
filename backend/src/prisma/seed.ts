import bcrypt from 'bcryptjs';
import { getPrisma, initPrisma } from '../lib/prisma.js';
import { ensureDefaultZones } from '../services/zoneService.js';

export async function runSeed(): Promise<void> {
  const prisma = getPrisma();
  await ensureDefaultZones(prisma);

  await prisma.appPricingConfig.upsert({
    where: { id: 'default' },
    update: {},
    create: {
      id: 'default',
      foodCommissionRate: 0.15,
      foodDeliveryFeeBdt: 45,
      foodPackagingFeeBdt: 15,
      foodServiceFeeBdt: 10,
      rideBaseFareSoloBdt: 40,
      ridePerKmSoloBdt: 18,
      rideMinFareSoloBdt: 85,
      parcelNormalBaseBdt: 60,
      parcelExpressBaseBdt: 110,
      parcelProtectionBdt: 15,
      parcelFrontMaxKg: 8.0,
      parcelFrontMaxVolCm3: 31500,
    },
  });

  // Seed Fleet EV Bikes for Rent
  const bikeCount = await prisma.fleetBike.count();
  if (bikeCount === 0) {
    await prisma.fleetBike.createMany({
      data: [
        {
          id: 'fleet-livo-ev',
          modelName: '2Bee EV Solo (Livo Fleet)',
          hubName: 'Banani Hub',
          powertrain: 'ELECTRIC',
          rangeKm: 120,
          dailyRateBdt: 250,
          weeklyRateBdt: 1500,
          availableQty: 6,
          frontMaxKg: 8,
          rearMaxKg: 15,
          rating: 4.9,
        },
        {
          id: 'fleet-gfr-02',
          modelName: '2Bee EV GFR-02 (Glafit)',
          hubName: 'Banani Hub',
          powertrain: 'ELECTRIC',
          rangeKm: 45,
          dailyRateBdt: 350,
          weeklyRateBdt: 2200,
          availableQty: 4,
          frontMaxKg: 8,
          rearMaxKg: 15,
          rating: 4.9,
        },
        {
          id: 'fleet-lom-ev',
          modelName: '2Bee EV LOM (Glafit)',
          hubName: 'Mohakhali Hub',
          powertrain: 'ELECTRIC',
          rangeKm: 60,
          dailyRateBdt: 400,
          weeklyRateBdt: 2600,
          availableQty: 3,
          frontMaxKg: 8,
          rearMaxKg: 15,
          rating: 4.8,
        },
      ],
    });
  }

  // 1) Demo Client: +8801711111111
  const clientUser = await prisma.user.upsert({
    where: { phone: '+8801711111111' },
    update: {},
    create: {
      phone: '+8801711111111',
      fullName: 'Alex Rahman',
      email: 'alex@2bee.app',
      activeRole: 'CLIENT',
    },
  });
  await prisma.walletAccount.upsert({
    where: { userId_role: { userId: clientUser.id, role: 'CLIENT' } },
    update: {},
    create: { userId: clientUser.id, role: 'CLIENT', balanceBdt: 1250 },
  });
  const addrCount = await prisma.savedAddress.count({ where: { userId: clientUser.id } });
  if (addrCount === 0) {
    await prisma.savedAddress.createMany({
      data: [
        { userId: clientUser.id, label: 'Home', address: 'House 42, Road 11, Banani', zoneId: 'zone-banani', lat: 23.7937, lng: 90.4066 },
        { userId: clientUser.id, label: 'Work', address: 'Road 13, Sector 7, Uttara', zoneId: 'zone-uttara', lat: 23.8726, lng: 90.3983 },
        { userId: clientUser.id, label: 'Airport T3', address: 'Hazrat Shahjalal Airport', zoneId: 'zone-uttara', lat: 23.8433, lng: 90.3978 },
      ],
    });
  }

  // 2) Demo Rider: +8801712345678 (4-digit PIN: 2580 created at reg)
  const riderUser = await prisma.user.upsert({
    where: { phone: '+8801712345678' },
    update: {},
    create: {
      phone: '+8801712345678',
      fullName: 'Md. Rafiqul Islam',
      activeRole: 'RIDER',
    },
  });
  const riderPassHash = await bcrypt.hash('2580', 10);
  const riderProfile = await prisma.riderProfile.upsert({
    where: { userId: riderUser.id },
    update: {},
    create: {
      userId: riderUser.id,
      kycStatus: 'APPROVED',
      passcodeHash: riderPassHash,
      dob: '1997-04-12',
      gender: 'Male',
      preferredZoneId: 'zone-banani',
      emergencyName: 'Kamal Islam',
      emergencyRelation: 'Brother',
      emergencyPhone: '+8801812345678',
      nidNumber: '1997269012345',
      licenseNumber: 'DK-DL-88241',
      licenseExpiry: '2029-12-31',
      vehicleOwnership: 'RENTAL',
      powertrain: 'ELECTRIC',
      vehicleBrandModel: '2Bee EV Solo (Livo Fleet)',
      plateNo: 'Dhaka Metro-Ha 45-2190',
      frontCarrierVerified: true,
      frontCarrierLengthCm: 35,
      frontCarrierWidthCm: 30,
      frontCarrierHeightCm: 30,
      frontCarrierMaxKg: 8,
      rearCarrierVerified: true,
      rearCarrierMaxKg: 15,
      multiServiceEnabled: true,
      spareHelmetConfirmed: true,
      currentLat: 23.7937,
      currentLng: 90.4066,
      totalTrips: 48,
      approvedAt: new Date(),
    },
  });
  await prisma.walletAccount.upsert({
    where: { userId_role: { userId: riderUser.id, role: 'RIDER' } },
    update: {},
    create: { userId: riderUser.id, role: 'RIDER', balanceBdt: 3240 },
  });
  await prisma.payoutAccount.upsert({
    where: { ownerRole_ownerId: { ownerRole: 'RIDER', ownerId: riderProfile.id } },
    update: {},
    create: {
      ownerRole: 'RIDER',
      ownerId: riderProfile.id,
      provider: 'BKASH',
      accountNumber: '+8801712345678',
      holderName: 'Md. Rafiqul Islam',
    },
  });

  // 3) Demo Physical Restaurant: Sultan's Dine (+8801722222222, 6-digit post-approval PIN: 258096)
  const restUser = await prisma.user.upsert({
    where: { phone: '+8801722222222' },
    update: {},
    create: { phone: '+8801722222222', fullName: 'Tariq Mahmud', activeRole: 'MERCHANT' },
  });
  const restPinHash = await bcrypt.hash('258096', 10);
  const restProfile = await prisma.merchantProfile.upsert({
    where: { userId: restUser.id },
    update: {},
    create: {
      userId: restUser.id,
      merchantType: 'PHYSICAL',
      kycStatus: 'APPROVED',
      passcodeHash: restPinHash,
      passcodeSet: true,
      businessName: "Sultan's Dine Banani",
      ownerOrCookName: 'Tariq Mahmud',
      cuisinesJson: ['Kacchi', 'Biryani', 'Mughlai'],
      address: 'Road 11, Block D, Banani, Dhaka',
      lat: 23.7942,
      lng: 90.4071,
      areaZoneId: 'zone-banani',
      contactPhone: '+8801722222222',
      eTin: '482910482910',
      tradeLicenseNo: 'TL-DNCC-9012',
      nidNumber: '1988123456789',
      fbPageUrl: 'https://facebook.com/sultansdine',
      fbVerifyToken: '2B-4821',
      avgPrepMins: 22,
      hygieneConfirmed: true,
      isStoreOpen: true,
      deliveryFeeBdt: 45,
      minOrderBdt: 150,
      rating: 4.8,
      reviewCount: 342,
      approvedAt: new Date(),
    },
  });
  await prisma.walletAccount.upsert({
    where: { userId_role: { userId: restUser.id, role: 'MERCHANT' } },
    update: {},
    create: { userId: restUser.id, role: 'MERCHANT', balanceBdt: 18450 },
  });

  if ((await prisma.menuCategory.count({ where: { merchantId: restProfile.id } })) === 0) {
    const cat = await prisma.menuCategory.create({
      data: { merchantId: restProfile.id, name: 'Kacchi & Platters', sortOrder: 1 },
    });
    await prisma.menuItem.createMany({
      data: [
        {
          merchantId: restProfile.id,
          categoryId: cat.id,
          name: 'Mutton Kacchi (Basmati)',
          description: 'Slow-cooked tender mutton with aged basmati rice, potato, and plum.',
          priceBdt: 480,
          strikePriceBdt: 520,
          prepTimeMins: 20,
          isBestseller: true,
          optionGroupsJson: [
            {
              title: 'Portion Size',
              required: true,
              maxSelect: 1,
              options: [
                { id: 'reg', name: 'Half (1 Person)', extraBdt: 0 },
                { id: 'full', name: 'Full (2 Persons)', extraBdt: 380 },
              ],
            },
            {
              title: 'Add-ons & Extras',
              required: false,
              maxSelect: 3,
              options: [
                { id: 'borhani', name: 'Shahi Borhani (250ml)', extraBdt: 80 },
                { id: 'jali', name: 'Jali Kabab', extraBdt: 75 },
              ],
            },
          ],
        },
        {
          merchantId: restProfile.id,
          categoryId: cat.id,
          name: 'Beef Tehari Special',
          description: 'Aromatic mustard-oil infused Chini Gura rice with tender beef.',
          priceBdt: 340,
          prepTimeMins: 18,
          isBestseller: false,
          optionGroupsJson: [],
        },
      ],
    });
    await prisma.promotion.create({
      data: {
        merchantId: restProfile.id,
        title: '2Bee Launch Special',
        promoCode: '2BEE100',
        discountType: 'FLAT_BDT',
        discountValue: 100,
        minOrderBdt: 400,
        endsAt: new Date(Date.now() + 60 * 86400 * 1000),
      },
    });
  }

  // 4) Demo Home Kitchen: Rina's Home Kitchen (+8801733333333, 6-digit post-approval PIN: 147852)
  const hkUser = await prisma.user.upsert({
    where: { phone: '+8801733333333' },
    update: {},
    create: { phone: '+8801733333333', fullName: 'Rina Akter', activeRole: 'MERCHANT' },
  });
  const hkPinHash = await bcrypt.hash('147852', 10);
  const hkProfile = await prisma.merchantProfile.upsert({
    where: { userId: hkUser.id },
    update: {},
    create: {
      userId: hkUser.id,
      merchantType: 'HOME_KITCHEN',
      kycStatus: 'APPROVED',
      passcodeHash: hkPinHash,
      passcodeSet: true,
      businessName: "Rina's Home Kitchen",
      ownerOrCookName: 'Rina Akter',
      cuisinesJson: ['Home Style', 'Bangladeshi', 'Fish Curry'],
      address: 'Road 4, Banani DOHS, Dhaka',
      lat: 23.7901,
      lng: 90.4029,
      areaZoneId: 'zone-banani',
      contactPhone: '+8801733333333',
      nidNumber: '1989234567890',
      fbPageUrl: 'https://facebook.com/rinaskitchenbd',
      fbVerifyToken: '2B-7492',
      avgPrepMins: 35,
      dailyOrderLimit: 15,
      dailyCutoffTime: '23:30', // Open in late evening testing
      hygieneConfirmed: true,
      hygieneScore: 4.95,
      isStoreOpen: true,
      deliveryFeeBdt: 35,
      minOrderBdt: 150,
      rating: 4.9,
      reviewCount: 118,
      approvedAt: new Date(),
    },
  });
  await prisma.walletAccount.upsert({
    where: { userId_role: { userId: hkUser.id, role: 'MERCHANT' } },
    update: {},
    create: { userId: hkUser.id, role: 'MERCHANT', balanceBdt: 6420 },
  });

  if ((await prisma.menuCategory.count({ where: { merchantId: hkProfile.id } })) === 0) {
    const cat = await prisma.menuCategory.create({
      data: { merchantId: hkProfile.id, name: "Tonight's Home Batch", sortOrder: 1 },
    });
    await prisma.menuItem.createMany({
      data: [
        {
          merchantId: hkProfile.id,
          categoryId: cat.id,
          name: 'Bhuna Khichuri & Beef Kala Bhuna',
          description: 'Freshly cooked home batch with mustard-fried egg & achar.',
          priceBdt: 320,
          prepTimeMins: 30,
          isBestseller: true,
          availableTonight: true,
          optionGroupsJson: [],
        },
        {
          merchantId: hkProfile.id,
          categoryId: cat.id,
          name: 'Rui Fish Curry & Plain Rice',
          description: 'Comfort home meal with lentil dal & green chili.',
          priceBdt: 240,
          prepTimeMins: 25,
          isBestseller: false,
          availableTonight: true,
          optionGroupsJson: [],
        },
      ],
    });
  }
}

if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('seed.ts')) {
  initPrisma()
    .then(() => runSeed())
    .then(() => {
      console.info('[2Bee Seed] Seed completed cleanly.');
      process.exit(0);
    })
    .catch((err) => {
      console.error('[2Bee Seed] Failed:', err);
      process.exit(1);
    });
}

