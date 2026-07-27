/// Riverpod dependency graph + app-level state providers.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/secure_store.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/ble_service.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

// --- Infrastructure ---------------------------------------------------------
final secureStoreProvider = Provider((ref) => SecureStore());
final apiClientProvider =
    Provider((ref) => ApiClient(store: ref.watch(secureStoreProvider)));
final localDbProvider = Provider((ref) => LocalDb());
final bleServiceProvider = Provider((ref) {
  final ble = BleService();
  ref.onDispose(ble.dispose);
  return ble;
});
final syncServiceProvider = Provider((ref) =>
    SyncService(ref.watch(apiClientProvider), ref.watch(localDbProvider)));

// --- Repositories -------------------------------------------------------------
final authRepositoryProvider = Provider((ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStoreProvider),
    ref.watch(bleServiceProvider)));
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

// Live BLE state
final bleStatusProvider = StreamProvider<BleStatus>(
    (ref) => ref.watch(bleServiceProvider).status);
final liveVitalsProvider = StreamProvider<LiveVitals>(
    (ref) => ref.watch(bleServiceProvider).vitals);

// Selected baby for dashboard/monitoring context
final selectedBabyProvider = StateProvider<Baby?>((ref) => null);
// Currently connected bracelet (backend id) for measurement attribution
final connectedBraceletIdProvider = StateProvider<int?>((ref) => null);

// Settings
final darkModeProvider = StateProvider<bool>((ref) => false);
final localeCodeProvider = StateProvider<String>((ref) => 'en');
