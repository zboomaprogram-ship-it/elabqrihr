import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:attend_mobile/core/database/local_attendance_outbox.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

class SqliteAttendanceOutbox implements LocalAttendanceOutbox {
  final Database _db;
  final _changeController = StreamController<void>.broadcast();

  SqliteAttendanceOutbox(this._db) {
    _initAndMigrateSchema();
  }

  static Future<SqliteAttendanceOutbox> create({String? dbPath}) async {
    final String path;
    if (dbPath != null) {
      path = dbPath;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      path = p.join(docsDir.path, 'attend_outbox.db');
    }
    final db = sqlite3.open(path);
    return SqliteAttendanceOutbox(db);
  }

  static SqliteAttendanceOutbox inMemory() {
    return SqliteAttendanceOutbox(sqlite3.openInMemory());
  }

  void _initAndMigrateSchema() {
    final ResultSet userVersionResult = _db.select('PRAGMA user_version;');
    final int currentVersion = userVersionResult.first.values.first as int;

    if (currentVersion < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS local_attendance_events (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          shift_instance_id TEXT NOT NULL,
          event_type TEXT NOT NULL,
          captured_at TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          accuracy_meters REAL,
          device_id TEXT,
          sync_status TEXT NOT NULL,
          reason_code TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at TEXT,
          created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_outbox_identity_status 
          ON local_attendance_events (tenant_id, user_id, sync_status);
        PRAGMA user_version = 1;
      ''');
    }
    if (currentVersion < 2) {
      _db.execute(
          'ALTER TABLE local_attendance_events ADD COLUMN location_captured_at TEXT');
      _db.execute('PRAGMA user_version = 2');
    }
    if (currentVersion < 3) {
      _db.execute(
          'ALTER TABLE local_attendance_events ADD COLUMN proof_installation_id TEXT');
      _db.execute(
          'ALTER TABLE local_attendance_events ADD COLUMN proof_digest TEXT');
      _db.execute(
          'ALTER TABLE local_attendance_events ADD COLUMN proof_signature TEXT');
      _db.execute('PRAGMA user_version = 3');
    }
  }

  @override
  Future<void> saveEvent({
    required String tenantId,
    required String userId,
    required AttendanceEventEntity event,
  }) async {
    final stmt = _db.prepare('''
      INSERT INTO local_attendance_events (
        id, tenant_id, user_id, shift_instance_id, event_type,
        captured_at, latitude, longitude, accuracy_meters, location_captured_at,
        proof_installation_id, proof_digest, proof_signature,
        device_id, sync_status, reason_code, retry_count, next_retry_at, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, NULL, ?)
      ON CONFLICT(id) DO UPDATE SET
        sync_status = excluded.sync_status,
        reason_code = excluded.reason_code
    ''');

    stmt.execute([
      event.id,
      tenantId,
      userId,
      event.shiftInstanceId,
      event.eventType.toApiValue(),
      event.capturedAt.toUtc().toIso8601String(),
      event.location.latitude,
      event.location.longitude,
      event.location.accuracyMeters,
      event.location.timestamp?.toUtc().toIso8601String(),
      event.captureProof?.installationId,
      event.captureProof?.digest,
      event.captureProof?.signature,
      event.deviceId,
      AttendanceValidationStatus.pendingSync.toApiValue(),
      event.reasonCode,
      DateTime.now().toUtc().toIso8601String(),
    ]);
    stmt.dispose();
    _changeController.add(null);
  }

  @override
  Future<List<AttendanceEventEntity>> getPendingEvents({
    required String tenantId,
    required String userId,
    int? limit,
  }) async {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    }
    final suffix = limit == null ? '' : ' LIMIT ?';
    final parameters = <Object?>[tenantId, userId];
    if (limit != null) parameters.add(limit);
    final ResultSet result = _db.select('''
      SELECT * FROM local_attendance_events
      WHERE tenant_id = ? AND user_id = ? AND sync_status = 'pending_sync'
      ORDER BY captured_at ASC
    $suffix''', parameters);

    return result.map((row) => _rowToEntity(row)).toList();
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents({
    required String tenantId,
    required String userId,
  }) async* {
    yield await getPendingEvents(tenantId: tenantId, userId: userId);
    yield* _changeController.stream
        .asyncMap((_) => getPendingEvents(tenantId: tenantId, userId: userId));
  }

  @override
  Future<void> updateEventStatus({
    required String tenantId,
    required String userId,
    required String eventId,
    required AttendanceValidationStatus status,
    String? reasonCode,
    bool isRetryAttempt = false,
    DateTime? nextRetryAt,
  }) async {
    // Strictly scoped to tenant_id, user_id, and eventId
    // Only increments retry_count when isRetryAttempt is true (not on terminal completion)
    final stmt = _db.prepare('''
      UPDATE local_attendance_events
      SET sync_status = ?,
          reason_code = ?,
          retry_count = retry_count + (CASE WHEN ? = 1 THEN 1 ELSE 0 END),
          next_retry_at = ?
      WHERE id = ? AND tenant_id = ? AND user_id = ?
    ''');

    stmt.execute([
      status.toApiValue(),
      reasonCode,
      isRetryAttempt ? 1 : 0,
      nextRetryAt?.toUtc().toIso8601String(),
      eventId,
      tenantId,
      userId,
    ]);
    stmt.dispose();
    _changeController.add(null);
  }

  AttendanceEventEntity _rowToEntity(Row row) {
    return AttendanceEventEntity(
      id: row['id'] as String,
      eventType: AttendanceEventTypeX.fromApiValue(row['event_type'] as String),
      capturedAt: DateTime.parse(row['captured_at'] as String),
      location: GeoPoint(
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        accuracyMeters: (row['accuracy_meters'] as num?)?.toDouble(),
        timestamp: row['location_captured_at'] == null
            ? null
            : DateTime.parse(row['location_captured_at'] as String),
      ),
      shiftInstanceId: row['shift_instance_id'] as String,
      deviceId: row['device_id'] as String?,
      captureProof: row['proof_installation_id'] == null ||
              row['proof_digest'] == null ||
              row['proof_signature'] == null
          ? null
          : OfflineAttendanceProof(
              installationId: row['proof_installation_id'] as String,
              digest: row['proof_digest'] as String,
              signature: row['proof_signature'] as String),
      status: AttendanceValidationStatusX.fromApiValue(
          row['sync_status'] as String),
      reasonCode: row['reason_code'] as String?,
    );
  }

  void close() {
    _changeController.close();
    _db.dispose();
  }
}
