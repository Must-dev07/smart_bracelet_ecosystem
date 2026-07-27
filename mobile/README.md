# Bracelet Monitor — Flutter Mobile App

Parent-facing app for the Smart Bracelet Newborn Monitoring ecosystem.

> ⚠️ This app flags abnormal readings for caregiver or medical follow-up.
> It is **not** a diagnostic medical device.

## Architecture (Clean Architecture, Riverpod)
```
lib/
  core/          # ApiClient (JWT + silent refresh), SecureStore, theme, config
  models/        # Pure-Dart domain entities
  repositories/  # Only layer that talks to the API — mocked in tests
  services/      # BLE (flutter_blue_plus), SQLite offline queue, sync, FCM
  providers/     # Riverpod dependency graph + state
  screens/       # 16 screens (splash → notifications)
  widgets/       # Shared widgets incl. the mandatory DisclaimerBanner
  utils/         # i18n (en/fr)
```

## Build & run
```bash
flutter pub get
# Point at your backend (nginx port from docker-compose):
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
# Android emulator default is http://10.0.2.2:8080 (host machine).
```

## Firebase (push notifications)
REQUIRES: `android/app/google-services.json` and (iOS) `GoogleService-Info.plist`
from your Firebase project. Without them, the app runs fine but push stays off.
The FCM token is auto-registered at `/api/v1/notifications/device-tokens/`.

## Android permissions (add to AndroidManifest.xml)
`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` (API<31),
`POST_NOTIFICATIONS`, `INTERNET`. See android_notes/README.md.

## Tests
```bash
flutter test          # unit (ApiClient, models) + widget (Live, Alerts)
```
NOTE: this repo was authored in an environment without the Flutter SDK;
tests are written but must be executed on a machine with Flutter installed
(see docs/testing-report.md).
