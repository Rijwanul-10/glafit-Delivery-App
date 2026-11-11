# 2Bee Super-App (Client · Rider · Restaurant & Home Kitchen)

Complete full-stack multi-role delivery, ride-share, parcel logistics, and food delivery super-app implemented from [docs/analysis.md](docs/analysis.md) and [docs/integrations.md](docs/integrations.md).

## Architecture Overview

- **`backend/`**: Node.js + TypeScript + Express + Prisma (`PostgreSQL` via external `pg` OR zero-setup local embedded `@electric-sql/pglite` WASM) + **`Redis GEO` (`GEOADD` / `GEOSEARCH` + 30s TTL + `Uber H3` hyper-scale index hook)** + **WebSockets (`Socket.IO`)** + **Stripe Free Sandbox** + `pdfkit` + Free **OSRM / OSM / Nominatim** routing.
- **`mobile/`**: Flutter Material 3 + Riverpod + GoRouter featuring **Option B Role-Tailored 4-Tab `AppBottomNav`**:
  - **Client**: `Home` | `Activity` | `Wallet` | `Profile`
  - **Rider**: `Home` | `Jobs` | `Wallet` | `Profile`
  - **Merchant (Split Physical & Home Kitchen)**: `Home` | `Orders` | `Wallet` | `Store` (`Menu` quick access in Home, Store & Orders header)

## Quick Start (Zero Paid API Keys / Zero Docker Required)

### 1. Start Backend
```powershell
cd backend
npm install
copy .env.example .env
npm run dev
```
*(Runs cleanly out of the box using embedded `pglite` PostgreSQL + automatic Dhaka demo seed on port `4000`, or run `docker compose up -d` and set `DB_MODE=postgres` + `REDIS_URL=redis://localhost:6379`.)*

### 2. Run Mobile App
```powershell
cd mobile
flutter pub get
flutter run -d chrome   # or -d windows / android emulator
```

## Seeded Demo Accounts (OTP = `123456` in Dev)

| Role | Phone | Passcode | Notes |
|---|---|---|---|
| **Client** | `+8801711111111` | *None* | Phone OTP only |
| **Rider (Approved)** | `+8801712345678` | **`2580`** *(4-digit, set at reg)* | Front 8kg carrier + Spare helmet + Multi-Service enabled |
| **Physical Restaurant** | `+8801722222222` | **`258096`** *(6-digit, set post-approval)* | Sultan's Dine Banani (`2BEE100` promo) |
| **Home Kitchen** | `+8801733333333` | **`147852`** *(6-digit, set post-approval)* | Rina's Home Kitchen (Daily Quota + Cutoff + Tonight stock) |
| **Admin REST API** | Header `x-admin-secret` | `Admin@2BeeDev!` | `/api/v1/admin/kyc/*` |

## Verification Commands
```powershell
# Backend TypeScript & End-to-End API + WebSocket + Multi-Service tests
cd backend && npm run typecheck && npm test

# Flutter static analysis & widget tests
cd mobile && flutter analyze && flutter test
```

