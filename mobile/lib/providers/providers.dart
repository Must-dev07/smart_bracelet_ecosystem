/// Riverpod dependency graph + app-level state providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/app_config.dart';
import '../core/secure_store.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/app_settings_store.dart';
import '../services/ble_service.dart';
import '../services/local_db.dart';
import '../services/simulator_vitals_source.dart';
import '../services/sync_service.dart';
import '../services/vitals_source.dart';

// --- Infrastructure ---------------------------------------------------------
final secureStoreProvider = Provider((ref) => SecureStore());
final apiClientProvider =
    Provider((ref) => ApiClient(store: ref.watch(secureStoreProvider)));
final localDbProvider = Provider((ref) => LocalDb());

/// Overridden in main.dart with a real instance once SharedPreferences has
/// loaded (before runApp), so every provider below can read a persisted
/// value synchronously on first build instead of needing a loading state.
/// Nullable rather than throwing-if-unset: widget tests build their own
/// ProviderScope without going through main.dart's bootstrap, and a screen
/// that merely touches units/darkMode/locale in passing shouldn't force
/// every such test to override this just to avoid a crash. Every provider
/// below null-checks accordingly and falls back to the same hardcoded
/// defaults this app always had before settings persistence existed.
final settingsStoreProvider = Provider<AppSettingsStore?>((ref) => null);

/// Section 22 / 11: which VitalsSource implementation is active — the real
/// ESP32 over BLE, or the in-app simulator (default, since hardware isn't
/// available project-wide yet). Settings exposes this as "Use BLE simulator"
/// (BLE preferences). Flipping it rebuilds bleServiceProvider with a fresh
/// instance of the other implementation — any screen with an open
/// connection should reconnect after switching, same as unplugging one
/// bracelet and pairing another.
final useSimulatedBleProvider = StateProvider<bool>((ref) =>
    ref.watch(settingsStoreProvider)?.useSimulatedBleOverride ??
    AppConfig.useSimulatedBleDefault);

final bleServiceProvider = Provider<VitalsSource>((ref) {
  final VitalsSource source = ref.watch(useSimulatedBleProvider)
      ? SimulatorVitalsSource()
      : BleService();
  ref.onDispose(source.dispose);
  return source;
});
final syncServiceProvider = Provider((ref) {
  final service = SyncService(ref.watch(apiClientProvider), ref.watch(localDbProvider));
  service.start();
  ref.onDispose(service.stop);
  return service;
});

// --- Repositories -------------------------------------------------------------
final authRepositoryProvider = Provider((ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStoreProvider),
    () => ref.read(bleServiceProvider)));
final babyRepositoryProvider =
    Provider((ref) => BabyRepository(ref.watch(apiClientProvider)));
final braceletRepositoryProvider =
    Provider((ref) => BraceletRepository(ref.watch(apiClientProvider)));
final measurementRepositoryProvider = Provider((ref) => MeasurementRepository(
    ref.watch(apiClientProvider), ref.watch(localDbProvider)));
final alertRepositoryProvider =
    Provider((ref) => AlertRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository(ref.watch(apiClientProvider)));
final userRepositoryProvider =
    Provider((ref) => UserRepository(ref.watch(apiClientProvider)));
final doctorAssignmentRepositoryProvider = Provider(
    (ref) => DoctorAssignmentRepository(ref.watch(apiClientProvider)));

// --- Session state --------------------------------------------------------------
class AuthState {
  final User? user;
  final bool loading;
  final String? error;
  const AuthState({this.user, this.loading = false, this.error});
  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  AuthNotifier(this._repo) : super(const AuthState(loading: true)) {
    _restore();
  }

  Future<void> _restore() async {
    final user = await _repo.currentUser();
    state = AuthState(user: user);
  }

  Future<bool> login(String email, String password) async {
    state = const AuthState(loading: true);
    try {
      final user = await _repo.login(email, password);
      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(
          error: e.statusCode == 401
              ? 'Invalid email or password.'
              : 'Server error (${e.statusCode}).');
      return false;
    } catch (_) {
      state = const AuthState(error: 'Network error — check your connection.');
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    state = const AuthState(loading: true);
    try {
      final user = await _repo.register(payload);
      state = AuthState(user: user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(error: 'Registration failed: ${e.message}');
      return false;
    } catch (_) {
      state = const AuthState(error: 'Network error — check your connection.');
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  /// Re-pull the current user from the server (after a profile edit) and
  /// update the cached session in place.
  Future<void> refreshFromServer() async {
    try {
      final user = await _repo.refreshMe();
      state = AuthState(user: user);
    } catch (_) {
      // Non-fatal: the edit itself already succeeded server-side; the local
      // cache just stays stale until the next login/restore.
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier(ref.watch(authRepositoryProvider)));

// --- Data providers ---------------------------------------------------------------
final babiesProvider = FutureProvider<List<Baby>>(
    (ref) => ref.watch(babyRepositoryProvider).list());

final braceletsProvider = FutureProvider<List<Bracelet>>(
    (ref) => ref.watch(braceletRepositoryProvider).list());

final alertsProvider = FutureProvider.family<List<Alert>, String?>(
    (ref, status) => ref.watch(alertRepositoryProvider).list(status: status));

final notificationsProvider = FutureProvider<List<AppNotification>>(
    (ref) => ref.watch(notificationRepositoryProvider).list());

// Medical history for a given baby (Section 4) — append-only, family-keyed
// by baby id so each patient's history is cached/invalidated independently.
final medicalHistoryProvider = FutureProvider.family<List<MedicalHistoryEntry>, int>(
    (ref, babyId) => ref.watch(babyRepositoryProvider).medicalHistory(babyId));

// Admin/doctor account directories (Section 1: admin dashboard content;
// doctor-assignment pickers). listUsers()/listParents() 403 for non-admins —
// screens that use them are only reachable from the admin dashboard.
final allUsersProvider = FutureProvider<List<User>>(
    (ref) => ref.watch(userRepositoryProvider).listUsers());
final doctorsDirectoryProvider = FutureProvider<List<DoctorProfile>>(
    (ref) => ref.watch(userRepositoryProvider).listDoctors());
final parentsDirectoryProvider = FutureProvider<List<ParentProfile>>(
    (ref) => ref.watch(userRepositoryProvider).listParents());

// Notification preferences (Section 11).
final notificationPreferencesProvider = FutureProvider<Map<String, bool>>(
    (ref) => ref.watch(notificationRepositoryProvider).getPreferences());

// Doctor assignment requests (Section 3).
final doctorRequestsForBabyProvider =
    FutureProvider.family<List<DoctorAssignmentRequest>, int>(
        (ref, babyId) => ref.watch(doctorAssignmentRepositoryProvider).forBaby(babyId));
final doctorRequestInboxProvider =
    FutureProvider.family<List<DoctorAssignmentRequest>, String?>(
        (ref, status) =>
            ref.watch(doctorAssignmentRepositoryProvider).inbox(status: status));

// Bracelet pairing history (Section 5).
final pairingHistoryProvider = FutureProvider.family<List<Pairing>, int>(
    (ref, braceletId) =>
        ref.watch(braceletRepositoryProvider).pairingHistory(braceletId));

// Live BLE state
final bleStatusProvider = StreamProvider<BleStatus>(
    (ref) => ref.watch(bleServiceProvider).status);
final liveVitalsProvider = StreamProvider<LiveVitals>(
    (ref) => ref.watch(bleServiceProvider).vitals);

// Selected baby for dashboard/monitoring context
final selectedBabyProvider = StateProvider<Baby?>((ref) => null);
// Bracelet currently being inspected (pairing history screen).
final selectedBraceletProvider = StateProvider<Bracelet?>((ref) => null);
// Currently connected bracelet (backend id) for measurement attribution
final connectedBraceletIdProvider = StateProvider<int?>((ref) => null);

// Settings
final darkModeProvider = StateProvider<bool>(
    (ref) => ref.watch(settingsStoreProvider)?.darkMode ?? false);
final localeCodeProvider = StateProvider<String>(
    (ref) => ref.watch(settingsStoreProvider)?.locale ?? 'en');
// 'metric' (kg/g, °C) or 'imperial' (lb/oz, °F) — Section 11 "Units".
final unitsProvider = StateProvider<String>(
    (ref) => ref.watch(settingsStoreProvider)?.units ?? 'metric');
