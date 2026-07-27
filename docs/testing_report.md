# Testing Report

Honest account of what was tested, **where**, and with what results.
Build environment: Linux sandbox (Python 3, Node 22, g++ 14). The Flutter
SDK and the ESP32 toolchain are **not** available in this environment —
those test suites are written and delivered but must be executed on a
developer machine (commands below).

## 1. Backend (Django + DRF) — ✅ executed here

```bash
cd backend && .venv/bin/python -m pytest
# 55 passed in ~60 s
```

- **Runner**: pytest + pytest-django, SQLite, `CELERY_TASK_ALWAYS_EAGER`
  (tasks run inline; Redis result backend disabled under pytest).
- **Coverage by area** (55 tests):
  - `authentication` — register (parent/doctor validation), login,
    refresh **rotation + old-token revocation**, logout revocation,
    throttling behaviour.
  - `users` — /me, admin-only user list (403 for non-admin), profile
    update permissions (self-or-admin).
  - `babies` — CRUD scoping (parent sees own, doctor sees assigned,
    foreign baby → **404 not 403** to avoid information leaks),
    birth-date/weight validation, medical-history append + supersedes.
  - `bracelets` — registration, pair/unpair with pairing history,
    ownership checks.
  - `measurements` — bulk ingest (≤500), physiological range rejection
    (HR −5 / 900 rejected), foreign-bracelet ingest rejected,
    `last_seen_at`/battery update, granularity bucketing
    (raw/minute/hour/day), bounded queries (92-day max).
  - `analysis` — every rule fires at its threshold and not inside the
    normal window; **dedup** (no second alert while one is open);
    NO_DATA auto-resolve on data return.
  - `alerts` — list filters (status/severity/baby), acknowledge
    (+auto-resolve), BLE-lost report endpoint (dedup + ownership).
  - `notifications` — channel dispatch on alert creation, device-token
    registration, stale-token cleanup on FCM 404/410 (mocked HTTP).

- Two defects found and fixed during the test pass:
  1. Medical-history endpoint returned 403 before existence check
     (information leak) → reordered to 404-first.
  2. Foreign-bracelet ingest test initially used the assigned doctor
     fixture (false pass) → rewritten with an unrelated doctor.

## 2. Firmware host tests (g++) — ✅ executed here

```bash
cd firmware/test_host
g++ -std=c++17 -I../include -Wall -Wextra -Werror -o test_host test_main.cpp
./test_host
# 184 checks, 0 failure(s)
```

- float32 little-endian encode/decode round-trips + known byte pattern
  (BLE payload contract shared with the Flutter parser).
- 28-byte movement payload field order.
- Ring buffer: FIFO order, overwrite-oldest on overflow, 1000-push
  wrap-around, pop-on-empty, Sample-struct storage.
- Battery model: curve anchors, clamping, **monotonicity sweep**,
  segment interpolation, EMA filter convergence.
- Plausibility windows (reject HR −5 / 900 etc.) and 5-tap median filter
  spike suppression.

**Not executed here**: compiling `src/` for the ESP32 target (needs
PlatformIO + the espressif32 toolchain). Run on your machine:
`cd firmware && pio run`.

## 3. Integration pass (simulator ↔ live backend) — ✅ executed here

Backend served with `manage.py runserver` (SQLite, eager Celery);
`tools/simulator/bracelet_simulator.py` playing bracelet+app:

| Step | Result |
|---|---|
| Register parent + doctor via API | ✅ tokens + sessions issued |
| Simulator registers bracelet `SIM0001`, creates baby, pairs | ✅ |
| `normal` ×10 | ✅ 0 alerts |
| `fever` ×12 | ✅ `high_temp` critical raised once (dedup held) |
| `hypoxia` ×12 | ✅ `low_oxygen` critical |
| `tachy` ×12 | ✅ `high_hr` critical |
| `lowbatt` ×12 | ✅ `battery_low` info |
| Doctor before assignment | ✅ sees 0 babies |
| Parent assigns doctor to baby | ✅ |
| Doctor queries babies/measurements (minute buckets)/alerts | ✅ |
| Doctor acknowledges alert | ✅ acknowledged + auto-resolved |

## 4. Dashboard (Next.js) — ✅ build-verified here

```bash
cd dashboard && npm run build
# ✓ Compiled successfully — 12 routes, strict TypeScript, 0 errors
```

- `next build` runs full type-checking and static generation; all 9
  pages compile under `strict: true`.
- Runtime behaviour was exercised indirectly: every API call the pages
  make (`/babies/`, `/alerts/?status=…`, `/measurements/?granularity=…`,
  `/users/`, `/doctors/…`) was hit with real requests during the
  integration pass above, including the role-scoping semantics the UI
  relies on.
- **Not executed here**: browser E2E (Playwright/Cypress) — recommended
  as a follow-up.

## 5. Mobile app (Flutter) — ⚠️ written, NOT executed here

The sandbox has no Flutter SDK. The suite is delivered and expected to
pass; run on your machine:

```bash
cd mobile && flutter pub get && flutter test
```

- `test/unit/api_client_test.dart` — JWT header injection, silent
  refresh on 401 (single retry), `UnauthenticatedException` propagation
  (mocked HTTP).
- `test/unit/models_test.dart` — JSON round-trips for all models,
  movement JSON encoding.
- `test/widget/alerts_screen_test.dart` — list rendering, severity
  badges, disclaimer presence, acknowledge flow (mocked repository).
- `test/widget/live_monitoring_test.dart` — vitals tiles render from
  BLE stream, reconnect states (mocked BleService/SyncService via
  Riverpod provider overrides).

## 6. Known gaps / recommended next steps

1. Flutter tests + `flutter build apk` on a machine with the SDK.
2. `pio run` firmware target build; then on-hardware validation of the
   MAX30102 calibration constants (empirical SpO2 curve).
3. Browser E2E for the dashboard.
4. Load testing of the ingest endpoint (bulk 500) before large fleets.
5. Docker Compose stack verification (`docker compose up` + smoke tests)
   on a Docker-capable host — compose file is complete but was not
   bootable in this sandbox.
