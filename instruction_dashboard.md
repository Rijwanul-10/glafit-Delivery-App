# 2Bee Super-App — Admin Control Dashboard & Firebase Integration Guide (`instruction.md`)

> **Target Audience:** Engineering Teammate building the **2Bee Admin Control Dashboard** & **Firebase Production Connections**  
> **Scope:** Full app control (Client · Rider · Physical Restaurant · Home Kitchen · EV Fleet · Finance/COD · Pricing/Zones · SOS Safety), All Reports & Exports, Firebase Integration, and Free-Tier Cloud Deployment.

---

## 1. System Architecture & Repository Context

The 2Bee Super-App currently consists of:
- **`backend/`**: Node.js + TypeScript + Express + Prisma (`PostgreSQL` / local `pglite`) + Socket.IO + `pdfkit` + Stripe Sandbox + OSM/OSRM.
- **`mobile/`**: Flutter Material 3 + Riverpod + GoRouter multi-role app (`Client`, `Rider`, `Merchant` Physical & Home Kitchen).
- **`docs/`**: Reference specifications (`docs/analysis.md`, `docs/integrations.md`).
- **`admin/` *(To Be Created)*:** The Web Admin Control Dashboard.

### Core Golden Rules
1. **API-First Control (Never Connect Browser Directly to Postgres):** The Admin Dashboard (`admin/`) MUST communicate exclusively with the Express backend (`/api/v1/admin/*`) and authenticated Socket.IO rooms. Never embed PostgreSQL connection strings or `x-admin-secret` in frontend browser code.
2. **Zero-Cost Free-Tier Architecture:** Every cloud component must run on free-tier infrastructure (see **Section 8**).
3. **Preserve 2Bee Business Rules:**
   - **Rider Auth:** Creates a **4-digit passcode** during registration Step 8.
   - **Merchant Auth (Critical):** Sets **NO passcode during registration**. After Admin approves KYC (`APPROVED`), the merchant logs in via OTP and is forced to set a **6-digit passcode** (`passcodeSet = true`) before unlocking the live Merchant Panel.
   - **Multi-Service Isolation:** Only `NORMAL_ECO` parcels fitting the front carrier (`<= 8 kg`, `<= 31,500 cm³`) can pair with a Zone A → Zone B Ride (`MultiServiceBatch`). Client tracking must remain strictly isolated; only Riders and Admins see paired batch legs.
   - **48-Hour Payout Guard:** Changes to `PayoutAccount` (`BKASH`, `NAGAD`, `ROCKET`, `BANK_BEFTN`) trigger a 48-hour hold (`pendingPayloadJson` + `pendingEffectiveAt`).

---

## 2. Recommended Tech Stack & Brand Design Tokens

### Admin Dashboard Stack (Free Hosting Friendly)
- **Framework:** Next.js (App Router, TypeScript) or React + Vite (TypeScript)
- **Styling & Components:** Tailwind CSS + shadcn/ui + Lucide Icons
- **Data Tables & Charts:** TanStack Table (`@tanstack/react-table`) + Recharts
- **Maps (100% Free, No API Key):** Leaflet (`react-leaflet`) with OpenStreetMap / CartoDB Voyager light tiles
- **Real-Time Updates:** `socket.io-client`
- **Firebase Auth & Web Push:** `firebase` (Web SDK v10+)
- **Deployment:** Vercel or Cloudflare Pages (Free Tier)

### 2Bee Brand Theme Tokens (Matched to `mobile/lib/core/theme/twobee_theme.dart`)
- **Primary Emerald:** `#00C853` (`primaryDark`: `#007A33`, `primaryAccent`: `#00A844`)
- **Sidebar / Dark Surface (Obsidian):** `#0E1310` (`obsidianCard`: `#171F1B`)
- **Page Background:** `#F6F8F7`
- **Card Surface:** `#FFFFFF` (`surfaceTonal`: `#EDF4F0`, `borderSoft`: `#E2EBE5`)
- **Typography Colors:** Primary `#0A110D`, Secondary `#334155`, Muted `#64748B`
- **Status Colors:** Warning `#9A5B00` on `#FCF8E0`; Error `#E53935` on `#FCD8D4`; Success `#007A33` on `#EDF4F0`

---

## 3. Firebase Connection Blueprint (Backend + Admin + Mobile)

Currently, `backend/.env` only has `FCM_ENABLED=false` and `firebase-admin` is **not yet installed** in `backend/` or `mobile/`. Follow these steps to wire Firebase completely on the **100% Free Firebase Spark Plan**.

### Step 3.1: Create & Register Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com) → **Create Project** (`twobee-prod`, Spark Free Plan).
2. Inside the project, register **3 apps**:
   - **Android App:** Package name `app.twobee.twobee_app` (from `mobile/android/app/build.gradle.kts`) → download `google-services.json` → place in `mobile/android/app/google-services.json`.
   - **iOS App:** Bundle ID `app.twobee.twobee_app` → download `GoogleService-Info.plist` → place in `mobile/ios/Runner/GoogleService-Info.plist`.
   - **Web App (`2Bee Admin & Web`):** Copy the `firebaseConfig` object (`apiKey`, `authDomain`, `projectId`, `storageBucket`, `messagingSenderId`, `appId`) and generate a **Web Push Certificate (VAPID Key)** under *Project Settings → Cloud Messaging*.
3. Enable **Authentication Providers**:
   - **Email/Password** (for Admin Dashboard login — **disable public sign-up**; create admin user accounts manually in Firebase Console or via script).
   - **Phone** (for real mobile OTPs: Firebase Spark Plan gives **10,000 free phone verifications/month** + free test phone numbers).
4. Generate **Service Account Credentials**:
   - *Project Settings → Service Accounts → Generate New Private Key* (JSON).

### Step 3.2: Backend Firebase Admin SDK Setup (`backend/`)
1. **Install dependency:**
   ```bash
   cd backend
   npm install firebase-admin
   ```
2. **Update `backend/.env`, `backend/.env.example`, and `backend/src/config/env.ts`:**
   `env.ts` does not currently export Firebase variables. Add:
   ```ts
   fcmEnabled: process.env.FCM_ENABLED === 'true',
   firebaseProjectId: process.env.FIREBASE_PROJECT_ID ?? '',
   firebaseClientEmail: process.env.FIREBASE_CLIENT_EMAIL ?? '',
   // Replace literal \n with real newlines for cloud hosts like Render/Railway
   firebasePrivateKey: (process.env.FIREBASE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'),
   adminEmails: (process.env.ADMIN_EMAILS ?? process.env.ADMIN_SEED_EMAIL ?? 'admin@2bee.app')
     .split(',')
     .map((e) => e.trim().toLowerCase())
     .filter(Boolean),
   ```
3. **Create `backend/src/services/firebaseService.ts`:**
   - Initialize `admin.initializeApp({ credential: admin.credential.cert(...) })` safely once when `firebaseProjectId`, `firebaseClientEmail`, and `firebasePrivateKey` are present.
   - Export helpers:
     - `verifyFirebaseIdToken(idToken: string)`: Verifies incoming Firebase Auth ID tokens (both Admin Email login and Mobile Phone Auth login).
     - `sendPushToTokens(tokens: string[], payload: { title: string; body: string; data?: Record<string, string>; channelId?: string })`: Uses `admin.messaging().sendEachForMulticast(...)` and automatically prunes invalid/unregistered tokens (`messaging/registration-token-not-registered`).
4. **Add Push Token Storage in `backend/prisma/schema.prisma`:**
   Add a `DevicePushToken` model (or `fcmToken String?` on `ActiveDevice` + an admin tokens table) and run `prisma migrate`:
   ```prisma
   model DevicePushToken {
     id        String   @id @default(cuid())
     userId    String?
     role      String   // CLIENT | RIDER | MERCHANT | ADMIN
     platform  String   // ANDROID | IOS | WEB
     token     String   @unique
     updatedAt DateTime @updatedAt
     createdAt DateTime @default(now())

     @@index([userId, role])
   }
   ```
5. **Wire FCM Dispatch Triggers in Backend Routes:**
   - **Food Order Created (`food.routes.ts`)**: Push to Merchant (`channelId: "merchant_orders_urgent"`, 60s alert).
   - **Ride / Parcel / Food Dispatch (`ride.routes.ts`, `parcel.routes.ts`, `rider.routes.ts`)**: Push to nearby Riders (`channelId: "rider_offers_urgent"`, 15s alert) and Multi-Service Ride Add-on pings.
   - **KYC Decision (`admin.routes.ts`)**: Push to Rider/Merchant on `APPROVED`, `NEEDS_CHANGES`, or `REJECTED`.
   - **SOS Incident (`common.routes.ts`)**: Push high-priority alert to all `ADMIN` web push tokens + emit `admin:sos:new` over Socket.IO.

### Step 3.3: Admin Dashboard Firebase Setup (`admin/`)
1. Install `firebase` in `admin/`:
   ```bash
   npm install firebase
   ```
2. Create `admin/src/lib/firebase.ts` initializing `initializeApp(firebaseConfig)`, `getAuth(app)`, and `getMessaging(app)` (for browser SOS push alerts).
3. **Admin Sign-In Flow (Zero Exposed Secrets):**
   - Teammate signs into Admin UI with Firebase `signInWithEmailAndPassword(auth, email, password)`.
   - Frontend retrieves `const idToken = await user.getIdToken()`.
   - Frontend calls `POST /api/v1/admin/auth/firebase` with `{ idToken }`.
   - Backend verifies `idToken` via `firebaseService.verifyFirebaseIdToken(idToken)`, confirms `decoded.email` is in `env.adminEmails` (or has custom claim `admin: true`), and issues a signed **Admin JWT** (`{ sub: decoded.uid, email: decoded.email, role: 'ADMIN' }`, expires in `8h`) signed with `env.jwtAccessSecret`.
   - All subsequent Admin API calls send `Authorization: Bearer <adminJwt>` — which **already matches** `requireAdmin` in `backend/src/middleware/auth.ts`!
   - Also keep `POST /api/v1/admin/auth/login` (email + `ADMIN_SEED_PASSWORD`) as a local dev fallback when Firebase is disabled.

### Step 3.4: Flutter Mobile Firebase Connection (`mobile/`)
1. Add dependencies to `mobile/pubspec.yaml`: `firebase_core`, `firebase_auth`, `firebase_messaging`, `flutter_local_notifications`.
2. Run `flutterfire configure` to generate `mobile/lib/firebase_options.dart`.
3. Register FCM token after OTP login (`POST /api/v1/common/fcm-token`) and handle foreground/background notifications.
4. For real production Phone OTP: Call `FirebaseAuth.instance.verifyPhoneNumber(...)`, verify SMS code to obtain Firebase `idToken`, and exchange at `POST /api/v1/auth/firebase-phone-login` on the backend (creating/fetching the `User` by verified `phone_number`). Keep `SMS_PROVIDER=mock` toggleable for local automated tests.

### Step 3.5: Media Storage Migration (Free Production Files)
Right now, `backend/src/routes/common.routes.ts` saves files to `./uploads`. **Cloud free hosts (Render/Koyeb) wipe local disk on restart.**
- **Free Solution:** Use **Cloudflare R2** (10 GB free, $0 egress) or **Supabase Storage** (1 GB free) or **Firebase Storage** (5 GB free).
- **Privacy Requirement:** Public assets (restaurant covers, dish photos, avatars) can be public read URLs; **sensitive KYC documents** (`NID_FRONT`, `NID_BACK`, `LICENSE_FRONT`, `LICENSE_BACK`, `SELFIE`, `TRADE_LICENSE`) and delivery proof photos must be stored in a private bucket/folder and accessed in the Admin Dashboard ONLY via **short-lived signed URLs** (`TTL = 300s`) generated by `GET /api/v1/admin/documents/:docId/signed-url` (which also records an `AuditLog` entry).

---

## 4. Existing Backend APIs vs. What Needs to Be Added

### 4.1 What Already Exists (`backend/src/routes/admin.routes.ts`)
Currently protected by `requireAdmin` (`x-admin-secret` header OR `Bearer <JWT>` with `role === 'ADMIN'`):
1. `GET /api/v1/admin/kyc/pending` — Returns `riders` and `merchants` with `kycStatus` in `['PENDING', 'NEEDS_CHANGES']`.
2. `POST /api/v1/admin/kyc/rider/:riderId/decision` — Body: `{ decision: 'APPROVED' | 'NEEDS_CHANGES' | 'REJECTED', frontCarrierVerified?, rearCarrierVerified?, notes?: Record<string, string> }`.
3. `POST /api/v1/admin/kyc/merchant/:merchantId/decision` — Body: `{ decision: 'APPROVED' | 'NEEDS_CHANGES' | 'REJECTED', notes?: Record<string, string> }`.

### 4.2 New Backend Endpoints to Build for Full App Control
Organize these cleanly under `/api/v1/admin/*` (modularize into `admin.auth.routes.ts`, `admin.operations.routes.ts`, `admin.finance.routes.ts`, `admin.reports.routes.ts` mounted on `adminRouter`):

#### A. Admin Auth & Real-Time Overview
- `POST /api/v1/admin/auth/firebase` — Exchanges verified Firebase ID token for Admin JWT (public route before `requireAdmin`).
- `POST /api/v1/admin/auth/login` — Local/fallback email+password login returning Admin JWT.
- `POST /api/v1/admin/fcm-token` — Registers Admin web push token in `DevicePushToken`.
- `GET /api/v1/admin/overview` — Real-time KPIs: today/month GMV, net commission, active food orders, active rides, active parcels, active multi-service batches, online riders count, open stores count, pending KYC count, active SOS count.
- `GET /api/v1/admin/live-radar` — Live online riders (lat/lng, active services, multi-service status from `geoMatchService` / `RiderProfile`), active trips/orders, and active `SosIncident` pins.

#### B. KYC & Document Inspection
- `GET /api/v1/admin/kyc/riders/:riderId` — Full rider profile + `VerificationDocument`s + `PayoutAccount` + `BikeRental`.
- `GET /api/v1/admin/kyc/merchants/:merchantId` — Full merchant profile + `VerificationDocument`s + `PayoutAccount` + `fbPageUrl` / `fbVerifyToken`.
- `GET /api/v1/admin/documents/:docId/signed-url` — Returns short-lived signed URL for private KYC document & creates an `AuditLog` record.
- `POST /api/v1/admin/kyc/documents/:docId/review` — Update individual document status (`APPROVED` | `NEEDS_CHANGES`) and `rejectionReason`.

#### C. Users, Riders & Merchants Management
- `GET /api/v1/admin/users` — Paginated search/filter by phone, name, `activeRole`.
- `GET /api/v1/admin/riders` — Filter by `kycStatus`, `isOnline`, `preferredZoneId`, `vehicleOwnership`, `multiServiceEnabled`.
- `PATCH /api/v1/admin/riders/:riderId` — Toggle `multiServiceEnabled`, `frontCarrierVerified`, `rearCarrierVerified`, force offline (`isOnline = false`), or suspend (`kycStatus = 'REJECTED'`).
- `DELETE /api/v1/admin/riders/:riderId/devices/:deviceId` — Force-revoke a rider's `ActiveDevice`.
- `GET /api/v1/admin/merchants` — Filter by `merchantType` (`PHYSICAL` | `HOME_KITCHEN`), `kycStatus`, `isStoreOpen`, `areaZoneId`.
- `PATCH /api/v1/admin/merchants/:merchantId` — Force open/close (`isStoreOpen`), adjust `dailyOrderLimit` / `dailyCutoffTime`, `deliveryFeeBdt`, `minOrderBdt`, `hygieneScore`, or suspend.
- `GET /api/v1/admin/merchants/:merchantId/menu` & `PATCH /api/v1/admin/menu-items/:itemId` — Moderate/disable `MenuItem` (`inStock`).

#### D. Dispatch & Order Control Center (All 4 Verticals)
- `GET /api/v1/admin/food-orders` & `GET /api/v1/admin/food-orders/:id`
- `PATCH /api/v1/admin/food-orders/:id/override` — Manual status change, assign/reassign `riderId`, or cancel & refund (`PaymentStatus = 'REFUNDED'`).
- `GET /api/v1/admin/rides` & `PATCH /api/v1/admin/rides/:id/override`
- `GET /api/v1/admin/parcels` & `PATCH /api/v1/admin/parcels/:id/override`
- `GET /api/v1/admin/multi-service-batches` & `PATCH /api/v1/admin/multi-service-batches/:id/override`
- `GET /api/v1/admin/chat/:serviceType/:orderId` — Read-only dispute inspection of `ChatThread` + `ChatMessage`s.

#### E. Pricing, Zones, Fleet & Promotions Control
- `GET /api/v1/admin/pricing` & `PATCH /api/v1/admin/pricing` — Read/update `AppPricingConfig` (`id: 'default'`) controlling `foodCommissionRate`, delivery/packaging/service fees, ride fares, parcel base & protection fees, front carrier `parcelFrontMaxKg` / `parcelFrontMaxVolCm3`, `payoutScheduleLabel`.
- `GET /api/v1/admin/zones`, `POST /api/v1/admin/zones`, `PATCH /api/v1/admin/zones/:id` — Manage Dhaka `Zone` records (`name`, `city`, `centerLat`, `centerLng`, `radiusKm`, `h3BaseIndex`, `rateBonusBdt`).
- `GET /api/v1/admin/promotions`, `POST /api/v1/admin/promotions`, `PATCH /api/v1/admin/promotions/:id` — Manage/toggle `Promotion` codes.
- `GET /api/v1/admin/fleet-bikes`, `POST /api/v1/admin/fleet-bikes`, `PATCH /api/v1/admin/fleet-bikes/:id` — Manage EV `FleetBike` inventory (`modelName`, `hubName`, `rangeKm`, `dailyRateBdt`, `weeklyRateBdt`, `availableQty`).
- `GET /api/v1/admin/bike-rentals` & `PATCH /api/v1/admin/bike-rentals/:id` — Approve `PENDING_HANDOVER → ACTIVE`, track `dayIndex`/`totalDays`, trigger or pause `RENTAL_DEDUCTION`.

#### F. Finance, Wallets, COD Reconciliation & Payout Guard
- `GET /api/v1/admin/wallets` — Search `WalletAccount`s (`balanceBdt`, `pendingHoldBdt`, `codCashInHandBdt`) across `CLIENT`, `RIDER`, `MERCHANT`.
- `POST /api/v1/admin/wallets/:walletId/adjust` — Credit/debit `WalletTransaction` (`BONUS`, `REFUND`, `COMMISSION`, `COD_OFFSET`) with mandatory audit reason.
- `GET /api/v1/admin/cod-ledger` — List unsettled `CodLedger` items grouped by rider.
- `POST /api/v1/admin/cod-ledger/settle` — Mark selected `CodLedger` IDs `settled: true`, decrement rider `codCashInHandBdt`, and create `WalletTransaction` (`COD_OFFSET`).
- `GET /api/v1/admin/payouts/pending-changes` — Monitor `PayoutAccount`s with active 48h `pendingEffectiveAt` holds; allow emergency cancel or force-apply.
- `GET /api/v1/admin/payouts/queue` & `POST /api/v1/admin/payouts/process-batch` — Execute scheduled payouts (`WITHDRAWAL` transactions) and download payout batch summary.

#### G. Safety (SOS), Reviews, Notifications & Audit Logs
- `GET /api/v1/admin/sos` & `PATCH /api/v1/admin/sos/:id` — List `SosIncident`s (`ACTIVE`, `INVESTIGATING`, `RESOLVED`) with user/order/GPS info and update resolution status.
- `GET /api/v1/admin/reviews` & `DELETE /api/v1/admin/reviews/:id` — Moderate abusive reviews.
- `POST /api/v1/admin/notifications/broadcast` — Create `NotificationItem` rows + dispatch FCM push by target role (`CLIENT`, `RIDER`, `MERCHANT`) or zone.
- `GET /api/v1/admin/audit-logs` — Paginated, filterable `AuditLog` viewer (`actorId`, `action`, `entityType`, `entityId`, date range). **Every Admin `POST`/`PATCH`/`DELETE` endpoint MUST write an `AuditLog` row.**

#### H. Socket.IO Admin Room (`backend/src/realtime/socketServer.ts`)
Update `socketServer.ts` so valid Admin JWTs can emit `join:admin` (verified via `jwt.verify` + `role === 'ADMIN'`) to receive live events:
- `admin:sos:new` (immediate alert + sound in Admin UI)
- `admin:kyc:submitted` (new Rider or Merchant KYC waiting)
- `admin:order:updated` (live status feeds for Food, Ride, Parcel, Multi-Service)
- `admin:rider:location` (throttled every 3–5s for the live map radar)

---

## 5. Admin Dashboard Pages & Control Specifications

Build the left navigation rail (`#0E1310` Obsidian) with the following **10 modules**:

| # | Page / Module | Core Controls & Data |
|---|---|---|
| **1** | **Dashboard Overview & Live Map** | KPI stat cards (Today Orders, GMV, Net Commission, Active Riders, Active SOS), 7-day revenue chart, and an interactive **Leaflet/OSM Live Radar Map** showing online riders, active deliveries/rides, and SOS pins. |
| **2** | **KYC Verification Center** | Tabs: **Riders** \| **Physical Restaurants** \| **Home Kitchens**. Slide-over detail drawer displaying user info, vehicle/carrier dimensions, `fbPageUrl` + `fbVerifyToken` verifier, signed image previews (`NID`, `License`, `Trade License`, `Selfie`, `Storefront`, `Kitchen`, `Dish Sample`, `Carrier`), per-document rejection inputs, and **Approve / Needs Changes / Reject** buttons. |
| **3** | **Orders & Dispatch Control** | Sub-tabs: **Food Orders** \| **Ride Trips** \| **Parcel Shipments** \| **Multi-Service Batches**. Filter by status, zone, payment method. Action drawer to inspect timeline, PINs, proof photos, chat logs (`ChatThread`), force status transitions, assign rider, or refund. |
| **4** | **Users, Riders & Merchants** | Searchable directories with detail pages. Manage Rider multi-service eligibility, active devices, and metrics (`rating`, `acceptanceRate`, `completionRate`). Manage Merchant store status (`isStoreOpen`), Home Kitchen daily limits/cutoffs, menus, and staff (`MerchantStaff`). |
| **5** | **Pricing, Zones & Promos** | Live form bound to `AppPricingConfig` (instant global fee & commission updates), CRUD table + map circle preview for Dhaka `Zone`s (including `rateBonusBdt` & `h3BaseIndex`), and `Promotion` code manager. |
| **6** | **EV Fleet & Bike Rentals** | Manage `FleetBike` catalog across hubs (`Banani Hub`, `Mohakhali Hub`, etc.), approve `BikeRental` handovers (`PENDING_HANDOVER → ACTIVE`), monitor `nextDebitAt` & overdue deductions. |
| **7** | **Finance, Wallets & COD** | Inspect `WalletAccount`s, settle rider `CodLedger` cash-in-hand deposits, process Friday payout batches, review 48-hour `PayoutAccount` change holds, and issue manual wallet credits/refunds. |
| **8** | **SOS Safety & Support** | Urgent alert banner + audio chime on new `SosIncident`, live map pin, emergency contact (`RiderProfile.emergencyPhone`), hotline triggers (`999` / `16216`), and resolution notes. |
| **9** | **Reports & Exports Hub** | Full reporting suite with date-range, zone, service-type, and merchant-type filters + **CSV**, **Excel (XLSX)**, and **PDF** download buttons (details in Section 6). |
| **10** | **Broadcasts, Reviews & Audit Log** | Send targeted Push/In-app announcements (`NotificationItem` + FCM), moderate `Review`s, and inspect immutable `AuditLog` history for admin accountability. |

---

## 6. Complete Reports & Analytics Specification

The teammate must implement backend aggregation endpoints (`GET /api/v1/admin/reports/:reportType?from=...&to=...&zoneId=...&format=json|csv|pdf`) and frontend report views covering **all 9 operational & financial reports**:

| # | Report Name | Key Metrics & Columns | Source Prisma Models | Exports |
|---|---|---|---|---|
| **1** | **Executive GMV & Net Revenue Report** | Total GMV, Platform Commission, Delivery/Service/Protection Fees, Discounts, Net Platform Revenue, Split by Vertical (`FOOD`, `RIDE`, `PARCEL`, `RENTAL`) & `PaymentMethodType` (`COD`, `STRIPE_SANDBOX`, `WALLET`). | `FoodOrder`, `RideTrip`, `ParcelShipment`, `BikeRental`, `WalletTransaction` | JSON, CSV, PDF |
| **2** | **Food Delivery & Merchant Settlement Report** | Orders placed/delivered/rejected/cancelled, `subtotalBdt`, `commissionBdt`, `deliveryFeeBdt`, `packagingFeeBdt`, `discountBdt`, Net Merchant Payout; broken down by `PHYSICAL` vs `HOME_KITCHEN` & Home Kitchen quota utilization vs `dailyOrderLimit`. | `FoodOrder`, `FoodOrderItem`, `MerchantProfile` | JSON, CSV, PDF |
| **3** | **Ride-Sharing & Multi-Service Report** | Total trips by `fleetTier`, avg `distanceKm`, avg `etaMins`, `baseFareBdt`, `distanceFareBdt`, `tipBdt`, `riderPayoutBdt`, cancellation rate, **Multi-Service attach rate** (`MultiServiceBatch` count vs eligible parcels), Zone A → Zone B corridor volume, and safety compliance (`helmetReturnedOk`, `curbDismountOk`). | `RideTrip`, `MultiServiceBatch`, `Zone` | JSON, CSV, PDF |
| **4** | **Parcel Logistics & Protection Report** | Shipments by `ParcelTier` (`NORMAL_ECO`, `NEXT_DAY`, `EXPRESS`) & `packageSizeClass`, `fitsFrontCarrier` rate, total weight (`weightKg`), `isProtected` uptake & `protectionFeeBdt` revenue, `codCollectBdt`, delivered vs `RETURNED` / `CANCELLED`. | `ParcelShipment` | JSON, CSV |
| **5** | **Rider Earnings, COD Liability & Fleet Rental Report** | Per-rider trip count, `WalletTransaction` breakdown (`EARNING`, `BONUS`, `RENTAL_DEDUCTION`, `WITHDRAWAL`, `COD_OFFSET`), unsettled `CodLedger` balance (`codCashInHandBdt`), `BikeRental` active days & rental revenue collected. | `RiderProfile`, `WalletAccount`, `WalletTransaction`, `CodLedger`, `BikeRental` | JSON, CSV, PDF |
| **6** | **Payouts & 48h Security Audit Report** | Weekly/instant payouts by provider (`BKASH`, `NAGAD`, `ROCKET`, `BANK_BEFTN`), settled vs failed withdrawals, pending 48-hour payout account modification holds (`PayoutAccount.pendingEffectiveAt`). | `WalletTransaction`, `PayoutAccount` | JSON, CSV |
| **7** | **KYC Onboarding & SLA Report** | Submissions by `KycStatus` (`PENDING`, `NEEDS_CHANGES`, `APPROVED`, `REJECTED`), average approval time (`approvedAt - createdAt`), top `VerificationDocument.rejectionReason` causes. | `RiderProfile`, `MerchantProfile`, `VerificationDocument` | JSON, CSV |
| **8** | **Promotions & Discount ROI Report** | Redemption count, total `discountBdt` subsidized, and GMV generated per `promoCode` across Food & Rides. | `Promotion`, `FoodOrder`, `RideTrip` | JSON, CSV |
| **9** | **Safety, SOS & Service Quality Report** | `SosIncident` count by zone/role/hour, mean time to resolution, average `Review.rating` & `riderRating`, flagged low-rated orders (`<= 2` stars). | `SosIncident`, `Review` | JSON, CSV, PDF |

### Export Implementation Guidance
- **CSV Export:** Stream UTF-8 CSV with BOM (`\uFEFF` so Excel renders `৳` BDT symbol cleanly!) directly from `/api/v1/admin/reports/:type?format=csv` with `Content-Type: text/csv; charset=utf-8` and `Content-Disposition: attachment`.
- **PDF Export:** Reuse/extend `backend/src/services/pdfService.ts` (`pdfkit`) with the `#092113` / `#00C853` 2Bee branded header to generate executive summary PDFs (`format=pdf`).

---

## 7. Security, Compliance & CORS Checklist

1. **Admin Route Protection:**
   - All `/api/v1/admin/*` routes (except `/auth/login` and `/auth/firebase`) MUST stay behind `requireAdmin`.
   - When verifying Firebase Admin login, check BOTH token signature AND an email allowlist (`env.adminEmails`) or Firebase Custom Claim (`admin === true`) — **never trust any arbitrary Firebase user as an Admin!**
2. **Audit Everything:**
   - Create a helper `writeAuditLog({ actorId, actorRole: 'ADMIN', action, entityType, entityId, metaJson })` and call it on every KYC decision, pricing edit, order override, COD settlement, wallet adjustment, payout override, and private KYC document view.
3. **CORS Update (`backend/.env`):**
   - In production, replace `CORS_ORIGINS=*` with explicit origins:
     ```env
     CORS_ORIGINS=https://twobee-admin.vercel.app,https://twobee-api.onrender.com
     ```
4. **Disable Dev-Only Endpoints in Production:**
   - Ensure `NODE_ENV=production` is set on the live backend so `/api/v1/common/demo/*` routes (already guarded by `if (env.nodeEnv !== 'production')` in `common.routes.ts`) and `DEV_STATIC_OTP` bypasses are automatically disabled.

---

## 8. 100% Free-Tier Deployment Stack

| Layer | Free Service | Limits / Notes |
|---|---|---|
| **PostgreSQL Database** | **Supabase** (Free) or **Neon** (Free) | 500 MB PostgreSQL, pooled connections compatible with Prisma (`DB_MODE=postgres`). Supabase also gives a backup Table Editor UI. |
| **Redis GEO (Optional)** | **Upstash Redis** (Free) or `GEO_BACKEND=memory` | Upstash gives 10k cmds/day; single-instance Render works fine with built-in memory GEO fallback (`GEO_BACKEND=auto`). |
| **Backend + Socket.IO** | **Render.com** (Free Web Service) or **Koyeb** (Free) | Free HTTPS/WSS URL. Set Build: `cd backend && npm install && npm run build`, Start: `cd backend && npm start`. |
| **Admin Dashboard Web** | **Vercel** or **Cloudflare Pages** (Free) | Zero-cost static/Next.js hosting with automatic Git deploys and SSL. |
| **Auth, OTP & Push** | **Firebase Spark Plan** (Free) | 10,000 Phone OTPs/mo + unlimited FCM push notifications + Admin Email/Password Auth. |
| **File / KYC Storage** | **Cloudflare R2** (10 GB Free, $0 egress) or **Supabase Storage** (1 GB Free) | Replaces ephemeral `./uploads` folder on cloud hosts. |
| **Maps & Routing** | **OpenStreetMap + Leaflet + OSRM** (Free) | Zero API keys, zero credit cards required. |

---

## 9. Teammate Implementation Roadmap (Execution Order)

1. **Milestone 1 — Cloud & Firebase Provisioning:**
   - Create Supabase/Neon PostgreSQL DB and run `npx prisma migrate deploy` + `npm run seed`.
   - Create Firebase project (Spark), register Web/Android/iOS apps, download service account JSON.
   - Add `DevicePushToken` model to `schema.prisma`, update `backend/src/config/env.ts`, and implement `backend/src/services/firebaseService.ts`.
2. **Milestone 2 — Backend Admin APIs & Reports:**
   - Implement `/api/v1/admin/auth/firebase`, `/overview`, `/live-radar`, entity CRUD/override routes, finance/COD settlement routes, pricing/zone/fleet routes, `AuditLog` tracking, `join:admin` Socket.IO room, and the 9 `/api/v1/admin/reports/*` endpoints.
3. **Milestone 3 — Admin Dashboard Scaffold & Auth:**
   - Initialize Next.js + Tailwind + shadcn/ui in `admin/`, wire Firebase Email/Password Auth → Backend JWT exchange, build Obsidian sidebar layout (`#0E1310`) with Eco-Emerald accents (`#00C853`).
4. **Milestone 4 — Core Operational Panels:**
   - Build Executive Overview + Leaflet Live Map, KYC Queue (with signed document previews & FB token check), Live Order/Ride/Parcel/Multi-Service Control Center, and Users/Riders/Merchants management.
5. **Milestone 5 — Configuration, Fleet, Finance & SOS:**
   - Build Pricing/Zones/Promos editors, Glafit EV Fleet & Rentals console, COD Ledger settlement & Payouts monitor, and real-time SOS Safety Center (with Socket.IO + Web Push audio chime).
6. **Milestone 6 — Reports Hub & Mobile Firebase Sync:**
   - Wire all 9 Reports with date/zone filters and CSV/PDF download buttons.
   - Add `firebase_core`, `firebase_auth`, `firebase_messaging` to `mobile/` so real phones receive FCM alerts and real OTPs.
7. **Milestone 7 — End-to-End Verification:**
   - Deploy `backend/` to Render + `admin/` to Vercel, test live Rider/Merchant KYC approval → mobile app unlock, live order dispatch, SOS alert, COD settlement, and report exports.
