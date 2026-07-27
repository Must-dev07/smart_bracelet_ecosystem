# Deployment Guide

Production deployment of the Smart Bracelet ecosystem. Four deliverables,
four deployment targets:

| Component | Target |
|---|---|
| Backend (Django + Celery) | any Docker host (VPS, cloud VM) |
| Doctor dashboard (Next.js) | same host (node) or Vercel/any Node host |
| Mobile app (Flutter) | Android APK / Play Store (iOS analog) |
| Firmware (ESP32) | flashed over USB with PlatformIO |

---

## 1. Backend — Docker Compose

### 1.1 Prerequisites
- Docker ≥ 24 + docker compose plugin
- A domain name pointing at the host (for TLS)
- A Firebase project with FCM enabled + a service-account JSON

### 1.2 Configure
```bash
cd backend
cp .env.example .env
```
Edit `.env` — every line marked `# REQUIRES:` must be set:

| Variable | Notes |
|---|---|
| `DJANGO_SECRET_KEY` | `python -c "import secrets;print(secrets.token_urlsafe(64))"` |
| `DJANGO_ALLOWED_HOSTS` | your domain, e.g. `api.example.com` |
| `POSTGRES_PASSWORD` | strong random |
| `CORS_ALLOWED_ORIGINS` | dashboard origin, e.g. `https://dash.example.com` |
| `FCM_PROJECT_ID` | Firebase project id |
| `FCM_SERVICE_ACCOUNT_FILE` | `/secrets/fcm.json` (mounted below) |

Place the Firebase service-account JSON at `backend/secrets/fcm.json`
(the compose file mounts `./secrets` read-only at `/secrets`).

### 1.3 Launch
```bash
docker compose up -d --build
docker compose exec web python manage.py migrate
docker compose exec web python manage.py createsuperuser   # admin account
docker compose ps    # db, redis, web, celery-worker, celery-beat, nginx → healthy
```

Services:
- **nginx** :80 — reverse proxy → gunicorn, serves `/static/`
- **web** — gunicorn (Django + DRF)
- **celery-worker** — rule evaluation + notification dispatch
- **celery-beat** — `detect_no_data` watchdog (every minute)
- **db** — PostgreSQL 16 (volume `pgdata`)
- **redis** — broker/result backend

### 1.4 TLS
Terminate TLS at nginx. Recommended: put the host behind a certbot-managed
cert or a cloud load balancer. `nginx/nginx.conf` contains a commented
`server { listen 443 ssl; … }` block — fill in the cert paths and reload.
**Do not run production over plain HTTP** — the mobile app and dashboard
send JWTs in headers.

### 1.5 Smoke test
```bash
curl -s https://api.example.com/api/v1/auth/login -X POST \
  -H 'Content-Type: application/json' -d '{"email":"x","password":"y"}'
# → 400/401 JSON (server up, auth wired)
```
Optionally run the simulator against production staging:
```bash
python3 tools/simulator/bracelet_simulator.py --base-url https://api.example.com \
  --email <parent> --password <pwd> --scenario normal --count 5
```

### 1.6 Operations
- **Migrations**: `docker compose exec web python manage.py migrate`
- **Logs**: `docker compose logs -f web celery-worker`
- **Backups**: `docker compose exec db pg_dump -U bracelet bracelet > backup.sql`
- **Admin UI**: `https://api.example.com/admin/`
- **OpenAPI docs**: `https://api.example.com/api/docs/` (Swagger UI)

---

## 2. Doctor Dashboard — Next.js

```bash
cd dashboard
cp .env.example .env.local
# NEXT_PUBLIC_API_BASE_URL=https://api.example.com
npm install
npm run build
npm run start        # serves on :3100 — put nginx/caddy in front
```

Alternative: deploy to Vercel/Netlify — set `NEXT_PUBLIC_API_BASE_URL`
as a build-time environment variable. Remember to add the dashboard's
origin to the backend `CORS_ALLOWED_ORIGINS`.

---

## 3. Mobile App — Flutter

> Built on **your machine** (Flutter SDK not available in the build sandbox).

```bash
cd mobile
flutter pub get
flutter test                                   # unit + widget tests

# Android release build against production API:
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com
```

Firebase Messaging: follow `mobile/android_notes/README.md` — add
`google-services.json`, the Gradle plugins, and Android 13+ notification
permission. BLE requires the listed Bluetooth permissions (already in the
notes) and location services enabled on the phone.

---

## 4. Firmware — ESP32

> Compiled/flashed on **your machine** with PlatformIO (see `firmware/README.md`).

```bash
cd firmware
pio run -t upload
pio device monitor -b 115200
```

Wiring table and BLE contract are in `firmware/README.md`. The bracelet
advertises `SB-BRACELET-<serial>`; pair from the app's Pairing screen.

---

## 5. End-to-end bring-up order

1. Backend up + migrated + superuser created
2. Dashboard deployed, doctor account registered (via app or API)
3. Parent registers in the mobile app
4. Bracelet flashed → app pairs it → assigns to the baby
5. Vitals flow; verify an alert path with the simulator (`--scenario fever`)
6. Parent receives FCM push; doctor sees the alert on the dashboard

## 6. Security checklist

- [ ] `DJANGO_DEBUG=false`, strong `DJANGO_SECRET_KEY`
- [ ] TLS on API and dashboard
- [ ] Postgres not exposed publicly (compose keeps it on the internal network)
- [ ] FCM service-account JSON mounted read-only, never committed
- [ ] Throttling active (auth 20/min, ingest 600/min) — tune in settings
- [ ] Audit log middleware enabled (metadata only, no medical payloads)
- [ ] Database backups scheduled
