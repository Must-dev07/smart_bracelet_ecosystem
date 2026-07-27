/// Background sync worker: periodically drains the local SQLite queue to the
/// backend bulk-ingest endpoint and marks rows synced. Reports BLE-lost events
/// to the backend when the BleService signals a dropped link.
import 'dart:async';
import 'dart:convert';

import '../core/api_client.dart';
import '../services/local_db.dart';

class SyncService {
  final ApiClient _api;
  final LocalDb _db;
  Timer? _timer;
  bool _running = false;

  SyncService(this._api, this._db);

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => syncOnce());
    // Kick one immediately so reconnect flushes fast.
    unawaited(syncOnce());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Push one batch of unsynced measurements. Returns number synced.
  Future<int> syncOnce() async {
    if (_running) return 0; // re-entrancy guard
    _running = true;
    try {
      final rows = await _db.unsyncedBatch();
      if (rows.isEmpty) return 0;

      final payload = rows.map((r) {
        Map<String, dynamic>? movement;
        final mj = r['movement_json'] as String?;
        if (mj != null) {
          try {
            movement = jsonDecode(mj) as Map<String, dynamic>;
          } catch (_) {
            movement = null;
          }
        }
        return {
          'bracelet': r['bracelet_id'],
          'heart_rate': r['heart_rate'],
          'temperature': r['temperature'],
          'spo2': r['spo2'],
          'movement': movement,
          'battery': r['battery'],
          'skin_contact': (r['skin_contact'] as int) == 1,
          'recorded_at': r['recorded_at'],
        };
      }).toList();

      await _api.post('/measurements/', body: payload);
      await _db.markSynced(rows.map((r) => r['local_id'] as int).toList());
      return rows.length;
    } on UnauthenticatedException {
      rethrow; // surfaced to UI → login screen
    } catch (_) {
      return 0; // network down: keep queue, retry next tick
    } finally {
      _running = false;
    }
  }

  Future<void> reportBleLost(int braceletId) async {
    try {
      await _api.post('/alerts/report-ble-lost/', body: {'bracelet_id': braceletId});
    } catch (_) {
      // Best effort; the backend no-data watchdog is the safety net.
    }
  }
}
