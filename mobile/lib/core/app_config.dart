/// Build-time configuration. Point the app at a backend with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
/// (see docs/deployment-guide.md).
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080', // Android emulator -> host nginx
  );

  static const String apiV1 = '$apiBaseUrl/api/v1';

  /// BLE UUIDs — MUST match firmware/config/ble_config.h.
  static const String healthServiceUuid = '8e7f1a20-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String hrCharUuid = '8e7f1a21-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String tempCharUuid = '8e7f1a22-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String spo2CharUuid = '8e7f1a23-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String movementCharUuid = '8e7f1a24-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String batteryCharUuid = '8e7f1a25-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String commandCharUuid = '8e7f1a26-5b3c-4d2e-9f10-0a1b2c3d4e5f';
  static const String deviceInfoCharUuid = '8e7f1a27-5b3c-4d2e-9f10-0a1b2c3d4e5f';

  /// Default source for vitals data (Section 22). The ESP32 hardware isn't
  /// available yet project-wide, so this defaults to the in-app simulator;
  /// flip with --dart-define=USE_BLE_SIMULATOR=false once real hardware is
  /// on hand, or toggle live from Settings (BLE preferences) — see
  /// useSimulatedBleProvider in providers.dart, which is the actual
  /// dependency-injection switch consumed by the app.
  static const bool useSimulatedBleDefault =
      bool.fromEnvironment('USE_BLE_SIMULATOR', defaultValue: true);

  /// Non-diagnostic disclaimer (Section 0 rule 10) — single source of truth
  /// for every alert-facing screen.
  static const String medicalDisclaimer =
      'This app flags abnormal readings for caregiver or medical follow-up. '
      'It does not provide medical diagnoses. If you are worried about your '
      'baby, contact a healthcare professional immediately.';
}
