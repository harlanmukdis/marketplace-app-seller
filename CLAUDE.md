# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **This document has two parts, and they do not describe the same thing.**
> **Part 1 — Current state** is what the code actually is today; verified against the repo.
> **Part 2 — Target architecture** is where the project is headed. It is now **partly built** — the migration checklist marks what landed.
> Never run a command or follow a pattern from Part 2 until the corresponding migration step is done. If the two parts conflict, Part 1 wins for any change you make right now.

---

## Where things stand — read this first (2026-09-28)

**The API catch-up and the Xpedia Partners redesign are underway: the
foundation and the order/wallet core are done, the long tail is not.** The app
now targets API **v1.28.0** and the design pack in
`assets/stitch_xpedia_seller_project/` (`design.md_1.md` is the design system;
`design.md_2.md` and the two `prompt_pack_seller` files are duplicates). Treat
the design pack as a product spec that outranks older screens, and treat every
🔴 trap further down as stale until re-verified — much of Part 2 predates
v1.6.0.

### Landed (2026-09-28)

- **Design foundation.** `lib/core/utils/xpedia_tokens.dart` (`XColors`,
  `XTone` status pairs, `XText` type scale, `XSpace`, `XRadius`, `XSize`);
  Inter bundled under `assets/fonts/inter/` and set as `kFontFamily`; the
  legacy `k*` colour constants remapped to the Xpedia palette so un-migrated
  screens pick it up; `app_theme.dart` and `customAppBar` restyled.
  Components in `lib/core/widgets/xpedia/x_widgets.dart` (`XButton` in the
  four allowed styles, `XCard`, `XChip`, `XBanner`, `XAppBar`, `XListGroup`,
  `XEmptyState`, …). New screens use these, not `AppStyles`.
- **Shell.** Five tabs — Beranda, Pesanan, Produk, Chat, Akun. The shell owns
  one `OrderListCubit` that Beranda, the Pesanan tab and its badge share. The
  long tail of modules is reached from the Akun tab.
- **Orders (S-13, S05, S-15/16/17, S-20, S-21).** No accept step (removed in
  v1.6.0): "Cetak Resi" runs pack then ship. Masked buyer (`shipping_address`
  is city + province only), fixed six-line earnings panel (estimated at 5%
  until `settlement` arrives on completion), SLA countdown, Tolak Pesanan,
  custom-order confirm, partial fulfilment, Final Invoice, handover method,
  Secure+ evidence upload.
- **Wallet (S-38, S-39, S-44).** Withdrawal takes `bank_account_id` + 6-digit
  `pin`; saved accounts (max 3, holder name must equal the account name);
  PIN set/change screen.
- **New modules.** Xpedia 911 support tickets (S-41, S-42); store settings
  (S-43); store `primary_status` / Signature badge / `sku_quota`; business
  verification PIC fields and the `DUPLICATE_IDENTITY` message.

- **Products (S-26, S-27, S-32), 2026-09-28.** Stock mode + lead time on
  create/edit (`fulfillment_mode`, seven chips per design rule 9 — the list
  shows the configured mode, the detail's `availability` adds Low Stock /
  Stok Kosong), SKU-capacity bar when `sku_quota` is set, per-product shipping
  coverage sheet, a photo per variant uploaded with `context=product_photo`
  (the server watermarks it — verified), "Simpan & Tayangkan", and the Xpedia
  Growth screen with the real 7-day report. `explainProductError` gives
  readable text for `SKU_QUOTA_EXCEEDED`, `PRODUCT_PROHIBITED`,
  `RESTRICTION_REVIEW_PENDING`, `CERTIFICATION_REQUIRED`,
  `NATURAL_PERFORMANCE_TOO_LOW`, `GROWTH_LOCKED`.
- **S-27 was rebuilt to the design on 2026-09-29** after a field-by-field
  check of the schema and routes. Kept out because the API has no field:
  Merek, Kondisi, Harga Grosir, Dangerous Goods/MSDS; Dimensi Kemasan has a
  `products.dimensions` column but no endpoint writes it. Secure+ is chosen by
  the buyer per transaction, never a product toggle. BPOM/Halal/SNI
  (`/products/{id}/certifications`, which validates nothing server-side)
  takes the MSDS box's place. Photos are one per variant — `product_images`
  is read-only — and creating a product now turns the server's generated
  variant into the first row and adds the rest (verified live in the
  onboarding test).
- **`XButton` in a `Row` with bounded height** used to fill it (a `Center`
  without `heightFactor`), which blanked the product form behind its own
  bottom bar. Fixed in `x_widgets.dart`; keep both factors.
- 🔴 **Growth locks on a no-op.** `PATCH /products/{id}/growth` with the value
  the product already has answers 200 *and* locks the setting for 7 days —
  verified by sending 0 to a product at 0. `GrowthCubit.save` refuses an
  unchanged value locally; keep it that way.
- **No seller-readable moderation state and no Natural Performance score.**
  S-28 and the ≥60 gauge in S-32 have no endpoint behind them; the app learns
  of both only from the refusal (`RESTRICTION_REVIEW_PENDING`,
  `NATURAL_PERFORMANCE_TOO_LOW`).

### Where the design and the API disagree (decided in favour of the API)

- **AWB is typed, not generated.** `POST /orders/{id}/ship` still requires
  `awb_number`; there is no courier integration behind "auto-generated resi".
- **One SLA of 48 plain hours**, not two in working days — that is what
  `order_resi_sla_worker` enforces (`OrderSla`).
- **No buyer name at all**, not `D******` — the seller payload carries none.
- **No "Saldo Ditahan"** — `held_balance` is never written.
- **Xpedia 911 categories** are the server's four (`order_transaction`,
  `payment_wallet`, `account_security`, `report_violation`), not the design's
  (Pesanan, Pengiriman, Wallet, Produk). Needs a product/backend decision.
- **No Secure+ flag on the order**; evidence becomes mandatory only when ship
  answers `SECURE_PLUS_EVIDENCE_REQUIRED`.

### Not yet done, in suggested order

1. **Chat (S-29/30):** 4-state ticks from `status` / `delivered_at`,
   `CHAT_CONTENT_BLOCKED`, no video. The store inbox endpoint is still missing.
2. **Performance & analytics (S-33, S-35):**
   `/stores/{id}/partners-performance`, `/customer-segmentation`,
   `/stock-mismatch-events`.
3. Restyle the remaining pre-redesign screens (inventory, promotions,
   merchandising, notifications, verification, auth) on the X components.

## Project identity

Flutter e-commerce **seller app**, duplicated from `markas-app-member` on 2026-09-05 and rebranded. Both projects descend from the same purchased UI kit, so the sample code under `lib/features/` is identical in the two trees.

- Directory: `marketplace-app-seller` (renamed from `markas-app-seller` on 2026-09-13, when the backend was replaced)
- Dart package name (`pubspec.yaml`): **`navy_wear`** — absolute imports are `package:navy_wear/...`. Renaming this breaks every absolute import plus `test/widget_test.dart`. **Deliberately left identical to `markas-app-member`** so a widget or cubit can be copied between member and seller without rewriting imports. Do not rename it in only one of the two projects.
- Product name / bundle id: **Marketplace Seller** / `com.marketplace.seller` (Android `namespace` + `applicationId`, iOS + macOS `PRODUCT_BUNDLE_IDENTIFIER`), and `MaterialApp.title`. The member app keeps its own id, so both can be installed on one device.
- Android `MainActivity.kt` lives at `android/app/src/main/kotlin/com/marketplace/seller/` and declares `package com.marketplace.seller` — this must stay in sync with the gradle `namespace`, because `AndroidManifest.xml` refers to the activity as the relative `.MainActivity`.

---

# Part 1 — Current state

## Commands

```bash
flutter pub get                       # install dependencies
flutter run -d chrome                 # the target platform for this app (see below)
flutter run                           # run on connected device/emulator
flutter analyze                       # static analysis (flutter_lints 4.0.0 via analysis_options.yaml)
flutter test                          # run all tests
flutter test test/widget_test.dart    # run a single test file
flutter test test/widget_test.dart --plain-name 'Counter increments smoke test'   # single test case
flutter build apk --release           # Android
flutter build ios --release           # iOS
```

**macOS is the proven target; Chrome became possible again on 2026-09-20.**
The API used to send no CORS headers, which blocked the web build outright.
It now answers preflight with `204` and allows `X-Store-Id`, so the web build
should reach it — but every integration test and every manual run to date has
been on macOS, so treat Chrome as unverified rather than as working.

```bash
flutter run -d macos                              # the proven target
flutter run -d chrome                             # unblocked since CORS landed; not yet exercised
flutter test integration_test -d macos            # drives the real app against the running backend
```

`macos/Runner/*.entitlements` must keep `com.apple.security.network.client` — the
app is sandboxed, and without it every request fails in a way indistinguishable
from the server being down. `integration_test/` is excluded from `flutter test`
(which only walks `test/`), so it never runs in CI without a backend. Run those
**one file per invocation** — a second file in the same run cannot start the app
— and note that a macOS debug build needs a few GB free: out of disk, the build
fails as `lipo: can't write to output file`, which looks like anything but a
disk problem. See [integration_test/README.md](integration_test/README.md).

Regenerate localizations after editing `lib/l10n/*.arb`:

```bash
dart run intl_utils:generate          # requires: dart pub global activate intl_utils (not a declared dev_dependency)
```

There is **no `build_runner` step in this repo** — no `freezed`, `json_serializable`, or `envied` is installed. This is deliberate, not merely unfinished: see *Seller API integration* below.

Point the app at a different backend without editing code:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1
flutter run -d chrome --dart-define=LOG_HTTP=false      # silence the request log
```

`intl` is pinned to `^0.20.2`. Flutter 3.41's bundled `flutter_localizations` requires exactly `0.20.2`, and the kit's original `^0.19.0` made `flutter pub get` fail outright.

## Architecture

**Two architectures coexist in `lib/` right now, on purpose.**

- The **UI kit** (`lib/features/auth`, `home`, `my_cart`, `favorites`, `trending`, `onboarding`, `profile`, `spalsh`, `notifications&messages`, `shared`) still has no backend. `HomePageCubit.productsTShirt` and friends are hardcoded lists. Nothing about it changed.
- The **seller app** (`lib/config`, `lib/core/data`, `lib/core/domain`, `lib/di`, `lib/features/seller_*`) talks to the marketplace API and follows the Part 2 layering. New seller work goes here.

When the two conflict, follow the seller-app conventions for anything touching the API, and the kit's conventions for anything touching its screens. Do not retrofit one onto the other file by file.

### Marketplace API integration

Backend: CodeIgniter 3 + MySQL + JWT at **`http://localhost:8000/api/v1`**. The contract lives in `~/Desktop/Harlan/marketplace-api`. Read them in this order:

1. **`docs/23-frontend-integration-guide.md`** — written by the backend team for exactly this app. Module→app map, the seed accounts, the core buyer and seller flows, and a list of traps each marked `[terverifikasi]` where it was reproduced against a running server. Start here. **It gets renumbered every time a doc is inserted below it**: `18-…` until 2026-09-17, `19-…` until 2026-09-20 (when `19` became the security audit findings), `20-…`/`22-…` in between, and `23-…` since 2026-09-29, when `22` became the buyer-blueprint gap analysis. Always `ls docs/` rather than trusting the number here.
2. **`CHANGELOG.md`** — added with the v1.1.0 tag on 2026-09-17 and now the fastest way to see what moved: it names each fixed bug and added field. Read it before `git log`. Currently at **v1.5.0** (2026-09-21); v1.2.0 carried a security audit that changed behaviour this app depends on, so do not skip the entries between tags.
3. **`postman/Marketplace-API.postman_collection.json`** — the real request bodies, and the tiebreaker whenever a field name is in doubt.
4. **`application/config/routes.php`** — the only complete list of what is actually dispatchable.
5. `docs/03-api-documentation.md` — the original design doc. Useful for intent, wrong often enough about specifics that it loses every disagreement.

The backend team ships continuously and the app has been caught out by silent payload changes more than once, so start a session by reading `CHANGELOG.md` and diffing `routes.php` — not by assuming last session's shapes still hold.

**This replaced a completely different backend on 2026-09-13.** The app previously talked to Markas Bangunan, a building-material marketplace with one store per account. Everything domain-specific to that — SKU master, price tiers, zone/fleet shipping tariffs, proof of delivery, returns and disputes, the four activation gates — was deleted rather than adapted, because none of it has a counterpart here. Git history before that date is the reference if any of it is ever needed.

What changed conceptually, and why it touches everything:

- **An account is not a store.** Every account registers as a buyer and becomes a seller by opening a store, and it can own several. `SessionStore.activeStoreId` is a UI choice, not an identity — losing it logs nobody out, it just means the app has to ask which store to open. `StoreCubit` is provided **above the router** in `main.dart` for exactly this reason: go_router reuses the home page, so a cubit owned by that page would never reload and a newly created store would stay invisible.
- **`X-Store-Id` accompanies the bearer token** on every store-scoped call. `AuthInterceptor` adds it from the stored active store unless the caller set it explicitly. Keep sending it: where it *is* read, forgetting it produces a 403 that reads like a permission bug. Note that it is not uniformly enforced — every endpoint carrying the store in its path (`/stores/{id}/products`, `/stores/{id}/warehouses`, `/stores/{id}/wallet`, `/warehouses/{id}/stocks`) answers correctly without the header, so a missing-header bug will not surface in testing and then will surface somewhere else. Pointing the header at a store the account does not own is the case that fails loudly: `403 STORE_ACCESS_DENIED`.
- **The session response carries no identity at all** — no user id, no role, no store. `GET /me` is the only source of all three, so `AuthRepositoryImpl.login` follows a successful login with a profile read and caches it.
- **The access token lives 15 minutes** (`expires_in: 900`), not two hours. Refresh is routine rather than rare, which is why `AuthInterceptor` stays a `QueuedInterceptor`.
- **Registration does not log you in.** It creates the account and returns `dev_verification_token` in a dev build. `SellerAuthCubit.register` chains register → verify → login so the flow completes without a mailbox. Verification is **no longer a gate on login** — an account sits at `status: "pending_verification"` with `email_verified: "0"` and signs in anyway — so the chain is now about leaving the account in a clean state, not about making login possible. A 409 on register can mean either field: `EMAIL_TAKEN` and `PHONE_TAKEN` are separate codes.
- **`POST /stores` is the "become a seller" endpoint.** There is no separate upgrade call; creating the first store is what grants the `seller` role, after which `GET /me` reports `["buyer", "seller"]`.
- **There is a file upload endpoint** — `POST /media/upload`, multipart with a single `file` part, allowlist `jpg|jpeg|png|gif|webp|pdf` at 5 MB. The previous backend had none, which blocked every document and photo feature.
- **A login response has one field the app ignores: `requires_reconsent`.** It is the UU PDP consent gate — when true the user is meant to be sent through `GET /legal/documents/active` and `POST /legal/documents/{id}/accept` before anything else. Nothing reads it today; that is a gap, not a decision.

Rules that carry over unchanged, because they were never about that backend:

- **Never cast a JSON value directly.** This backend also hands MySQL columns to `json_encode`, so `"id": "2"`, `"rating_avg": "0.00"` and `"email_verified": "0"` are normal. Money is the same — `"base_price": "149000.00"` — so amounts arrive as two-decimal strings even though the platform has no cents; `asIntOrNull` falls through to `double.round()` for exactly that. Some columns go further and hand back **JSON as a string**: `variant_options` on a product variant does, both nested in `GET /products/{id}` and joined onto `GET /warehouses/{id}/stocks`, and needs `asEncodedMap`. Every model reads through `lib/core/utils/json_parse.dart`; `test/core/json_parse_test.dart` pins the behaviour.
- **Services throw, repositories don't.** `RepositoryGuard.guard` turns an `ApiException` into `DataFailed`, and an empty collection into `DataEmpty`.
- **Cubits pull repositories with `injector<XRepository>()`** and expose `static XCubit get(context)`. Action methods return `DataError?` rather than emitting an error state, so a form keeps what was typed.
- **Adding an endpoint** means: path constant in `api_endpoints.dart` -> method on a `*Service` -> method on the abstract repository -> implementation via `guard` -> registration in `injector_service.dart` / `injector_repository.dart`, **in that dependency order**.

**Where the docs and the server disagree, the server wins.** Found by testing against the running backend:

- ✅ **CORS landed on 2026-09-20 and the web build is no longer blocked.** This was the single biggest restriction on this app and it is gone: `OPTIONS` now answers `204` with `Access-Control-Allow-Methods`, `Vary: Origin`, an echoed `Access-Control-Allow-Origin`, and — the part that matters here — `X-Store-Id` present in `Access-Control-Allow-Headers`. Verified by preflight and by a plain `GET` carrying an `Origin`. The macOS-only guidance below is therefore historical; `flutter run -d chrome` is worth trying again, though nothing in this app has yet been *run* on web against the live API, so treat the first attempt as a test rather than a certainty.
- 🔴 **The auth endpoints are throttled, and a successful login counts.** Added in v1.2.0: login allows **5 attempts per email and 20 per IP, both per 15 minutes**, and `Rate_limiter::too_many_attempts` records the attempt **before** the password is verified — so signing in correctly consumes the budget too. Over the limit is `429 TOO_MANY_REQUESTS` in the normal envelope. The per-IP cap is the one that bites in development: every integration test run logs in, and once 20 are spent **no account can log in from this machine for 15 minutes**, which looks exactly like broken credentials. Clear it locally with `DELETE FROM auth_rate_limits;`. Also throttled: `resend-verification` and `forgot-password` at 3/email/hour, `reset-password` at 10/IP/hour.
- **`POST /media/upload` returns a URL on a host that does not serve.** It builds `http://localhost:8080/marketplace-api/uploads/...` from its own config while the file is actually served by the API host. `normaliseUploadUrl` in `media_service.dart` rewrites it; the test pins both the rewrite and the no-op cases.
- **`GET /stores/{id}` answers `STORE_NOT_FOUND` for an inactive store, even to its owner.** It is the public profile. An owner's own store is only visible through `GET /stores`, which is why `StoreService.getMyStores` exists. Since v1.2.0 it also carries `follower_count` and `is_following` from the new store-follower feature; `Store` ignores both today, which is safe but means the dashboard shows no follower figure.
- **Seller review replies are finally readable.** `review_replies` has been writable through `POST /reviews/{id}/reply` all along but was never joined back, so a reply could be written and never seen; since v1.2.0 each row of `GET /products/{id}/reviews` carries a `reply` field. Relevant the moment the reviews module lands, which is next. The same release also changed `POST /reviews/{id}/report`: one report no longer auto-hides a review, it queues it for a moderator, and a duplicate report is rejected.
- **A store opens `inactive`** and cannot sell until verified. `POST /stores` answers `{ "id": N }`, not the created row. **A product opens `draft`** the same way, and `PATCH /products/{id}` with `{"status": "active"}` is what publishes it — a store that never sends that patch has a catalogue only it can see.
- **No write returns what it wrote.** Every `POST` answers `{ "id": N }` and every `PATCH` answers `data: null`, across stores, products, variants, warehouses, vouchers and settings alike. A screen that wants the saved row has to re-read it; there is no shortcut. `StoreService.updateSettings` does exactly that — parsing the patch response instead would hand the caller a blank object and quietly undo what the form just showed.
- **`GET /stores/{id}/settings` can answer `data: null`.** The row is created on first write, so every store that came from the seed has none. That is an empty state, not an error: `StoreService.getSettings` turns it into `StoreSettings.empty(storeId)` so a settings form renders from defaults. `PATCH` upserts (it used to fail silently against a store with no row) and whitelists `auto_accept_order`, `vacation_mode`, `operational_hours`, `return_policy`, `shipping_origin`, `contact_phone`, `contact_whatsapp` — `default_currency` is read-only, and **there is no `vacation_message` column**, whatever the previous backend had. `contact_phone` / `contact_whatsapp` are seller-private and deliberately absent from the public store profile.
- **The slug is assigned, not requested** — the server appends a uniqueness suffix, so the address that exists differs from the name that was typed.
- **A success envelope can carry `data: null`.** `GET /stores/{id}/tier` does exactly this until the nightly `seller_tier_evaluation_worker` has run, and `/health-score` answers `{"latest": null, "history": []}`. Neither is an error; both need a real empty state rather than a failure path.
- **Not every failure uses the envelope.** A route reached with a verb it does not implement never gets as far as a controller: the REST library answers `405 {"status": false, "error": "Unknown method"}`, where `error` is a bare string rather than the `{code, message}` object. `DELETE /products/{id}` is one of these — it is routed, but only GET and PATCH are implemented, so the product survives the call. `ApiException.fromDio` reads that shape and keeps the server's wording.
- **A bad foreign key is a 500 with an HTML body, not a 422.** `POST /warehouses/{id}/stock-in` with an unknown `product_variant_id` returns CodeIgniter's "Database Error" page, because the foreign key is never checked before the insert. `ApiException.fromDio` summarises such a body down to its HTML `<title>` instead of putting a whole document in a snackbar, and `test/config/api_envelope_test.dart` pins that — so it degrades to "kesalahan internal" rather than a crash, but the user still learns nothing. Validate ids client-side.
- **`Idempotency-Key` is documented but not implemented.** `docs/03` calls it mandatory on the financial endpoints; no controller reads the header, and the only idempotency that exists is a unique `wallet_transactions.idempotency_key` the server fills with its own UUID. **Automatic retry on withdraw or checkout confirm therefore duplicates the operation** — keep retry off for those requests until the backend honours the header.
- **The database is being actively rebuilt by the backend team.** It has been reset repeatedly during development: accounts that worked minutes earlier started failing with `INVALID_CREDENTIALS`, and registrations restarted from `user_id: 2` more than once. Before concluding the app broke something, register a new account and see whether that works. The current seed is documented in the frontend integration guide (`docs/23-…` today) §3 — 9 users, 8 stores, 19 products, 51 categories, with working seller logins (`budi.santoso@kedaikopi.id` / `RahasiaAman123` owns store 1), which is faster to test against than registering a throwaway account.
- 🔴 **Category ids do not survive a reseed.** The tree was reseeded between two sessions and every id moved — the leaf that was `101` under a flat "Elektronik" is now `13` under "Elektronik & Gadget", and the old id answers `CATEGORY_NOT_FOUND` on product create. Never persist or hardcode a category id: read `GET /categories` and let the user pick. Both level-0 parents and their children are accepted as a product's `category_id`.

What is implemented: auth (register → verify → login, refresh, logout), the account profile, store list/create/settings and the active-store context, file upload, the **product catalogue** (categories, products, variants, publish/unpublish), **store verification** (submit, documents, status), **warehouses & inventory** (warehouses, stock in/out, adjustments, transfers, audits, the movement ledger), the store's **courier selection**, **orders** (queue, detail, accept/pack/ship, cancel, tracking, refund decisions), the **store wallet** (balance, ledger, withdrawal), **promotions** (store vouchers, flash sales, flash-sale contents), and **chat** (a conversation: read, reply, read receipts — but see the inbox gap below), **notifications** (inbox, read, mute switches), and **merchandising** — product bundles and store showcases — plus the province/city master behind the warehouse form. Fourteen services in all: `auth_service`, `store_service`, `media_service`, `catalog_service`, `verification_service`, `inventory_service`, `shipping_service`, `order_service`, `wallet_service`, `promotion_service`, `chat_service`, `location_service`, `notification_service`, `merchandising_service`.

That closes the money loop: open a shop, get verified, list products, stock them, work the orders, take the proceeds out, and discount what is not moving. Roughly 70 of the ~116 seller-relevant endpoints are wired. What is left, in the order agreed with the owner: **reviews** (reply, report) -> **store profile extras** (analytics, ratings, tier, health score) -> **staff & RBAC** -> **notifications** -> **tax & legal** -> **campaign participation** (`/stores/{id}/campaigns/{id}/products`, seller submits products for admin review) -> **live commerce**. The **chat inbox** is blocked on the backend rather than on this app — it needs one new endpoint, and the screen is already written around its absence.

⚠️ **The order actions past `paid` have never been exercised against a live order.** Nothing in this environment can move an order to `paid`: the payment callback rejects every signature and then 500s trying to log the rejection (it writes `payment_transaction_id = 0`, which violates a foreign key), so `accept` → `pack` → `ship` are built from the controller and model rather than proven end to end. The list, detail, tracking and status-gating paths *are* verified live.

`lib/features/seller_catalog/` is the reference for how a seller domain is built here: cubits with hand-written sealed states, action methods returning `DataError?` so a form keeps what was typed, and screens under `presentation/views`. `seller_verification/` and `seller_inventory/` follow it. Routes carry a path parameter (`SellerRoutes.productEdit`, `.warehouseStock`) rather than `state.extra`.

`api_endpoints.dart` runs ahead of that: it holds verified path constants for the whole seller surface, including modules with no service behind them yet. Every constant in it has been exercised against the running server and the ones that turned out not to exist were removed, so a path there can be trusted; the absence of a `*Service` is what tells you a module is unbuilt.
### Feature-first layout

```
lib/core/       # cross-cutting: routes, theme, styles, constants, cached prefs, shared widgets
lib/features/<feature>/data/models/
lib/features/<feature>/presentation/{cubits,views,views/widgets}
lib/generated/  # Flutter Intl output — DO NOT EDIT
lib/l10n/       # .arb translation sources
```

The seller features (`seller_auth`, `seller_store`, `seller_home`, `seller_shell`) use the same `presentation/{cubits,views,views/widgets}` shape but keep **no** `data/` subtree — their models and repositories are centralised under `lib/core/domain` and `lib/core/data`, per the target architecture.

The convention is applied loosely: `favorites`, `trending`, and `spalsh` are single files with no `presentation/` layer. Directory names contain typos that are part of the real paths — `spalsh` (splash), `presentaion` (profile only), and `notifications&messages` (literal `&`). Match the existing spelling rather than "fixing" it, or every import breaks.

### State: Cubits with mutable fields, not immutable state

`flutter_bloc` cubits are created **locally** — each view wraps its own body in `BlocProvider(create: ...)` inside `build()`. There is no global provider and no DI container.

Cubits hold **public mutable fields** (`currentIndex`, `products`, controllers) and emit **marker states** that carry no data (`class HomeChangeBottomNav extends HomeLayoutState {}`). `BlocBuilder` reacts to the emit, then reads the field off the cubit. Follow this pattern; do not convert to data-carrying states piecemeal. (Part 2 replaces this with freezed sealed unions — a deliberate, project-wide migration, not a per-file change.)

Every cubit exposes `static XCubit get(context) => BlocProvider.of(context);` — used as `HomePageCubit.get(context)`.

**The seller cubits do not follow the marker-state pattern.** They emit hand-written sealed states that carry their data (`OnboardingLoadSuccess`, `ShippingRateLoadFailure`, …) and are consumed with an exhaustive `switch`. That is the intended end state for the whole app; the kit's cubits are simply not migrated yet.

`MyBlocObserver` (`lib/core/utils/bloc_observer.dart`) logs all cubit lifecycle in debug.

`lib/core/cubits/app_cubit.dart` (`AppCubit`) is **dead code** — never provided or referenced. The live theme toggle is the top-level function in `components.dart` (below).

### Navigation: go_router, one flat table

All routes live in one file, [app_routes.dart](lib/core/utils/app_routes.dart): an `AppRoutes` class of path string constants plus a single flat `GoRouter` route list. Every route uses `FadeThroughTransitionPageWrapper` for a consistent transition. Arguments are passed untyped via `state.extra` and cast (`state.extra! as String`).

The `router` object is global and often called directly (`router.go(AppRoutes.onboarding)` in the splash screen) rather than through `context.go`. Adding a screen = add a constant to `AppRoutes` + a `GoRoute` entry with the wrapper.

Note: `AppRoutes.contactUs` is registered twice; the first entry wins.

### Theming: preferences-driven, not `Theme.of(context)`

This is the most important convention to get right. `lightTheme`/`darkTheme` exist in [app_theme.dart](lib/core/utils/app_theme.dart), but **widgets almost never read `Theme.of(context)`**. Instead every color decision is written inline as:

```dart
color: isAppDarkMode() ? kDarkSecondColor : kLightSecondColor,
```

`isAppDarkMode()` reads SharedPreferences **synchronously** via `CachedHelper.getData(kAppTheme)`. Colors are `k`-prefixed constants in [constant.dart](lib/core/utils/constant.dart). New UI should use these constants + `isAppDarkMode()`, not theme lookups.

**Theme and language changes restart the app.** `toggleAppTheme()` / `changeAppLanguage()` in [components.dart](lib/core/function/components.dart) persist the value then call `Phoenix.rebirth(context)`. This is why `CachedHelper.init()` must complete before `runApp` in [main.dart](lib/main.dart) — the whole app reads prefs synchronously at build time.

### Text and spacing helpers

- **Text**: `AppStyles.styleSemiBold16(context)` etc. in [app_styles.dart](lib/core/utils/app_styles.dart). Every style takes `context` because font size is scaled by `getResponsiveFontSize()` against a 375pt base width, clamped to ±20%. Never hardcode a `TextStyle` with a raw `fontSize`.
- **Spacing**: extensions in [extensions.dart](lib/core/utils/extensions.dart) — `16.pa`, `16.ps`/`.pe` (start/end), `.pt`/`.pb`, `.psh`/`.psv` all return **`EdgeInsetsDirectional`** (RTL-aware — important, Arabic is supported). Gaps use `12.sbh` / `12.sbw` for `SizedBox`. Screen size via `context.screenWidth` / `context.screenHeight`.
- **Assets**: referenced through `AppImages` constants; `assets/images/` and `assets/icon/` are glob-registered in `pubspec.yaml`, so new files need only an `AppImages` entry.
- **App bar**: `customAppBar(context, title, action: ...)` in [custom_app_bar.dart](lib/core/function/custom_app_bar.dart).
- **States**: `LoadingIndicatorView`, `ErrorStateView`, `EmptyStateView`, `showErrorSnackBar`, `showSuccessSnackBar` in [state_widgets.dart](lib/core/widgets/state_widgets.dart). Use these rather than hand-rolling a spinner, so every API failure is reported the same way.
- **Forms**: `AppDropdownField<T>` in [app_dropdown_field.dart](lib/core/widgets/app_dropdown_field.dart) for closed-list fields, and `Validators` in [validators.dart](lib/core/utils/validators.dart). Several backend fields accept only a fixed list (doc types, fleet codes, cancellation reasons) — a free-text box just produces 422s.
- **Numbers and dates**: `formatRupiah`, `formatThousands`, `formatDate`, `formatDateTime`, `parseRupiahInput` in [format_helper.dart](lib/core/utils/format_helper.dart). These avoid `intl`'s locale-aware formatters on purpose — a missing `id_ID` dataset throws at runtime on web. Amounts are whole rupiah; the server rounds and there are no cents.
- **Note**: `CustomTextFormField`'s default validator returns Arabic text (`'هذا الحقل مطلوب'`). Always pass an explicit `validator` — pass `Validators.optional` for a field that is genuinely optional or is a helper input (a search box, a URL box consumed by a button). Any such field inside a `Form` blocks submission when empty, and the message is unreadable to the user: it is what silently broke the first build of the product-create screen.

### Localization

Generated by the **Flutter Intl IDE plugin** (Localizely), not `flutter gen-l10n`. `lib/generated/l10n.dart` and `lib/generated/intl/*` are generated — edit `lib/l10n/*.arb` and regenerate. Usage in views: `final l = S.of(context); ... l.home`.

Adding a language: add `lib/l10n/intl_<code>.arb`, regenerate, then add a `LanguageModel` to `supportedLanguages` in [language_model.dart](lib/features/shared/models/language_model.dart) (this list drives the settings picker and RTL direction, and is separate from `S.delegate.supportedLocales`).

Current state: `en` and `ar` are complete (284 keys) and selectable. `fr` appears in `S.delegate.supportedLocales` but `intl_fr.arb` is **empty** and `fr` is not in `supportedLanguages` — so device-locale French resolves to a locale with no translations. Either fill it in or drop it.

## Known rough edges

- **Assets are still missing, and the app renders wrong because of it.** `assets/images/` and `assets/icon/` now exist but contain only a `.gitkeep` — the UI kit's real files were never copied over from `markas-app-member`. Any kit screen that renders an `AppImages` path shows a missing-asset error. The seller screens are asset-free by design and are unaffected.
- **The kit's custom font is disabled.** `assets/fonts/Hanimation_Arabic_Regular.otf` is not in the repo, and a declared-but-missing font file fails asset bundling and blocks `flutter build` entirely, so the `fonts:` block in `pubspec.yaml` is commented out. `kFontFamily = 'Hanimation'` is still referenced in the theme; an unregistered family falls back to the platform default silently. Restore the `.otf` and uncomment to get the kit's typography back.
- **The router's `initialLocation` is `SellerRoutes.bootstrap` (`/`), not `AppRoutes.splash`.** The kit's animated splash renders four SVGs from the missing `assets/images/`, so it cannot be the entry point. `SellerBootstrapView` decides between the seller login and the onboarding dashboard based on the stored session. Every kit route stays registered and reachable.
- `test/widget_test.dart` (the Flutter counter template, which failed) has been **replaced**. `flutter test` now runs 142 real tests covering the tolerant JSON parsers, model parsing against payloads captured from the live server, and envelope/pagination/error handling. It is a genuine signal — keep it green.
- `lib/features/my_cart/presentation/views/map_screen.dart` is 100% commented out, and the `com.google.android.geo.API_KEY` meta-data in `android/app/src/main/AndroidManifest.xml` is commented out too. Restoring the map needs both, plus an iOS key. Location permissions are already declared in the manifest.
- `DevicePreview` wraps the app when `kDebugMode`, so debug builds render inside a simulated device frame — layout that looks wrong in debug may be the preview frame, not the code.
- Orientation is locked to portrait in `main()`.
- `flutter_launcher_icons` and `flutter_native_splash` config blocks in `pubspec.yaml` are commented out, though `flutter_launcher_icons.yaml` / `flutter_native_splash.yaml` exist at the root.

---

# Part 2 — Target architecture

**Status: partly implemented.** The layering, DI and result-wrapper landed with the seller API integration; the codegen did not, deliberately.

Present: `lib/config/`, `lib/di/`, `lib/core/data/`, `lib/core/domain/`, `lib/core/data_state.dart`, the named `"api"` Dio singleton, `lib/config/route/app_route_seller.dart`.

Still absent, by choice: `freezed` / `json_serializable` / `build_runner` / `envied` and any `*.freezed.dart` / `*.g.dart`. Models and cubit states are hand-written; env config is `String.fromEnvironment` rather than `.env` + `envied`, which needs no build step and works identically on web.

Still absent, not yet done: `lib/ui/`, and any migration of the UI kit's own features. No Firebase, no `.env`, no `lib/firebase_options.dart`.

This is the layering the project is being moved toward: **data → domain → presentation** per feature, wired with `get_it` for DI and `go_router` for navigation.

## Additional commands (only if codegen is adopted later)

**Not applicable today** — there is no `build_runner` in this project and the seller integration was built without one. If `freezed` + `json_serializable` are adopted later, every change to a model or cubit state file gains a regeneration step:

```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs   # while iterating
```

Env config today is `lib/config/env/app_config.dart` reading `String.fromEnvironment` — override with `--dart-define`, no `.env` and no `envied`. Add a new constant there per base URL / API key as feature domains are added.

## Target layout

```
lib/
  config/         # env, network (Dio), routing, theming
  core/
    data/
      datasources/remote/service/   # Dio-based *Service classes, one per API
      repositories/                 # *RepositoryImpl — calls Service, wraps result in DataState<T>
    domain/
      model/        # freezed/json_serializable models, grouped per API
      repositories/ # abstract repository interfaces consumed by cubits
    data_state.dart # DataState<T> result wrapper: DataLoading/DataSuccess/DataEmpty/DataFailed(DataError)
  di/               # get_it registration, split into injector (Dio client) / injector_service / injector_repository
  ui/
    main/           # shared shell: splash, login, register, home, profile + their cubits
    <feature>/<subfeature>/{cubit,screens,widgets}/   # new feature domains use this layout
  util/             # format_helper, list_slice_extension
```

## Conventions to preserve once migrated

**DI wiring order matters.** `lib/di/injector.dart` registers one **named** `Dio` singleton (`"api"` — see `DioClient` in `lib/config/network/dio_client.dart`), then calls `initializeService()` (services take the named Dio instance), then `initializeRepository()` (repositories take the services). New services/repositories must be registered in `injector_service.dart` / `injector_repository.dart` **in that same dependency order**, and `initialize()` must run before `runApp` in `main.dart`. When adding a feature domain that calls its own API, register another named `Dio` singleton here (see the example comments in `dio_client.dart` / `injector.dart`).

**Repositories never throw.** Every repository method wraps its service call in try/catch and returns `DataState<T>` (`DataSuccess` / `DataFailed(DataError(...))`), so cubits pattern-match on state instead of using try/catch for control flow. Follow this for every new repository method.

**Services own caching and raw HTTP errors.** `*Service` classes are the layer that catches `DioException` and rethrows a plain `Exception` with context. For expensive per-ID lookups, keep an in-memory `Map<int, Model>` cache (see the `PokemonService` pattern in the origin GameHub project) and chunk calls into `Future.wait` batches rather than firing unbounded concurrent requests.

**Cubits use freezed sealed state.** Each feature's `*_state.dart` is an `@freezed` union (initial/loading/loaded/error or similar), declared via `part 'x_state.dart'; part 'x_cubit.freezed.dart';` in the cubit file. Cubits pull their repository directly with `injector<XRepository>()` — **not** constructor injection — and are provided to widgets via `BlocProvider`/`BlocBuilder` from `flutter_bloc`.

**Routes split per domain, combined into one `GoRouter`.** `lib/config/route/app_route.dart` holds the shared shell routes; spread a new `appRouterMyFeature` from its own `app_route_myfeature.dart`, following the marked example pattern. Add new feature routes to that domain file, **not** directly into `app_route.dart`.

## Migration checklist (current → target)

1. ~~Add `freezed_annotation`, `json_annotation`, `envied` + generators.~~ **Dropped deliberately.** Models and states are hand-written; see *Seller API integration*. Revisit only if `copyWith`/equality boilerplate becomes the bottleneck.
2. ~~Create `lib/config/env/env.dart` + `.env`.~~ **Done differently** — `lib/config/env/app_config.dart` with `String.fromEnvironment`, overridable via `--dart-define`. No `.env` file exists or is needed.
3. ~~Create `lib/config/network/dio_client.dart` with the named `"api"` Dio singleton.~~ **Done**, plus `auth_interceptor.dart` (queued, auto-refresh), `api_envelope.dart`, `api_exception.dart`, `api_endpoints.dart`.
4. ~~Add `lib/core/data_state.dart` with the `DataState<T>` union.~~ **Done**, with `DataError` and `DataErrorCode` alongside it.
5. ~~Build `lib/di/{injector,injector_service,injector_repository}.dart` and call `initialize()` before `runApp`.~~ **Done** — `main()` runs `CachedHelper.init()` then `initialize(onSessionExpired: …)`.
6. **Partly done.** The *seller* domain is fully behind `*Service` + `*RepositoryImpl` (auth, store, media). The UI kit's hardcoded lists (`HomePageCubit.productsTShirt` and friends) are untouched — and note the kit sells fashion, so most of it has no counterpart in the seller API and will likely be deleted rather than wired up.
7. **Partly done.** Seller cubits emit hand-written sealed states carrying data. The kit's marker states are unchanged.
8. **Started.** `lib/config/route/app_route_seller.dart` holds `SellerRoutes` + `appRouterSeller`, spread into the single `GoRouter` in [app_routes.dart](lib/core/utils/app_routes.dart). The kit's routes are still a flat table in that file.
9. **Not started.** `lib/features/` vs `lib/ui/` is still undecided. Seller features currently live under `lib/features/seller_*`.

### Remaining API surface

The marketplace API exposes **235 dispatchable routes** (`application/config/routes.php`) as of v1.5.0, up from 213 at v1.1.0; the seller app needs a fraction of them. Everything v1.2.0 through v1.5.0 added on the seller side is now wired — bundles, showcases, the locations master, notifications and product badges. The rest of what those releases brought — admin dashboard counts and reports, store follow, `POST /orders/{id}/rating`, recommendation paging — is buyer- or admin-side. Build in this order, since each depends on the last: **store verification** (submit + documents, using `/media/upload`) -> **product catalog** (categories, products, variants) -> **warehouses & inventory** (stock-in/out, adjustments, audits, movements) -> **orders** (accept, pack, ship, cancel, tracking, refund requests) -> **store wallet** (balance, withdraw) -> **promotions** (vouchers, flash sales) -> **chat** (built out of order, on request) -> reviews and the advanced modules.

**`routes.php` is the ground truth, not `docs/03-api-documentation.md`.** The doc describes a design; the routes file describes what is dispatchable. Endpoints that exist only in the doc: `POST /products/{id}/images` and `/products/{id}/subscriptions` are unrouted and answer 404, while `DELETE /products/{id}` is routed but unimplemented and answers 405 — there is no way to delete or archive a product through the API at all. Where the doc and the routes both have an endpoint but disagree on a field name, the **Postman collection** is the one that matches the code.

Traps already confirmed against the running server, which will bite when those land:

- `POST /media/upload` is `multipart/form-data` with a single `file` part, and the returned URL needs `normaliseUploadUrl`. Verification documents are a **separate** uploader — `POST /stores/{id}/verification/documents`, `file` plus a `doc_type` part — with a narrower allowlist (`jpg|jpeg|png|pdf`, no gif or webp) that answers `{"file_url": …}` where `/media/upload` answers `{"url": …}`. Both land on the non-serving host.
- **Product images can be read but never written.** `GET /products/{id}` returns an `images` array that `Product_model` fills from the `product_images` table — seeded products really do have rows there — but **no route reaches that table**, so a product the app creates can never get one. The only image a seller can actually set is a variant's `image_url`, via `/media/upload` then `POST`/`PATCH` on the variant. A gallery UI can display `images`; a gallery *editor* has nothing to call.
- **`GET /products/{id}` is a whole product page in one call** — `variants[]`, `images[]`, `couriers[]`, plus `stock` and `compare_at_price`, and a `flash_sale` object while a sale is running. Two shapes to watch: `flash_sale` is an **optional key** (absent, not null, when idle), and `stock` — on the product and again per variant — is a real **integer** while its neighbours are numeric strings. `asInt` reads both, so nothing breaks as long as it is not cast directly. The other integers in an otherwise all-strings API are `meta.facets.rating[].count` and the `cost` / `etd_*_days` of a shipping estimate; `facets.category[].cnt` is a string, which is the pair that catches people out.
- 🔴 **The list endpoints without `meta` are still paginated at 20.** This is the trap that actually bit: `GET /products` reports `meta` (`{page, per_page, total}` plus `facets`), while `GET /stores/{id}/products`, `/warehouses/{id}/movements`, `/stores/{id}/orders` and `/stores/{id}/ratings` return a bare array — which reads as "unpaged" and is not. They cap at 20 rows and say nothing about it, so one request yields a silently truncated list. A store with 23 products showed 20, and the three that were missing were the only real ones. With no total to page against, a **short page is the only end-of-list signal**: walk pages until one comes back under 20 (`CatalogService.getAllStoreProducts` is the pattern) and put a page cap on the loop so a server that ignored `page` cannot spin it forever. Its rows are the `products` table plus `compare_at_price` and `flash_sale`; **images, stock, variants and couriers are detail-only**, so listing cards need placeholders rather than an N+1 of detail calls.
- **The two facets in `meta.facets` have different shapes.** `rating` is always present and uses an integer `count`; `category` appears only when `q` is given and uses a string `cnt`. One parser will not read both. `meta.facets.rating` is also cumulative (a 4.5-star product counts toward `min_rating` 4, 3, 2 and 1) and is a different thing from `GET /products/{id}/reviews` → `meta.rating_histogram`, which counts reviews per exact star with a percentage.
- **`/search/*` needs Elasticsearch on port 9200** and answers `503 SEARCH_UNAVAILABLE` without it (`/search/trending` still returns 200 with an empty list). `GET /products?q=` is the MySQL-backed fallback and returns facets too — use it for dev, and design any search screen to switch between the two.
- **The two product lists are different scopes, not just different paths.** `GET /products` shows **active products only**; a seller's drafts exist only in `GET /stores/{id}/products`. Using the public list for the seller's catalogue screen silently hides everything unpublished.
- **Creating a product also creates a variant.** The server generates one immediately (`SKU-<productId>-<hash>`, `variant_options: null`, price copied from `base_price`), so `POST /products/{id}/variants` adds a *second* one. Stock is tracked per variant, so even a product with no real options has to point its inventory at that generated row — and a create-then-add-variant flow leaves a phantom variant behind unless it edits the generated one instead.
- **`/categories` is seeded and rich** — 12 top-level categories with children — but its ids are not stable across reseeds. See the category-id note above.
- **Voucher create takes `valid_from`/`valid_until` and `min_spend`**, not `start_at`/`end_at` or `min_purchase`. The model reads those two dates with no fallback, so omitting either is still a 500 with a PHP warning rather than a 422. (`name` used to be dropped on the way in; that was fixed on 2026-09-14 and it now persists.) Flash sales, confusingly, really do take `start_at`/`end_at`.
- **Promotions are create-and-list only.** Neither `/stores/{id}/vouchers` nor `/stores/{id}/flash-sales` implements `PATCH` or `DELETE` — both answer `405 Unknown method` — and there is no route that removes a variant from a sale. Nothing the seller creates here can be edited, paused or withdrawn, so the forms have to say so *before* submitting. There is also **no `GET /flash-sales/{id}`**: only its `/products`, which is **public**. A detail screen recovers the sale by reading the store's list and picking it out by id.
- 🔴 **Only a voucher's `name` is validated; everything else is a 500.** `discount_type`, `discount_value`, `quota`, `valid_from` and `valid_until` are read straight out of the decoded body with no fallback, so omitting one answers HTTP 500 with a PHP `Undefined array key` warning. Flash sale create is worse — it validates **nothing at all**, not even the name. Verified live for each field.
- **MySQL is not in strict mode, so the enums do not defend themselves.** `discount_type: "ngawur"` is accepted with a `201` and stored as `''`, leaving a voucher that discounts nothing; `discount_value: 500` on a percentage voucher is accepted too. The closed list and the 0–100 bound have to be enforced client-side, and `StoreVoucher.fromJson` deliberately reads `discount_type` **without** a fallback so that `''` survives to be labelled rather than being quietly relabelled as a real type.
- **`vouchers.code` is `UNIQUE` across the whole platform** and a collision is an unhandled duplicate-key **500**, not a 409. Left out of the request the server generates `VC-XXXXXXXX`, which is the safer default — a client can only check its own store's codes, never another store's.
- **`vouchers.status` is never written by any code.** There is no endpoint and no worker, so it reads `active` from creation forever and says nothing about whether the voucher still works. `Promotion_model::validate_for_user` checks the window and the quota, so those are what a phase must be derived from (`StoreVoucher.phaseAt`).
- 🔴 **A flash sale scheduled for later may never start.** `status` is computed once by SQL at creation and moved afterwards only by `flash_sale_status_worker.php` on a five-minute cron — and **no crontab is installed in this environment**. Meanwhile the buyer-facing query in `Product_model::attach_flash_sale_progress` demands **both** `fs.status = 'active'` **and** the window covering `NOW()`. So a sale created with a future start is born `scheduled`, its window opens, and it still sells nothing. A sale created with a window that already covers now is born `active` and works. `FlashSale.phaseAt` names that broken middle state `stalled` and the UI warns on it; nothing the app can call repairs one. A backwards window (`end_at` before `start_at`) is likewise accepted with a `201`.
- 🔴 **`POST /flash-sales/{id}/products` never checks that the variant belongs to the sale's store.** `authorize` runs against the *flash sale's* store, and the variant is then inserted without an ownership test — so a seller can put **another store's product** into their own sale, and it shows on that product's public detail at the price they chose. Reproduced against the running server (a throwaway store discounted seed product 1 to Rp1.000) and cleaned up afterwards. Compare `submit_campaign_product`, which does check. This is a backend bug to report, not something the app can fix.
- **Adding the same variant to a sale twice breaks a `UNIQUE` key** and answers an HTML 500, so the picker has to exclude what is already in. Posting to a flash sale id that does not exist dereferences null in the controller and answers **403** wrapped in a PHP warning page.
- **`flash_sale_products.stock_quota` is not reconciled with warehouse stock.** Nothing compares the two, so a quota above what is on hand oversells. Nor is `flash_price` compared against the variant's own price — a "discount" that raises the price is accepted.
- **`PATCH /products/{id}` whitelists six fields** — `name`, `description`, `base_price`, `compare_at_price`, `weight_grams`, `status`. **`category_id` and `product_type` are not among them**, so both are settled at creation and the edit form shows them read-only. Publishing can also be refused with `CERTIFICATION_REQUIRED`: a category flagged under `docs/12-indonesia-compliance.md` needs a verified certificate before a product in it may go active. Nothing in the current seed triggers it, so it is a live path with no test data behind it.
- **Verification has a fixed order: submit, then documents.** `POST /stores/{id}/verification/documents` answers `404 VERIFICATION_NOT_FOUND` when no request exists, because a document row hangs off a verification id. `GET` answers `data: null` before the first submission — an empty state, not an error. `type` (`individual` | `business`) is read without a fallback, so omitting it is a 500 rather than a 422.
- 🔴 **Submitting verification again starts from scratch.** It inserts a *new* row rather than updating the old one, and documents belong to the row they were uploaded against — so a second submission arrives with zero documents and everything already uploaded is orphaned. Only offer it after a rejection. `doc_type` is a plain `VARCHAR(50)` the server never validates (`"ngawur"` is accepted with a 201), so the closed list — `ktp`, `npwp`, `siup`, `nib`, `selfie` — has to be enforced client-side.
- **Approving a verification is what activates the store**, in one transaction that also sets `stores.status = 'active'`. It is an admin action (`POST /admin/verifications/{id}/approve`), so the seller app can only submit and wait.
- **Warehouse create is whitelisted since v1.2.0** (security finding #5). It used to pass the body straight into the SQL insert, so one key that was not a column answered `500` with an HTML "Database Error" page; now an unknown key is **silently dropped** and the call answers `201`. Verified. The failure mode inverted rather than disappearing — a typo in a field name is no longer loud, it just does not save — so keep sending exactly `name`, `address`, `city`, `province`, `postal_code`, `latitude`, `longitude`, `status`. `is_default` is still pointless to send: the server makes the store's first warehouse the default and every later one not, whatever the request said.
- **Warehouses now carry a nullable `city_id`** pointing at the new `master_cities` table, alongside the free-text `city`/`province` that were kept. `GET /locations/provinces` and `GET /locations/cities` (filterable with `?province_id=`) are the master lists, both public and unpaged. **Their payloads do not follow the rest of the API's naming**: `province_name` / `city_name` rather than `name`, `active` rather than `is_active`, and `created_date` / `modified_date` rather than `created_at` / `updated_at` — read `name` and you get an empty string, not an error.
- 🔴 **The master list is a seed, not a gazetteer: 11 provinces and 15 cities.** Indonesia has ~38 and hundreds. It is missing places already in use — there is `Jakarta`, `Jakarta Barat` and `Jakarta Selatan` but **no `Jakarta Timur`**, which the app's own onboarding test used. That is why `city_id` is nullable and the text columns survive, and why `warehouse_sheet.dart` offers the master list *and* a "kota saya tidak ada di daftar" escape hatch. A form that only offered the dropdown would refuse valid addresses.
- **Nothing checks that `city_id` agrees with the `city` text.** Sending `city: "Bandung"` with the `city_id` of Banda Aceh is accepted and stored. Always derive both from the same chosen row.
- **Stock is never set, only moved.** `warehouse_stocks` is derived from an append-only ledger, so a correction is `POST /stock-adjustments` with a **signed delta** (`quantity_delta: -2`), not a new total. `stock-in` and `stock-out` take magnitudes and the server signs them. Verified end to end: 50 in, 5 out, −2 adjustment leaves 43; an audit counted at 40 writes the variance and leaves 40 — as an `adjustment` movement, not a type of its own.
- **`stock-out` is refused against reserved stock**, not against what is on hand: `422 STOCK_INSUFFICIENT` with a message naming the reservation. A seller reading "43 on hand" can be refused 43. Screens must show `quantity_available`.
- **A transfer debits the source at create and credits the destination only at complete.** In between the stock is in neither warehouse, which is what a van looks like in a ledger. Equal source and destination are rejected with `VALIDATION_ERROR`.
- **The wallet ledger stores every amount as a positive number.** Unlike the stock ledger, direction is not in the sign — `wallet_transactions.amount` is `abs()` and the meaning lives in `type`, so a UI that renders it raw shows a withdrawal as money arriving. `WalletTransaction.isCredit` derives direction from `balance_before` vs `balance_after` instead of a type whitelist, so a transaction type the backend adds later is still read correctly.
- **Seller revenue lands only when an order reaches `completed`** — a buyer action, or the H+3 auto-complete job after `delivered`. Not at ship, not at delivery. The credited figure is `grand_total` minus the platform commission (3.5% by default from `marketplace_settings_defaults`), so the wallet shows net proceeds, and each row carries `reference_type: 'order'` + `reference_id` to trace it back.
- **A withdrawal debits the balance at request time, not at approval.** `POST /stores/{id}/wallet/withdraw` (JSON body, unlike ship/cancel) calls `debit()` before inserting the `withdrawal_requests` row, so the money leaves the moment the call succeeds and a rejected request would have to be credited back by hand. The server validates only two things — a 50 000 minimum and the balance — and reports both as the same `WITHDRAWAL_REJECTED` with different messages. **It does not validate the bank fields at all**: with a sufficient balance, a missing `bank_name` reaches a `NOT NULL` column and answers 500, so the form must require them. There is also **no endpoint for a seller to list their own withdrawal requests** (only `/admin/withdrawals`), so the `withdraw` ledger row is the only trace.
- **`seller_wallets.held_balance` is never written by any code** and is always zero. Do not build a "pending funds" display on it.
- 🔴 **An out-of-turn order action answers HTTP 200 with an HTML exception page.** `accept`, `pack` and `ship` each demand an exact starting status (`paid` → `processed` → `packed` → `shipped`), and `Order_model::transition` throws a `RuntimeException` otherwise which no controller catches — so CodeIgniter renders it as an error page and sends it with a **200**. Dio sees success, `ApiEnvelope` sees a non-map body. There is no error code to match on and no status code to branch on. The only defence is client-side: `Order.canAccept` / `canPack` / `canShip` / `canCancel` gate every button, and `OrderDetailCubit` refuses locally before calling. `ApiEnvelope.from` lifts the `Message:` line out of such a page so at least the real reason survives, but nothing should rely on that.
- **Order actions are split between JSON and form encoding.** Most of this API reads its body with `json_decode(file_get_contents('php://input'))`, but a handful use the REST library's `post()` helper, which only ever reads `$_POST` — and PHP never populates that from a JSON body. `POST /orders/{id}/ship` and `/cancel` are in that group, and the failure is silent rather than loud: ship still moves the order to `shipped`, it just stores a null AWB. `BaseService.postFormRequest` exists for exactly these. The others known to need it: `orders/{id}/refund-request`, `admin/verifications/{id}/reject`, `vouchers/claim`.
- **Only the seller's own statuses are the seller's to move.** `delivered` and `completed` belong to the buyer, and cancellation is refused once an order is past `paid`. A refund decision needs `refund.id`, which is reachable **only** through `GET /orders/{id}` — the create response goes to the buyer.
- **`store_couriers` is an optional whitelist, and empty means "all".** `PATCH /stores/{id}/couriers` with `{"courier_codes": [...]}` sets which couriers a store ships with, and since 2026-09-15 the backend narrows buyers' shipping options against it — but `Shipping_model::_filter_by_store_couriers` applies the filter **only when the list is non-empty**, so a store that has set nothing keeps every active courier. That default-open behaviour is deliberate, so stores predating the feature did not suddenly lose all options. Verified: with store 1 unrestricted, `/products/1/shipping-estimate` returned jnt and sicepat; after selecting only `jne`, it returned JNE services alone. **Selecting restricts; it does not enable.** The `PATCH` is **replace-all** — every row for the store is deleted and re-inserted — so a partial list silently drops the rest and `[]` clears the restriction. An unrecognised code fails the whole call with `VALIDATION_ERROR`; take codes from `GET /couriers` (`jne`, `jnt`, `sicepat` today) rather than typing them.
- **`GET /products/{id}` disagrees with itself about couriers.** Its `couriers` array is built straight from `store_couriers`, so an unrestricted store shows `[]` there while shipping through everything. A storefront reading that array as "what this seller ships with" would be wrong; it is "what this seller has restricted itself to".
- **`GET /couriers` and `GET /stores/{id}/couriers` return different shapes** — the master list carries `is_active`, the store's list only `code` and `name`. A courier listed against a store is enabled by definition, which is why `Courier.isActive` defaults to true.
- **Product variants now carry `warehouse_city` / `warehouse_province`** on `GET /products/{id}`: the warehouse holding **the most** of that variant, not a sum — cities differ per warehouse, so there is nothing to add up. Null when no warehouse has any. There is also a new `GET /products/{id}/shipping-estimate?address_id=&variant_id=`, but it needs a buyer's address id, so it belongs to the member app.
- **`flash_sale` now appears at two levels with two conventions** (v1.1.0). On the product it is an **optional key** — absent, never null, when idle — and aggregates across variants. On `variants[i]` it is **always present** and `null` when that variant is not discounted. Price against the per-variant one: the aggregate discounts variants that are not in the sale. `FlashSaleInfo.maybeFrom` reads both, and `Product.hasPartialFlashSale` names the case where they disagree.
- **Flash sales used to be stuck in `scheduled` forever.** A sale created through `POST /stores/{id}/flash-sales` never became `active`; fixed on 2026-09-17 by computing status from SQL `NOW()` at create, plus a `flash_sale_status_worker` on a 5-minute cron. **The fix only covers creation.** A sale whose window is still in the future is born `scheduled` and depends entirely on that worker, which is not scheduled here — see the `stalled` trap above.
- **Six staff roles are seeded per store on creation** (`owner`, `admin`, `manager`, `customer_service`, `finance_staff`, `warehouse_staff`), each with an empty `permissions` array until one is set.
- **`GET /warehouses/{id}/stocks` already joins what an inventory screen needs** — `sku`, `product_name`, `variant_options`, and `quantity_on_hand` / `_reserved` / `_available` — so it does not need a second call per row. The ledger behind it behaves: stock-in 50, stock-out 5 and an adjustment of −2 leave 43, and completing an audit with `actual_quantity: 40` writes the variance and leaves 40.
- 🔴 **A seller cannot list their store's conversations — there is no endpoint.** `GET /chat/conversations` looks like the inbox and is not: `Chat_model::list_conversations` filters on `cc.buyer_id = <signed in user>`, so it answers with the conversations in which the account is the **customer**. Verified live: after a buyer wrote to store 1, its owner still got `[]` while the database held seven conversations for that store. The schema is ready for the missing query — it carries `idx_conversations_store (store_id, last_message_at)`, an index with nothing behind it — so this is one model method and one route away. Everything downstream already works: `guard_participant` admits the store's owner and active staff, so reading, replying, `POST /read` and polling all succeed on an id obtained elsewhere, and an unrelated seller is properly refused with `403 NOT_PARTICIPANT`. `ChatInboxView` is built around the gap rather than pretending it away.
- 🔴 **A bundle's detail is active-only, so switching one off hides its contents from its own owner.** `GET /bundles/{id}` is public and filters `status = 'active'`; an inactive bundle answers `404 BUNDLE_NOT_FOUND` — whose `message` is the bare error code, with no Indonesian text behind it. Reproduced both ways: created `inactive`, and created active then patched off. The list (`GET /stores/{id}/bundles`) does show every status but carries **no items**, so `BundleDetailCubit` reads the row from the list first and only then asks for contents, and says plainly why they are missing.
- **A bundle's items are fixed at creation.** `PATCH /bundles/{id}` whitelists `name`, `bundle_price` and `status`, and no route adds, removes or re-quantifies an item. There is no `DELETE` either (405) — `status: inactive` is how a bundle is retired. Create validates properly though: a missing name, a price of zero, an empty `items`, or a product belonging to another store each come back as a readable `422`, which makes this one of the politer write paths on this API. Nothing checks that the bundle is actually cheaper than its parts.
- **Showcases are the exception that has full CRUD**, `DELETE` included. Adding a product answers `201` with **no id at all**, a duplicate is a `422` (the pair is unique and the server checks first), and removal is **by product id**, answering `404 SHOWCASE_PRODUCT_NOT_FOUND` when the product was not there — a v1.3.0 fix; it used to return a silent `200`.
- 🔴 **`GET /showcases/{id}/products` filters `p.status = 'active'`.** A draft product can be added — the ownership check passes and the call answers `201` — and then never appears, to the seller as much as to a buyer. Nothing reports the discrepancy, so a showcase can look emptier than it is. The picker marks drafts rather than hiding them, and the screen says why.
- **Products carry `badges` since v1.4.0** — a subset of `new`, `best_seller`, `hot`, `sale`, derived from age, `sold_count`, `view_count` and the better of the `compare_at_price` and flash-sale discounts. Default thresholds are 14 days / 50 sold / 500 views / 20% off, overridable through `admin_settings`, so treat the numbers as defaults rather than guarantees. **Only `GET /products` and `GET /products/{id}` attach them** — `attach_badges()` is never called from `store_index_get`, so the seller's own catalogue has no `badges` key at all and the cards in this app deliberately show none. The product's own screen does, because it loads the detail.
- **`GET /stores/{id}/products` does take a `status` parameter**, contrary to what this file said for weeks: `list_for_store($storeId, $status, $page)` filters server-side, verified (`?status=draft` → 0 rows, `?status=active` → 3). The app still filters client-side because it walks every page anyway and the chips then switch instantly, but the server-side option exists if that changes.
- **Notifications are per account, not per store.** `GET /me/notifications` is one stream for every shop the account owns, and nothing in a row says which shop it belongs to beyond whatever went into `data` — which arrives as a **JSON string**, like `variant_options`. Twenty a page, newest first, no `meta`. `POST /me/notifications/{id}/read` is scoped to the caller and **answers `200` for an id that does not exist**, so success proves nothing.
- **A new order finally notifies the seller (v1.5.0).** `POST /checkout/sessions/{id}/confirm` now raises `order_new` to the store owner with `{order_id, order_number}` in `data`. Before that the order lifecycle raised nothing at all — a staff invitation was the only notification the system had ever sent.
- **`GET /me/notification-preferences` lists only types the account has already received.** The server derives it from `SELECT DISTINCT type FROM notifications WHERE user_id = …`, so a seller with no orders yet sees an empty list and cannot pre-configure anything; it fills in as traffic arrives. Channels with no stored override default to **on**, the values come back as **real booleans** rather than `"1"`/`"0"`, and `PATCH` sets **one** `{notification_type, channel, is_enabled}` at a time. `in_app` is refused with a 422 — it is the app's own inbox and doubles as the history.
- **Chat has no WebSocket in this build**, whatever `docs/03` says about `wss://realtime.marketplace.id`. There is no such service in `docker-compose.yml` and no socket library in the repo; `GET /chat/conversations/{id}/poll?since_id=` is the only realtime path that exists.
- 🔴 **That long-poll must not be used while the API runs on `php -S`.** It holds the request for ~25 seconds, and the built-in PHP server is single-threaded, so one held request blocks **every** other one. Measured: `GET /health` took **23.9s** during a poll against 0.00s otherwise, and sending a chat message from the app took 24 seconds to come back. `ChatThreadCubit` re-reads `/messages` on a four-second timer instead — sending is immediate again — and `ChatService.pollMessages` is kept, verified and documented for a backend running behind a real worker pool.
- **`chat_conversations.buyer_unread_count` and `store_unread_count` are never written by any code**, like `seller_wallets.held_balance`. They are always `"0"`. A badge built on them would never light up.
- **The conversation list joins the store's name but not the buyer's.** It was written for the buyer, who needs the shop; the seller's counterpart — who is writing to me — is not joined anywhere, so a future inbox needs that added too.
- **`POST /chat/conversations` opens a conversation as the *buyer*, and accepts a store the caller owns.** The server answers `201` and writes a row where buyer and owner are the same person. It is also get-or-create, so a repeat returns the existing id. The seller app never calls it.
- **`chat_messages.content` is nullable and unvalidated**, so an empty message is accepted and stored; the composer refuses one. `chat_attachments` exists in the schema but **no route writes to it**, so `image` and `video` messages have nowhere to put a file — the same "readable but not writable" shape as product images.
- **Messages come back newest-first, thirty to a page, ordered by `created_at`** — which stores whole seconds, so two messages sent in the same second return in an arbitrary order (observed). Sort by `id`, which is also what `poll?since_id=` pages against.
- There is no seller-side order list separate from `/stores/{id}/orders`; the buyer's `/orders` is a different scope.

## Follow-ups when starting a new project from this base

- **Firebase**: this repo has no Firebase at all today. If it is adopted (or if this project is duplicated from one that has it), run `flutterfire configure` rather than inheriting another project's `firebase.json`, `lib/firebase_options.dart`, and platform config files — a copied config points at the origin project.
- **App identifier**: already done for this project — Android `applicationId`/`namespace`, iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER`, `android:label`, `CFBundleDisplayName`, `MaterialApp.title` and the desktop/web names all say `com.marketplace.seller` / "Marketplace Seller". `name:` in `pubspec.yaml` is intentionally still `navy_wear` — see Project identity.
- **In-app brand text is still "Shopapay"** and was deliberately left alone during the rebrand, because the strings live in `lib/l10n/*.arb` and changing them requires regenerating `lib/generated/` (`dart run intl_utils:generate`, which needs `dart pub global activate intl_utils` first — it is not a declared dev_dependency). What remains: the `appName` and `aboutShopapay` keys in `intl_en.arb` / `intl_ar.arb`, the `AppImages.Shopapay` constant in [app_images.dart](lib/core/utils/app_images.dart), and its use in `about_app_view.dart`, `profile_view.dart`, `settings_view.dart` and `splash_screen.dart`. Never hand-edit `lib/generated/`.
- **Missing assets**: see *Known rough edges*. The directories now exist so the build succeeds, but the files themselves are still absent.
