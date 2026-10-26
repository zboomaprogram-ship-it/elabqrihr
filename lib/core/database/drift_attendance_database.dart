import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/open.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/local_attendance_outbox.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

part 'drift_attendance_database.g.dart';

void _configureSqlCipher() {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}

void _assertSqlCipherAvailable(dynamic database) {
  if (database.select('PRAGMA cipher_version;').isEmpty) {
    throw StateError(
      'SQLCipher is unavailable. Refusing to open the offline database without encryption.',
    );
  }
}

String _escapeSqlLiteral(String value) => value.replaceAll("'", "''");

const _plaintextSqliteHeader = <int>[
  0x53,
  0x51,
  0x4c,
  0x69,
  0x74,
  0x65,
  0x20,
  0x66,
  0x6f,
  0x72,
  0x6d,
  0x61,
  0x74,
  0x20,
  0x33,
  0x00,
];

Future<void> _encryptExistingPlaintextDatabase(
    File database, String key) async {
  if (!await database.exists()) return;

  final header = await database
      .openRead(0, _plaintextSqliteHeader.length)
      .fold<List<int>>(<int>[], (buffer, bytes) => buffer..addAll(bytes));
  final isPlaintext = header.length == _plaintextSqliteHeader.length &&
      List.generate(header.length,
              (index) => header[index] == _plaintextSqliteHeader[index])
          .every((value) => value);
  if (!isPlaintext) return;

  final temporary = File('${database.path}.encrypting');
  final backup = File('${database.path}.plaintext-backup');
  await _deleteIfExists(temporary);
  await _deleteIfExists(backup);

  try {
    // The source database is still plaintext here. Create a consistent copy,
    // then use SQLCipher's rekey command to encrypt that copy before any file
    // is swapped into place.
    final source = sqlite3.open(database.path);
    try {
      source.execute('PRAGMA wal_checkpoint(FULL);');
      source.execute("VACUUM INTO '${_escapeSqlLiteral(temporary.path)}';");
    } finally {
      source.dispose();
    }

    final encrypted = sqlite3.open(temporary.path);
    try {
      _assertSqlCipherAvailable(encrypted);
      encrypted.execute("PRAGMA rekey = '${_escapeSqlLiteral(key)}';");
    } finally {
      encrypted.dispose();
    }

    await database.rename(backup.path);
    await temporary.rename(database.path);
    await backup.delete();
  } catch (_) {
    if (!await database.exists() && await backup.exists()) {
      await backup.rename(database.path);
    }
    rethrow;
  } finally {
    await _deleteIfExists(temporary);
  }
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) await file.delete();
}

@DataClassName('LocalAttendanceRow')
class LocalAttendanceEntries extends Table {
  TextColumn get id => text()(); // Stable client UUID
  TextColumn get tenantId => text()();
  TextColumn get userId => text()();
  TextColumn get shiftInstanceId => text()();
  TextColumn get eventType => text()(); // check_in | check_out
  DateTimeColumn get capturedAt => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracyMeters => real().nullable()();
  TextColumn get deviceId => text().nullable()();
  TextColumn get syncStatus =>
      text()(); // pending_sync | accepted | rejected | pending_review | conflict
  TextColumn get reasonCode => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tenantId, userId, id};
}

@DataClassName('LocalRequestRow')
class LocalRequestEntries extends Table {
  TextColumn get id => text()(); // Stable client UUID
  TextColumn get tenantId => text()();
  TextColumn get userId => text()();
  TextColumn get requestType =>
      text()(); // leave | permission | attendance_correction
  TextColumn get payloadJson => text()();
  TextColumn get syncStatus =>
      text()(); // pending_sync | submitted | conflict | rejected
  TextColumn get reasonCode => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tenantId, userId, id};
}

@DriftDatabase(tables: [LocalAttendanceEntries, LocalRequestEntries])
class AppDriftDatabase extends _$AppDriftDatabase
    implements LocalAttendanceOutbox {
  AppDriftDatabase(super.e);

  /// Opens the durable offline store encrypted with a per-installation key.
  ///
  /// The SQLCipher library is selected in every Drift isolate before the file
  /// is opened. Failing closed here is intentional: silently falling back to
  /// plaintext storage would expose attendance locations and request data.
  static Future<AppDriftDatabase> open({TokenStorage? tokenStorage}) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'attend_outbox.sqlite'));
    final key =
        await (tokenStorage ?? TokenStorage()).getOrCreateOfflineDatabaseKey();

    _configureSqlCipher();
    await _encryptExistingPlaintextDatabase(file, key);
    return AppDriftDatabase(
      NativeDatabase.createInBackground(
        file,
        isolateSetup: _configureSqlCipher,
        setup: (database) {
          _assertSqlCipherAvailable(database);
          database.execute("PRAGMA key = '${_escapeSqlLiteral(key)}';");
          // Verify that the key can actually read the database before Drift
          // runs migrations. This prevents an accidental plaintext fallback.
          database.select('SELECT count(*) FROM sqlite_master;');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement('''
            CREATE TABLE IF NOT EXISTS local_profile_entries (
              tenant_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              profile_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (tenant_id, user_id)
            );
          ''');
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(
                localAttendanceEntries, localAttendanceEntries.reasonCode);
            await m.addColumn(
                localAttendanceEntries, localAttendanceEntries.retryCount);
            await m.addColumn(
                localAttendanceEntries, localAttendanceEntries.nextRetryAt);
          }
          if (from < 3) {
            await m.createTable(localRequestEntries);
          }
          if (from < 4) {
            // Re-create local_attendance_entries with composite PK (tenant_id, user_id, id)
            await customStatement('''
              CREATE TABLE local_attendance_entries_v4 (
                id TEXT NOT NULL,
                tenant_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                shift_instance_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                captured_at INTEGER NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                accuracy_meters REAL,
                device_id TEXT,
                sync_status TEXT NOT NULL,
                reason_code TEXT,
                retry_count INTEGER NOT NULL DEFAULT 0,
                next_retry_at INTEGER,
                created_at INTEGER NOT NULL,
                PRIMARY KEY (tenant_id, user_id, id)
              );
            ''');
            await customStatement('''
              INSERT INTO local_attendance_entries_v4 
              SELECT id, tenant_id, user_id, shift_instance_id, event_type, captured_at,
                     latitude, longitude, accuracy_meters, device_id, sync_status,
                     reason_code, retry_count, next_retry_at, created_at
              FROM local_attendance_entries;
            ''');
            await customStatement('DROP TABLE local_attendance_entries;');
            await customStatement(
                'ALTER TABLE local_attendance_entries_v4 RENAME TO local_attendance_entries;');

            // Re-create local_request_entries with composite PK (tenant_id, user_id, id) if it exists
            final hasReqTable = await customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name='local_request_entries';")
                .get();
            if (hasReqTable.isNotEmpty) {
              await customStatement('''
                CREATE TABLE local_request_entries_v4 (
                  id TEXT NOT NULL,
                  tenant_id TEXT NOT NULL,
                  user_id TEXT NOT NULL,
                  request_type TEXT NOT NULL,
                  payload_json TEXT NOT NULL,
                  sync_status TEXT NOT NULL,
                  reason_code TEXT,
                  retry_count INTEGER NOT NULL DEFAULT 0,
                  next_retry_at INTEGER,
                  created_at INTEGER NOT NULL,
                  PRIMARY KEY (tenant_id, user_id, id)
                );
              ''');
              await customStatement('''
                INSERT INTO local_request_entries_v4 
                SELECT id, tenant_id, user_id, request_type, payload_json, sync_status,
                       reason_code, retry_count, next_retry_at, created_at
                FROM local_request_entries;
              ''');
              await customStatement('DROP TABLE local_request_entries;');
              await customStatement(
                  'ALTER TABLE local_request_entries_v4 RENAME TO local_request_entries;');
            }
          }
          if (from < 5) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS local_profile_entries (
                tenant_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                profile_json TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (tenant_id, user_id)
              );
            ''');
          }
        },
      );

  /// Identity-scoped row inspection for testing assertions and audit verification
  Future<LocalAttendanceRow?> getEntry({
    required String tenantId,
    required String userId,
    required String eventId,
  }) {
    return (select(localAttendanceEntries)
          ..where((t) =>
              t.id.equals(eventId) &
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId)))
        .getSingleOrNull();
  }

  @override
  Future<void> saveEvent({
    required String tenantId,
    required String userId,
    required AttendanceEventEntity event,
  }) async {
    await into(localAttendanceEntries).insertOnConflictUpdate(
      LocalAttendanceEntriesCompanion(
        id: Value(event.id),
        tenantId: Value(tenantId),
        userId: Value(userId),
        shiftInstanceId: Value(event.shiftInstanceId),
        eventType: Value(event.eventType.toApiValue()),
        capturedAt: Value(event.capturedAt.toUtc()),
        latitude: Value(event.location.latitude),
        longitude: Value(event.location.longitude),
        accuracyMeters: Value(event.location.accuracyMeters),
        deviceId: Value(event.deviceId),
        syncStatus: Value(AttendanceValidationStatus.pendingSync.toApiValue()),
        reasonCode: Value(event.reasonCode),
        retryCount: const Value(0),
        nextRetryAt: const Value(null),
        createdAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<List<AttendanceEventEntity>> getPendingEvents({
    required String tenantId,
    required String userId,
  }) async {
    final now = DateTime.now().toUtc();
    final rows = await (select(localAttendanceEntries)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId) &
              t.syncStatus.equals('pending_sync') &
              (t.nextRetryAt.isNull() |
                  t.nextRetryAt.isSmallerOrEqualValue(now)))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.capturedAt, mode: OrderingMode.asc)
          ]))
        .get();

    return rows.map((r) => _toEntity(r)).toList();
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents({
    required String tenantId,
    required String userId,
  }) {
    return (select(localAttendanceEntries)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId) &
              t.syncStatus.equals('pending_sync'))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.capturedAt, mode: OrderingMode.asc)
          ]))
        .watch()
        .map((rows) => rows.map((r) => _toEntity(r)).toList());
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
    final existing = await (select(localAttendanceEntries)
          ..where((t) =>
              t.id.equals(eventId) &
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId)))
        .getSingleOrNull();

    if (existing == null) return;

    await (update(localAttendanceEntries)
          ..where((t) =>
              t.id.equals(eventId) &
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId)))
        .write(
      LocalAttendanceEntriesCompanion(
        syncStatus: Value(status.toApiValue()),
        reasonCode: Value(reasonCode),
        retryCount: Value(
            isRetryAttempt ? existing.retryCount + 1 : existing.retryCount),
        nextRetryAt: Value(nextRetryAt?.toUtc()),
      ),
    );
  }

  /// Removes all locally cached, identity-scoped data on logout or session
  /// invalidation. Server records and audit evidence are never touched.
  Future<void> clearIdentity({
    required String tenantId,
    required String userId,
  }) async {
    await transaction(() async {
      await (delete(localAttendanceEntries)
            ..where(
                (t) => t.tenantId.equals(tenantId) & t.userId.equals(userId)))
          .go();
      await (delete(localRequestEntries)
            ..where(
                (t) => t.tenantId.equals(tenantId) & t.userId.equals(userId)))
          .go();
      await customStatement(
        'DELETE FROM local_profile_entries WHERE tenant_id = ? AND user_id = ?',
        [tenantId, userId],
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Request Outbox (Feature 002: T023)
  // ---------------------------------------------------------------------------

  Future<void> saveRequest({
    required String tenantId,
    required String userId,
    required String id,
    required String requestType,
    required String payloadJson,
    String syncStatus = 'pending_sync',
    String? reasonCode,
    DateTime? createdAt,
  }) async {
    final existing = await getRequestEntry(
      tenantId: tenantId,
      userId: userId,
      requestId: id,
    );
    if (existing != null) {
      // Do not overwrite an existing row if it already has a terminal status or is in conflict
      if (existing.syncStatus != 'pending_sync') {
        return;
      }
    }

    final now = (createdAt ?? DateTime.now()).toUtc();
    await into(localRequestEntries).insertOnConflictUpdate(
      LocalRequestEntriesCompanion(
        id: Value(id),
        tenantId: Value(tenantId),
        userId: Value(userId),
        requestType: Value(requestType),
        payloadJson: Value(payloadJson),
        syncStatus: Value(existing?.syncStatus ?? syncStatus),
        reasonCode: Value(existing?.reasonCode ?? reasonCode),
        createdAt: Value(existing?.createdAt ?? now),
      ),
    );
  }

  Future<List<LocalRequestRow>> getPendingRequests({
    required String tenantId,
    required String userId,
    DateTime? now,
  }) async {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return (select(localRequestEntries)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId) &
              t.syncStatus.equals('pending_sync') &
              (t.nextRetryAt.isNull() |
                  t.nextRetryAt.isSmallerOrEqualValue(currentTime)))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        .get();
  }

  Future<List<LocalRequestRow>> getAllRequests({
    required String tenantId,
    required String userId,
  }) async {
    return (select(localRequestEntries)
          ..where((t) => t.tenantId.equals(tenantId) & t.userId.equals(userId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Stream<List<LocalRequestRow>> watchPendingRequests({
    required String tenantId,
    required String userId,
  }) {
    return (select(localRequestEntries)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId) &
              t.syncStatus.equals('pending_sync'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)
          ]))
        .watch();
  }

  Future<LocalRequestRow?> getRequestEntry({
    required String tenantId,
    required String userId,
    required String requestId,
  }) async {
    return (select(localRequestEntries)
          ..where((t) =>
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId) &
              t.id.equals(requestId)))
        .getSingleOrNull();
  }

  Future<void> updateRequestStatus({
    required String tenantId,
    required String userId,
    required String requestId,
    required String status,
    String? reasonCode,
    bool isRetryAttempt = false,
    DateTime? nextRetryAt,
  }) async {
    final existing = await (select(localRequestEntries)
          ..where((t) =>
              t.id.equals(requestId) &
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId)))
        .getSingleOrNull();

    if (existing == null) return;

    await (update(localRequestEntries)
          ..where((t) =>
              t.id.equals(requestId) &
              t.tenantId.equals(tenantId) &
              t.userId.equals(userId)))
        .write(
      LocalRequestEntriesCompanion(
        syncStatus: Value(status),
        reasonCode: Value(reasonCode),
        retryCount: Value(
            isRetryAttempt ? existing.retryCount + 1 : existing.retryCount),
        nextRetryAt: Value(nextRetryAt?.toUtc()),
      ),
    );
  }

  AttendanceEventEntity _toEntity(LocalAttendanceRow row) {
    return AttendanceEventEntity(
      id: row.id,
      eventType: AttendanceEventTypeX.fromApiValue(row.eventType),
      capturedAt: row.capturedAt,
      location: GeoPoint(
        latitude: row.latitude,
        longitude: row.longitude,
        accuracyMeters: row.accuracyMeters,
      ),
      shiftInstanceId: row.shiftInstanceId,
      deviceId: row.deviceId,
      status: AttendanceValidationStatusX.fromApiValue(row.syncStatus),
      reasonCode: row.reasonCode,
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Cache (Feature 004: T007)
  // ---------------------------------------------------------------------------

  Future<void> saveProfile({
    required String tenantId,
    required String userId,
    required String profileJson,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await customStatement('''
      INSERT INTO local_profile_entries (tenant_id, user_id, profile_json, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(tenant_id, user_id) DO UPDATE SET
        profile_json = excluded.profile_json,
        updated_at = excluded.updated_at;
    ''', [tenantId, userId, profileJson, now]);
  }

  Future<String?> getCachedProfile({
    required String tenantId,
    required String userId,
  }) async {
    final res = await customSelect(
      'SELECT profile_json FROM local_profile_entries WHERE tenant_id = ? AND user_id = ?;',
      variables: [Variable.withString(tenantId), Variable.withString(userId)],
    ).getSingleOrNull();
    return res?.data['profile_json'] as String?;
  }
}
