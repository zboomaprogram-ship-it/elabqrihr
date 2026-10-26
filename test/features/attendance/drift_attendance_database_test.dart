import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('AppDriftDatabase (T032-T033 Drift Outbox Persistence & Isolation)',
      () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attend_drift_test_');
      dbFile = File('${tempDir.path}/drift_outbox.sqlite');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'Events persist to Drift database and survive across database connection close & reopen',
        () async {
      final db1 = AppDriftDatabase(NativeDatabase(dbFile));
      final event = AttendanceEventEntity(
        id: 'drift-evt-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(
            latitude: 30.0444, longitude: 31.2357, accuracyMeters: 10.0),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.pendingSync,
      );

      await db1.saveEvent(
          tenantId: 'tenant-alpha', userId: 'user-001', event: event);
      await db1.close();

      // Fresh connection to same SQLite file
      final db2 = AppDriftDatabase(NativeDatabase(dbFile));
      final restored = await db2.getPendingEvents(
          tenantId: 'tenant-alpha', userId: 'user-001');

      expect(restored.length, equals(1));
      expect(restored.first.id, equals('drift-evt-1'));
      expect(
          restored.first.capturedAt.toUtc(), DateTime.utc(2026, 9, 20, 8, 0));
      expect(restored.first.location.latitude, equals(30.0444));
      expect(restored.first.status,
          equals(AttendanceValidationStatus.pendingSync));

      await db2.close();
    });

    test('Strict tenant and user identity isolation across operations',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());

      final eventA = AttendanceEventEntity(
        id: 'evt-alpha',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      final eventB = AttendanceEventEntity(
        id: 'evt-beta',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 15),
        location: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
        shiftInstanceId: 'shift-2',
        status: AttendanceValidationStatus.pendingSync,
      );

      await db.saveEvent(tenantId: 'alpha', userId: 'user-1', event: eventA);
      await db.saveEvent(tenantId: 'beta', userId: 'user-2', event: eventB);

      // Identity 1 sees only alpha
      final alphaEvents =
          await db.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(alphaEvents.length, equals(1));
      expect(alphaEvents.first.id, equals('evt-alpha'));

      // Foreign identity query returns empty
      final foreignQuery =
          await db.getPendingEvents(tenantId: 'beta', userId: 'user-1');
      expect(foreignQuery, isEmpty);

      await db.close();
    });

    test(
        'Retry metadata persists and terminal update removes from pending list',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());

      final event = AttendanceEventEntity(
        id: 'evt-retry',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      await db.saveEvent(tenantId: 'alpha', userId: 'user-1', event: event);

      // Transient retry update
      final nextRetry = DateTime.utc(2026, 9, 20, 8, 0, 30);
      await db.updateEventStatus(
        tenantId: 'alpha',
        userId: 'user-1',
        eventId: 'evt-retry',
        status: AttendanceValidationStatus.pendingSync,
        reasonCode: '503_TEMPORARY_ERROR',
        isRetryAttempt: true,
        nextRetryAt: nextRetry,
      );

      final pendingAfterRetry =
          await db.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(pendingAfterRetry.length, equals(1));

      // Terminal conflict update
      await db.updateEventStatus(
        tenantId: 'alpha',
        userId: 'user-1',
        eventId: 'evt-retry',
        status: AttendanceValidationStatus.conflict,
        reasonCode: 'CONFLICT_DUPLICATE',
      );

      // Terminal states are no longer in pendingSync
      final pendingAfterConflict =
          await db.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(pendingAfterConflict, isEmpty);

      await db.close();
    });

    test(
        'Drift inspects persisted retryCount and nextRetryAt metadata directly',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());

      final event = AttendanceEventEntity(
        id: 'evt-metadata-check',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      await db.saveEvent(tenantId: 'tenant-x', userId: 'user-y', event: event);

      final nextRetry = DateTime.utc(2026, 9, 20, 8, 5, 0);
      await db.updateEventStatus(
        tenantId: 'tenant-x',
        userId: 'user-y',
        eventId: 'evt-metadata-check',
        status: AttendanceValidationStatus.pendingSync,
        reasonCode: '503_TEMPORARY_UNAVAILABLE',
        isRetryAttempt: true,
        nextRetryAt: nextRetry,
      );

      final entry = await db.getEntry(
        tenantId: 'tenant-x',
        userId: 'user-y',
        eventId: 'evt-metadata-check',
      );

      expect(entry, isNotNull);
      expect(entry!.retryCount, equals(1));
      expect(entry.reasonCode, equals('503_TEMPORARY_UNAVAILABLE'));
      expect(entry.nextRetryAt?.toUtc(), equals(nextRetry));

      await db.close();
    });

    test('does not submit an attendance retry before its persisted due time',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());
      final event = AttendanceEventEntity(
        id: 'evt-deferred-retry',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8),
        location: const GeoPoint(latitude: 30, longitude: 31),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );
      await db.saveEvent(tenantId: 'tenant', userId: 'user', event: event);
      await db.updateEventStatus(
        tenantId: 'tenant',
        userId: 'user',
        eventId: event.id,
        status: AttendanceValidationStatus.pendingSync,
        isRetryAttempt: true,
        nextRetryAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      expect(
        await db.getPendingEvents(tenantId: 'tenant', userId: 'user'),
        isEmpty,
      );
      await db.close();
    });

    test('logout purge removes only the current identity local data', () async {
      final db = AppDriftDatabase(NativeDatabase.memory());
      final alphaEvent = AttendanceEventEntity(
        id: 'alpha-purge-event',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8),
        location: const GeoPoint(latitude: 30, longitude: 31),
        shiftInstanceId: 'alpha-shift',
        status: AttendanceValidationStatus.pendingSync,
      );
      final betaEvent = AttendanceEventEntity(
        id: 'beta-keep-event',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8),
        location: const GeoPoint(latitude: 24, longitude: 46),
        shiftInstanceId: 'beta-shift',
        status: AttendanceValidationStatus.pendingSync,
      );
      await db.saveEvent(
          tenantId: 'alpha', userId: 'employee', event: alphaEvent);
      await db.saveEvent(
          tenantId: 'beta', userId: 'employee', event: betaEvent);
      await db.saveRequest(
        tenantId: 'alpha',
        userId: 'employee',
        id: 'alpha-request',
        requestType: 'leave',
        payloadJson: '{}',
      );
      await db.saveProfile(
        tenantId: 'alpha',
        userId: 'employee',
        profileJson: '{"name":"Alpha"}',
      );

      await db.clearIdentity(tenantId: 'alpha', userId: 'employee');

      expect(
        await db.getPendingEvents(tenantId: 'alpha', userId: 'employee'),
        isEmpty,
      );
      expect(
        await db.getAllRequests(tenantId: 'alpha', userId: 'employee'),
        isEmpty,
      );
      expect(
        await db.getCachedProfile(tenantId: 'alpha', userId: 'employee'),
        isNull,
      );
      expect(
        await db.getPendingEvents(tenantId: 'beta', userId: 'employee'),
        hasLength(1),
      );
      await db.close();
    });

    test(
        'Foreign identity cannot update status or mutate rows owned by another identity',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());

      final event = AttendanceEventEntity(
        id: 'evt-protected',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      await db.saveEvent(
          tenantId: 'tenant-legit', userId: 'user-legit', event: event);

      // Attempt foreign tenant update
      await db.updateEventStatus(
        tenantId: 'tenant-attacker',
        userId: 'user-legit',
        eventId: 'evt-protected',
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'MALICIOUS_UPDATE',
      );

      // Attempt foreign user update
      await db.updateEventStatus(
        tenantId: 'tenant-legit',
        userId: 'user-attacker',
        eventId: 'evt-protected',
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'MALICIOUS_UPDATE',
      );

      final entry = await db.getEntry(
        tenantId: 'tenant-legit',
        userId: 'user-legit',
        eventId: 'evt-protected',
      );

      expect(entry, isNotNull);
      // Status must remain original pendingSync because foreign updates had no effect
      expect(entry!.syncStatus, equals('pending_sync'));
      expect(entry.reasonCode, isNull);

      await db.close();
    });

    test('Logout/login identity switching maintains complete outbox isolation',
        () async {
      final db = AppDriftDatabase(NativeDatabase(dbFile));

      // 1. User 1 on Tenant Alpha logs in and creates pending offline event
      final event1 = AttendanceEventEntity(
        id: 'evt-user1-alpha',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-alpha-1',
        status: AttendanceValidationStatus.pendingSync,
      );
      await db.saveEvent(
          tenantId: 'tenant-alpha', userId: 'user-1', event: event1);

      // Simulate Logout (app switches active session context)

      // 2. User 2 on Tenant Beta logs in
      final user2Events =
          await db.getPendingEvents(tenantId: 'tenant-beta', userId: 'user-2');
      expect(user2Events, isEmpty);

      final event2 = AttendanceEventEntity(
        id: 'evt-user2-beta',
        eventType: AttendanceEventType.checkOut,
        capturedAt: DateTime.utc(2026, 9, 20, 17, 0),
        location: const GeoPoint(latitude: 24.0, longitude: 46.0),
        shiftInstanceId: 'shift-beta-1',
        status: AttendanceValidationStatus.pendingSync,
      );
      await db.saveEvent(
          tenantId: 'tenant-beta', userId: 'user-2', event: event2);

      // User 2 sees only their event
      final user2Pending =
          await db.getPendingEvents(tenantId: 'tenant-beta', userId: 'user-2');
      expect(user2Pending.length, equals(1));
      expect(user2Pending.first.id, equals('evt-user2-beta'));

      // Simulate Logout and Login back as User 1 on Tenant Alpha
      final user1Restored =
          await db.getPendingEvents(tenantId: 'tenant-alpha', userId: 'user-1');
      expect(user1Restored.length, equals(1));
      expect(user1Restored.first.id, equals('evt-user1-alpha'));

      await db.close();
    });

    test(
        'Schema migration v1 -> v2 preserves immutable event payload and upgrades schema',
        () async {
      // 1. Create a raw SQLite database fixture with v1 schema (PRAGMA user_version = 1)
      final rawDb = sqlite3.open(dbFile.path);
      rawDb.execute('''
        CREATE TABLE local_attendance_entries (
          id TEXT NOT NULL PRIMARY KEY,
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
          created_at INTEGER NOT NULL
        );
      ''');
      rawDb.execute('PRAGMA user_version = 1;');

      final nowUnix =
          DateTime.utc(2026, 9, 20, 8, 30).millisecondsSinceEpoch ~/ 1000;
      rawDb.execute('''
        INSERT INTO local_attendance_entries (
          id, tenant_id, user_id, shift_instance_id, event_type, captured_at,
          latitude, longitude, accuracy_meters, device_id, sync_status, created_at
        ) VALUES (
          'v1-event-999', 'tenant-migrated', 'user-migrated', 'shift-v1', 'check_in',
          $nowUnix, 30.0444, 31.2357, 12.5, 'dev-v1', 'pending_sync', $nowUnix
        );
      ''');
      rawDb.dispose();

      // 2. Open with Drift AppDriftDatabase (schemaVersion = 2), triggering onUpgrade
      final driftDb = AppDriftDatabase(NativeDatabase(dbFile));

      final pending = await driftDb.getPendingEvents(
        tenantId: 'tenant-migrated',
        userId: 'user-migrated',
      );

      expect(pending.length, equals(1));
      final migrated = pending.first;
      expect(migrated.id, equals('v1-event-999'));
      expect(migrated.shiftInstanceId, equals('shift-v1'));
      expect(migrated.location.latitude, equals(30.0444));
      expect(migrated.location.longitude, equals(31.2357));
      expect(migrated.location.accuracyMeters, equals(12.5));
      expect(migrated.status, equals(AttendanceValidationStatus.pendingSync));

      // Inspect new v2 columns via getEntry
      final entry = await driftDb.getEntry(
        tenantId: 'tenant-migrated',
        userId: 'user-migrated',
        eventId: 'v1-event-999',
      );
      expect(entry, isNotNull);
      expect(entry!.retryCount, equals(0));
      expect(entry.reasonCode, isNull);
      expect(entry.nextRetryAt, isNull);

      // Verify that v2 updates on the migrated row succeed
      await driftDb.updateEventStatus(
        tenantId: 'tenant-migrated',
        userId: 'user-migrated',
        eventId: 'v1-event-999',
        status: AttendanceValidationStatus.pendingSync,
        reasonCode: 'TEMPORARY_NETWORK_FAILURE',
        isRetryAttempt: true,
      );

      final updatedEntry = await driftDb.getEntry(
        tenantId: 'tenant-migrated',
        userId: 'user-migrated',
        eventId: 'v1-event-999',
      );
      expect(updatedEntry!.retryCount, equals(1));
      expect(updatedEntry.reasonCode, equals('TEMPORARY_NETWORK_FAILURE'));

      await driftDb.close();
    });

    test(
        'Schema migration v3 -> v4 preserves rows and scopes duplicate IDs by identity',
        () async {
      final rawDb = sqlite3.open(dbFile.path);
      rawDb.execute('''
        CREATE TABLE local_attendance_entries (
          id TEXT NOT NULL PRIMARY KEY,
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
          created_at INTEGER NOT NULL
        );
      ''');
      rawDb.execute('''
        CREATE TABLE local_request_entries (
          id TEXT NOT NULL PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          request_type TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          sync_status TEXT NOT NULL,
          reason_code TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          next_retry_at INTEGER,
          created_at INTEGER NOT NULL
        );
      ''');
      final timestamp =
          DateTime.utc(2026, 9, 21, 8).millisecondsSinceEpoch ~/ 1000;
      rawDb.execute('''
        INSERT INTO local_attendance_entries VALUES (
          'shared-id', 'tenant-alpha', 'user-alpha', 'shift-alpha', 'check_in',
          $timestamp, 30.0, 31.0, 8.0, NULL, 'pending_sync', NULL, 0, NULL, $timestamp
        );
      ''');
      rawDb.execute('''
        INSERT INTO local_request_entries VALUES (
          'shared-request', 'tenant-alpha', 'user-alpha', 'leave', '{}',
          'pending_sync', NULL, 0, NULL, $timestamp
        );
      ''');
      rawDb.execute('PRAGMA user_version = 3;');
      rawDb.dispose();

      final db = AppDriftDatabase(NativeDatabase(dbFile));
      await db.saveEvent(
        tenantId: 'tenant-beta',
        userId: 'user-beta',
        event: AttendanceEventEntity(
          id: 'shared-id',
          eventType: AttendanceEventType.checkOut,
          capturedAt: DateTime.utc(2026, 9, 21, 9),
          location: const GeoPoint(latitude: 24.0, longitude: 46.0),
          shiftInstanceId: 'shift-beta',
          status: AttendanceValidationStatus.pendingSync,
        ),
      );
      await db.saveRequest(
        tenantId: 'tenant-beta',
        userId: 'user-beta',
        id: 'shared-request',
        requestType: 'permission',
        payloadJson: '{}',
      );

      expect(
        await db.getEntry(
          tenantId: 'tenant-alpha',
          userId: 'user-alpha',
          eventId: 'shared-id',
        ),
        isNotNull,
      );
      expect(
        await db.getEntry(
          tenantId: 'tenant-beta',
          userId: 'user-beta',
          eventId: 'shared-id',
        ),
        isNotNull,
      );
      expect(
        await db.getRequestEntry(
          tenantId: 'tenant-alpha',
          userId: 'user-alpha',
          requestId: 'shared-request',
        ),
        isNotNull,
      );
      expect(
        await db.getRequestEntry(
          tenantId: 'tenant-beta',
          userId: 'user-beta',
          requestId: 'shared-request',
        ),
        isNotNull,
      );
      await db.close();
    });

    test(
        'Schema migration v4 -> v5 creates local_profile_entries table and persists data',
        () async {
      // 1. Create a raw SQLite database with v4 schema
      final rawDb = sqlite3.open(dbFile.path);
      rawDb.execute('''
        CREATE TABLE local_attendance_entries (
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
      rawDb.execute('PRAGMA user_version = 4;');
      rawDb.dispose();

      // 2. Open with Drift AppDriftDatabase (schemaVersion = 5), triggering onUpgrade
      final driftDb = AppDriftDatabase(NativeDatabase(dbFile));

      await driftDb.saveProfile(
        tenantId: 'tenant-v5',
        userId: 'user-v5',
        profileJson: '{"displayName": "مهندس تجريبي"}',
      );

      final cached = await driftDb.getCachedProfile(
        tenantId: 'tenant-v5',
        userId: 'user-v5',
      );

      expect(cached, isNotNull);
      expect(cached, contains('مهندس تجريبي'));

      await driftDb.close();
    });

    test('Profile caching enforces strict tenant and user identity isolation',
        () async {
      final db = AppDriftDatabase(NativeDatabase.memory());

      await db.saveProfile(
        tenantId: 'tenant-1',
        userId: 'user-1',
        profileJson: '{"displayName": "أحمد"}',
      );

      await db.saveProfile(
        tenantId: 'tenant-2',
        userId: 'user-1',
        profileJson: '{"displayName": "سارة"}',
      );

      final p1 =
          await db.getCachedProfile(tenantId: 'tenant-1', userId: 'user-1');
      final p2 =
          await db.getCachedProfile(tenantId: 'tenant-2', userId: 'user-1');
      final foreign =
          await db.getCachedProfile(tenantId: 'tenant-3', userId: 'user-1');

      expect(p1, contains('أحمد'));
      expect(p2, contains('سارة'));
      expect(foreign, isNull);

      await db.close();
    });
  });
}
