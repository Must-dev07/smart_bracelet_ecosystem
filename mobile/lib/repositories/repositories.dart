// Repository layer: the only place that talks to ApiClient. Screens/providers
// depend on these interfaces, so unit tests mock repositories, and repository
// tests mock the ApiClient.
import '../core/api_client.dart';
import '../core/secure_store.dart';
import '../models/models.dart';
import '../services/local_db.dart';
import '../services/vitals_source.dart';

class AuthRepository {
  final ApiClient _api;
  final SecureStore _store;
  final VitalsSource _ble;

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

  /// Re-fetches the current user from the server (GET /me/) and updates the
  /// cached copy — used after a profile edit so every screen that reads
  /// `authProvider.user` (name, phone, doctor_profile_id, …) sees fresh data
  /// without requiring a full re-login.
  Future<User> refreshMe() async {
    final data = await _api.get('/me/');
    final user = User.fromJson(data as Map<String, dynamic>);
    await _store.saveUser(data);
    return user;
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

  /// Parent/admin only — the backend rejects a doctor editing these fields
  /// (doctors record clinical notes via medical history, not registration edits).
  Future<Baby> update(int id, Map<String, dynamic> payload) async {
    final data = await _api.patch('/babies/$id/', body: payload);
    return Baby.fromJson(data as Map<String, dynamic>);
  }

  /// Parent/admin only — the backend rejects a doctor deleting a patient record.
  Future<void> delete(int id) => _api.delete('/babies/$id/');

  /// Append-only medical history (Section 4): doctors/admins append entries,
  /// parents/doctors only ever read them. The backend enforces who may POST.
  Future<List<MedicalHistoryEntry>> medicalHistory(int babyId) async {
    final data = await _api.get('/babies/$babyId/medical-history/');
    return (data['results'] as List)
        .map((e) => MedicalHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MedicalHistoryEntry> addMedicalHistoryEntry(
    int babyId, {
    required String title,
    required String details,
    int? supersedes,
  }) async {
    final data = await _api.post('/babies/$babyId/medical-history/', body: {
      'title': title,
      'details': details,
      if (supersedes != null) 'supersedes': supersedes,
    });
    return MedicalHistoryEntry.fromJson(data as Map<String, dynamic>);
  }

  /// Admin: direct-assign or clear a baby's doctor. Doctor: may only clear
  /// their own assignment (self-removal). The backend enforces both rules;
  /// this is a thin wrapper, not the source of truth.
  Future<Baby> setAssignedDoctor(int babyId, int? doctorId) async {
    final data =
        await _api.patch('/babies/$babyId/', body: {'assigned_doctor': doctorId});
    return Baby.fromJson(data as Map<String, dynamic>);
  }
}

/// Section 3 workflow: parent requests a doctor, the doctor accepts/declines.
class DoctorAssignmentRepository {
  final ApiClient _api;
  DoctorAssignmentRepository(this._api);

  /// Parent: request a doctor for one of their babies.
  Future<DoctorAssignmentRequest> create(
    int babyId,
    int doctorId, {
    String note = '',
  }) async {
    final data = await _api.post('/babies/$babyId/doctor-requests/', body: {
      'doctor': doctorId,
      if (note.isNotEmpty) 'note': note,
    });
    return DoctorAssignmentRequest.fromJson(data as Map<String, dynamic>);
  }

  /// History of requests for one baby (parent/admin/assigned doctor).
  Future<List<DoctorAssignmentRequest>> forBaby(int babyId) async {
    final data = await _api.get('/babies/$babyId/doctor-requests/');
    return (data['results'] as List)
        .map((e) => DoctorAssignmentRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Top-level inbox: doctor sees requests addressed to them, parent sees
  /// requests for their babies, admin sees everything.
  Future<List<DoctorAssignmentRequest>> inbox({String? status}) async {
    final data = await _api.get('/babies/doctor-requests/',
        query: status != null ? {'status': status} : null);
    return (data['results'] as List)
        .map((e) => DoctorAssignmentRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DoctorAssignmentRequest> accept(int requestId) async {
    final data = await _api.post('/babies/doctor-requests/$requestId/accept/');
    return DoctorAssignmentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<DoctorAssignmentRequest> decline(int requestId) async {
    final data = await _api.post('/babies/doctor-requests/$requestId/decline/');
    return DoctorAssignmentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<DoctorAssignmentRequest> cancel(int requestId) async {
    final data = await _api.post('/babies/doctor-requests/$requestId/cancel/');
    return DoctorAssignmentRequest.fromJson(data as Map<String, dynamic>);
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

  /// Persisted app-level rename (works regardless of BLE connection state —
  /// unlike the BLE "rename" command in bracelet_info_screen, which writes
  /// the name to the physical device itself and needs an active connection).
  Future<Bracelet> rename(int braceletId, String nickname) async {
    final data = await _api.patch('/bracelets/$braceletId/', body: {'nickname': nickname});
    return Bracelet.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Pairing>> pairingHistory(int braceletId) async {
    final data = await _api.get('/bracelets/$braceletId/pairings/');
    return (data['results'] as List)
        .map((e) => Pairing.fromJson(e as Map<String, dynamic>))
        .toList();
  }
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

  Future<List<Alert>> list({
    int? babyId,
    String? status,
    String? severity,
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _api.get('/alerts/', query: {
      if (babyId != null) 'baby_id': '$babyId',
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
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

  /// Doctor/admin only — the backend rejects a parent resolving a
  /// vitals-based alert (acknowledging is as far as a parent's action goes).
  Future<Alert> resolve(int id) async {
    final data = await _api.post('/alerts/$id/resolve/');
    return Alert.fromJson(data as Map<String, dynamic>);
  }
}

class NotificationRepository {
  final ApiClient _api;
  NotificationRepository(this._api);

  Future<List<AppNotification>> list({bool unreadOnly = false, String? category}) async {
    final data = await _api.get('/notifications/', query: {
      if (unreadOnly) 'unread': 'true',
      if (category != null) 'category': category,
    });
    return (data['results'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(int id) => _api.post('/notifications/$id/read/');

  Future<int> markAllRead() async {
    final data = await _api.post('/notifications/read-all/');
    return (data['marked_read'] as int?) ?? 0;
  }

  Future<void> delete(int id) => _api.delete('/notifications/$id/');

  /// Section 11: per-category mute (alert is never included — always on).
  Future<Map<String, bool>> getPreferences() async {
    final data = await _api.get('/notifications/preferences/');
    return (data as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool));
  }

  Future<Map<String, bool>> updatePreference(String category, bool enabled) async {
    final data = await _api
        .patch('/notifications/preferences/', body: {category: enabled});
    return (data as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool));
  }
}

/// Account directory + profile editing. The admin-only list endpoints
/// (`/users/`, `/parents/`) 403 for non-admins; the doctor directory
/// (`/doctors/`) is readable by any authenticated user (needed for doctor
/// assignment pickers and for a doctor to find their own Doctor.id).
class UserRepository {
  final ApiClient _api;
  UserRepository(this._api);

  /// Walks every page of a DRF-paginated list endpoint.
  Future<List<T>> _paged<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final all = <T>[];
    var page = 1;
    while (true) {
      final data = await _api.get(path, query: {'page': '$page'});
      all.addAll(
          (data['results'] as List).map((e) => fromJson(e as Map<String, dynamic>)));
      if (data['next'] == null || page > 100) break;
      page += 1;
    }
    return all;
  }

  /// Admin-only: every account on the platform.
  Future<List<User>> listUsers() => _paged('/users/', User.fromJson);

  /// Readable by any authenticated user (doctor assignment pickers, and so a
  /// doctor can find their own Doctor.id for self-editing).
  Future<List<DoctorProfile>> listDoctors() =>
      _paged('/doctors/', DoctorProfile.fromJson);

  /// Admin-only: every parent account with contact details.
  Future<List<ParentProfile>> listParents() =>
      _paged('/parents/', ParentProfile.fromJson);

  /// Edit the current user's own basic info (any role).
  Future<User> updateMe({String? firstName, String? lastName, String? phone}) async {
    final data = await _api.patch('/me/', body: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phone != null) 'phone': phone,
    });
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Doctor self-edit (or admin editing a doctor): specialty + basic user fields.
  Future<DoctorProfile> updateDoctor(
    int doctorId, {
    String? firstName,
    String? lastName,
    String? phone,
    String? specialty,
  }) async {
    final data = await _api.patch('/doctors/$doctorId/', body: {
      if (firstName != null || lastName != null || phone != null)
        'user': {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (phone != null) 'phone': phone,
        },
      if (specialty != null) 'specialty': specialty,
    });
    return DoctorProfile.fromJson(data as Map<String, dynamic>);
  }

  /// Parent self-edit (or admin editing a parent): address/emergency contact
  /// + basic user fields.
  Future<ParentProfile> updateParent(
    int parentId, {
    String? firstName,
    String? lastName,
    String? phone,
    String? address,
    String? emergencyContact,
  }) async {
    final data = await _api.patch('/parents/$parentId/', body: {
      if (firstName != null || lastName != null || phone != null)
        'user': {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (phone != null) 'phone': phone,
        },
      if (address != null) 'address': address,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
    });
    return ParentProfile.fromJson(data as Map<String, dynamic>);
  }

  /// Section 11 "Delete account": soft-deletes (deactivates) the current
  /// user server-side. Requires the current password. Throws ApiException
  /// (400) on a wrong password — the caller is expected to surface that.
  Future<void> deactivateAccount(String password) =>
      _api.post('/me/deactivate/', body: {'password': password});
}
