# Integration tests

These drive the **real app** against the **running marketplace API**. They are
not unit tests and are not part of `flutter test` — that command only picks up
`test/`, so these never run by accident in CI without a backend.

```bash
# Backend must be up and seeded first (see the API repo's
# docs/23-frontend-integration-guide.md §1).
curl -s http://localhost:8000/api/v1/health

# One file at a time — see below.
flutter test integration_test/seller_catalog_test.dart -d macos
flutter test integration_test/seller_onboarding_test.dart -d macos
```

**Run them one file per invocation.** `flutter test integration_test` launches
the app once per file on desktop, and the second launch fails with "Unable to
start the app on the device" because the first instance has not released it.
Each file passes on its own.

A macOS debug build needs a few GB of free disk. When space runs out the failure
looks nothing like a disk problem — `lipo: can't write to output file` inside a
`Target debug_unpack_macos failed` exception — so check `df -h` before debugging
the test.

**If a run builds and then sits at `+0` until the timeout**, printing
`Failed to foreground app; open returned 1` and finally
`'!_expectingFrame': is not true`, the app never came to the front, so no
frames were pumped and every `pumpUntil` starved. Nothing is wrong with the
test. Launch the built app once by hand and then re-run:

```bash
pkill -f "Marketplace Seller"
open "build/macos/Build/Products/Debug/Marketplace Seller.app"   # then quit it
flutter test integration_test/seller_catalog_test.dart -d macos
```

## Why macOS and not Chrome

The backend sends **no CORS headers and answers `OPTIONS` with 405**, so a
browser cannot call it cross-origin — the web build cannot reach the API at all
unless it is served from the same origin. A native macOS build has no such
restriction, which makes it the only target these tests run against today.

macOS sandboxes network access, so `macos/Runner/*.entitlements` must keep
`com.apple.security.network.client`. Without it every request fails in a way
that looks exactly like the server being down.

**Every run logs in, and login is throttled.** Since API v1.2.0 it allows five
attempts per email and twenty per IP over fifteen minutes, and a *successful*
login counts — the limiter records the attempt before the password is checked.
So roughly twenty test runs in a quarter hour exhausts the per-IP budget and
then **no account can sign in from this machine**, which reads as broken
credentials rather than as throttling. The response is `429 TOO_MANY_REQUESTS`.
Clear it locally:

```sql
DELETE FROM auth_rate_limits;
```

## What they assume

`seller_catalog_test.dart` signs in as a seed seller (`budi.santoso@kedaikopi.id`,
store 1) and walks the catalogue. It needs that account to exist — the seed is
rebuilt periodically, so if login starts failing, check the account table in the
API repo's integration guide rather than assuming the app broke.

The test clears the stored session before booting so a run always starts from
the login screen, and it skips `DevicePreview` — the simulated device frame
`main()` adds in debug makes hit-testing depend on the preview's scaling.
