# Smart Bracelet — Newborn Monitoring Ecosystem

Production-grade, four-part IoT system for monitoring newborn vitals:
an ESP32 smart bracelet, a Flutter parent app, a Django backend with a
pluggable medical rule engine, and a Next.js doctor dashboard.

> **Disclaimer** — This system flags abnormal readings for caregiver or
> medical follow-up. **It is not a medical diagnosis device.** This
> disclaimer is embedded in every alert payload, every alert-facing
> screen, every PDF report and the firmware docs.

## Repository layout

```
webapp/
├── firmware/    ESP32 C++ (PlatformIO) — sensors, BLE GATT, buffering, power
├── mobile/      Flutter parent app — BLE pairing, live vitals, offline-first sync, FCM
├── backend/     Django + DRF + Celery — auth, ingest, rule engine, notifications, Docker
├── dashboard/   Next.js doctor dashboard — patients, charts, alerts triage, PDF reports
├── tools/
│   └── simulator/   bracelet_simulator.py — hardware-free end-to-end exercising
└── docs/        openapi.yaml, api_overview, ERD, UML, deployment guide,
                 parent user manual, testing report
```

## Data flow

```
Bracelet (ESP32) --BLE GATT float32--> Mobile app (Flutter)
                                        │  offline-first SQLite queue
                                        ▼
                              Backend /api/v1/measurements/ (bulk)
                                        │ validation → rule engine
                                        ▼
                          Alert ── Celery ──> FCM push ──> parent phone
                                        │
                                        ▼
                              Doctor dashboard (Next.js)
```

- **BLE contract**: service `8e7f1a20-…4e5f`, float32 LE characteristics
  (hr/temp/spo2/movement/battery) + command + device-info — identical
  constants in `firmware/include/config/config.h` and
  `mobile/lib/core/app_config.dart`.
- **Rules** (server-side, pluggable `@register` classes): high/low temp,
  low SpO2, high/low HR, no movement, bracelet removed, battery low,
  BLE lost (app-reported), no data (celery-beat watchdog). Critical rules
  run synchronously at ingest; one open alert per (baby, type).
- **Security**: JWT with rotating refresh sessions (revocable), role
  scoping (parent/doctor/admin — foreign objects 404), throttling,
  metadata-only audit log, bonded+encrypted BLE.

## Quick start (development)

```bash
# 1. Backend (Python 3.11+)
cd backend && python -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python manage.py migrate
CELERY_TASK_ALWAYS_EAGER=true .venv/bin/python manage.py runserver 0.0.0.0:8080

# 2. Exercise it without hardware
python3 tools/simulator/bracelet_simulator.py --base-url http://localhost:8080 \
  --email <parent-email> --password <pwd> --scenario fever --count 12

# 3. Dashboard
cd dashboard && cp .env.example .env.local && npm install && npm run dev  # :3100

# 4. Mobile (your machine, Flutter SDK)
cd mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# 5. Firmware (your machine, PlatformIO)
cd firmware && pio run -t upload
```

Production: `docs/deployment_guide.md` (Docker Compose: postgres, redis,
gunicorn, celery worker+beat, nginx).

## Verified state (see docs/testing_report.md)

| Suite | Where | Result |
|---|---|---|
| Backend pytest (55 tests) | this sandbox | ✅ 55/55 |
| Firmware host logic (g++) | this sandbox | ✅ 184 checks |
| Simulator ↔ live backend integration | this sandbox | ✅ full pass (pair → ingest → alerts → doctor ack) |
| Dashboard `next build` (strict TS) | this sandbox | ✅ 12 routes |
| Flutter tests | your machine (`flutter test`) | written, not run here |
| ESP32 target build | your machine (`pio run`) | written, not run here |
| Docker Compose stack | your machine | complete, not booted here |

## Documentation

| Doc | Purpose |
|---|---|
| `docs/api_overview.md` | Human-readable endpoint reference |
| `docs/openapi.yaml` | Machine-readable spec (drf-spectacular; Swagger at `/api/docs/`) |
| `docs/erd.md` | Database schema (Mermaid ERD) + design notes |
| `docs/uml.md` | Use-case, class (rule engine, firmware), 2 sequence diagrams |
| `docs/deployment_guide.md` | Docker Compose production deployment, TLS, ops |
| `docs/user_manual_parent.md` | Parent-facing manual |
| `docs/testing_report.md` | What was tested where, honestly |
| per-component `README.md` | firmware/, mobile/, backend/, dashboard/, tools/simulator/ |

## Tech stack

| Component | Stack |
|---|---|
| Firmware | C++17, Arduino/ESP32, PlatformIO, NimBLE-equivalent BLE stack (ESP32 BLE), MAX30102, DS18B20, MPU6050 |
| Mobile | Flutter, Riverpod, flutter_blue_plus, sqflite, firebase_messaging, Clean Architecture |
| Backend | Django 5.2, DRF, simplejwt (+ custom Session rotation), Celery + Redis, drf-spectacular, PostgreSQL, Docker Compose, nginx |
| Dashboard | Next.js 14 (App Router), TypeScript strict, Tailwind CSS, Chart.js, jsPDF |
