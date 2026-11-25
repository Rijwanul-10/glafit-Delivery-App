-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('CLIENT', 'RIDER', 'MERCHANT');

-- CreateEnum
CREATE TYPE "KycStatus" AS ENUM ('DRAFT', 'PENDING', 'NEEDS_CHANGES', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "MerchantType" AS ENUM ('PHYSICAL', 'HOME_KITCHEN');

-- CreateEnum
CREATE TYPE "VehicleOwnership" AS ENUM ('OWN', 'RENTAL');

-- CreateEnum
CREATE TYPE "PowertrainType" AS ENUM ('PETROL', 'ELECTRIC');

-- CreateEnum
CREATE TYPE "RentalPlanType" AS ENUM ('DAILY', 'WEEKLY', 'RENT_TO_OWN');

-- CreateEnum
CREATE TYPE "PaymentMethodType" AS ENUM ('COD', 'STRIPE_SANDBOX', 'WALLET');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED');

-- CreateEnum
CREATE TYPE "ServiceType" AS ENUM ('FOOD', 'PARCEL', 'RIDE');

-- CreateEnum
CREATE TYPE "ParcelTier" AS ENUM ('NORMAL_ECO', 'NEXT_DAY', 'EXPRESS');

-- CreateEnum
CREATE TYPE "FoodOrderStatus" AS ENUM ('PLACED', 'ACCEPTED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'DELIVERED', 'REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "RideStatus" AS ENUM ('MATCHING', 'RIDER_ASSIGNED', 'ARRIVED_PICKUP', 'ON_TRIP', 'COMPLETED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ParcelStatus" AS ENUM ('BOOKED', 'MATCHING', 'RIDER_ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED', 'RETURNED');

-- CreateEnum
CREATE TYPE "MultiServiceStatus" AS ENUM ('PARCEL_ACTIVE', 'PASSENGER_PICKUP_PENDING', 'PASSENGER_ONBOARD', 'PASSENGER_DROPPED', 'COMPLETED', 'CANCELLED');

-- CreateTable
CREATE TABLE "Zone" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "city" TEXT NOT NULL DEFAULT 'Dhaka',
    "centerLat" DOUBLE PRECISION NOT NULL,
    "centerLng" DOUBLE PRECISION NOT NULL,
    "radiusKm" DOUBLE PRECISION NOT NULL DEFAULT 3.5,
    "h3BaseIndex" TEXT,
    "rateBonusBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Zone_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "fullName" TEXT NOT NULL DEFAULT '2Bee User',
    "email" TEXT,
    "avatarUrl" TEXT,
    "activeRole" "UserRole" NOT NULL DEFAULT 'CLIENT',
    "lastActiveAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OtpChallenge" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "purpose" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "consumedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "OtpChallenge_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RiderProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "kycStatus" "KycStatus" NOT NULL DEFAULT 'PENDING',
    "kycNotesJson" JSONB,
    "passcodeHash" TEXT NOT NULL,
    "biometricEnabled" BOOLEAN NOT NULL DEFAULT false,
    "dob" TEXT,
    "gender" TEXT,
    "preferredZoneId" TEXT,
    "emergencyName" TEXT,
    "emergencyRelation" TEXT,
    "emergencyPhone" TEXT,
    "nidNumber" TEXT NOT NULL,
    "licenseNumber" TEXT,
    "licenseExpiry" TEXT,
    "vehicleOwnership" "VehicleOwnership" NOT NULL DEFAULT 'OWN',
    "powertrain" "PowertrainType" NOT NULL DEFAULT 'PETROL',
    "vehicleBrandModel" TEXT,
    "plateNo" TEXT,
    "frontCarrierVerified" BOOLEAN NOT NULL DEFAULT false,
    "frontCarrierLengthCm" DOUBLE PRECISION DEFAULT 35,
    "frontCarrierWidthCm" DOUBLE PRECISION DEFAULT 30,
    "frontCarrierHeightCm" DOUBLE PRECISION DEFAULT 30,
    "frontCarrierMaxKg" DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    "rearCarrierVerified" BOOLEAN NOT NULL DEFAULT false,
    "rearCarrierMaxKg" DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    "multiServiceEnabled" BOOLEAN NOT NULL DEFAULT false,
    "spareHelmetConfirmed" BOOLEAN NOT NULL DEFAULT false,
    "isOnline" BOOLEAN NOT NULL DEFAULT false,
    "activeServicesJson" JSONB NOT NULL DEFAULT '{"food":true,"parcel":true,"ride":true}',
    "currentLat" DOUBLE PRECISION,
    "currentLng" DOUBLE PRECISION,
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 4.9,
    "acceptanceRate" DOUBLE PRECISION NOT NULL DEFAULT 98.4,
    "completionRate" DOUBLE PRECISION NOT NULL DEFAULT 99.1,
    "totalTrips" INTEGER NOT NULL DEFAULT 0,
    "approvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RiderProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantProfile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "merchantType" "MerchantType" NOT NULL DEFAULT 'PHYSICAL',
    "kycStatus" "KycStatus" NOT NULL DEFAULT 'PENDING',
    "kycNotesJson" JSONB,
    "passcodeHash" TEXT,
    "passcodeSet" BOOLEAN NOT NULL DEFAULT false,
    "biometricEnabled" BOOLEAN NOT NULL DEFAULT false,
    "businessName" TEXT NOT NULL,
    "ownerOrCookName" TEXT NOT NULL,
    "cuisinesJson" JSONB NOT NULL DEFAULT '[]',
    "address" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL DEFAULT 23.7937,
    "lng" DOUBLE PRECISION NOT NULL DEFAULT 90.4066,
    "areaZoneId" TEXT NOT NULL,
    "contactPhone" TEXT NOT NULL,
    "contactEmail" TEXT,
    "eTin" TEXT,
    "tradeLicenseNo" TEXT,
    "nidNumber" TEXT NOT NULL,
    "fbPageUrl" TEXT,
    "fbVerifyToken" TEXT,
    "hoursJson" JSONB NOT NULL DEFAULT '{}',
    "avgPrepMins" INTEGER NOT NULL DEFAULT 25,
    "dailyOrderLimit" INTEGER DEFAULT 15,
    "dailyCutoffTime" TEXT DEFAULT '20:00',
    "hygieneConfirmed" BOOLEAN NOT NULL DEFAULT false,
    "hygieneScore" DOUBLE PRECISION NOT NULL DEFAULT 4.9,
    "isStoreOpen" BOOLEAN NOT NULL DEFAULT false,
    "pausedUntil" TIMESTAMP(3),
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 4.8,
    "reviewCount" INTEGER NOT NULL DEFAULT 0,
    "coverImageUrl" TEXT,
    "deliveryFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 45,
    "minOrderBdt" DOUBLE PRECISION NOT NULL DEFAULT 150,
    "approvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MerchantProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MerchantStaff" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "roleLabel" TEXT NOT NULL DEFAULT 'Kitchen Manager',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MerchantStaff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "VerificationDocument" (
    "id" TEXT NOT NULL,
    "ownerRole" "UserRole" NOT NULL,
    "ownerId" TEXT NOT NULL,
    "docType" TEXT NOT NULL,
    "fileUrl" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "rejectionReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VerificationDocument_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PayoutAccount" (
    "id" TEXT NOT NULL,
    "ownerRole" "UserRole" NOT NULL,
    "ownerId" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "walletAccountType" TEXT NOT NULL DEFAULT 'PERSONAL',
    "accountNumber" TEXT NOT NULL,
    "holderName" TEXT NOT NULL,
    "instantCashoutOn" BOOLEAN NOT NULL DEFAULT true,
    "pendingPayloadJson" JSONB,
    "pendingEffectiveAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PayoutAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ActiveDevice" (
    "id" TEXT NOT NULL,
    "ownerRole" "UserRole" NOT NULL,
    "ownerId" TEXT NOT NULL,
    "deviceName" TEXT NOT NULL,
    "deviceKey" TEXT NOT NULL,
    "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ActiveDevice_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FleetBike" (
    "id" TEXT NOT NULL,
    "modelName" TEXT NOT NULL,
    "hubName" TEXT NOT NULL,
    "powertrain" TEXT NOT NULL DEFAULT 'ELECTRIC',
    "rangeKm" INTEGER NOT NULL DEFAULT 60,
    "dailyRateBdt" DOUBLE PRECISION NOT NULL DEFAULT 250,
    "weeklyRateBdt" DOUBLE PRECISION NOT NULL DEFAULT 1500,
    "availableQty" INTEGER NOT NULL DEFAULT 5,
    "frontMaxKg" DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    "rearMaxKg" DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    "rating" DOUBLE PRECISION NOT NULL DEFAULT 4.9,
    "imageUrl" TEXT,

    CONSTRAINT "FleetBike_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BikeRental" (
    "id" TEXT NOT NULL,
    "riderId" TEXT NOT NULL,
    "bikeId" TEXT NOT NULL,
    "bikeModel" TEXT NOT NULL,
    "plateNo" TEXT NOT NULL,
    "hubName" TEXT NOT NULL,
    "planType" "RentalPlanType" NOT NULL DEFAULT 'DAILY',
    "dailyRateBdt" DOUBLE PRECISION NOT NULL DEFAULT 250,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "dayIndex" INTEGER NOT NULL DEFAULT 1,
    "totalDays" INTEGER NOT NULL DEFAULT 7,
    "nextDebitAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "BikeRental_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MenuCategory" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "MenuCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MenuItem" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "priceBdt" DOUBLE PRECISION NOT NULL,
    "strikePriceBdt" DOUBLE PRECISION,
    "prepTimeMins" INTEGER NOT NULL DEFAULT 15,
    "imageUrl" TEXT,
    "isBestseller" BOOLEAN NOT NULL DEFAULT false,
    "inStock" BOOLEAN NOT NULL DEFAULT true,
    "availableTonight" BOOLEAN NOT NULL DEFAULT true,
    "dailyStockCap" INTEGER,
    "optionGroupsJson" JSONB NOT NULL DEFAULT '[]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MenuItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Promotion" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "promoCode" TEXT NOT NULL,
    "discountType" TEXT NOT NULL,
    "discountValue" DOUBLE PRECISION NOT NULL,
    "minOrderBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "startsAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Promotion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Review" (
    "id" TEXT NOT NULL,
    "merchantId" TEXT,
    "userId" TEXT NOT NULL,
    "serviceType" "ServiceType" NOT NULL,
    "orderId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "riderRating" INTEGER,
    "tagsJson" JSONB NOT NULL DEFAULT '[]',
    "comment" TEXT,
    "merchantReply" TEXT,
    "repliedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Review_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SavedAddress" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "zoneId" TEXT NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SavedAddress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FavoriteEntry" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FavoriteEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FoodOrder" (
    "id" TEXT NOT NULL,
    "orderCode" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "merchantId" TEXT NOT NULL,
    "riderId" TEXT,
    "status" "FoodOrderStatus" NOT NULL DEFAULT 'PLACED',
    "paymentMethod" "PaymentMethodType" NOT NULL DEFAULT 'COD',
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "stripeIntentId" TEXT,
    "deliveryAddress" TEXT NOT NULL,
    "deliveryZoneId" TEXT NOT NULL,
    "deliveryLat" DOUBLE PRECISION NOT NULL,
    "deliveryLng" DOUBLE PRECISION NOT NULL,
    "scheduleMode" TEXT NOT NULL DEFAULT 'NOW',
    "scheduledFor" TIMESTAMP(3),
    "cookingNote" TEXT,
    "riderNote" TEXT,
    "promoCode" TEXT,
    "subtotalBdt" DOUBLE PRECISION NOT NULL,
    "deliveryFeeBdt" DOUBLE PRECISION NOT NULL,
    "packagingFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 15,
    "serviceFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "discountBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "commissionBdt" DOUBLE PRECISION NOT NULL,
    "totalBdt" DOUBLE PRECISION NOT NULL,
    "riderPayoutBdt" DOUBLE PRECISION NOT NULL DEFAULT 85,
    "prepTimeMins" INTEGER NOT NULL DEFAULT 20,
    "rejectReason" TEXT,
    "acceptExpiresAt" TIMESTAMP(3),
    "deliveryPin" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FoodOrder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FoodOrderItem" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "menuItemId" TEXT NOT NULL,
    "itemName" TEXT NOT NULL,
    "unitPriceBdt" DOUBLE PRECISION NOT NULL,
    "quantity" INTEGER NOT NULL,
    "selectedOptionsJson" JSONB NOT NULL DEFAULT '[]',
    "lineTotalBdt" DOUBLE PRECISION NOT NULL,

    CONSTRAINT "FoodOrderItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RideTrip" (
    "id" TEXT NOT NULL,
    "tripCode" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "riderId" TEXT,
    "fleetTier" TEXT NOT NULL,
    "pickupAddress" TEXT NOT NULL,
    "pickupZoneId" TEXT NOT NULL,
    "pickupLat" DOUBLE PRECISION NOT NULL,
    "pickupLng" DOUBLE PRECISION NOT NULL,
    "dropoffAddress" TEXT NOT NULL,
    "dropoffZoneId" TEXT NOT NULL,
    "dropoffLat" DOUBLE PRECISION NOT NULL,
    "dropoffLng" DOUBLE PRECISION NOT NULL,
    "distanceKm" DOUBLE PRECISION NOT NULL,
    "etaMins" INTEGER NOT NULL,
    "status" "RideStatus" NOT NULL DEFAULT 'MATCHING',
    "paymentMethod" "PaymentMethodType" NOT NULL DEFAULT 'COD',
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "stripeIntentId" TEXT,
    "promoCode" TEXT,
    "baseFareBdt" DOUBLE PRECISION NOT NULL,
    "distanceFareBdt" DOUBLE PRECISION NOT NULL,
    "discountBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "totalFareBdt" DOUBLE PRECISION NOT NULL,
    "riderPayoutBdt" DOUBLE PRECISION NOT NULL,
    "startPin" TEXT NOT NULL,
    "tipBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rating" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RideTrip_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ParcelShipment" (
    "id" TEXT NOT NULL,
    "trackingCode" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "riderId" TEXT,
    "tier" "ParcelTier" NOT NULL DEFAULT 'NORMAL_ECO',
    "packageSizeClass" TEXT NOT NULL DEFAULT 'MEDIUM',
    "category" TEXT NOT NULL,
    "weightKg" DOUBLE PRECISION NOT NULL,
    "lengthCm" DOUBLE PRECISION NOT NULL DEFAULT 30,
    "widthCm" DOUBLE PRECISION NOT NULL DEFAULT 20,
    "heightCm" DOUBLE PRECISION NOT NULL DEFAULT 15,
    "volumeCm3" DOUBLE PRECISION NOT NULL DEFAULT 9000,
    "declaredValueBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "isProtected" BOOLEAN NOT NULL DEFAULT false,
    "protectionFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "handlingNote" TEXT,
    "senderName" TEXT NOT NULL,
    "senderPhone" TEXT NOT NULL,
    "pickupAddress" TEXT NOT NULL,
    "originZoneId" TEXT NOT NULL,
    "pickupLat" DOUBLE PRECISION NOT NULL,
    "pickupLng" DOUBLE PRECISION NOT NULL,
    "recipientName" TEXT NOT NULL,
    "recipientPhone" TEXT NOT NULL,
    "dropoffAddress" TEXT NOT NULL,
    "destinationZoneId" TEXT NOT NULL,
    "dropoffLat" DOUBLE PRECISION NOT NULL,
    "dropoffLng" DOUBLE PRECISION NOT NULL,
    "distanceKm" DOUBLE PRECISION NOT NULL,
    "status" "ParcelStatus" NOT NULL DEFAULT 'BOOKED',
    "paymentMethod" "PaymentMethodType" NOT NULL DEFAULT 'COD',
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
    "stripeIntentId" TEXT,
    "deliveryChargeBdt" DOUBLE PRECISION NOT NULL,
    "codCollectBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "riderPayoutBdt" DOUBLE PRECISION NOT NULL,
    "deliveryPin" TEXT NOT NULL,
    "pickupPhotoUrl" TEXT,
    "deliveryPhotoUrl" TEXT,
    "fitsFrontCarrier" BOOLEAN NOT NULL DEFAULT false,
    "tipBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "rating" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ParcelShipment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MultiServiceBatch" (
    "id" TEXT NOT NULL,
    "batchCode" TEXT NOT NULL,
    "riderId" TEXT NOT NULL,
    "parcelShipmentId" TEXT NOT NULL,
    "rideTripId" TEXT NOT NULL,
    "originZoneId" TEXT NOT NULL,
    "destinationZoneId" TEXT NOT NULL,
    "status" "MultiServiceStatus" NOT NULL DEFAULT 'PASSENGER_PICKUP_PENDING',
    "passengerDroppedAt" TIMESTAMP(3),
    "parcelDeliveredAt" TIMESTAMP(3),
    "helmetReturnedOk" BOOLEAN NOT NULL DEFAULT false,
    "curbDismountOk" BOOLEAN NOT NULL DEFAULT false,
    "totalPayoutBdt" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MultiServiceBatch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WalletAccount" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "balanceBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "pendingHoldBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "codCashInHandBdt" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WalletAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WalletTransaction" (
    "id" TEXT NOT NULL,
    "walletId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "amountBdt" DOUBLE PRECISION NOT NULL,
    "referenceCode" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'SETTLED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WalletTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CodLedger" (
    "id" TEXT NOT NULL,
    "riderId" TEXT NOT NULL,
    "serviceType" "ServiceType" NOT NULL,
    "orderId" TEXT NOT NULL,
    "cashCollectedBdt" DOUBLE PRECISION NOT NULL,
    "settled" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CodLedger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatThread" (
    "id" TEXT NOT NULL,
    "serviceType" "ServiceType" NOT NULL,
    "orderId" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "riderId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChatThread_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ChatMessage" (
    "id" TEXT NOT NULL,
    "threadId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "senderRole" "UserRole" NOT NULL,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ChatMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationItem" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "category" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "actionRoute" TEXT,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotificationItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SosIncident" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "orderId" TEXT,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SosIncident_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "actorRole" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "metaJson" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AppPricingConfig" (
    "id" TEXT NOT NULL DEFAULT 'default',
    "foodCommissionRate" DOUBLE PRECISION NOT NULL DEFAULT 0.15,
    "foodDeliveryFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 45,
    "foodPackagingFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 15,
    "foodServiceFeeBdt" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "rideBaseFareSoloBdt" DOUBLE PRECISION NOT NULL DEFAULT 40,
    "ridePerKmSoloBdt" DOUBLE PRECISION NOT NULL DEFAULT 18,
    "rideMinFareSoloBdt" DOUBLE PRECISION NOT NULL DEFAULT 85,
    "parcelNormalBaseBdt" DOUBLE PRECISION NOT NULL DEFAULT 60,
    "parcelExpressBaseBdt" DOUBLE PRECISION NOT NULL DEFAULT 110,
    "parcelProtectionBdt" DOUBLE PRECISION NOT NULL DEFAULT 15,
    "parcelFrontMaxKg" DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    "parcelFrontMaxVolCm3" DOUBLE PRECISION NOT NULL DEFAULT 31500,
    "payoutScheduleLabel" TEXT NOT NULL DEFAULT 'Every Friday at 12:00 AM GMT+6',
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AppPricingConfig_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DevicePushToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "role" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DevicePushToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Zone_name_key" ON "Zone"("name");

-- CreateIndex
CREATE UNIQUE INDEX "User_phone_key" ON "User"("phone");

-- CreateIndex
CREATE INDEX "OtpChallenge_phone_purpose_idx" ON "OtpChallenge"("phone", "purpose");

-- CreateIndex
CREATE UNIQUE INDEX "RiderProfile_userId_key" ON "RiderProfile"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "MerchantProfile_userId_key" ON "MerchantProfile"("userId");

-- CreateIndex
CREATE INDEX "VerificationDocument_ownerRole_ownerId_idx" ON "VerificationDocument"("ownerRole", "ownerId");

-- CreateIndex
CREATE UNIQUE INDEX "PayoutAccount_ownerRole_ownerId_key" ON "PayoutAccount"("ownerRole", "ownerId");

-- CreateIndex
CREATE INDEX "ActiveDevice_ownerRole_ownerId_idx" ON "ActiveDevice"("ownerRole", "ownerId");

-- CreateIndex
CREATE UNIQUE INDEX "FavoriteEntry_userId_targetType_targetId_key" ON "FavoriteEntry"("userId", "targetType", "targetId");

-- CreateIndex
CREATE UNIQUE INDEX "FoodOrder_orderCode_key" ON "FoodOrder"("orderCode");

-- CreateIndex
CREATE UNIQUE INDEX "RideTrip_tripCode_key" ON "RideTrip"("tripCode");

-- CreateIndex
CREATE UNIQUE INDEX "ParcelShipment_trackingCode_key" ON "ParcelShipment"("trackingCode");

-- CreateIndex
CREATE UNIQUE INDEX "MultiServiceBatch_batchCode_key" ON "MultiServiceBatch"("batchCode");

-- CreateIndex
CREATE UNIQUE INDEX "MultiServiceBatch_parcelShipmentId_key" ON "MultiServiceBatch"("parcelShipmentId");

-- CreateIndex
CREATE UNIQUE INDEX "MultiServiceBatch_rideTripId_key" ON "MultiServiceBatch"("rideTripId");

-- CreateIndex
CREATE UNIQUE INDEX "WalletAccount_userId_role_key" ON "WalletAccount"("userId", "role");

-- CreateIndex
CREATE UNIQUE INDEX "ChatThread_orderId_key" ON "ChatThread"("orderId");

-- CreateIndex
CREATE UNIQUE INDEX "DevicePushToken_token_key" ON "DevicePushToken"("token");

-- CreateIndex
CREATE INDEX "DevicePushToken_userId_role_idx" ON "DevicePushToken"("userId", "role");

-- AddForeignKey
ALTER TABLE "RiderProfile" ADD CONSTRAINT "RiderProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantProfile" ADD CONSTRAINT "MerchantProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MerchantStaff" ADD CONSTRAINT "MerchantStaff_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BikeRental" ADD CONSTRAINT "BikeRental_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MenuCategory" ADD CONSTRAINT "MenuCategory_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MenuItem" ADD CONSTRAINT "MenuItem_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MenuItem" ADD CONSTRAINT "MenuItem_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "MenuCategory"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Promotion" ADD CONSTRAINT "Promotion_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Review" ADD CONSTRAINT "Review_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SavedAddress" ADD CONSTRAINT "SavedAddress_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FavoriteEntry" ADD CONSTRAINT "FavoriteEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FoodOrder" ADD CONSTRAINT "FoodOrder_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FoodOrder" ADD CONSTRAINT "FoodOrder_merchantId_fkey" FOREIGN KEY ("merchantId") REFERENCES "MerchantProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FoodOrder" ADD CONSTRAINT "FoodOrder_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FoodOrderItem" ADD CONSTRAINT "FoodOrderItem_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "FoodOrder"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RideTrip" ADD CONSTRAINT "RideTrip_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RideTrip" ADD CONSTRAINT "RideTrip_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ParcelShipment" ADD CONSTRAINT "ParcelShipment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ParcelShipment" ADD CONSTRAINT "ParcelShipment_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiServiceBatch" ADD CONSTRAINT "MultiServiceBatch_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiServiceBatch" ADD CONSTRAINT "MultiServiceBatch_parcelShipmentId_fkey" FOREIGN KEY ("parcelShipmentId") REFERENCES "ParcelShipment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MultiServiceBatch" ADD CONSTRAINT "MultiServiceBatch_rideTripId_fkey" FOREIGN KEY ("rideTripId") REFERENCES "RideTrip"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WalletAccount" ADD CONSTRAINT "WalletAccount_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WalletTransaction" ADD CONSTRAINT "WalletTransaction_walletId_fkey" FOREIGN KEY ("walletId") REFERENCES "WalletAccount"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CodLedger" ADD CONSTRAINT "CodLedger_riderId_fkey" FOREIGN KEY ("riderId") REFERENCES "RiderProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_threadId_fkey" FOREIGN KEY ("threadId") REFERENCES "ChatThread"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationItem" ADD CONSTRAINT "NotificationItem_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SosIncident" ADD CONSTRAINT "SosIncident_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
