/// Persists the handful of local-only preferences (Section 11): theme,
/// language, units, and which VitalsSource to use. Everything else
/// (notification preferences) is server-side, since those need to affect
/// what the backend sends regardless of which device the user opens next.
///
/// Wrapped in main.dart's ProviderScope override so `AppSettingsStore` is
/// synchronously available by the time the widget tree builds — see
/// settingsStoreProvider in providers.dart.
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsStore {
  final SharedPreferences _prefs;
  const AppSettingsStore(this._prefs);

  static const _kDarkMode = 'settings.dark_mode';
  static const _kLocale = 'settings.locale';
  static const _kUnits = 'settings.units'; // 'metric' | 'imperial'
  static const _kUseSimulatedBle = 'settings.use_simulated_ble';

  bool get darkMode => _prefs.getBool(_kDarkMode) ?? false;
  Future<void> setDarkMode(bool v) => _prefs.setBool(_kDarkMode, v);

  String get locale => _prefs.getString(_kLocale) ?? 'en';
  Future<void> setLocale(String v) => _prefs.setString(_kLocale, v);

  String get units => _prefs.getString(_kUnits) ?? 'metric';
  Future<void> setUnits(String v) => _prefs.setString(_kUnits, v);

  bool? get useSimulatedBleOverride => _prefs.containsKey(_kUseSimulatedBle)
      ? _prefs.getBool(_kUseSimulatedBle)
      : null;
  Future<void> setUseSimulatedBle(bool v) =>
      _prefs.setBool(_kUseSimulatedBle, v);
}
