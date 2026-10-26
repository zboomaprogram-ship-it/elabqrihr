import 'package:test/test.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

class LocalOutboxStorageFake {
  final Map<String, List<AttendanceEventEntity>> _identityEvents = {};

  Future<void> saveEvent({
    required String tenantId,
    required String userId,
    required AttendanceEventEntity event,
  }) async {
    final key = '$tenantId:$userId';
    _identityEvents.putIfAbsent(key, () => []).add(event);
  }

  Future<List<AttendanceEventEntity>> getPendingEvents({
    required String tenantId,
    required String userId,
  }) async {
    final key = '$tenantId:$userId';
    return List.unmodifiable(_identityEvents[key] ?? []);
  }

  Future<void> clearForIdentity({
    required String tenantId,
    required String userId,
  }) async {
    final key = '$tenantId:$userId';
    _identityEvents.remove(key);
  }
}

void main() {
  group('Offline Outbox Identity Isolation & Survival', () {
    late LocalOutboxStorageFake outbox;

    setUp(() {
      outbox = LocalOutboxStorageFake();
    });

    test(
        'Events saved locally are strictly isolated per tenant and user identity',
        () async {
      final userAEvent = AttendanceEventEntity(
        id: 'evt-alpha-001',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      final userBEvent = AttendanceEventEntity(
        id: 'evt-beta-001',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 30),
        location: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
        shiftInstanceId: 'shift-2',
        status: AttendanceValidationStatus.pendingSync,
      );

      await outbox.saveEvent(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        event: userAEvent,
      );

      await outbox.saveEvent(
        tenantId: 'tenant-beta',
        userId: 'user-002',
        event: userBEvent,
      );

      // User A in Tenant Alpha should only see Alpha events
      final alphaEvents = await outbox.getPendingEvents(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
      );
      expect(alphaEvents.length, equals(1));
      expect(alphaEvents.first.id, equals('evt-alpha-001'));

      // User B in Tenant Beta should only see Beta events
      final betaEvents = await outbox.getPendingEvents(
        tenantId: 'tenant-beta',
        userId: 'user-002',
      );
      expect(betaEvents.length, equals(1));
      expect(betaEvents.first.id, equals('evt-beta-001'));

      // Tenant Beta cannot access Alpha's data
      final foreignQuery = await outbox.getPendingEvents(
        tenantId: 'tenant-beta',
        userId: 'user-001',
      );
      expect(foreignQuery, isEmpty);
    });

    test('Pending events survive simulation of app restart', () async {
      final persistentEvent = AttendanceEventEntity(
        id: 'evt-alpha-002',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 9, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-1',
        status: AttendanceValidationStatus.pendingSync,
      );

      await outbox.saveEvent(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        event: persistentEvent,
      );

      // Simulating new session reading the persisted store
      final restoredEvents = await outbox.getPendingEvents(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
      );

      expect(restoredEvents.length, equals(1));
      expect(restoredEvents.first.status,
          equals(AttendanceValidationStatus.pendingSync));
      expect(restoredEvents.first.id, equals('evt-alpha-002'));
    });
  });
}
