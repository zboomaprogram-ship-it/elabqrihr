import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';

class MockOfflineApiClient extends ApiClient {
  bool isOnline = false;
  int serverSubmissionCount = 0;
  final List<String> receivedEventIds = [];

  MockOfflineApiClient({required super.baseUrl, required super.tokenStorage});

  @override
  Future<ShiftContextEntity> getCurrentAttendanceContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-acceptance-001',
      branchName: 'Cairo HQ',
      shiftName: 'Morning Shift',
      scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required String eventId,
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    required GeoPoint location,
    required DateTime capturedAt,
    AttendanceEvidenceDto? evidence,
  }) async {
    if (!isOnline) {
      throw const SocketException('Network is unreachable (offline)');
    }

    serverSubmissionCount++;
    receivedEventIds.add(eventId);

    return AttendanceEventEntity(
      id: eventId,
      eventType: eventType,
      capturedAt: capturedAt,
      location: location,
      shiftInstanceId: shiftInstanceId,
      status: AttendanceValidationStatus.accepted,
      reasonCode: 'ACCEPTED',
    );
  }
}

class EphemeralTokenStorage extends TokenStorage {
  AuthSessionEntity? session;

  @override
  Future<void> saveSession(AuthSessionEntity s) async {
    session = s;
  }

  @override
  Future<AuthSessionEntity?> getSession() async {
    return session;
  }

  @override
  Future<void> clearSession() async {
    session = null;
  }
}

void main() {
  group('T036 Process-Restart Offline Attendance Journey', () {
    late Directory tempDir;
    late File dbFile;
    late EphemeralTokenStorage tokenStorage;
    late MockOfflineApiClient apiClient;

    final testSession = const AuthSessionEntity(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      tenantId: 'tenant-alpha',
      userId: 'user-001',
      role: UserRole.employee,
      email: 'alpha-001@example.com',
      displayName: 'ALPHA 001',
    );

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('attend_offline_journey_');
      dbFile = File('${tempDir.path}/outbox.sqlite');
      tokenStorage = EphemeralTokenStorage();
      await tokenStorage.saveSession(testSession);
      apiClient = MockOfflineApiClient(
          baseUrl: 'http://test', tokenStorage: tokenStorage);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
        'Offline capture, process restart survival, reconnection, and single terminal acceptance',
        () async {
      // 1. App process starts offline
      apiClient.isOnline = false;
      final outboxInstance1 = AppDriftDatabase(NativeDatabase(dbFile));
      final repoInstance1 = AttendanceRepositoryImpl(
        apiClient: apiClient,
        outbox: outboxInstance1,
        tokenStorage: tokenStorage,
      );

      final eventId = 'journey-evt-001';
      final offlineResult = await repoInstance1.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-acceptance-001',
        location: const GeoPoint(
            latitude: 30.0444, longitude: 31.2357, accuracyMeters: 10.0),
        clientEventId: eventId,
      );

      // Verify event is durably committed locally before success feedback
      expect(offlineResult.id, equals(eventId));
      expect(
          offlineResult.status, equals(AttendanceValidationStatus.pendingSync));

      // The retry backoff deliberately makes the row ineligible immediately
      // after a transport failure, but it must still be encrypted and durable.
      final savedBeforeRestart = await outboxInstance1.getEntry(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        eventId: eventId,
      );
      expect(savedBeforeRestart?.syncStatus, equals('pending_sync'));

      // 2. SIMULATE PROCESS KILL & RESTART (close connections & recreate instances)
      await outboxInstance1.close();

      // 3. Re-open application (fresh process state from Drift persistence)
      final outboxInstance2 = AppDriftDatabase(NativeDatabase(dbFile));
      final repoInstance2 = AttendanceRepositoryImpl(
        apiClient: apiClient,
        outbox: outboxInstance2,
        tokenStorage: tokenStorage,
      );

      // Verify event survived the process restart
      final savedAfterRestart = await outboxInstance2.getEntry(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        eventId: eventId,
      );
      expect(savedAfterRestart?.syncStatus, equals('pending_sync'));

      // A real connectivity callback schedules the row as due. The test
      // advances that scheduler boundary without waiting for a 30-second
      // backoff timer.
      await outboxInstance2.updateEventStatus(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        eventId: eventId,
        status: AttendanceValidationStatus.pendingSync,
        nextRetryAt: DateTime.now().toUtc(),
      );

      // 4. RESTORE CONNECTIVITY and Synchronize
      apiClient.isOnline = true;
      await repoInstance2.synchronizeOutbox();

      // 5. Assert terminal result
      expect(apiClient.serverSubmissionCount, equals(1));
      expect(apiClient.receivedEventIds.first, equals(eventId));

      // Outbox no longer has pending sync items
      final pendingAfterSync = await outboxInstance2.getPendingEvents(
          tenantId: 'tenant-alpha', userId: 'user-001');
      expect(pendingAfterSync, isEmpty);

      await outboxInstance2.close();
    });
  });
}
