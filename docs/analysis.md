# 2Bee Super-App — Phase 1 Analysis, Flow Map, Navigation Reconciliation & Architecture

> **Verification Scope:** Every one of the **108 UI screen designs** in `Untitled/` (plus `P&D • Spacious flow map.jpg`) and every one of the **195 flow transitions (`F001`–`F195`)** across all **17 sections** on `Untitled.jpg` (`32768 × 14698 px`) have been inspected and cross-checked against your **Business Rules**, **Unified Navigation Rules**, **Theme**, **Branding (`2Bee`)**, and **MUST ASK ME** checklist.

---

## 1. Executive Summary & Workspace State

### 1.1 Workspace Inspection
Inspecting `f:\glafit Delivery App` shows **no existing application source code or documentation** yet — only the design deliverables:
- `Untitled.jpg` (`32,768 × 14,698 px`): Master flow map linking **17 numbered sections** via arrows **`F001` through `F195`**.
- `Untitled/` (`109` files total): **108 individual screen mockups** (`P&D - *.jpg`, `P&D Parcel - *.jpg`, `P&D Ride - *.jpg`, `P&D Merchant - *.jpg`, `P&D Rider - *.jpg`) plus `P&D • Spacious flow map.jpg`.

### 1.2 Rule Precedence Applied Throughout This Spec
Whenever screen designs conflict with your stated rules, this document enforces strict precedence:
1. **Business Rules** (highest authority)
2. **Unified 4-Tab Navigation Rule**
3. **Flow Map (`F001`–`F195`)**
4. **Individual Screen Mockups** (lowest authority when conflicting)

---

## 2. Branding & Pixel-Verified Theme Specification

### 2.1 Branding Replacement (`P&D` / `glafit` → `2Bee`)
All legacy brand strings observed across the 108 screens will be unified under **`2Bee`**:

| Legacy String Observed in Mockups | Occurrences | Target `2Bee` Standard |
|---|---|---|
| `P&D`, `P&D EXPRESS`, `P&D FLEET`, `P&D RIDE`, `P&D Zero-Emission Fleet`, `P&D Certified Rider Standard` | Splash, Onboarding 3, Parcel 1/2, Ride 1/2, Rider A10, Bike Rental Home, Batch Summary, search copy | **`2Bee`**, **`2Bee Express`**, **`2Bee Fleet`**, **`2Bee Ride`** |
| `Glafit EV`, `100% GLAFIT EV FLEET`, `Glafit GFR-02`, `Glafit GFR-01 Eco`, `Glafit LOM EV`, `Glafit EV Solo` | Parcel 1/2, Ride 2, Bike Rental Home | Neutral **`2Bee EV`** fleet / tier names (see **Open Question Q7** if hardware model codes `GFR-02` should also be renamed or kept as EV tier labels) |
| Order/Token Prefixes `#PPRO-9204`, `GF FEST`, `PD-4821` | Parcel 1–4, Rider Multi-Service, Order Detail, Cart, Verification Pending, Reg Step 3 | `#2B-XXXX`, `2BEE100` / `2BFEST`, `2B-XXXX` verification code |
| Stray Template Brands: `Matcha EcoPoints`, `Matcha Nocturne Merchant Core`, `Be-Green certified badge` | Ride 5, Merchant Store footer, Home Kitchen Step 4 | `2Bee EcoPoints` (or removed if no loyalty program), `2Bee Merchant`, `2Bee Hygiene Verified` |

### 2.2 Pixel-Sampled Color Palette & Visual Inconsistencies Found
RGB pixel sampling across representative mockups shows the designs were generated in **3 slightly different surface palettes**:
1. **Auth / Client Home (`Login`, `Role Selection`, `Client Home`)**: `#EDF8F0` / `#F5FBF7` scaffold, `#FFFFFF` / `#E8F7F0` cards, **`#189850` / `#199853`** primary button, **`#2563EC` (BLUE!)** accent bug on `Role Selection`.
2. **Core Commerce (`Food`, `Parcel`, `Merchant`, `Rider Reg`, `Security Settings`)**: `#ECFFE3` scaffold, `#E6F9DD` / `#E1F4D6` tonal cards, `#FFFFFF` cards, **`#006C04` / `#037007`** deep forest green primary CTA, `#8CF07C` light matcha highlight, `#101C0C` primary dark ink.
3. **Rider Live & Wallet (`Rider Home`, `Rider Wallet`, `Rider Job History`, `Carrying Setup`)**: `#FAF9FF` cool lavender-white scaffold, `#F1F3FF` tonal fill, `#090E14` / `#121F0D` obsidian cards, `#006C04` green CTA (`#01FC1B` neon button in `Carrying Setup` over `#10172A` barrier).

> **Recommended Unified `2Bee` Theme Tokens (combining Splash + Core Green while removing stray Blue/Cool-Gray mismatches):**

| Token | Hex | Source Observed |
|---|---|---|
| `splashBg` | `#092113` | `P&D - Splash Screen.jpg` (`#061C0F`–`#092113`) |
| `primary` | `#006C04` | `Food Delivery Mobile`, `Merchant Home`, `Rider A9`, `Wallet` CTA (`#006C04`–`#037007`) |
| `primaryAccent` | `#199853` | `Login`, `Client Home` badge/CTA (`#189850`–`#199853`) |
| `primarySoft` | `#8CF07C` | Selected MFS card, active tags (`Merchant Home`, `Rider A9`) |
| `scaffoldBg` | `#F5FBF7` (or `#ECFFE3`) | Unify all screens to `#F5FBF7` (clean mint white) or `#ECFFE3` (stronger mint); `#F5FBF7` gives cleaner readability on dense Rider/Merchant dashboards — confirm in Open Questions |
| `surfaceCard` | `#FFFFFF` | All white elevated cards across roles |
| `surfaceTonal` | `#E8F7F0` (or `#E6F9DD`) | Grouped soft cards, icon containers |
| `obsidianCard` | `#101C0C` | `Rider Wallet` balance card, `Rider Home` earnings card, dark dispatch CTAs (`#090E14`–`#121F0D`) |
| `textPrimary` | `#101C0C` | Headings and values (`#101C0C` / `#141824`) |
| `textSecondary` | `#545C70` | Muted labels, timestamps (`#545C70` / `#5C7C68`) |
| `warningBg` / `warningBorder` | `#FCF8E0` / `#FCE080` | `Rider Home Pending` banner |
| `errorBg` / `errorAccent` | `#FCD8D4` / `#C62828` | `Merchant Home Pending` banner, offline/closed locks |
| `typography` | `Inter` + Bangla/Taka fallback (`Noto Sans Bengali` / system fallback) | Required because **Mockup Rider screens display `[NO GLYPH]` boxes on `৳`** where the font lacked U+09F3 (`৳`) |
| `cardRadius` / `buttonRadius` | `16.0 px` / `12.0 px` | Per THEME spec |
| `currency` | `BDT (৳)` | Per THEME spec (fixing `$` and `§` typos in designs) |

---

## 3. Unified Navigation Architecture (`AppBottomNav`)

### 3.1 Target 4-Tab Bar Specification (Option B — Role-Tailored Labels)
A single shared `AppBottomNav` widget renders **4 fixed destinations** parameterized per role. Top-level screens stay inside the shell; detail/booking/execution flows push onto a root navigator (`bottomBar = hidden`).

| Tab Index | **Client** (`Home \| Activity \| Wallet \| Profile`) | **Rider** (`Home \| Jobs \| Wallet \| Profile`) | **Restaurant / Home Kitchen** (`Home \| Orders \| Wallet \| Store`) |
|---|---|---|---|
| `0` | **`Home`** — `Client Home` (Ride, Parcel, Food + Trending + Promos) | **`Home`** — `Rider Home` / `Home Pending` (Verification banner, Online toggle, Hotspots, Requests shortcut, Today stats) | **`Home`** — Split `Physical` / `Home Kitchen Home` (`Home Pending`, Open toggle, Quota/Stats, Incoming orders, **`Manage Menu` Quick Card**) |
| `1` | **`Activity`** — Unified Active & Past Hub across **All · Food · Parcel · Ride** | **`Jobs`** — `Rider Service History` with **`Live \| Completed`** & **`All \| Food \| Parcel \| Ride`** (multi-service batch under `Live`) | **`Orders`** — `Merchant Orders` (`New \| Preparing \| Ready \| History` + KPIs + `Menu` header button) |
| `2` | **`Wallet`** — **Client Wallet** (Balance, Stripe Sandbox Online / Saved MFS / COD prefs, Vouchers, Refunds Ledger) | **`Wallet`** — Unified **Rider Wallet & Earnings** (`Wallet \| Earnings` toggle, Balance, COD cash-in-hand, Rent auto-debit, Cash Out, Ledger) | **`Wallet`** — Unified **Merchant Wallet & Earnings** (`Today \| Week \| Month`, Gross, 15% Commission, Payout countdown, Statement PDF) |
| `3` | **`Profile`** — **Client Profile** (Info, Saved Addresses, Favorites, Notifications, Help/SOS, **Switch Role → Role Selection**, Log Out) | **`Profile`** — `Rider Profile` (Metrics, **Vehicle & Carrying Setup / Multi-Service**, Bike Rental, **Security & Passcode**, Language, **Switch Role**, Log Out) | **`Store`** — Split `Physical` / `Home Kitchen Store` (**Menu**, **Promotions**, **Reviews**, Profile, Hours, Quota/Cutoff, Staff, **Security (6-digit)**, Payouts, **Switch Role**, Log Out) |

### 3.2 Complete Navigation Removal & Relocation Table (Approved)
Per Navigation Rules, every incompatible service-specific bottom bar in the mockups is stripped:

| Design Screen(s) | Original Mockup Bottom Nav / Tabs | Action | Where Original Items Relocate Under Role-Tailored `AppBottomNav` |
|---|---|---|---|
| `Client Home` | `HOME \| ORDERS \| WALLET \| PROFILE` | **Rename tab 1** | `ORDERS` → **`Activity`** (unified across Food + Parcel + Ride). |
| `P&D Parcel - 1. Hub & Rate Calculator` | `Hub/Send \| Shipments \| History \| Help` | **Strip 4-tab bar** | `Hub/Send` → **Parcel entry**; `Shipments` → **`Activity → Parcel (Live)`**; `History` → **`Activity → Parcel (Past)`**; `Help` → **Top Help icon + `Profile → Help & Support`**. |
| `P&D Ride - 1. Map Radar & Location Selector` | Floating `Ride \| Saved \| Trips \| Hub` | **Strip 4-tab bar** | `Ride` → Default; `Saved` → **Saved address chips** + `Profile → Saved Addresses`; `Trips` → **`Activity → Ride`**; `Hub` → **Back to `Client Home`**. |
| `P&D - Food Delivery Mobile`, `Orders`, `Favorites` | `Explore \| Orders \| Favorites` | **Strip 3-tab bar** | `Explore` → `Client Home → Food`; `Orders` → **`Activity → Food`**; `Favorites` → **Header Heart + `Profile → Favorites`**. |
| `P&D Merchant - Home`, `Home (Rina's Kitchen)`, `Orders`, `Menu`, `Earnings`, `Store`, `Store (Rina's Kitchen)` | **5-tab bar:** `Home \| Orders \| Menu \| Earnings \| Store` | **Strip 5th tab (`Menu`) -> Keep 4 tabs (`Home \| Orders \| Wallet \| Store`)** | `Home` → **`Home`**; `Orders` → **`Orders`**; **`Menu`** → **Quick Action Card on `Home` + Menu row in `Store` + `Orders` header button**; `Earnings` → **`Wallet`**; `Store` → **`Store`**. |
| `P&D - Rider Home`, `Rider Earnings`, `Rider Wallet`, `Rider Profile`, `Security Settings`, `Looking for Requests`, `Home Pending`, `Home Approved` | `Home \| Earnings \| Wallet \| Profile` | **Replace `Earnings` with `Jobs`** | `Home` → **`Home`**; **`Jobs`** → **`Rider Job History` (`Live \| Completed`)**; **`Earnings`** → **Merged into `Wallet` (`Wallet \| Earnings` toggle)**; `Profile` → **`Profile`**. |
| `P&D - Role Selection` & Switch Role rows | Separate `Switch Role` links | **Role Switching via Tab 4 (`Profile`)** | Client switching to **Rider** prompts **4-digit Passcode** (set at reg); switching to **Merchant** prompts **6-digit Passcode** if approved & passcode set (or enters `Home Pending` while unapproved, or triggers **post-approval OTP -> Create 6-Digit Passcode** if newly approved!). Switching back to Client needs no passcode. |

---

## 4. Complete End-to-End Flow Map (`F001`–`F195`)

### 4.1 Entry, Auth & Role Switching (`Section 01` — `F001`–`F015`)
> **Finalized Auth & Passcode Rules (Approved):**
> - **One account per phone (OTP login only; `Continue with Google` removed)**. Client requires no passcode.
> - **Rider**: Creates a permanent **4-digit passcode AT registration (Step 8)**, then enters `Rider Home Pending` (`Verification in progress`, offline locked), and logs in thereafter with that **4-digit passcode**.
> - **Merchant (Physical Restaurant & Home Kitchen)**: Sets **NO passcode during registration**. Upon submitting KYC, pending merchants view `Merchant Home Pending` (`Verification in progress`, store locked closed). Once Admin approves (`APPROVED`) and sends an approval notification to their phone, their **first login after approval** runs **`Merchant OTP Verification` -> `Create 6-Digit Passcode` (+ optional Fingerprint)** BEFORE unlocking the live Merchant Home panel; every subsequent login uses that fixed **6-digit passcode**.

| Flow ID | From Screen | Trigger / Condition | To Screen | Rule / Spec Note |
|---|---|---|---|---|
| `F001` | `Splash Screen` | First visit | `Onboarding 1 of 3` | Rebrand to `2Bee` |
| `F008` | `Splash Screen` | Returning guest (unauthenticated) | `Login` | Active valid JWT skips directly to last role / Role Selection (subject to 15-min passcode lock for Rider 4-digit / Merchant 6-digit) |
| `F002` | `Onboarding 1 of 3` | `Next ->` | `Onboarding 2 of 3` | Rebrand `2Bee` |
| `F009` | `Onboarding 1 of 3` | `Skip` | `Login` | — |
| `F003` | `Onboarding 2 of 3` | `Next ->` | `Onboarding 3 of 3` | — |
| `F010` | `Onboarding 2 of 3` | `Skip` | `Login` | — |
| `F004` | `Onboarding 3 of 3` | `Get started` | `Login` | Remove `P&D EXPRESS` |
| `F005` | `Login` | `Send OTP` (valid `+8801XXXXXXXXX`) | `OTP Verification` | **Removed `Continue with Google`** per user decision |
| `F011` | `OTP Verification` | `Edit` phone / Back | `Login` | — |
| `F006` | `OTP Verification` | `Verify & Continue` (6-digit OTP ok) | `Role Selection` | Auto-creates Client profile on first OTP verification |
| `F007` | `Role Selection` | Select **Client** -> Continue | `Client Home` | No passcode required |
| `F012` | `Role Selection` | Select **Rider** (New KYC not started) | `A1. Personal Info` | Same verified phone; creates 4-digit passcode at Step 8 |
| `F013` | `Role Selection` | Select **Rider** (Registered / Pending / Approved) | `Rider Enter Passcode` | Verifies permanent **4-digit passcode** |
| `F014` | `Role Selection` | Select **Restaurant** (Registered) | If `PENDING`/`NEEDS_CHANGES`: `Merchant Home Pending` / `Needs Changes`; If `APPROVED` & no passcode yet: `Approved Notice / Merchant OTP Verification -> Create 6-Digit Passcode`; If `APPROVED` & passcode set: `Restaurant Login` (**6-digit passcode**) | Enforces post-approval **6-digit passcode** gate |
| `F015` | `Role Selection` | Select **Restaurant** (New KYC not started) | `Restaurant Type` | Choose Physical or Home Kitchen (no passcode set at reg) |

### 4.2 Client Root & Ride Flow (`Client Home` + `Section 02` — `F016`–`F028`)
> Flow map note: *"Dedicated ride history / receipt screens from the diagram are not supplied."* Must add Ride cards inside Client `Activity` and `Ride Receipt / Detail`.

| Flow ID | From Screen | Trigger / Condition | To Screen | Spec Note |
|---|---|---|---|---|
| `F016` | `Client Home` | Tap **Ride** service card | `Ride 1. Map Radar & Location Selector` | — |
| `F017` | `Client Home` | Tap **Parcel** service card | `Parcel 1. Hub & Rate Calculator` | — |
| `F018` | `Client Home` | Tap **Food** card / Trending item | `Food Delivery Mobile` | — |
| `F019` | `Client Home` | Bottom Nav `Activity` (`Orders` in mockup) | `Activity (Unified Orders)` | Replaced Orders with Activity tab |
| `F020` | `Client Home` | Tap Notification bell | `Notifications` | — |
| `F021` | `Client Home` | Tap Search / Filter bar | `Search & Filter` | — |
| `F028` | `Ride 1. Map Radar` | Back / Hub icon | `Client Home` | Strip Ride bottom bar |
| `F022` | `Ride 1. Map Radar` | Set Pickup + Destination -> `Find Rides ->` | `Ride 2. Vehicle & Fleet Tier Selection` | — |
| `F023` | `Ride 2. Vehicle Selection` | Select Tier, Payment, Promo -> `Confirm Ride` | `Ride 3. Courier & Rider Matching Radar` | — |
| `F026` | `Ride 3. Matching Radar` | `Cancel Request` / Timeout | `Ride 2. Vehicle Selection` | Server emits ride-cancelled event |
| `F024` | `Ride 3. Matching Radar` | Rider accepts request | `Ride 4. Active Trip & Driver En-Route` | Wait: missing intermediate `Trip Started (En-route to dropoff)` state separate from pickup waiting! Add sub-state on `Ride 4` |
| `F025` | `Ride 4. Active Trip` | Rider completes dropoff | `Ride 5. Trip Completion & Fare Rating` | `SOS` & `Share` need modals/endpoints |
| `F027` | `Ride 5. Completion & Rating` | `Submit Rating & Done` | `Ride 1` (`Client Home` or `Ride 1` per diagram) | `Download Invoice` triggers PDF receipt |

### 4.3 Client Parcel Flow (`Section 03` — `F030`–`F035`)
> Flow map note: *"Dedicated shipment history, completion / rating, cancellation, refund and return screens are not supplied."* Must add Parcel history + completion/rating + cancel/refund UI.

| Flow ID | From Screen | Trigger / Condition | To Screen | Rule / Spec Note |
|---|---|---|---|---|
| `F035` | `Parcel 1. Hub & Rate Calculator` | Back | `Client Home` | Strip Parcel 4-tab bar |
| `F030` | `Parcel 1. Hub & Rate Calculator` | Pickup/Dropoff, Tier (`Express`/`Standard Eco`/`Next-Day`), Size -> `Continue` | `Parcel 2. Package & Carrier Specs` | Only **Normal (`Standard Eco`/`Next-Day`)** parcels <= 8 kg qualify silently for rider multi-service |
| `F033` | `Parcel 1. Hub & Rate Calculator` | Tap live banner `#...` / Track existing | `Parcel 4. Active Shipment & Tracking` | Also reachable from `Activity -> Parcel (Live)` |
| `F031` | `Parcel 2. Package & Carrier Specs` | Category, Weight (<=8 kg for bike / front), Volume, Declared Value, Protection -> `Continue` | `Parcel 3. Addresses & Payment` | Note: Business rules specify front carrier max 8 kg (rear max 15 kg for solo parcel!) |
| `F032` | `Parcel 3. Addresses & Payment` | Sender/Recipient details, Payment method -> `Confirm & Dispatch` | `Parcel 4. Active Shipment & Tracking` | Creates shipment + generates 4-digit Delivery Security PIN |
| `F034` | `Parcel 4. Active Shipment & Tracking` | After completion [missing completion/rating screen] | Returns to `Parcel 1` (`Client Home`) | **CRITICAL PRIVACY FIX:** Strip all `"Zero-Detour Multi-Route"`, `"matched passenger route"`, and `"alongside passenger commute"` strings! |

### 4.4 Client Food Order, Discovery & History (`Sections 04 & 05` — `F029`, `F036`–`F062`)

| Flow ID | From Screen | Trigger | To Screen | Notes |
|---|---|---|---|---|
| `F036` | `Food Delivery Mobile` | Tap restaurant card | `Restaurant Detail` | Filter open restaurants + Home Kitchens honoring daily quota/cutoff |
| `F044` | `Food Delivery Mobile` | Tap search / filter | `Search & Filter` | — |
| `F046` | `Food Delivery Mobile` | Tap favorite heart/icon | `Favorites` | Heart on card toggles wishlist; header heart opens Favorites |
| `F055` | `Food Delivery Mobile` | Activity / Orders link | `Orders` (`Activity -> Food`) | Bottom nav replaced |
| `F037` | `Restaurant Detail` | Tap menu item `+Add` (with options) | `Item Customization` | Simple items with zero required options can quick-add directly |
| `F048` | `Restaurant Detail` | Tap floating `View Cart` bar | `Cart` | Enforces single-restaurant cart guard |
| `F038` | `Item Customization` | Required choices met -> `Add to cart` | `Cart` (or closes modal back to `Restaurant Detail` + bar update) | Diagram shows arrow -> `Cart` |
| `F049` | `Item Customization` | Missing required option | Stay on `Item Customization` | Validation highlight |
| `F039` | `Cart` | `Go to Checkout ->` | `Checkout` | Recomputes promo voucher + fees |
| `F050` | `Cart` | `+ Add more items` | `Restaurant Detail` | — |
| `F040` | `Checkout` | Select address, time (`Now` / `Schedule`), payment -> `Place Order` | `Order Placed` | Online payments (`bKash`/`Nagad`/`Card`) must open simulated/real payment gateway step before confirming! |
| `F041` | `Order Placed` | `Track Live Order` | `Live Tracking` | — |
| `F051` | `Order Placed` | `Back to Food Home` | `Food Delivery Mobile` | — |
| `F042` | `Live Tracking` | Rider marks delivered | `Delivered & Rating` | — |
| `F052` | `Live Tracking` | Order delayed alert / refresh | Stay on `Live Tracking` | Shows SLA delay badge |
| `F043` | `Delivered & Rating` | `Submit Review` | `Order Detail` | Dual rating (Restaurant + Rider + Tip) |
| `F054` | `Delivered & Rating` | `Order again` | `Restaurant Detail` | — |
| `F045` | `Search & Filter` | Tap result | `Restaurant Detail` | — |
| `F047` | `Favorites` | Tap saved restaurant/dish | `Restaurant Detail` | **Fix `$` currency bug -> `৳`** |
| `F061` | `Favorites` | Tap Explore / Empty CTA | `Food Delivery Mobile` | — |
| `F029` | `Orders` (`Activity`) | Tap completed order | `Order Detail` | Extend to Ride Detail & Parcel Detail |
| `F056` | `Orders` (`Activity`) | Tap active live card | `Live Tracking` | Also Parcel/Ride live tracking |
| `F057` | `Orders` (`Activity`) | Tap `Reorder` | `Cart` | Re-adds available items to cart |
| `F062` | `Orders` (`Activity`) | Empty CTA / Explore | `Food Delivery Mobile` | — |
| `F053` | `Order Detail` | `Reorder` | `Cart` | — |
| `F058` | `Notifications` | Tap live status alert | `Live Tracking` | — |
| `F059` | `Notifications` | Tap `Rate Order` | `Delivered & Rating` | — |
| `F060` | `Notifications` | Tap `View Receipt` | `Order Detail` | — |

### 4.5 Merchant Access, Registration, Review & Operations (`Sections 06–11` — `F063`–`F126`)
> **FINALIZED USER DECISIONS APPLIED:**
> 1. **Passcode Timing & Length**: Merchant creates **NO passcode during registration**. After submitting KYC (`F085` / `F086`), pending owners can view `Merchant Home Pending` (`Verification in progress`, store locked closed). Once Admin approves (`APPROVED`), an approval notification is sent to their verified phone; at **first post-approval login**, the merchant MUST complete **`Merchant OTP Verification` -> `Create 6-Digit Passcode` (+ optional `Fingerprint Setup`)** before seeing their active Merchant Home panel. Every subsequent login uses that fixed **6-digit passcode** on `Restaurant Login` (which updates from 4 dots to **6 dots**).
> 2. **Split Merchant Panel Approved**: Keep tailored layouts for **Physical Restaurant** (`Merchant Home`, `Merchant Store`) vs **Home Kitchen** (`Home Kitchen Home` w/ batch quota & cutoff, `Home Kitchen Store`), sharing unified `Activity (Orders)`, `Wallet`, `Menu`, `Promotions`, `Reviews`, `Security` components and unified 4-tab `AppBottomNav`.

| Flow ID | From Screen | Trigger / Path | To Screen | Finalized Spec Target |
|---|---|---|---|---|
| `F063` | `Restaurant Login` (**6-digit** passcode / biometric) | Physical Restaurant verified | `Merchant Home (Physical)` | Requires 6-digit passcode (if approved & set) |
| `F064` | `Restaurant Login` (**6-digit** passcode / biometric) | Home Kitchen verified | `Merchant Home (Home Kitchen)` | **Split panel** (quota/cutoff/tonight stock) |
| `F065` | `Restaurant Login` | `Forgot passcode?` | `Restaurant Forgot Passcode` | Verifies **6-digit SMS OTP + last 4 digits of NID** -> Reset **6-digit** passcode |
| `F066` | `Restaurant Forgot Passcode` | Verify & save new 6-digit passcode | `Restaurant Login` | Re-enter panel cleanly |
| `F067` | `Restaurant Login` | `Register your restaurant` | `Restaurant Type` | — |
| `F068`–`F072` | `Approved Notice` -> `Merchant OTP` -> `Create 6-Digit PIN` -> `Fingerprint Setup` -> `Merchant Home` | **First login after Admin Approval** | Active Split `Merchant Home` | Replaces manual `RST-XXXX` 12-digit password (`Panel Login`) with seamless phone-OTP + **6-digit PIN setup** (or keeps `Panel Login` optional if activation token sent) |
| `F073` | `Restaurant Type` | Choose **Physical Restaurant** | `Restaurant Reg Step 1: Business Info` | — |
| `F074`–`F078` | `Step 1` -> `2 Legal` -> `3 Facebook` -> `4 Photos & Hours` -> `5 Payout` -> `Review & Submit` | Sequential wizard `Next` | `Restaurant Reg: Review & Submit` | **No passcode step during reg** (per Decision 2c) |
| `F079` | `Restaurant Type` | Choose **Home Kitchen** | `Home Kitchen Reg Step 1: Kitchen Info` | — |
| `F080`–`F084` | `Step 1` -> `2 Identity` -> `3 Facebook` -> `4 Food & Hygiene` -> `5 Payout` -> `Review & Submit` | Sequential wizard `Next` | `Home Kitchen Reg: Review & Submit` | **No passcode step during reg** (per Decision 2c) |
| `F085` / `F086` | `Review & Submit` (Physical / Home Kitchen) | `Submit Application` | `Merchant Home Pending` (`F085`/`F086`) | Enters `Home Pending` (`"Verification in progress"` + locked Closed) without needing a passcode yet |
| `F087`–`F093` | `Verification Pending` <-> `Needs Changes`, `Approved Notice`, `Home Pending` | Admin decision states | `Needs Changes` / `Merchant OTP -> Create 6-Digit PIN` | Backend states: `PENDING`, `NEEDS_CHANGES`, `APPROVED` (locks Home behind **Create 6-Digit PIN** until set!), `REJECTED` |
| `F094`–`F098` | `Merchant Home (Physical)` | Tabs / Bell / Card | `F094 Activity (Orders)`, `F095 Menu`, `F096 Wallet (Earnings)`, `F097 Profile (Store)`, `F098 New Order Popup` | Unified 4-tab `AppBottomNav` + `Menu` quick card on `Home` & `Profile` |
| `F099`–`F103` | `Merchant Home (Home Kitchen)` | Tabs / Cards | `F099 Activity (Orders)`, `F100 Menu`, `F101 Wallet`, `F102 Profile (HK Store)`, `F103 New Order Popup` | **Split HK panel** + unified 4-tab `AppBottomNav` |
| `F104`, `F109` | `Merchant Orders` (`Activity`) | `F104`: New Order alert; `F109`: Tap order row | `New Order Popup` / `Merchant Order Detail` | — |
| `F105`, `F106` | `New Order Popup` | `F105`: `Accept Order`; `F106`: `Reject Order` | `Order Detail` / `Reject Reason Sheet` | 60s countdown timer; server auto-rejects if timer hits 0 |
| `F107`, `F108` | `Reject Reason Sheet` | `F107`: `Confirm Reject`; `F108`: `Keep Order` | `Orders` / `New Order Popup` | Triggers refund/re-notify to client |
| `F110` | `Merchant Order Detail` | `Mark as Ready` | `Orders` (moves to `Ready` tab & dispatches rider) | Needs QR/PIN `Handover Scan` verification too |
| `F111`, `F112` | `Merchant Menu` <-> `Add or Edit Item` | `+ Add Item` / `Edit` <-> `Save Item` | Bidirectional | Accessible from `Home` shortcut + `Profile` + `Orders` header |
| `F113`, `F114` | `Merchant Earnings` (`Wallet`) <-> `Payout Statement` | `View Statement` <-> `Back` | Bidirectional | Resolve Wed vs Fri settlement schedule |
| `F115`–`F119`, `F125` | `Merchant Store` (`Profile`) | `F115 Promotions`, `F116 Reviews`, `F117 Security`, `F118 Role Selection`, `F119 Restaurant Login (Log out)`, `F125 Home` | **IMPORTANT:** Add visible rows for `Promotions` and `Reviews` in `Store` (`Profile`) UI because mockups omitted them despite `F115`/`F116`! |
| `F120`–`F124`, `F126` | `Store (Rina's Kitchen)` | Same + Home Kitchen quota/cutoff rows | Merged into single `Merchant Store` (`Profile`) | — |

### 4.6 Rider Registration, Access, Dispatch & Multi-Service (`Sections 12–17` — `F127`–`F195`)

| Flow ID | From Screen | Trigger / Branch | To Screen | Notes |
|---|---|---|---|---|
| `F127`–`F130` | `A1 Personal` -> `A2 Docs` -> `A3 Vehicle` -> `A4 Own Bike` | `F129`: Own bike -> `A4`; `F131`: Rent -> `A5` | `A6 Carriers (Own)` | Unified 8-step KYC wizard |
| `F131`, `F135`, `F136` | `A3 Vehicle` -> `A5 Rental` -> `A8 Carriers (Rented)` | Rent bike branch | `A9 Payout Setup` | Pre-fitted carriers on rental |
| `F132`, `F133`, `F134` | `A6 Carriers (Own)` <-> `A7 (No Front)` | `F132` Front OFF -> `A7` (locks multi-service); `F133`/`F134` -> `A9` | `A9 Payout Setup` | Enforces Business Rule: Front carrier <= 8 kg required for multi-service |
| `F137`–`F140` | `A9 Payout` -> `A10 Terms` -> `Create Passcode` -> `Review & Submit` | Sequential | `Rider Home Pending` | **Fix:** A9 footer/title says "Vehicle Information", Review says "STEP 4 OF 4" & shows "Police Clearance" not asked in A2 & duplicates "Passcode" twice! |
| `F141` | `Rider Home Pending` | Refresh / Polling while pending | Stay on `Rider Home Pending` | Red/amber banner `"Verification in progress"` + locked Go Online (**Remove fake sample completed trips!**) |
| `F142` | `Rider Home Pending` | Admin approves KYC | `Rider Home Approved` | Dismissible green `"You're approved!"` banner |
| `F143`, `F158` | `Rider Home Approved` | `F143`: Continue / dismiss banner -> `Rider Home`; `F158`: `Go Online` -> `Go Online Sheet` | `Rider Home` / `Go Online Sheet` | Note: if rider has NOT verified front carrier + helmet, multi-service disabled |
| `F144` | `Enter Passcode` | Valid 4-digit PIN or biometric | `Rider Home` (`Home Pending` if still pending) | Add **`Rider Forgot Passcode`** (`OTP + NID last 4 digits`) missing screen! |
| `F145`–`F157` | `Rider Home` / `Rider Profile` / Subscreens | `F145` Profile; `F146` Security; `F147` Carrying Setup; `F148` Switch Role -> `Role Selection`; `F149`/`F156` Rental; `F150`/`F155` Notifications; `F151`/`F190` Earnings (`Wallet`); `F152`/`F194` Wallet; `F153` Job History (`Activity`); `F154` Security back; `F157` Go Online | Unified under `Home \| Activity \| Wallet \| Profile` | **IMPORTANT:** `Rider Profile` mockup lacks visible rows for `Security` (`F146`), `Carrying Setup` (`F147`), and `Switch Role` (`F148`) — must restore them! |
| `F159` | `Go Online Sheet` | Select services (`Parcel`, `Ride`, `Food`) -> `Go Online` | `Looking for Requests` | — |
| `F160`–`F167`, `F185` | `Looking for Requests` | Dispatch pings (`F160 Food`, `F161 Ride`, `F162 Parcel Solo`, `F163 Parcel Normal Multi-Service`); Declines `F164`–`F167` return; `F185` `Go Offline` -> `Rider Home` | Incoming modal sheets / `Rider Home` | **NOTE:** Solo Food execution (`F170 -> Job History`) & Solo Ride execution (`F195 -> Job History`) screens are **NOT SUPPLIED** in mockups! |
| `F168`, `F169` | `Incoming Request Parcel` (`F168`) / `Parcel Request (Normal Multi-Service)` (`F169`) | `Accept Request` | `Parcel Pickup (Multi-Service)` | **Rule:** Multi-service ONLY starts with a `NORMAL` Parcel (weight `<= frontMaxKg` & volume `<= frontVolume`) from **Zone A -> Zone B**. Accepting a Ride Share request first (`F161`) NEVER allows adding a parcel! |
| `F171`, `F172`, `F173`, `F174` | `Parcel Pickup (Multi-Service)` | `F171` (Eligible: front carrier verified + normal parcel fits front weight & volume + helmet + toggle ON) -> `Carrying Setup`; `F172` (Ineligible: Food / Express parcel / Ride-first / missing front carrier / no spare helmet) -> `Multi-service Unavailable`; `F173` Save -> `Parcel Deliver`; `F174` Got it -> `Parcel Deliver` | `Parcel Deliver (Multi-Service)` | Enforces Zone A -> Zone B readiness |
| `F175`–`F177` | `Parcel Deliver (Multi-Service)` <-> `Ride Add-on Request` | `F175` Ride request whose **pickup is in Zone A AND destination is in Zone B** matches active parcel corridor -> `Ride Add-on Request`; `F176` Accept -> `Passenger Pickup`; `F177` Decline -> `Final Parcel Delivery` | `Passenger Pickup` / `Final Parcel Delivery` | Strictly **Zone A -> Zone B matching**; Parcel Client & Ride Passenger NEVER see each other's leg |
| `F178`, `F179` | `Passenger Pickup` | `F178` Invalid 4-digit Start PIN -> Retry; `F179` Valid PIN + helmet confirmed -> `Multi-service Live` | `Multi-service Live` | Passenger Start PIN matches Client `Ride 4` `Start Trip PIN` |
| `F180` | `Multi-service Live` | `Arrived at Stop 1 (Drop Passenger)` | `Passenger Dropoff & Fare Collection` | Safety lock: **Passenger MUST drop first** before final parcel leg completes |
| `F181`, `F189` | `Passenger Dropoff & Fare Collection` | `F181` `Complete Dropoff & Head to Parcel` -> `Final Parcel Delivery`; `F189` Ride fare logged -> `Rider Earnings` | `Final Parcel Delivery` / Wallet ledger | — |
| `F182` | `Parcel Deliver (Multi-Service)` | `Slide when Arrived` (no ride add-on accepted) | `Final Parcel Delivery (Multi-Service)` | Direct single-parcel completion path |
| `F183`, `F184` | `Final Parcel Delivery` | `F183` Invalid Customer OTP -> Retry; `F184` Valid 4-digit Delivery PIN + POD photo + COD confirm -> `Batch Completion Summary` | `Batch Completion Summary` | Customer OTP matches Parcel Client's `Delivery Security PIN` |
| `F185`–`F188` | `Batch Completion Summary` | `F185` Find Next -> `Looking for Requests`; `F186` Break -> `Rider Home`; `F187` -> `Earnings`/`Wallet`; `F188` -> `Job History` (`Activity`) | Respective screens | — |
| `F190`–`F194` | `Rider Earnings` / `Wallet` / `Job History` / `Service Detail` | `F190` Earnings -> Wallet; `F191` Job row -> `Service Detail`; `F192` Navigate -> `Parcel Deliver`; `F193` Back -> `Rider Home`; `F194` Back -> `Rider Home` | Unified `Wallet` / `Activity` | `Service Detail` shows both Passenger + Parcel legs ONLY to Rider |

---

## 5. Complete Screen-by-Screen Inventory (108 Supplied + Inferred Missing)

To keep specifications clear and actionable for Phase 2 buildout, every single one of the **108 JPG screens** (plus missing screens needed for completeness) is cataloged below.

### 5.1 Auth & Onboarding (`7` Supplied Screens)
1. **`P&D - Splash Screen.jpg`** (`Entry`): Dark forest green (`#092113`) splash, V1.0 badge, 3 service badges, animated dots. *Change:* Rebrand `P&D` → **`2Bee`**. Route: check stored JWT -> valid returns to last role (`Enter Passcode` if Rider/Merchant locked after 15m), new user -> Onboarding 1, signed out -> Login.
2. **`P&D - Onboarding 1 of 3.jpg`**, **`2 of 3.jpg`**, **`3 of 3.jpg`**: Multi-service pitch slides (`Skip`, `Next ->`, `Get started`). *Change:* Rebrand `P&D EXPRESS` → **`2Bee`**. Ensure CNG/Car mentions align with supported tiers (`Ride` offers EV Bike / Auto / Sedan).
3. **`P&D - Login.jpg`**: `+880` 10-digit phone input (`17XX-XXXXXX`), `Send OTP`, **`Continue with Google`**, Terms & Privacy links. *Validation:* BD mobile regex `^1[3-9]\d{8}$`. *Changes:* **Remove `Continue with Google`** per Business Rule (or put behind feature flag disabled in config), build missing Terms/Privacy viewer.
4. **`P&D - OTP Verification.jpg`**: 6-digit OTP boxes, target phone + `Edit` icon, 30s countdown + `Resend Code`, custom numeric keypad, error state for expired/wrong OTP.
5. **`P&D - Role Selection.jpg`**: 3 radio cards (`Client`, `Rider`, `Restaurant`) + CTA. *Changes:* Fix **`#2563EC` blue accent → brand green `#006C04`**, fix text `"Both profiles use the same verified phone number"` → **"All roles share the same verified phone number"**, show dynamic badge (`Active`, `Verification Pending`, `Needs Changes`, `Passcode Protected`, or `Setup Required`).

### 5.2 Client Core (`4` Supplied + `2` Missing Tab Screens)
6. **`P&D - Client Home.jpg`** (`Tab 0: Home`): Greeting + Standard badge, Delivery Address dropdown, Search+Filter bar, Promotional Express Courier Banner, 3 Service Cards (`Parcel`, `Ride`, `Food`), `TRENDING IN <ZONE>` horizontal carousel, notifications icon. *Nav Change:* `Orders` → `Activity`. *Missing State:* Empty trending fallback, Location Picker modal.
7. **`P&D - Orders.jpg`** → **Becomes `Client Activity` (`Tab 1: Activity`)**: Currently shows Food orders only (`Active` / `Past Orders`, Contactless note, Recent purchases, Reorder). *Change:* Remove `Explore | Orders | Favorites` bar; add service filter chips **`All | Food | Parcel | Ride`** so Ride trips & Parcel shipments appear alongside Food orders; add empty state CTA.
8. **`P&D - Order Detail.jpg`**: Itemized Food receipt (`Subtotal`, `Delivery fee`, `Packaging`, `Service fee`, Promo code breakdown, `Total Paid` + payment method), Assigned Driver info, `Reorder`, `Need Help / Support`. *Extend/Complement:* Add equivalent `Ride Receipt` and `Parcel Receipt` detail layouts for unified `Activity`.
9. **`P&D - Notifications.jpg`**: Read/unread badge, `Mark all as read`, category filters (`All | Orders | Offers`), deep links (`Rate Order`, `View Receipt`, `Track Order`), SMS/Push preference sheet.
10. **MISSING: `Client Wallet` (`Tab 2: Wallet`)**: Wallet balance, Add money / Top-up (bKash/Nagad/Card), Saved Payment Methods, Promo Vouchers ledger, Refunds & Cashback transaction list.
11. **MISSING: `Client Profile` (`Tab 3: Profile`)**: Verified Name/Phone/Avatar, Saved Addresses (`Home`, `Work`, custom pins), `Favorites`, `Notifications`, `Help & Safety (SOS Contacts)`, **`Switch Role -> Role Selection`**, `Log Out`.

### 5.3 Client Ride (`5` Supplied Screens + Missing History/Receipt/SOS)
12. **`P&D Ride - 1. Map Radar & Location Selector.jpg`**: Live map + nearby vehicle pins, Pickup & Destination inputs, Saved chips (`Home`, `Work`, `Airport`), Recent Destinations, `2Bee` EV badge, `Find Rides ->`. *Change:* Remove bottom pill `Ride | Saved | Trips | Hub`.
13. **`P&D Ride - 2. Vehicle & Fleet Tier Selection.jpg`**: Interactive map preview + ETA/km, 3 fleet tiers (`2Bee EV Solo`, `Eco Auto / EV Trike`, `Comfort Sedan` — verify exact rates in Open Questions), Payment selector (`bKash`, `Cash` — align w/ Nagad/Card), Promo input, `Confirm`.
14. **`P&D Ride - 3. Courier & Rider Matching Radar.jpg`**: Animated radar, dispatch timer, `Cancel Request (Xs)` (auto-cancels at timeout or user confirm dialog).
15. **`P&D Ride - 4. Active Trip & Driver En-Route.jpg`**: Driver card (photo, plate, rating), Call + In-App Chat, `SOS` red action, `Start Trip PIN` (4 digits), Live route progress (`Driver arriving` -> `En route to destination`), `Share Live Trip Link`. *Fix:* Add distinct visual phase once PIN is entered & trip is in motion; wire `SOS` and `Chat`.
16. **`P&D Ride - 5. Trip Completion & Fare Rating.jpg`**: Trip distance/duration/CO2 badge (`2Bee EcoPoints`), Fare breakdown (Base + Distance + Waiting - Promo), 1–5 Star rating + feedback tags + Tip (`No tip`, `৳20`, `৳50`, `৳100`), `Submit Rating & Done`, `Download Invoice`.

### 5.4 Client Parcel (`4` Supplied Screens + Missing History/Rating/Cancel/Refund)
17. **`P&D Parcel - 1. Hub & Rate Calculator.jpg`**: Active parcel status banner, `2Bee EV Fleet` badge, Pickup & Dropoff fields, Recent drops, 3 Delivery Tiers (`Express`, `Standard Eco`, `Next-Day Saver`), Package Sizes (`Doc <=0.5kg`, `Small Box <=3kg`, `Medium <=8kg`, plus heavy parcel note if `>8kg` rear carrier allowed), CO2 readout, `Continue`. *Change:* Remove `Hub/Send | Shipments | History | Help` nav bar.
18. **`P&D Parcel - 2. Package & Carrier Specs.jpg`**: Step 1/2: Category chips, Weight stepper (`0.1` kg steps; enforce `<=8 kg` for Standard multi-service eligibility, `<=15 kg` solo rear), Cubic box size (`Small`/`Medium`/`Large`), Carrier indicator, Declared value (`BDT`), `Parcel Protection` toggle + fee, Handling instructions.
19. **`P&D Parcel - 3. Addresses & Payment.jpg`**: Step 2/2: Map polyline, Sender & Receiver details (Name, valid BD phone, Street, Floor/Apt, Note), Payment (`bKash`, `Nagad`, `Card`, `COD`), Itemized total, `Confirm & Dispatch`.
20. **`P&D Parcel - 4. Active Shipment & Tracking.jpg`**: Shipment ID, Rider card + `Call` + `Chat`, 4-digit `Delivery Security PIN`, 4-step milestone timeline, `Share Live Tracking`, `Need Help`. **MANDATORY BUSINESS RULE FIX:** Remove `"Zero-Detour Multi-Route: light parcel + Banani..."`, `"matched passenger route"`, `"alongside passenger commute"` — parcel clients must **NEVER** see passenger co-ride metadata!
21. **MISSING Parcel Screens**: `Parcel Delivery Rating & Receipt`, `Cancel Shipment & Refund Modal`, `Parcel Return-to-Sender Status`.

### 5.5 Client Food (`10` Supplied Screens)
22. **`P&D - Food Delivery Mobile.jpg`**: Delivery address pill, Search+Filter, Cuisines horizontal strip, Featured/Nearby restaurants (`badge`, ETA, fee, rating, wishlist heart), floating `View Cart` bar. *Change:* Remove `Explore | Orders | Favorites` bar; add `Home Kitchen` hygiene/daily cutoff availability badge where `type == HOME_KITCHEN`.
23. **`P&D - Search & Filter.jpg`**: Cross-food search box, quick filter tags (`Free Delivery`, `Under 30m`, `Top Rated`, `Halal`, `Home Kitchen`), Recent Searches + `Clear`, `Sort & Filter` modal sheet (`Price`, `Rating`, `Cuisine`, `Delivery Time`).
24. **`P&D - Favorites.jpg`**: Segmented **`Restaurants | Saved Dishes`**, unfavorite toggle, item add shortcut. *Changes:* Remove bottom bar; **fix `$15 / $1.50 / $0.99 / $2.00` USD bug → `৳` BDT!**
25. **`P&D - Restaurant Detail.jpg`**: Hero banner, Share + Favorite icons, rating/review count, prep ETA / fee / min order, Tap-to-Copy Promo Voucher, sticky category tabs, dish list (`+Add` / qty badge), floating Cart bar. *Home Kitchen Check:* Show remaining daily order slots / cutoff warning (`Closes at 8:00 PM`) and lock `+Add` once quota is full!
26. **`P&D - Item Customization.jpg`**: Bottom sheet (`Required` radio option group, `Optional` checkbox extras with `+৳`, qty stepper, special instructions, `Add to cart` / `Update cart`). Validates all required groups before unlock.
27. **`P&D - Cart.jpg`**: Merchant name, line items w/ option summary + `- / +` steppers + item delete at `0`, `+ Add more items`, Cooking instructions modal, Promo code apply/remove, Itemized bill (`Subtotal`, `Delivery`, `Packaging`, `Service Fee`, `Discount`, `Total`), `Go to Checkout ->`.
28. **`P&D - Checkout.jpg`**: Address + `Change`, Delivery instructions, **`Deliver Now | Schedule` time slot picker**, Payment (`bKash`, `Nagad`, `COD`, `Card`), Place Order CTA.
29. **`P&D - Order Placed.jpg`**: Success state, Order ID, 4-stage stepper (`Confirmed`, `Cooking`, `On the way`, `Delivered`), Payment TrxID, Rider dispatch indicator, `Track Live Order`, `Back to Food Home`.
30. **`P&D - Live Tracking.jpg`**: Live Rider GPS map + merchant/customer pins, ETA badge, Rider card (`Call` + `Chat`), 5-step milestone list, collapsible receipt, `Need help`. Delayed state shows delay banner (`F052`).
31. **`P&D - Delivered & Rating.jpg`**: Rate Restaurant (1–5★ + food quality tags) + Rate Rider (1–5★ + delivery tags + Tip `৳10/৳20/৳50/Custom`), Additional Comment, `Submit Review`, `Order again`.

### 5.6 Merchant Auth & KYC Registration (`19` Supplied Screens — Post-Approval 6-Digit Passcode)
32. **`P&D - Restaurant Login.jpg`**: Restaurant/Kitchen passcode pad (**update from 4 dots to 6 dots** + biometric button + `Forgot passcode?` + `Register your restaurant`). Used for daily login once approved & passcode is created.
33. **`P&D - Restaurant Forgot Passcode.jpg`**: Step 1 verify 6-digit SMS OTP (30s resend) + **Last 4 digits of Owner NID** -> Step 2 set new **6-digit** passcode.
34. **`P&D - Panel Login.jpg`**, **`P&D - Merchant OTP Verification.jpg`**, **`P&D - Approved with Passcode.jpg`**, **`P&D - Create PIN.jpg`**, **`P&D - Fingerprint Setup.jpg`**:
    - **FINALIZED FLOW:** During registration, the merchant sets **no passcode** and can open `Merchant Home Pending` (`Verification in progress`, store locked closed). Once Admin approves the merchant, a phone approval notice is dispatched; upon first login after verification, the merchant runs `Approved Notice` / `Merchant OTP Verification` -> **`Create 6-Digit PIN`** (`Create PIN`) -> optional **`Fingerprint Setup`**, after which the live `Merchant Home` panel unlocks! (`Panel Login` is kept optional only if using an activation ID fallback, or bypassed cleanly via phone session + OTP).
35. **`P&D - Restaurant Type.jpg`**: Choose `Physical Restaurant` (Trade License & e-TIN required) vs `Home Kitchen` (Hygiene checklist, daily cap, cutoff, e-TIN optional).
36. **Physical Restaurant Reg (`6` screens):**
    - `Step 1: Business Info` (Name, Cuisines, Full Address + GPS Pin, Commercial Area, Phone, Email; *fix wrong footer copy saying "Operating Hours & Capacity" -> "Legal Details"*).
    - `Step 2: Legal Details` (12-digit e-TIN, Trade License #, License PDF/Image <=15MB, Owner Full Name, NID 10/17 digits, NID Front/Back, Live Selfie).
    - `Step 3: Facebook Verification` (Public Page URL, copyable token `2B-XXXX`, verification checkbox).
    - `Step 4: Photos & Hours` (Storefront photo, Kitchen photo, 3 Dish photos, Avg prep time stepper, Day-by-day hours + `Copy Mon to all`).
    - `Step 5: Payout Setup` (`bKash`, `Nagad`, `Bank BEFTN`, Account Holder Name, Wallet/Acc No — MFS options selectable in UI/mock, BEFTN/Stripe test notes).
    - `Review and Submit` (Section summaries + `Edit`, Terms checkbox -> enters **`Merchant Home Pending`**, no passcode required while pending).
37. **Home Kitchen Reg (`6` screens):**
    - `Step 1: Kitchen Info` (Brand Name, Cook Name, Specialties, Residential Kitchen Address + GPS Pin + privacy badge, Area/Hub, Phone).
    - `Step 2: Identity` (NID 10/17 digits + Front/Back + Live Selfie + Optional TIN).
    - `Step 3: Facebook Page` (URL + verification token).
    - `Step 4: Food and Hygiene` (Clean kitchen photo + 3 dish photos, **`Max orders per day`** stepper default `15`, **`Daily cutoff time`** picker default `08:00 PM`, Est. Prep time default `45 min`, 3 mandatory hygiene declarations; *replace `Be-Green` copy*).
    - `Step 5: Payout Setup` (`bKash`, `Nagad`, `Bank`, NID-matched account holder).
    - `Review and Submit` (-> enters **`Merchant Home Pending`**, no passcode required while pending).
38. **`P&D - Verification Pending.jpg`** & **`P&D Merchant - Home Pending.jpg`**:
    - **BUG FIX:** Separate Rider steps (`Carrier check: front 8kg/rear 15kg`) from Merchant `Verification Pending`. Pending merchants view `Merchant Home Pending` (`"Verification in progress · Store stays closed until approval"` banner, locked Closed toggle, zeroed stats).
39. **`P&D - Merchant Needs Changes.jpg`**: Shows exact admin-flagged issues per field (e.g., blurry NID -> re-upload, FB token missing -> re-verify, bank mismatch) + `Resubmit Application ->`.

### 5.7 Split Merchant Panel (`14` Supplied Screens)
> **Approved Decision:** Dedicated **split Home & Store panels** for Physical Restaurant (`Physical Home` / `Store`) vs Home Kitchen (`Home Kitchen Home` / `Store`) sharing common `Activity (Orders)`, `Menu`, `Wallet (Earnings)`, `Promotions`, `Reviews`, `Security` components and unified **4-tab `AppBottomNav` (`Home | Activity | Wallet | Profile`)**.

40. **`P&D Merchant - Home.jpg` + `Home (Rina's Kitchen).jpg` (`Tab 0: Home` — Split Panel)**:
    - **Physical Restaurant Home**: Open/Closed live switch (+ `Pause 30 min`), Daily stats (`Orders`, `Sales ৳`, `Avg Prep`), Live incoming order cards, `Orders by Hour` bar chart, `Manage Menu` Quick Card.
    - **Home Kitchen Home**: Kitchen Open switch + `Batch Quota X / Y Orders` progress bar, `Order Cutoff` indicator, `Hourly Dispatch Activity` spline, `Available Tonight` dish toggles, `Manage Menu` Quick Card.
    - Both block live orders behind `"Verification in progress"` banner while pending, and require **6-digit Passcode creation** on first login after Admin approval before accessing active controls.
41. **`P&D Merchant - Orders.jpg` (`Tab 1: Activity`)**: Live Kitchen KPIs (`Avg Prep`, `On Time %`, `Rush Load`), segmented tabs **`New | Preparing | Ready | History`**, `Menu` shortcut icon in app bar, action buttons (`Mark Ready`, `Handover Scan`, `Slip`, `Call Rider`).
42. **`P&D Merchant - New Order Popup.jpg`**: Modal sheet with live countdown ring (`60s` auto-reject), Item summary + notes, Prep Time selector (`15m`, `20m`, `30m`, `40m`), `Accept Order`, `Reject Order`.
43. **`P&D Merchant - Reject Reason Sheet.jpg`**: Radio list (`Item unavailable`, `Kitchen too busy`, `Closing soon`, `Other reason` + note), ranking/visibility warning (*strip `P&D` copy & replace background Japanese mockup items with proper menu items*), `Confirm Reject`, `Keep Order`.
44. **`P&D Merchant - Order Detail.jpg`**: Order code, `Print Slip` / Thermal PDF action, 5-step progress, Assigned Courier + `Call Rider`, Itemized foods & customizations, Customer note, Payment & Commission summary (mock configurable default `15%`), `Mark as Ready`, `Report a problem`.
45. **`P&D Merchant - Menu.jpg` + `Add or Edit Item.jpg`** (Opened from `Home` / `Profile` / `Activity` shortcut): Search bar, Category chips, `+ Add Item`, `Bulk Edit`, per-item Availability switch, Duplicate, Edit. Editor modal/page: Photo upload, Name, Category dropdown, Price `৳`, Original Strike Price `৳`, Description (`<=200` chars), Prep time chips, Option Groups (`Required` single-select + `Optional` multi-select), `Bestseller` & `In Stock` switches.
46. **`P&D Merchant - Earnings.jpg` + `Payout Statement.jpg` (`Tab 2: Wallet`)**: `Today | Week | Month` segmented switch, Gross Sales, Platform Commission (`15%` mock default), Net Payout, Daily bar chart, Next Scheduled Payout countdown (mock default), Payout History list, `View Statement` -> `Payout Statement` (day-by-day itemized order totals, `Download Statement (PDF)`).
47. **`P&D Merchant - Store.jpg` + `Store (Rina's Kitchen).jpg` (`Tab 3: Profile` — Split Panel)**: Store avatar/status, `Manage Menu` shortcut, **`Promotions` & `Reviews` rows (restored per `F115`/`F116`)**, Store Profile, Operating Hours, Default Prep Time, **Home Kitchen Store adds `Daily Order Limit`, `Order Cutoff Time`, `Hygiene Standards` card**, Staff Accounts, **`Security & Passcode` (`6-digit` PIN + OTP 48h Payout Guard)**, Payout Account, Documents & Compliance, Help Hotline, **`Switch Role -> Role Selection`**, `Log Out`. (*Remove `Matcha Nocturne` footer!*).
48. **`P&D Merchant - Promotions.jpg`**: *Fix header title `Catalog Item Editor` → `Promotions & Offers`!* Toggle active campaigns, `Create New Offer` form (`Percentage %` / `Flat ৳` / `Free Delivery`, value, min order, item scope, start/end dates, dynamic margin preview, `Launch Promotion`).
49. **`P&D Merchant - Reviews.jpg`**: *Fix header title `Store Profile Settings` → `Customer Reviews`!* Average rating + star bar breakdown, filter chips (`All`, `5★`, `4★`, `With Comments`, `Critical`), public merchant `Reply` / `Edit Response` composer.
50. **`P&D Merchant - Security.jpg`**: Security Health score, `Change Passcode` (**6-digit** per Merchant spec), Biometric toggle, Auto-Logout (`15 minutes`), **Critical Payout Guard (`SMS OTP + 48-hour hold`)**, Active Devices list + `Log out device` / `Log out all others`, Audit & Activity Log.

### 5.8 Rider KYC Registration (`12` Supplied Screens)
51. **`P&D Rider - A1. Personal Info.jpg`**: Step 1/8: Full Name (matching NID), Verified Phone (read-only), DOB (`18+` check), Gender, Preferred Working Zone (e.g., `Banani / Gulshan` w/ rate hint), Emergency Contact (Name, Relation, BD Phone).
52. **`P&D Rider - A2. Documents.jpg`**: Step 2/8: *Fix clipped header title!* Driving License (Number/Expiry date, Front + Back photo), NID (Front + Back photo), Live Selfie holding License. (*Remove/add Police Clearance cleanly — `Review & Submit` lists Police Clearance as Uploaded even though `A2` never asks for it!*).
53. **`P&D Rider - A3. Vehicle Choice.jpg`**: Step 3/8: Radio cards `Own Bike` (`-> A4`) vs `Rent a Bike from 2Bee` (`-> A5`).
54. **`P&D Rider - A4. Own Bike Details.jpg`**: Step 4/8 (Own): Powertrain (`Petrol` / `Electric`), Brand & Model, Year, Registration Plate, Vehicle photo, Reg paper (optional for eligible e-bikes).
55. **`P&D Rider - A5. Rental Setup.jpg`**: Step 4/8 (Rental): Hub selector (`Banani Hub`, `Mirpur Hub`, etc.), Assigned bike preview + battery swap details, Rental Plan (`Daily ৳250/day`, `Weekly ৳1,500/wk`, `Rent-to-Own ৳320/day`), Handover Date & Time Slot, Pre-fitted carriers badge.
56. **`P&D Rider - A6. Carriers & Services (Own Bike).jpg`** & **`A7. Carriers (No Front Carrier).jpg`**: Step 5/8: Front Carrier toggle (L×W×H cm, Max 8 kg, Photo), Rear Carrier toggle (Photo), Computed Capacity (`e.g. 31.5L / 8kg front + 72L / 15kg rear`). **Business Rule Match:** When Front Carrier is OFF (`A7`), **`Multi-Service Mode` locks (`"Add a front carrier to unlock"`)**; when Front Carrier is ON (`A6`), rider can toggle `Multi-Service` + confirm **Spare Helmet checkbox**.
57. **`P&D Rider - A8. Carriers & Services (Rented Bike).jpg`**: Step 5/8 (Rental): Pre-verified Front `35×30×30 cm (8 kg)` & Rear `45×40×40 cm (15 kg)` carriers + `Multi-Service Mode` toggle + Spare Helmet checkbox.
58. **`P&D Rider - A9. Payout Setup.jpg`**: Step 6/8: *Fix header title `Vehicle Information` → `Payout Setup`!* Tabs `MFS Wallet` (`bKash`, `Nagad`, `Rocket` — confirm `Rocket` support!) | `Bank Account`, `Personal` | `Merchant` wallet radio, Registered Mobile, NID-matched holder validation, `Daily Instant Cash-out` toggle (`up to ৳2,000/day after 5 trips`). *Fix payout schedule Tuesday 10 AM inconsistency.*
59. **`P&D Rider - A10. Terms and Safety.jpg`**: Step 7/8: Rebrand `P&D Certified` hero photo, 4 expandable policy accordions (Conduct, Payload limits, Multi-service co-ride rules, Rental terms), 3 mandatory checkboxes -> `Agree and continue`.
60. **`P&D Rider - Create Passcode.jpg`**: Step 8/8: *Fix clipped header!* Permanent **4-digit passcode** creator (4 dots, block weak PINs like `1234`/`0000`, numeric keypad) + optional biometric setup prompt.
61. **`P&D Rider - Review and Submit.jpg`**: *Fix header clipping (`gistration Summar`), fix badge `FINAL STEP 4 OF 4` → `FINAL STEP`, remove Ghost `Police Clearance Certificate` row OR add optional upload on `A2`, remove duplicate `Passcode` row, replace `P&D` with `2Bee`.* Submits -> enters **`Rider Home Pending`**.

### 5.9 Rider Operations, Multi-Service & Settlement (`20` Supplied Screens + Missing Screens)
62. **`P&D Rider - Home Pending.jpg` & `Home Approved.jpg` & `Rider Home.jpg` (`Tab 0: Home`)**:
    - Pending shows amber banner `"Verification in progress · You can go online once approved"`, locked `Go Online` button, `Parcel/Ride/Food` locked `Pending`. **BUG FIX:** Clear fake `Recent Completed Trips` (`+85`, `+140`) from Pending empty state!
    - Approved adds dismissible green banner, unlocks `Go Online -> Go Online Sheet`, live service toggles (`Parcel`, `Ride`, `Food`), Hotspot Radar (`1.8x`), Bike Rental banner (`Browse`), Recent trips (`See History -> Activity`).
    - *All Rider screens:* **Fix `[NO GLYPH]` on `৳`** and unify clipped top headers + floating pill bottom bar → **`Home | Activity | Wallet | Profile`**.
63. **`P&D Rider - Enter Passcode.jpg`**: Avatar, `Welcome back`, 4-digit passcode dots, keypad + biometric unlock button, **`Forgot passcode?`**. (*Add missing `Rider Forgot Passcode` screen using `OTP + NID last 4 digits`!*)
64. **`P&D - Rider Profile.jpg` (`Tab 3: Profile`)**: Verified partner badge, metrics (`Rating`, `Acceptance`, `Completion`), Vehicle & Documents, My Bike Rental, Job History link, Payout Methods, Language (`EN/বাংলা`), Navigation app pref, Emergency SOS/Dispatch Support, Log Out. **ADD MISSING ROWS wired on flow map:** **`Security Settings & Passcode` (`F146`)**, **`Carrying Setup / Multi-Service Mode` (`F147`)**, **`Switch Role -> Role Selection` (`F148`)**.
65. **`P&D Rider - Security Settings.jpg`**: Account Guard status, `Change Passcode` (4-digit), Fingerprint toggle, Auto-lock (`15 mins`), Authorized Devices (max 3) + Remove, Payout guard notice (*Align copy: OTP + 48h hold on payout method changes, matching Business Rule*).
66. **`P&D - Bike Rental Home.jpg`**: Active rental hero card (`Manage Rental`), Available EV bikes filter & cards (`Rent this Bike`). *Rebrand `P&D` & `Glafit`.*
67. **`P&D - Rider Notifications.jpg`**: Read/unread inbox (`All | Requests & Trips | Earnings & Wallet | System`).
68. **`P&D Rider - Go Online Sheet.jpg`**: Service checkboxes (`Parcel`, `Ride`, `Food`, locked `CNG/Car` for bike riders), Vehicle + Zone selector (`Change`), `Go Online -> Looking for Requests`.
69. **`P&D Rider - Looking for Requests.jpg`**: Live Dhaka dispatch radar + surge zones, active service pills, Today summary, `Go Offline`.
70. **`P&D Rider - Incoming Request Food.jpg`**, **`Incoming Request Ride.jpg`**, **`Incoming Request Parcel.jpg`**: 15s countdown ring, guaranteed/estimated fare `৳`, payment mode (Online Prepaid / Cash on Drop / COD amount to collect), Pickup & Dropoff distances/addresses, customer/merchant badge, `Accept` / `Decline`.
71. **`P&D Rider - Parcel Request (Normal Multi-Service).jpg`**: Shows `Parcel · Normal`, delivery SLA (`12 hours`), `+detour mins`, front carrier load preview (`2 / 8 kg`), `"Fits front carrier ✓"`, `"Ride add-ons can be offered on this trip"`, COD collection banner, `Accept` / `Decline`.
72. **`P&D Rider - Parcel Pickup (Multi-Service).jpg`**: Sender contact (`Call`/`Chat`), Weigh & Measure confirmation (`<= 8.0 kg`), Step 2/2 Rack Placement (`Front Cargo Rack ACTIVE · Rear Passenger Seat Reserved`), mandatory camera **`Proof of Loading`** photo, `Slide to confirm Picked Up`.
73. **`P&D Rider - Carrying Setup (Multi-Service).jpg`**: Segmented **`Parcels only` | `Parcels + passengers`**, Carrier limits (`Front 8kg max`, `Rear Reserved`), **Multi-Service Dispatch Rules** (`1 passenger max`, `Normal parcels only`, `Passenger dropped first`), mandatory **`I have a helmet for the passenger`** checkbox, `Save setup`.
74. **`P&D Rider - Parcel Deliver (Multi-Service).jpg`**: Live turn-by-turn map, `RIDE RADAR ACTIVE` banner searching compatible passenger add-ons along corridor (**REMOVE `Demo: Incoming Request ->` dev button in prod build!**), Front carrier utilization bar, COD collection box, `Slide when Arrived`, `SOS`, `Open in Maps`.
75. **`P&D Rider - Multi-service Unavailable.jpg`**: *Fix wrong header `Cancel Task Confirmation` → `Multi-Service Status`!* Explains locking condition when task is Express, front carrier unverified, or multi-service disabled. **Fix contradiction** where card shows `Express Mode` badge YET checks `"A normal parcel is in your carrier"` green!
76. **`P&D Rider - Ride Add-on Request (Multi-Service).jpg`**: 12s countdown, Passenger add-on payout, 3-stop sequence (`1. Add-on Pickup -> 2. Passenger Drop (Before parcel) -> 3. Parcel Drop`), Detour & SLA buffer badges, front rack compatibility check. *Fix cargo label `"Express Parcel"` → `"Normal Parcel"`!*
77. **`P&D Rider - Passenger Pickup (Multi-Service).jpg`**: Passenger card (`Call`/`Chat`), reminder `Front Carrier Occupied · Rear Pillion Reserved`, 4-digit **`Enter passenger PIN`**, mandatory **`Passenger has a helmet`** checkbox, `Start trip ->`.
78. **`P&D Rider - Multi-service Live.jpg`**: *Fix header `Passenger Pickup` → `Active Multi-Service`!* Combined payout banner, live map (`Stop 1/2`), speed telemetry, Multi-Stop Sequence (`Stop 1 Passenger Drop` -> safety rule note -> `Stop 2 Parcel Delivery`), capacity status cards, `Report Detour`, `SOS`, `Arrived at Stop 1 ->`.
79. **`P&D Rider - Passenger Dropoff & Fare Collection.jpg`**: *Fix clipped header!* Cash/Digital fare collection summary, `Cash Collected` confirm, 2/2 Safety checks (`Helmet returned & sanitized`, `Dismounted on curb`), Stop 2 Parcel preview (*fix label `"Remaining Ride Payout"` → `"Parcel Leg Payout"`!*), `Complete Dropoff & Head to Parcel ->`.
80. **`P&D Rider - Final Parcel Delivery (Multi-Service).jpg`**: Recipient profile + delivery instructions, Front carrier inspection, COD cash collection confirm checkbox, Proof of Delivery (`ID check`, **4-digit Customer Delivery OTP**, Geo-tagged Delivery Photo), `Complete Delivery & Finish Batch ->`.
81. **`P&D Rider - Batch Completion Summary.jpg`**: Combined batch duration + earnings breakdown (`Leg 1 Ride + Leg 2 Parcel + Tips`), Total Cash Handled (`COD + Ride Cash`), Vehicle Readiness check, `Find Next Request`, `View Wallet`, `Take a Break`. *Fix `(Express base)` / `(Express D...)` copy → `(Normal Parcel)`.*
82. **`P&D - Rider Earnings.jpg` + `P&D - Rider Wallet.jpg` → Unified `Rider Wallet` (`Tab 2: Wallet`)**:
    - Segmented top switch **`Wallet & Payouts` | `Earnings Analytics`**:
    - Balance card (Total Available Balance, **Cash-in-Hand / COD Settlement Tracker** — *added gap!*, `Withdraw` CTA), **Bike Rent Auto-Debit card** (`৳250/day` + schedule), Quick actions (`Withdraw`, `Bank Transfer`, `Statement`), Filterable Ledger (`All | Earnings | Deductions`), Weekly/Daily Bar Chart & Breakdown (`Base`, `Surge`, `Tips`, `Bonuses`).
83. **`P&D - Rider Job History.jpg` (`Tab 1: Activity`)**: Search bar, **`Live | Completed`** toggle, **`All | Food | Parcel | Ride`** filters, Multi-service Live Batch card (`#MULTI-XXXX` showing both Parcel & Ride legs exclusively to Rider), Past Services grouped by day.
84. **`P&D Rider - Service Detail.jpg`**: Live route map, `Multi-Service Flow` showing both legs with timestamps, Earnings Breakdown, both customer cards (only for Rider!), `Navigate` CTA, `Scan Consignment`, `Report Route Issue`. *Reconcile conflicting sample figures (`৳250` vs `৳260` vs `৳280`, `2.0kg` vs `3.5kg`, `Prepaid` vs `৳1,200 COD`, `Road 13` vs `Road 14`).*

### 5.10 Missing / Unsupplied Screens Required for Complete End-to-End Flow
1. **Admin Approval Dashboard / API UI**: Required by Business Rules (`approve` / `needs-changes` / `reject` Rider KYC & Merchant KYC, view NID/License/Selfie/FB token/Carrier dimensions).
2. **Client `Wallet` Tab** & **Client `Profile` Tab**.
3. **Client Ride History (`Activity -> Ride`) & Ride Invoice/Detail**.
4. **Client Parcel History (`Activity -> Parcel`), Parcel Delivery Completion & Rating, Parcel Cancellation/Refund/Return**.
5. **Rider Standalone Food Execution (`Accepted -> Arrived Restaurant -> Picked Up w/ Photo -> Arrived Customer -> Delivered w/ COD`)** & **Rider Standalone Ride Execution (`Accepted -> Arrived Pickup -> Enter Passenger Start PIN -> En-Route -> Dropoff & Fare Collection`)** (`F170`, `F195` explicitly flagged unsupplied on flow map).
6. **Rider `Forgot Passcode`** (`OTP + NID last 4 digits`, matching Merchant's flow) & **Rider `Needs Changes` / `Rejected`** KYC screens.
7. **In-App Real-Time Chat Screen** (referenced from Client `Ride 4`, `Parcel 4`, `Live Tracking`, and all Rider active legs).
8. **Emergency `SOS` Drawer / Live Safety Center** (referenced from `Ride 4`, `Parcel Deliver`, `Multi-service Live`, `Rider Profile`).
9. **Simulated/Hosted Payment Gateway Screen** (bKash / Nagad / SSLCommerz Card payment sheet for Food Checkout, Parcel, Ride, and Client Wallet Top-up).
10. **Legal (`Terms of Service`, `Privacy Policy`) & `Help & Support` Center**.
11. **Merchant Sub-views**: `Edit Store Profile`, `Operating Hours Editor`, `Staff Accounts Manager`, `Order Thermal Slip Preview`.

---

## 6. Consolidated Gaps, Rule Conflicts & Finalized Resolutions

| # | Severity | Category | Conflict / Defect Observed | Finalized Decision (User Approved) |
|---|---|---|---|---|
| 1 | **CRITICAL** | **Privacy / Rule** | `Parcel 4. Active Shipment & Tracking.jpg` displays `"Zero-Detour Multi-Route"`, `"matched passenger route"`, and `"alongside passenger commute"` to the Parcel Client. | **Enforce strict privacy:** Replace banner/milestones with neutral parcel-only copy. Neither Parcel Client nor Ride Passenger sees the other service. |
| 2 | **CRITICAL** | **Auth / Rule** | `P&D - Login.jpg` displays `Continue with Google`. | **Removed** (`One account per phone, OTP login only`). |
| 3 | **CRITICAL** | **Auth & Passcodes** | `Restaurant Login` showed 4 dots while `Create PIN` & `Merchant Security` showed 6 digits; timing of passcode creation conflicted. | **Resolved:** **Rider = 4-digit passcode set AT registration (Step 8)**; **Merchant = 6-digit passcode set AFTER Admin Approval** (no passcode during KYC reg; pending owners view `Merchant Home Pending` locked; upon first post-approval login, OTP + **Create 6-digit Passcode** unlocks live Merchant Home!). Update `Restaurant Login` to 6 dots. |
| 4 | **CRITICAL** | **Merchant Panel Split** | Physical Restaurant vs Home Kitchen have dedicated Home & Store layouts (`Rina's Kitchen`). | **Approved Split Merchant Panel:** Dedicated `Physical` vs `Home Kitchen` Home & Store views sharing common Orders, Menu, Wallet, Promotions, Reviews, Security components. |
| 5 | **CRITICAL** | **Multi-Service Dispatch** | Mockup copy contradicts Normal-only rule (`Express Parcel / Express base`, `Express Mode` green check contradictions). | **Exact Multi-Service Spec Applied:** Strictly **NORMAL parcels only** (never Express, never Food) fitting **`<= frontCarrierMaxKg` & `<= frontCarrierVolume`**, starting with **Parcel first** (Ride-first requests lock out multi-service). Active Parcel **Zone A -> Zone B** filters matching Ride Share requests starting in **Zone A** & ending in **Zone B**. **Passenger dropped 1st, Parcel delivered 2nd.** Tracked exclusively on Rider side. |
| 6 | **HIGH** | **Navigation** | Mockups mix incompatible bottom bars across services/roles. | **Approved 4-Tab Role-Aware `AppBottomNav` (`Home \| Activity \| Wallet \| Profile`)** with role-tailored icons/screens & stripped service bars. |
| 7 | **HIGH** | **Missing Hub Links** | `Merchant Store` lacks `Promotions`/`Reviews` rows; `Rider Profile` lacks `Security`, `Carrying Setup`, `Switch Role` rows. | **Restore** all missing links in respective `Profile` tab screens. |
| 8 | **HIGH** | **Payout Guard Rule** | `Rider Security Settings` mentions 4-digit PIN vs `Merchant Security` SMS OTP + 48h hold. | **Enforce uniformly:** Payout account changes require **SMS OTP + 48-hour hold** for both Rider and Merchant. |
| 9 | **HIGH** | **Payments & Gateways** | Mockups vary between bKash/Nagad/Rocket/Card/COD. | **2 Payment Categories (`COD` & `Online`):** Wire **Stripe Free Sandbox** for live functional Online test-card payments; keep **`bKash`, `Nagad`, `Rocket`** as selectable upcoming UI options without live gateway credentials for now. |
| 10 | **HIGH** | **Pricing / Commission / Schedule** | `Order Detail` (`0% Waived`) vs `Earnings` (`15%`); payout days differ (Tue/Wed/Fri). | **Approved Configurable Mock Defaults:** Use configurable mock BDT rates (`15%` platform commission, rental tiers `৳250`–`৳400/day`, Friday payout schedule, Ride/Parcel formulas) stored in DB/config so exact commercial terms swap in cleanly later. Add Rider COD Cash-in-Hand reconciliation card in Wallet. |
| 11 | **MEDIUM** | **Currency & Glyph Bugs** | `Favorites` shows `$`; `Home Pending` shows `§0`; Rider screens show `[NO GLYPH]` box on `৳`. | Enforce `BDT (৳)` and bundle `Noto Sans Bengali` / fallback glyphs for U+09F3 (`৳`). |
| 12 | **MEDIUM** | **KYC & Mockup Bugs** | `Verification Pending` mixes Restaurant + Rider text; Rider `Review & Submit` shows ghost `Police Clearance` & duplicate `Passcode` row; `Rider Home Pending` shows fake past trips. | Separate schemas cleanly, sync step numbering, remove `Police Clearance` ghost & duplicate rows, clear sample trips from Pending states. |
| 13 | **MEDIUM** | **Copy & Visual Bugs** | Wrong headers (`Promotions`, `Reviews`, `Unavailable`, `Multi-service Live`, `A9`), Japanese item backdrop, `#2563EC` blue Role Selection, `Demo` button, legacy brands (`P&D`, `GF`, `PPRO`, `Matcha`, `Be-Green`, `Glafit` EV tier copy). | Fix all titles/colors (`#006C04` + `#F5FBF7`), rebrand to **`2Bee` / `2Bee EV`** (`Glafit` kept only if hardware label needed), remove dev button in prod UI. |

---

## 7. Finalized Technical Choices & Architecture Answers

1. **Q1 — SMS / OTP (`100% Free`)**: Free local Mock/Console SMS adapter (`DEV_STATIC_OTP=123456` + stdout logging + optional dev OTP helper pill in non-prod Flutter build) behind `SmsProvider`, ready to swap SSL Wireless / GreenWeb / Twilio later.
2. **Q2 — Payments (`Free Sandbox + MFS UI`)**: Dual mode **`Cash on Delivery (COD)`** + **`Online Payment (Stripe Test Sandbox)`** using free Stripe test keys, plus visible non-functional **`bKash`**, **`Nagad`**, **`Rocket`** UI chips/cards marked cleanly for later activation.
3. **Q3 — Admin Portal Scope**: Build full **REST Admin APIs (`/api/v1/admin/*` + CLI/Postman/seed helpers)** in Phase 2 for approving/flagging Riders & Merchants; keep the lightweight **Web Admin UI** documented in roadmap for Phase 3 while 100% of current implementation focuses on Flutter mobile + Node backend.
4. **Q4 — Mock Economics**: Configurable BDT mock rate tables stored cleanly in PostgreSQL/config (`Ride` tiers, `Parcel` rates, `15%` Food commission, `৳250`–`৳400` rental auto-debit).
5. **Q5 — Maps & Places (`100% Free`)**: **OpenStreetMap (`flutter_map`) + Nominatim/Photon + OSRM** + `url_launcher` Google Maps deep link.
6. **Q6 & Q7 — Nav, Panels, Auth & `2Bee` Branding**: Approved `AppBottomNav` 4 tabs across all roles (`Home | Activity | Wallet | Profile`), Split Merchant Panel, no Google Login, **Rider 4-digit reg PIN** vs **Merchant 6-digit post-approval PIN**, clean `2Bee` rebrand (`#F5FBF7` scaffold + `#006C04` green).
7. **Technical Evaluation — Realtime Rider Location (`Redis GEO`) & Live Tracking (`WebSockets`)**:
   - **Redis GEO (`GEOADD` / `GEOSEARCH` + Zone Sets) — RECOMMENDED & KEPT:** Excellent, battle-tested free choice (`redis:7-alpine` / Upstash free tier). Avoids write pressure on PostgreSQL from 5s GPS pings and supports sub-millisecond radius queries. For your exact **Zone A -> Zone B Multi-Service Rule**, pairing **Redis GEO** (rider GPS) with **Redis Zone Hash/Set keys** (`ms:parcel:from:{zoneA}:to:{zoneB}` + spatial polygon/ward lookup) delivers O(1) corridor matching! *(Alternative at hyper-scale: Uber **H3** hexagonal indexing on Redis, which is easy to swap inside our `GeoMatchService` later).*
   - **WebSockets (`Socket.IO`) — RECOMMENDED & KEPT:** The best free bidirectional choice for streaming live Rider GPS upstream, receiving `15s`/`60s` dispatch popups & Zone A->Zone B Ride Add-on pings downstream, pushing order milestones, and powering in-app chat — with automatic HTTP long-polling fallback on shaky mobile data networks. *(Alternative like SSE is unidirectional only and cannot stream rider GPS/chat cleanly without extra REST calls; Firebase RTDB hits paid Spark quotas at scale).*

---

## 8. Finalized System Architecture

### 8.1 Free Resource Monorepo Stack
- **Mobile (`mobile/`)**: Flutter (Dart), Riverpod, GoRouter (role-tailored 4-tab `AppBottomNav`: Client `Home|Activity|Wallet|Profile`, Rider `Home|Jobs|Wallet|Profile`, Merchant `Home|Orders|Wallet|Store` + Split Merchant Home/Store), Dio (JWT + 15-min inactivity tracker), `socket_io_client`, `flutter_stripe` (test sandbox) + COD/MFS UI, `flutter_map` (OSM) + OSRM/Nominatim client, `flutter_secure_storage`, `local_auth`, `image_picker`, `flutter_local_notifications`, `Noto Sans Bengali` fallback for `৳`.
- **Backend (`backend/`)**: Node.js + TypeScript + Express + **PostgreSQL + Prisma** (`pglite` / Docker PG options so zero-Docker local & prod PG both run cleanly) + **Redis (`ioredis` GEO + Zone A->B matcher + `H3IndexStrategy` hyper-scale hook + in-memory Redis GEO fallback when local Redis absent)** + **Socket.IO** + **Stripe Node SDK (Sandbox)** + Local disk Multer uploads + `pdfkit` + Zod + Docker Compose (`postgres:16-alpine` + `redis:7-alpine`).

### 8.2 Key Schema & Security Updates
- **`MerchantProfile`**: `merchantType` (`PHYSICAL` | `HOME_KITCHEN`), **`pinHash` nullable until `APPROVED`**, `passcodeSet` boolean (`false` initially -> gated at first post-approval login via OTP -> `Create 6-Digit PIN`), `dailyOrderLimit`, `dailyCutoffTime`, `hygieneConfirmed`.
- **`RiderProfile`**: `pinHash` required at registration Step 8 (4-digit), `frontCarrierMaxKg` (`8.0`), `frontCarrierVolumeCm3`, `rearCarrierVerified`, `spareHelmetConfirmed`, `multiServiceEnabled`.
- **`ParcelShipment` & `RideTrip` & `MultiServiceBatch`**:
  - Adds **`originZoneId`** & **`destinationZoneId`** on both `ParcelShipment` and `RideTrip`.
  - Dispatch matching rule: Rider accepts Ride Add-on ONLY when `activeBatch == NULL`, `activeParcel.tier == NORMAL`, `activeParcel.weightKg <= frontMaxKg`, `activeParcel.volume <= frontVol`, `ride.originZoneId == activeParcel.originZoneId`, and `ride.destinationZoneId == activeParcel.destinationZoneId`.
  - Execution state machine enforces `PASSENGER_DROPPED` -> `PARCEL_DELIVERED`. Client DTO serializers **never join or return** cross-leg fields (`Parcel 4` & `Ride 4` are 100% blind to multi-service batching!).
- **Dual-Layer Session & Timers**:
  - Phone OTP JWT (`accessToken`/`refreshToken`) + Role Unlock JWT (`4-digit` Rider / post-approval `6-digit` Merchant) with **15-minute inactivity enforcement**.
  - `PendingPayoutChange`: **SMS OTP + 48-hour hold** before switching payout accounts for both Rider & Merchant.
- **API Route Groups**: `/auth/*`, `/client/*`, `/rides/*`, `/parcels/*`, `/food/*`, `/merchant/*` (physical & home-kitchen endpoints), `/rider/*` (kyc, online, geo-heartbeat, multi-service, wallet, rental, history), `/payments/*` (`cod`, `stripe/create-intent`, `stripe/webhook`), `/chat/*`, `/notifications/*`, `/sos/*`, `/admin/*` (API-ready for KYC approval testing & future lightweight portal).


