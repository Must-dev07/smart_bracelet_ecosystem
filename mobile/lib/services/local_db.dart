// Offline-first SQLite store: every BLE measurement is written here FIRST,
// then the SyncService pushes unsynced rows to the backend in batches and
// marks them synced. The app stays fully usable with no network.
//
// A row that keeps failing to upload (network error, server rejecting the
// batch, etc.) is NOT retried forever silently — after
// [SyncService.failThreshold] attempts it's classified "failed" rather than
// "pending", so the Settings screen can show it separately and offer a
// manual retry instead of it just quietly never syncing.
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

class LocalDb {
  static const _dbName = 'bracelet_monitor.db';
  static const failThreshold = 5;
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE measurements (
            local_id INTEGER PRIMARY KEY AUTOINCREMENT,
            bracelet_id INTEGER NOT NULL,
            heart_rate REAL, temperature REAL, spo2 REAL,
            movement_json TEXT, battery REAL,
            skin_contact INTEGER NOT NULL DEFAULT 1,
            recorded_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            last_attempt_at TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_meas_synced ON measurements(synced, recorded_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE measurements ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE measurements ADD COLUMN last_error TEXT');
          await db
              .execute('ALTER TABLE measurements ADD COLUMN last_attempt_at TEXT');
        }
      },
    );
    return _db!;
  }

  Future<int> insertMeasurement(Measurement m) async {
    final database = await db;
    return database.insert('measurements', {
      'bracelet_id': m.braceletId,
      'heart_rate': m.heartRate,
      'temperature': m.temperature,
      'spo2': m.spo2,
      'movement_json': m.movement == null ? null : jsonEncode(m.movement),
      'battery': m.battery,
      'skin_contact': m.skinContact ? 1 : 0,
      'recorded_at': m.recordedAt.toUtc().toIso8601String(),
      'synced': 0,
    });
  }

  /// Oldest-first batch that's still worth retrying automatically (excludes
  /// rows that have already crossed [failThreshold] — those wait for a
  /// manual retry so a permanently-broken row doesn't hog every sync tick).
  Future<List<Map<String, dynamic>>> unsyncedBatch({int limit = 200}) async {
    final database = await db;
    return database.query('measurements',
        where: 'synced = 0 AND retry_count < ?',
        whereArgs: [failThreshold],
        orderBy: 'recorded_at ASC',
        limit: limit);
  }

  Future<void> markSynced(List<int> localIds) async {
    if (localIds.isEmpty) return;
    final database = await db;
    await database.update('measurements', {'synced': 1},
        where: 'local_id IN (${List.filled(localIds.length, '?').join(',')})',
        whereArgs: localIds);
  }

  /// Bump retry_count/last_error for a batch that failed to upload.
  Future<void> markFailed(List<int> localIds, String error) async {
    if (localIds.isEmpty) return;
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.rawUpdate(
      'UPDATE measurements SET retry_count = retry_count + 1, '
      'last_error = ?, last_attempt_at = ? '
      'WHERE local_id IN (${List.filled(localIds.length, '?').join(',')})',
      [error, now, ...localIds],
    );
  }

  /// Give up-and-tried-again rows another chance (Settings "Retry failed").
  Future<void> resetFailed() async {
    final database = await db;
    await database.update('measurements', {'retry_count': 0},
        where: 'synced = 0 AND retry_count >= ?', whereArgs: [failThreshold]);
  }

  /// Recent local history for offline viewing (bounded window).
  Future<List<Map<String, dynamic>>> recentMeasurements({int limit = 500}) async {
    final database = await db;
    return database.query('measurements',
        orderBy: 'recorded_at DESC', limit: limit);
  }

  Future<int> pendingCount() async {
    final database = await db;
    final rows = await database.rawQuery(
        'SELECT COUNT(*) AS c FROM measurements WHERE synced = 0 AND retry_count < ?',
        [failThreshold]);
    return rows.first['c'] as int;
  }

  Future<int> failedCount() async {
    final database = await db;
    final rows = await database.rawQuery(
        'SELECT COUNT(*) AS c FROM measurements WHERE synced = 0 AND retry_count >= ?',
        [failThreshold]);
    return rows.first['c'] as int;
  }

  Future<void> clearAll() async {
    final database = await db;
    await database.delete('measurements');
  }
}
