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

  // Reset menu items for demo restaurant to ensure rich images and options are seeded
  await prisma.menuCategory.deleteMany({ where: { merchantId: restProfile.id } });

  const cat = await prisma.menuCategory.create({
    data: { merchantId: restProfile.id, name: 'Kacchi & Platters', sortOrder: 1 },
  });
  await prisma.menuItem.createMany({
    data: [
      {
        merchantId: restProfile.id,
        categoryId: cat.id,
        name: 'Mutton Kacchi (Basmati)',
        description: 'Slow-cooked tender mutton with aged basmati rice, spiced potato, and dried plum.',
        priceBdt: 480,
        strikePriceBdt: 520,
        prepTimeMins: 20,
        imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800',
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
              { id: 'mutton', name: 'Extra Mutton Piece', extraBdt: 180 },
            ],
          },
        ],
      },
      {
        merchantId: restProfile.id,
        categoryId: cat.id,
        name: 'Beef Tehari Special',
        description: 'Old Dhaka style mustard-oil infused Chinigura rice with flavorful beef cubes.',
        priceBdt: 340,
        strikePriceBdt: 380,
        prepTimeMins: 18,
        imageUrl: 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800',
        isBestseller: true,
        optionGroupsJson: [
          {
            title: 'Portion Size',
            required: true,
            maxSelect: 1,
            options: [
              { id: 'reg', name: 'Regular Plate', extraBdt: 0 },
              { id: 'large', name: 'Large Platter', extraBdt: 120 },
            ],
          },
          {
            title: 'Sides & Drinks',
            required: false,
            maxSelect: 2,
            options: [
              { id: 'egg', name: 'Boiled Egg', extraBdt: 30 },
              { id: 'borhani', name: 'Shahi Borhani (250ml)', extraBdt: 80 },
            ],
          },
        ],
      },
      {
        merchantId: restProfile.id,
        categoryId: cat.id,
        name: 'Shahi Morog Polao',
        description: 'Golden spiced chicken roast with traditional aromatic ghee bhat, beresta & egg.',
        priceBdt: 390,
        strikePriceBdt: 420,
        prepTimeMins: 22,
        imageUrl: 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=800',
        isBestseller: false,
        optionGroupsJson: [
          {
            title: 'Spice Preference',
            required: true,
            maxSelect: 1,
            options: [
              { id: 'mild', name: 'Mild Traditional', extraBdt: 0 },
              { id: 'spicy', name: 'Rich Spiced Roast', extraBdt: 0 },
            ],
          },
          {
            title: 'Extras',
            required: false,
            maxSelect: 2,
            options: [
              { id: 'roast', name: 'Extra Roast Quarter', extraBdt: 160 },
              { id: 'borhani', name: 'Borhani', extraBdt: 80 },
            ],
          },
        ],
      },
      {
        merchantId: restProfile.id,
        categoryId: cat.id,
        name: 'Shahi Firni & Borhani Pack',
        description: 'Traditional clay matka firni garnished with saffron, pistachio and chilled borhani.',
        priceBdt: 160,
        prepTimeMins: 10,
        imageUrl: 'https://images.unsplash.com/photo-1541832676-9b763b0239ab?w=800',
        isBestseller: false,
        optionGroupsJson: [],
      },
    ],
  });

  if ((await prisma.promotion.count({ where: { merchantId: restProfile.id } })) === 0) {
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

  // Reset menu items for demo home kitchen
  await prisma.menuCategory.deleteMany({ where: { merchantId: hkProfile.id } });

  const hkCat = await prisma.menuCategory.create({
    data: { merchantId: hkProfile.id, name: "Tonight's Home Batch", sortOrder: 1 },
  });
  await prisma.menuItem.createMany({
    data: [
      {
        merchantId: hkProfile.id,
        categoryId: hkCat.id,
        name: 'Bhuna Khichuri & Beef Kala Bhuna',
        description: 'Freshly cooked home batch with mustard-fried egg, traditional achar, and thick dal.',
        priceBdt: 320,
        strikePriceBdt: 360,
        prepTimeMins: 30,
        imageUrl: 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=800',
        isBestseller: true,
        availableTonight: true,
        optionGroupsJson: [
          {
            title: 'Spice Level',
            required: true,
            maxSelect: 1,
            options: [
              { id: 'medium', name: 'Medium Traditional Spice', extraBdt: 0 },
              { id: 'spicy', name: 'Extra Jhal Kala Bhuna', extraBdt: 0 },
            ],
          },
          {
            title: 'Add-ons & Sides',
            required: false,
            maxSelect: 2,
            options: [
              { id: 'egg', name: 'Mustard Fried Egg', extraBdt: 35 },
              { id: 'achar', name: 'Extra Mango Achar', extraBdt: 25 },
            ],
          },
        ],
      },
      {
        merchantId: hkProfile.id,
        categoryId: hkCat.id,
        name: 'Rui Fish Curry & Plain Rice',
        description: 'Comfort Bengali home meal cooked with fresh Rui fish, potato, potol, and lentil dal.',
        priceBdt: 240,
        prepTimeMins: 25,
        imageUrl: 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=800',
        isBestseller: false,
        availableTonight: true,
        optionGroupsJson: [
          {
            title: 'Fish Cut Choice',
            required: true,
            maxSelect: 1,
            options: [
              { id: 'peti', name: 'Peti Cut (Tender Belly)', extraBdt: 20 },
              { id: 'gada', name: 'Gada Cut (Center Piece)', extraBdt: 0 },
            ],
          },
          {
            title: 'Sides',
            required: false,
            maxSelect: 2,
            options: [
              { id: 'dal', name: 'Thick Masoor Dal', extraBdt: 30 },
              { id: 'begun', name: 'Fried Eggplant (Begun Bhaja)', extraBdt: 40 },
            ],
          },
        ],
      },
      {
        merchantId: hkProfile.id,
        categoryId: hkCat.id,
        name: 'Chitol Macher Muitha',
        description: 'Hand-beaten boneless fish dumpling curry made from fresh local river Chitol.',
        priceBdt: 380,
        strikePriceBdt: 420,
        prepTimeMins: 35,
        imageUrl: 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=800',
        isBestseller: true,
        availableTonight: true,
        optionGroupsJson: [],
      },
      {
        merchantId: hkProfile.id,
        categoryId: hkCat.id,
        name: 'Panchmishali Sobji & Hand Roti',
        description: 'Wholesome mixed seasonal vegetables cooked home-style with 4 soft atta rotis.',
        priceBdt: 180,
        prepTimeMins: 20,
        imageUrl: 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
        isBestseller: false,
        availableTonight: true,
        optionGroupsJson: [],
      },
    ],
  });
}

if (process.argv[1]?.includes('seed')) {
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

