/// Repository layer: the only place that talks to ApiClient. Screens/providers
/// depend on these interfaces, so unit tests mock repositories, and repository
/// tests mock the ApiClient.
import '../core/api_client.dart';
import '../core/secure_store.dart';
import '../models/models.dart';
import '../services/ble_service.dart';
import '../services/local_db.dart';

class AuthRepository {
  final ApiClient _api;
  final SecureStore _store;
  final BleService _ble;

  AuthRepository(this._api, this._store, this._ble);

  Future<User> login(String email, String password) async {
    final data = await _api.post('/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    await _store.saveTokens(
        access: data['access'] as String, refresh: data['refresh'] as String);
    await _store.saveUser(data['user'] as Map<String, dynamic>);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> register(Map<String, dynamic> payload) async {
    final data = await _api.post('/auth/register', body: payload, auth: false);
    await _store.saveTokens(
        access: data['access'] as String, refresh: data['refresh'] as String);
    await _store.saveUser(data['user'] as Map<String, dynamic>);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Logout: revoke server session, clear secure storage AND BLE bond (spec 5.3).
  Future<void> logout() async {
    final refresh = await _store.readRefreshToken();
    if (refresh != null) {
      try {
        await _api.post('/auth/logout', body: {'refresh': refresh});
      } catch (_) {/* server unreachable: still clear locally */}
    }
    await _ble.clearBond();
    await _store.clear();
  }

  Future<User?> currentUser() async {
    final json = await _store.readUser();
    return json == null ? null : User.fromJson(json);
  }
}

class BabyRepository {
  final ApiClient _api;
  BabyRepository(this._api);

  Future<List<Baby>> list() async {
    final data = await _api.get('/babies/');
    return (data['results'] as List)
        .map((e) => Baby.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Baby> create(Map<String, dynamic> payload) async {
    final data = await _api.post('/babies/', body: payload);
    return Baby.fromJson(data as Map<String, dynamic>);
  }
}

class BraceletRepository {
  final ApiClient _api;
  BraceletRepository(this._api);

  Future<List<Bracelet>> list() async {
    final data = await _api.get('/bracelets/');
    return (data['results'] as List)
        .map((e) => Bracelet.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Bracelet> register(String serialNumber, String firmwareVersion) async {
    final data = await _api.post('/bracelets/', body: {
      'serial_number': serialNumber,
      'firmware_version': firmwareVersion,
    });
    return Bracelet.fromJson(data as Map<String, dynamic>);
  }

  Future<void> pair(int braceletId, int babyId) =>
      _api.post('/bracelets/$braceletId/pair/', body: {'baby_id': babyId});

  Future<void> unpair(int braceletId) =>
      _api.post('/bracelets/$braceletId/unpair/');
}

class MeasurementRepository {
  final ApiClient _api;
  final LocalDb _db;
  MeasurementRepository(this._api, this._db);

  /// Offline-first write path: SQLite first, sync worker pushes later.
  Future<void> saveLocal(Measurement m) => _db.insertMeasurement(m);

  Future<List<Measurement>> history(
    int babyId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _api.get('/measurements/', query: {
      'baby_id': '$babyId',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return (data['results'] as List)
        .map((e) => Measurement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> aggregated(
    int babyId, {
    required String granularity,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _api.get('/measurements/', query: {
      'baby_id': '$babyId',
      'granularity': granularity,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    });
    return (data['results'] as List).cast<Map<String, dynamic>>();
  }
}

class AlertRepository {
  final ApiClient _api;
  AlertRepository(this._api);

  Future<List<Alert>> list({int? babyId, String? status}) async {
    final data = await _api.get('/alerts/', query: {
      if (babyId != null) 'baby_id': '$babyId',
      if (status != null) 'status': status,
    });
    return (data['results'] as List)
        .map((e) => Alert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Alert> detail(int id) async {
    final data = await _api.get('/alerts/$id/');
    return Alert.fromJson(data as Map<String, dynamic>);
  }

  Future<Alert> acknowledge(int id) async {
    final data = await _api.post('/alerts/$id/acknowledge/');
    return Alert.fromJson(data as Map<String, dynamic>);
  }
}

class NotificationRepository {
  final ApiClient _api;
  NotificationRepository(this._api);

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final data = await _api.get('/notifications/',
        query: unreadOnly ? {'unread': 'true'} : null);
    return (data['results'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(int id) => _api.post('/notifications/$id/read/');
}
