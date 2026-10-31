import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/database/sqlite_attendance_outbox.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

void main() {
  group(
      'SqliteAttendanceOutbox (T032-T033 Persistence & Multi-tenant isolation)',
      () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attend_db_test_');
      dbPath = '${tempDir.path}/outbox.db';
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Events persist to disk and survive across database re-open',
        () async {
      final outbox1 = await SqliteAttendanceOutbox.create(dbPath: dbPath);
      final event = AttendanceEventEntity(
        id: 'evt-persist-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(
            latitude: 30.0444, longitude: 31.2357, accuracyMeters: 12.0),
        shiftInstanceId: 'shift-123',
        captureProof: const OfflineAttendanceProof(
            installationId: 'test-installation',
            digest: 'test-digest',
            signature: 'test-signature'),
        status: AttendanceValidationStatus.pendingSync,
      );

      await outbox1.saveEvent(
          tenantId: 'tenant-alpha', userId: 'user-001', event: event);
      outbox1.close();

      // Re-open fresh database connection pointing to the same file
      final outbox2 = await SqliteAttendanceOutbox.create(dbPath: dbPath);
      final restored = await outbox2.getPendingEvents(
          tenantId: 'tenant-alpha', userId: 'user-001');

      expect(restored.length, equals(1));
      expect(restored.first.id, equals('evt-persist-1'));
      expect(restored.first.location.latitude, equals(30.0444));
      expect(restored.first.location.accuracyMeters, equals(12.0));
      expect(restored.first.captureProof?.signature, 'test-signature');
      expect(restored.first.captureProof?.digest, 'test-digest');
      outbox2.close();
    });

    test(
        'Strict multi-tenant & user identity isolation: cross-tenant access returns empty',
        () async {
      final outbox = SqliteAttendanceOutbox.inMemory();

      final eventAlpha = AttendanceEventEntity(
        id: 'evt-alpha',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      final eventBeta = AttendanceEventEntity(
        id: 'evt-beta',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 30),
        location: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
        shiftInstanceId: 'shift-2',
        status: AttendanceValidationStatus.pendingSync,
      );

      await outbox.saveEvent(
          tenantId: 'alpha', userId: 'user-1', event: eventAlpha);
      await outbox.saveEvent(
          tenantId: 'beta', userId: 'user-2', event: eventBeta);

      // Alpha identity queries
      final alphaEvents =
          await outbox.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(alphaEvents.length, equals(1));
      expect(alphaEvents.first.id, equals('evt-alpha'));

      // Beta identity queries
      final betaEvents =
          await outbox.getPendingEvents(tenantId: 'beta', userId: 'user-2');
      expect(betaEvents.length, equals(1));
      expect(betaEvents.first.id, equals('evt-beta'));

      // Cross-tenant attempt (user-1 in beta)
      final foreignQuery =
          await outbox.getPendingEvents(tenantId: 'beta', userId: 'user-1');
      expect(foreignQuery, isEmpty);

      outbox.close();
    });

    test('Ordered queue and terminal status transition', () async {
      final outbox = SqliteAttendanceOutbox.inMemory();

      final event1 = AttendanceEventEntity(
        id: 'evt-early',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 7, 59),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      final event2 = AttendanceEventEntity(
        id: 'evt-later',
        eventType: AttendanceEventType.checkOut,
        capturedAt: DateTime.utc(2026, 9, 20, 16, 0),
        location: const GeoPoint(latitude: 30.0, longitude: 31.0),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      await outbox.saveEvent(
          tenantId: 'alpha', userId: 'user-1', event: event2);
      await outbox.saveEvent(
          tenantId: 'alpha', userId: 'user-1', event: event1);

      // FIFO ordering by capturedAt
      final list =
          await outbox.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(list.length, equals(2));
      expect(list[0].id, equals('evt-early'));
      expect(list[1].id, equals('evt-later'));

      // Mark accepted -> should disappear from pending list
      await outbox.updateEventStatus(
        tenantId: 'alpha',
        userId: 'user-1',
        eventId: 'evt-early',
        status: AttendanceValidationStatus.accepted,
        reasonCode: 'ACCEPTED',
      );

      final remaining =
          await outbox.getPendingEvents(tenantId: 'alpha', userId: 'user-1');
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('evt-later'));

      outbox.close();
    });

    test('pending attendance query can return a FIFO bounded batch', () async {
      final outbox = SqliteAttendanceOutbox.inMemory();
      for (var i = 0; i < 3; i++) {
        await outbox.saveEvent(
          tenantId: 'alpha',
          userId: 'user-1',
          event: AttendanceEventEntity(
            id: 'evt-$i',
            eventType: AttendanceEventType.checkIn,
            capturedAt: DateTime.utc(2026, 9, 20, 8 + i),
            location: const GeoPoint(latitude: 30, longitude: 31),
            shiftInstanceId: 'shift-1',
            status: AttendanceValidationStatus.pendingSync,
          ),
        );
      }
      final batch = await outbox.getPendingEvents(
        tenantId: 'alpha',
        userId: 'user-1',
        limit: 2,
      );
      expect(batch.map((event) => event.id), ['evt-0', 'evt-1']);
      outbox.close();
    });

    test('pending attendance query rejects non-positive limits', () async {
      final outbox = SqliteAttendanceOutbox.inMemory();
      for (final limit in [0, -1]) {
        expect(
          outbox.getPendingEvents(
            tenantId: 'alpha',
            userId: 'user-1',
            limit: limit,
          ),
          throwsArgumentError,
        );
      }
      outbox.close();
    });

    test(
        'terminal rejection survives restart and is never returned to retry queue',
        () async {
      final outbox1 = await SqliteAttendanceOutbox.create(dbPath: dbPath);
      final event = AttendanceEventEntity(
        id: 'evt-terminal',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8),
        location: const GeoPoint(latitude: 30, longitude: 31),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );
      await outbox1.saveEvent(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        event: event,
      );
      await outbox1.updateEventStatus(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        eventId: event.id,
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'LOCATION_OUT_OF_RADIUS',
      );
      outbox1.close();

      final outbox2 = await SqliteAttendanceOutbox.create(dbPath: dbPath);
      expect(
        await outbox2.getPendingEvents(
          tenantId: 'tenant-alpha',
          userId: 'user-001',
        ),
        isEmpty,
      );
      outbox2.close();
    });
  });
}
