// Background sync worker: periodically drains the local SQLite queue to the
// backend bulk-ingest endpoint and marks rows synced. Reports BLE-lost events
// to the backend when the active VitalsSource (real BLE or simulator — see
// vitals_source.dart) signals a dropped link.
//
// Auto-started once (see `syncServiceProvider`) as soon as any authenticated
// screen is reached — not just while Live Monitoring happens to be open —
// so readings collected while the app was in the background still drain
// promptly once connectivity returns.
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

      try {
        await _api.post('/measurements/', body: payload);
        await _db.markSynced(rows.map((r) => r['local_id'] as int).toList());
        return rows.length;
      } catch (e) {
        // Distinguish "the network is down, try again next tick" from
        // "the server actively rejected this batch" isn't possible with the
        // ApiException shape alone, so we treat both as one retry attempt —
        // after failThreshold attempts the row surfaces as "failed" in
        // Settings instead of retrying forever silently.
        await _db.markFailed(
            rows.map((r) => r['local_id'] as int).toList(), e.toString());
        rethrow;
      }
    } on UnauthenticatedException {
      rethrow; // surfaced to UI → login screen
    } catch (_) {
      return 0; // keep queue, retry next tick (or manual retry once "failed")
    } finally {
      _running = false;
    }
  }

  /// Settings screen "Retry failed": give rows that hit failThreshold another
  /// chance, then immediately attempt a sync.
  Future<int> retryFailed() async {
    await _db.resetFailed();
    return syncOnce();
  }

  Future<void> reportBleLost(int braceletId) async {
    try {
      await _api.post('/alerts/report-ble-lost/', body: {'bracelet_id': braceletId});
    } catch (_) {
      // Best effort; the backend no-data watchdog is the safety net.
    }
  }
}
