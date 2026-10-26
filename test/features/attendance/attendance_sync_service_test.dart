import 'dart:io';
import 'package:test/test.dart';
import 'package:attend_mobile/features/attendance/data/attendance_sync_service.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';

class MockAttendanceRepo implements AttendanceRepository {
  int attempts = 0;
  bool shouldSucceed = false;
  bool throwConflict = false;
  int? throwStatus;
  DateTime? lastCapturedAt;
  AttendanceValidationStatus forcedStatus = AttendanceValidationStatus.accepted;

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() =>
      throw UnimplementedError();

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() =>
      throw UnimplementedError();

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    attempts++;
    lastCapturedAt = capturedAt;
    if (throwConflict) {
      throw const ApiException(statusCode: 409, message: 'duplicate');
    }
    if (throwStatus != null) {
      throw ApiException(statusCode: throwStatus!, message: 'server result');
    }
    if (!shouldSucceed) {
      throw const SocketException('offline');
    }
    return AttendanceEventEntity(
      id: clientEventId ?? 'evt-1',
      eventType: eventType,
      capturedAt: capturedAt ?? DateTime.utc(2026, 9, 20, 8, 0),
      location: location ?? const GeoPoint(latitude: 30.0, longitude: 31.0),
      shiftInstanceId: shiftInstanceId,
      status: forcedStatus,
      reasonCode: forcedStatus == AttendanceValidationStatus.pendingReview
          ? 'STALE_LOCATION'
          : forcedStatus == AttendanceValidationStatus.rejected
              ? 'FUTURE_TIMESTAMP'
              : null,
    );
  }
}

void main() {
  group('AttendanceSyncService', () {
    test('retries bounded number of times on network failure', () async {
      final repo = MockAttendanceRepo()..shouldSucceed = false;
      final service = AttendanceSyncService(
        repository: repo,
        maxRetries: 3,
        backoffStep: const Duration(milliseconds: 10),
      );

      final events = [
        AttendanceEventEntity(
          id: 'test-evt-1',
          eventType: AttendanceEventType.checkIn,
          capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
          location: const GeoPoint(latitude: 30.0, longitude: 31.0),
          shiftInstanceId: 'shift-1',
          status: AttendanceValidationStatus.pendingSync,
        ),
      ];

      final results = await service.syncBatch(events);

      expect(repo.attempts, equals(3));
      expect(results.length, equals(1));
      expect(results.first.outcome, equals(SyncOutcome.networkFailure));
      expect(results.first.retryAfter, const Duration(seconds: 30));
    });

    test('immediately stops and marks conflict without retrying on 409',
        () async {
      final repo = MockAttendanceRepo()..throwConflict = true;
      final service = AttendanceSyncService(
        repository: repo,
        maxRetries: 3,
        backoffStep: const Duration(milliseconds: 10),
      );

      final events = [
        AttendanceEventEntity(
          id: 'test-evt-conflict',
          eventType: AttendanceEventType.checkIn,
          capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
          location: const GeoPoint(latitude: 30.0, longitude: 31.0),
          shiftInstanceId: 'shift-1',
          status: AttendanceValidationStatus.pendingSync,
        ),
      ];

      final results = await service.syncBatch(events);

      expect(repo.attempts, equals(1));
      expect(results.first.outcome, equals(SyncOutcome.conflictDuplicate));
    });

    test('never retries terminal validation response', () async {
      final repo = MockAttendanceRepo()..throwStatus = 422;
      final service = AttendanceSyncService(
        repository: repo,
        maxRetries: 3,
        backoffStep: const Duration(milliseconds: 1),
      );
      final results = await service.syncBatch([_pendingEvent('terminal')]);
      expect(repo.attempts, 1);
      expect(results.single.outcome, SyncOutcome.rejected);
    });

    test('successful sync returns accepted outcome', () async {
      final repo = MockAttendanceRepo()..shouldSucceed = true;
      final service = AttendanceSyncService(
        repository: repo,
        maxRetries: 3,
        backoffStep: const Duration(milliseconds: 10),
      );

      final events = [
        AttendanceEventEntity(
          id: 'test-evt-success',
          eventType: AttendanceEventType.checkIn,
          capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
          location: const GeoPoint(latitude: 30.0, longitude: 31.0),
          shiftInstanceId: 'shift-1',
          status: AttendanceValidationStatus.pendingSync,
        ),
      ];

      final results = await service.syncBatch(events);

      expect(repo.attempts, equals(1));
      expect(results.first.outcome, equals(SyncOutcome.accepted));
      expect(repo.lastCapturedAt, DateTime.utc(2026, 9, 20, 8, 0));
    });

    test('stale original timestamp remains immutable and reaches review',
        () async {
      final capturedAt = DateTime.utc(2026, 9, 20, 7, 50);
      final repo = MockAttendanceRepo()
        ..shouldSucceed = true
        ..forcedStatus = AttendanceValidationStatus.pendingReview;
      final service = AttendanceSyncService(repository: repo);

      final results = await service.syncBatch([
        AttendanceEventEntity(
          id: 'stale-event',
          eventType: AttendanceEventType.checkIn,
          capturedAt: capturedAt,
          location: GeoPoint(
            latitude: 30,
            longitude: 31,
            timestamp: capturedAt,
          ),
          shiftInstanceId: 'shift-1',
          status: AttendanceValidationStatus.pendingSync,
        ),
      ]);

      expect(repo.lastCapturedAt, capturedAt);
      expect(results.single.outcome, SyncOutcome.reviewRequired);
    });

    test('future original timestamp remains immutable and is rejected',
        () async {
      final capturedAt = DateTime.utc(2026, 9, 20, 8, 10);
      final repo = MockAttendanceRepo()
        ..shouldSucceed = true
        ..forcedStatus = AttendanceValidationStatus.rejected;
      final service = AttendanceSyncService(repository: repo);

      final results = await service.syncBatch([
        AttendanceEventEntity(
          id: 'future-event',
          eventType: AttendanceEventType.checkIn,
          capturedAt: capturedAt,
          location: GeoPoint(
            latitude: 30,
            longitude: 31,
            timestamp: capturedAt,
          ),
          shiftInstanceId: 'shift-1',
          status: AttendanceValidationStatus.pendingSync,
        ),
      ]);

      expect(repo.lastCapturedAt, capturedAt);
      expect(results.single.outcome, SyncOutcome.rejected);
    });
  });
}

AttendanceEventEntity _pendingEvent(String id) => AttendanceEventEntity(
      id: id,
      eventType: AttendanceEventType.checkIn,
      capturedAt: DateTime.utc(2026, 9, 20, 8),
      location: const GeoPoint(latitude: 30, longitude: 31),
      shiftInstanceId: 'shift-1',
      status: AttendanceValidationStatus.pendingSync,
    );
