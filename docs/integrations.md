# 2Bee Super-App — Third-Party Integrations & `.env` Configuration

> Every integration below is mapped directly to the flows and screens observed across `Untitled/` and `Untitled.jpg`, with **free/zero-cost local development options** and **Bangladesh production options** structured behind clean adapter interfaces so local testing requires zero paid API keys.

---

## 1. Integration Matrix Summary

| Category | Used By (Screens / Flows) | Recommended Local Dev / Free Option | Recommended Bangladesh / Production Option | Adapter Interface |
|---|---|---|---|---|
| **SMS & OTP** | `Login`, `OTP Verification`, `Forgot Passcode` (Rider 4-digit & Merchant 6-digit), `Merchant Approval Notice`, `Payout Guard OTP` | **100% Free Mock / Console OTP Adapter** (fixed `DEV_STATIC_OTP=123456` or stdout console + optional Firebase Phone Auth Spark free test numbers) | **SSL Wireless** / **GreenWeb BD** / **BulkSMSBD** (swap later via `SMS_PROVIDER`) | `SmsProvider` (`sendOtp`, `sendAlert`) |
| **Payments (`COD` + `Online`)** | `Food Checkout`, `Parcel 3`, `Ride 2`, `Client Wallet` + MFS selection UI | **2 Working Options Now:** (a) **`COD / Cash`** & (b) **Online via `Stripe Sandbox`** (`flutter_stripe` + Stripe Node SDK free test cards `4242...`). **`bKash`, `Nagad`, `Rocket`** kept in UI as selectable preview options (non-functional until prod credentials). | Add **bKash Tokenized Checkout**, **Nagad**, **Rocket**, **SSLCommerz** alongside Stripe | `PaymentGateway` (`initiate`, `verifyWebhook`, `refund`) |
| **Maps, Geocoding & Routing** | `Client Home` address picker, `Ride 1–4`, `Parcel 1–3`, `Food Live Tracking`, `Reg Step 1`, `Looking for Requests`, `Multi-service Live`, `Open in Google Maps` | **100% Free:** **OpenStreetMap (`flutter_map`)** + **Nominatim/Photon** (places) + **OSRM** (route polyline, ETA, km) + `url_launcher` (`geo:` / Google Maps deep link) | **Google Maps Platform** or **Barikoi API** (swap later via `MAPS_PROVIDER`) | `MapsClient` (`autocomplete`, `geocode`, `reverseGeocode`, `routeEta`) |
| **Real-Time Geo & Dispatch** | Rider live GPS stream, nearby dispatch radar, **Zone A -> Zone B Multi-Service matching**, `15s`/`60s` offer timers | **100% Free Self-Hosted:** **Redis GEO** (`GEOADD`/`GEOSEARCH` on Docker `redis:7-alpine` / Upstash free tier) + **Redis Zone Sets** (`Zone A -> Zone B`) + in-memory fallback | **Redis Cluster / Upstash + Socket.IO Redis Streams/Adapter** (optional **Uber H3** geo-grid extension at hyper-scale) | `GeoMatchService` (`updateRiderPos`, `findNearby`, `matchZoneCorridor`) |
| **Live Tracking & Chat** | Client `Ride 4`, `Parcel 4`, Food `Live Tracking`, Merchant `Orders`, Rider `Multi-service Live`, In-app Chat | **100% Free:** **WebSockets via `Socket.IO`** (bidirectional GPS upload, milestone push, offer countdowns, isolated tracking rooms, live chat) | Same **`Socket.IO` + Redis Adapter** horizontally scaled across instances | `RealtimeGateway` (`emitToRoom`, `onLocationPing`) |
| **Push Notifications** | Merchant 60s New Order popup, Rider 15s Dispatch pings, Multi-Service Ride Add-on pings, KYC approval, Order milestone tracking | **Socket.IO Foreground Events** + **`flutter_local_notifications`** for simulated local banner + **Firebase Console/Test** (optional) | **Firebase Cloud Messaging (FCM)** via `firebase-admin` (data + high-priority Android channels for urgent rider/merchant sound alerts) | `PushNotifier` (`sendToUser`, `sendToDeviceTokens`) |
| **Object & Media Storage** | KYC (`NID`, `Driving License`, `Trade License`, `Live Selfie`), Merchant photos (`Storefront`, `Kitchen`, `Dish`, `Menu Item`), Rider (`Proof of Loading`, `Proof of Delivery`), `Avatar` | **Local Disk / Express Signed Static Storage** (`./uploads` + Sharp thumbnailer + short-lived signed URLs for private KYC docs) | **Cloudflare R2** (10 GB free, zero egress fees) or **AWS S3 / MinIO** (`S3Client` compatible) with private presigned URLs for PII KYC docs | `StorageProvider` (`upload`, `getSignedUrl`, `delete`) |
| **PDF & Thermal Receipt Generation** | `Ride 5` (`Download Invoice`), `Merchant Order Detail` (`Print Slip`), `Merchant Payout Statement` (`Download Statement`), `Rider Wallet` (`Statement`) | **`pdfkit`** (Node backend PDF generator) + Flutter `share_plus` / `open_filex` preview | **`pdfkit`** / Puppeteer HTML-to-PDF on backend + ESC/POS Bluetooth thermal helper (`blue_thermal_printer` optional on Merchant Android) | `DocumentGenerator` (`buildInvoicePdf`, `buildStatementPdf`, `buildKitchenSlip`) |
| **Facebook Page Verification** | `Merchant Reg Step 3` (`Physical` & `Home Kitchen` `PD-4821` / `2B-XXXX` page verification) | **Manual Token Match / HTML Meta Scraper** checking user-entered Page URL + Admin manual verify checkbox in Admin Portal | **Server-side public link verifier** + Admin review checklist inside KYC approval queue (avoids brittle Meta Graph App Review unless needed) | `SocialVerifier` (`checkPublicPageToken`) |
| **Phone Call & SOS Safety** | `Call Rider`, `Call Recipient`, `Merchant Call Rider`, `Rider Emergency SOS`, `Client Ride 4 SOS` (`16216` / `999`) | **OS Native Dialer (`url_launcher` `tel:`)** + live **SOS Incident Endpoint** (alerts Admin dashboard + shares live GPS snapshot) | **OS Native Dialer** + Optional **Twilio / Exotel Masked Number Proxy** (hides real phone numbers between Client and Rider) + SOS Webhook | `SafetyService` (`triggerSos`, `maskPhoneBridge`) |
| **Device Biometrics** | `Rider Enter Passcode`, `Merchant Restaurant Login`, `Fingerprint Setup`, `Security Settings` | **`local_auth` Flutter package** (hardware BiometricPrompt / FaceID) + device-bound cryptographic unlock flag | **`local_auth`** paired with server-side device ID (`ActiveDevices`, max 3 devices observed on Rider Security screen) | `BiometricAuthService` (`authenticate`, `registerDeviceKey`) |
| **Deprecated / Removed** | `P&D - Login.jpg` (`Continue with Google` button) | **Not Wired (Removed)** | **Excluded** per Business Rule (`"One account per phone (OTP login). Client has no credential."`) | — |

---

## 2. Detailed Integration Architecture & Sandbox Design

### 2.1 SMS & OTP Service (`SmsProvider`)
- **Screens**: `Login` -> `OTP Verification` (6-digit, 30s resend TTL, max 5 attempts/15 min), `Merchant Approval Notice` + `Merchant OTP Verification` (before 6-digit PIN setup), `Restaurant Forgot Passcode` / `Rider Forgot Passcode` (OTP + last 4 NID digits), `Security Payout Guard` (OTP + 48h hold).
- **100% Free Local Dev Behavior**: `SMS_PROVIDER=mock`. Backend hashes generated OTP, stores expiry (`5 min`), logs `[DEV OTP] +88017XXXXXXXX -> 123456` in stdout, and supports fixed `DEV_STATIC_OTP=123456` for seamless testing with zero external cost.
- **Production Swap**: Set `SMS_PROVIDER=sslwireless` (or `greenweb` / `twilio`) when ready to deploy paid SMS credits.

### 2.2 Payments: `COD` + `Online (Stripe Sandbox)` + Upcoming MFS Options
- **Approved Architecture (`100% Free Sandbox`)**:
  - **Working Checkout Modes**:
    1. **`Cash on Delivery (COD)` / `Cash`**: Immediate server order creation; Rider confirms collected cash at dropoff / delivery and reconciles in `CodLedger`.
    2. **`Online Payment` via `Stripe Free Sandbox`**: Uses Stripe Node SDK + Flutter `flutter_stripe` PaymentSheet with free test keys (`pk_test_...` / `sk_test_...`, e.g., test Visa `4242 4242 4242 4242`) and real PaymentIntent + `POST /api/v1/payments/stripe/webhook` handling! (Note: Stripe amounts convert or test cleanly in BDT/USD test mode per Stripe test currency settings; zero fees in test mode).
  - **Upcoming Bangladesh MFS Options (`UI-Only Preview`)**: **`bKash`**, **`Nagad`**, and **`Rocket`** remain visible as recognizable selectable option tiles/badges in Checkout and Payout Setup UI (clearly marked `"Coming Soon — Use Online Card (Stripe Test) or COD for demo"` if tapped at checkout) so zero paid merchant credentials are needed now while keeping the exact visual layout ready for future `PaymentGateway` adapter plugins.

### 2.3 Maps, Geocoding & Routing (`MapsClient`)
- **Free Zero-Billing Stack (Recommended Default for Phase 2)**:
  - **Rendering**: `flutter_map` + OpenStreetMap / CartoDB Voyager light tiles (clean minimal styling matching `#F5FBF7` UI).
  - **Autocomplete & Geocoding**: Nominatim (`countrycodes=bd`, biased to Dhaka bounding box) OR **Barikoi** free developer tier (far better accuracy for Dhaka Roads/Blocks/Holding numbers like `"Road 11, Block D, Banani"`!).
  - **Routing & ETA**: OSRM (`router.project-osrm.org/route/v1/driving/...` or local Docker OSRM Bangladesh extract) returning GeoJSON route polyline, `distanceMeters`, and `durationSeconds` for both single rides and **Multi-Service 2-stop routing** (`Pickup Parcel -> Pickup Passenger -> Stop 1 Drop Passenger -> Stop 2 Drop Parcel`).
  - **External Navigation Handoff**: Clicking `"Open in Google Maps"` on `Rider Parcel Deliver` or `Multi-service Live` opens `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` via `url_launcher` (zero API key cost!).
- **Google Maps Swap**: Toggle `MAPS_PROVIDER=google` + supply `GOOGLE_MAPS_API_KEY` to switch backend Places/Directions calls and Flutter `google_maps_flutter` widget without changing business logic.

### 2.4 Real-Time Dispatch, Redis GEO & WebSocket Live Tracking (`Socket.IO`)
- **Redis GEO (`GEOADD` / `GEOSEARCH`)**:
  - Online riders publish GPS updates every 3–5s via WebSocket (`rider:location:update`), stored cleanly in Redis GEO indexes (`geo:riders:food`, `geo:riders:parcel`, `geo:riders:ride`) with short TTL heartbeat keys (`rider:heartbeat:{id}` `EX 30`) so stale riders drop off automatically without bloating PostgreSQL.
  - Nearest-rider lookups run in <1 ms via `GEOSEARCH ... FROMLONLAT lng lat BYRADIUS 5 km ASC`.
- **Zone A -> Zone B Multi-Service Matcher**:
  - When a Rider picks up an eligible **`NORMAL` parcel** (`weightKg <= frontMaxKg` & `volume <= frontVol`, verified front carrier, spare helmet, toggle ON) traveling from **`originZoneId` (`Zone A`) -> `destinationZoneId` (`Zone B`)**, Redis marks `rider:ms:active:{id}` under `ms:zone:{ZoneA}:{ZoneB}`.
  - New `RideTrip` requests whose `pickupZoneId == Zone A` AND `dropoffZoneId == Zone B` automatically match those active riders and push **`ride_addon_offer`** (`12s` timer) via Socket.IO! *(Ride-first requests NEVER match multi-service parcels).*
- **Strict Tracking Isolation**: Client tracking rooms (`tracking:parcel:{id}` vs `tracking:ride:{id}`) emit strictly partitioned payloads — `Parcel 4` and `Ride 4` NEVER see each other's leg, OTP, or passenger/parcel existence. Only the Rider's `multi-service` room sees both stops (`Stop 1 Passenger` -> `Stop 2 Parcel`).

### 2.5 Private KYC Media & Public Catalog Storage (`StorageProvider`)
- **Privacy Split**:
  - **Public / Authenticated App Assets** (merchant storefronts, dishes, rider avatars, food photos): stored under `/public/...` (direct CDN/server read).
  - **Sensitive PII Documents** (`NID Front/Back`, `Driving License`, `Trade License PDF`, `Live Selfies`, `Proof of Delivery photos`): stored in private bucket/folder `/private/kyc/...`, NEVER exposed publicly. Admin portal fetches temporary time-limited signed URLs (`TTL = 300s`), with every view written to `AuditLog`.
- **Upload Limits** (matching mockups): Max image/PDF upload `15 MB` (`Restaurant Reg Step 2`), auto-compressed thumbnails via `sharp`.

### 2.6 Push Notifications (FCM + Local Socket Fallback)
- Even when FCM credentials are not yet configured locally, Socket.IO + Flutter `flutter_local_notifications` delivers in-app and background-when-connected alerts.
- Production adds `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY` to `firebase-admin` on Node.js + `google-services.json` / `GoogleService-Info.plist` on Flutter (`high_importance_channel` with ringtone sound for `60s` Merchant New Order & `15s` Rider Offer alerts).

### 2.7 Compliance & Security Timers
- **15-Minute Inactivity Auto-Lock**: Handled both client-side (Flutter lifecycle + interaction listener tracking `lastActiveAt` for Rider & Merchant role sessions) AND server-side (`roleSessionLastSeen` sliding expiry on every protected `/rider/*` & `/merchant/*` call).
- **Critical Payout Change Guard (`48h` Hold)**: Any request to edit `PayoutAccount` (`bKash`, `Nagad`, `Rocket`, `Bank BEFTN`) requires SMS OTP verification first, creates a `PendingPayoutChange` row locked for `48 hours` (`effectiveAt = createdAt + 48h`), notifies user via SMS + Push + Inbox with a `Cancel Pending Change` emergency action, and swaps automatically via scheduled cron job after `48h`.

---

## 3. Complete Environment Variables Reference (`.env.example`)

### 3.1 Backend (`backend/.env`)

| Key | Example / Default (Dev) | Required in Prod | Description |
|---|---|---|---|
| `NODE_ENV` | `development` | Yes | `development` \| `staging` \| `production` |
| `PORT` | `4000` | Yes | Express + Socket.IO HTTP server port |
| `APP_NAME` | `2Bee` | Yes | Brand name used in SMS, PDF receipts, logs |
| `DATABASE_URL` | `postgresql://postgres:postgres@localhost:5432/twobee_dev` | Yes | PostgreSQL connection string for Prisma |
| `REDIS_URL` | `redis://localhost:6379` | Yes | Redis GEO (`GEOADD`/`GEOSEARCH`), Zone A->B multi-service sets, OTP rate limits & Socket.IO adapter |
| `JWT_ACCESS_SECRET` | `change_me_dev_access_secret_min_32_chars` | Yes | Signs primary phone-session JWT |
| `JWT_REFRESH_SECRET` | `change_me_dev_refresh_secret_min_32_chars` | Yes | Signs refresh token |
| `JWT_ROLE_SECRET` | `change_me_dev_role_secret_min_32_chars` | Yes | Signs passcode-unlocked role session (4-digit Rider / 6-digit post-approval Merchant) |
| `ROLE_INACTIVITY_MINUTES` | `15` | Yes | Auto-lock timeout for Rider & Merchant panels |
| `PAYOUT_CHANGE_HOLD_HOURS` | `48` | Yes | Critical Payout Guard delay after OTP check |
| `CORS_ORIGINS` | `http://localhost:3000,http://localhost:8080` | Yes | Allowed Admin & Flutter Web origins |
| `SMS_PROVIDER` | `mock` | Yes | `mock` \| `sslwireless` \| `greenweb` \| `twilio` |
| `DEV_STATIC_OTP` | `123456` | Never (`""` in prod) | Fixed OTP bypass strictly when `NODE_ENV=development` |
| `SSLWIRELESS_API_TOKEN` | `""` | If `sslwireless` | SSL Wireless BD SMS API token |
| `SSLWIRELESS_SID` | `""` | If `sslwireless` | SSL Wireless Sender ID / Masking name |
| `GREENWEB_API_TOKEN` | `""` | If `greenweb` | GreenWeb BD SMS token |
| `PAYMENT_MODE` | `stripe_sandbox` | Yes | `stripe_sandbox` \| `live` |
| `STRIPE_SECRET_KEY` | `sk_test_...` *(free Stripe test key)* | If Online Stripe | Used to create PaymentIntents in Stripe Sandbox |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` *(Stripe CLI / sandbox secret)* | If Online Stripe | Verifies Stripe checkout webhook signatures |
| `STRIPE_CURRENCY` | `usd` *(or `bdt` test conversion rate)* | Yes | Stripe test currency (`BDT_TO_USD_RATE=0.0084` mock helper if USD test account) |
| `MFS_LIVE_ENABLED` | `false` | Prod MFS later | Keeps `bKash` / `Nagad` / `Rocket` as preview options when `false` |
| `BKASH_BASE_URL` | `https://tokenized.sandbox.bka.sh/v1.2.0-beta` | If `MFS_LIVE_ENABLED=true` | Future bKash Tokenized Checkout base URL |
| `BKASH_APP_KEY` | `""` | Future MFS | Future bKash Merchant App Key |
| `BKASH_APP_SECRET` | `""` | Future MFS | Future bKash Merchant App Secret |
| `NAGAD_MERCHANT_ID` | `""` | Future MFS | Future Nagad Merchant ID |
| `SSLCOMMERZ_STORE_ID` | `""` | Future Cards/MFS | Future SSLCommerz Store ID |
| `MAPS_PROVIDER` | `osm` | Yes | `osm` \| `barikoi` \| `google` |
| `OSRM_BASE_URL` | `https://router.project-osrm.org` | If `osm` | Routing & ETA polyline service |
| `BARIKOI_API_KEY` | `""` | If `barikoi` | Bangladesh Places & Geocoding key |
| `GOOGLE_MAPS_SERVER_API_KEY` | `""` | If `google` | Server-side Routes / Geocoding API key |
| `STORAGE_PROVIDER` | `local` | Yes | `local` \| `s3` \| `r2` |
| `LOCAL_UPLOAD_DIR` | `./uploads` | If `local` | Local filesystem upload directory |
| `SIGNED_URL_SECRET` | `change_me_dev_signed_url_secret` | Yes | HMAC key protecting private KYC document downloads |
| `S3_ENDPOINT` | `""` | If `s3`/`r2` | Cloudflare R2 or MinIO endpoint |
| `S3_BUCKET` | `2bee-media` | If `s3`/`r2` | Bucket name |
| `S3_ACCESS_KEY_ID` | `""` | If `s3`/`r2` | Object storage access key |
| `S3_SECRET_ACCESS_KEY` | `""` | If `s3`/`r2` | Object storage secret key |
| `FCM_ENABLED` | `false` | Yes | Enables `firebase-admin` push notifications |
| `FIREBASE_PROJECT_ID` | `""` | If `FCM_ENABLED=true` | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | `""` | If `FCM_ENABLED=true` | Firebase service account email |
| `FIREBASE_PRIVATE_KEY` | `""` | If `FCM_ENABLED=true` | Firebase service account private key |
| `ADMIN_SEED_EMAIL` | `admin@2bee.app` | Yes | Initial admin user for `/api/v1/admin/*` API & future lightweight portal |
| `ADMIN_SEED_PASSWORD` | `Admin@2BeeDev!` | Rotate on deploy | Initial seeded admin password |

### 3.2 Flutter Mobile App (`mobile/.env` / `--dart-define`)

| Key | Example / Default (Dev) | Description |
|---|---|---|
| `APP_ENV` | `dev` | `dev` \| `staging` \| `prod` |
| `API_BASE_URL` | `http://10.0.2.2:4000/api/v1` | Android emulator host (`localhost` for iOS/Web) |
| `SOCKET_URL` | `http://10.0.2.2:4000` | Real-time Socket.IO WebSocket endpoint |
| `MAP_TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Free OpenStreetMap tile template |
| `STRIPE_PUBLISHABLE_KEY` | `pk_test_...` | Free Stripe Sandbox test publishable key (`flutter_stripe`) |
| `MFS_UI_PREVIEW_ONLY` | `true` | Shows `bKash`, `Nagad`, `Rocket` options as non-functional preview choices |
| `DEMO_DISPATCH_HELPER` | `true` *(false in prod)* | Optional QA trigger cleanly separated from Rider prod UI |

