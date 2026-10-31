import 'dart:io';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import '../test/test_doubles/fake_dynamic_request_repo.dart';
import '../test/test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';

class MockOfflineApiClient extends ApiClient {
  bool isOnline = false;
  int serverSubmissionCount = 0;
  final List<String> receivedEventIds = [];
  DateTime? receivedLocationTime;

  MockOfflineApiClient({required super.baseUrl, required super.tokenStorage});

  @override
  Future<UnreadNotificationCountDto> getUnreadNotificationCount() async =>
      const UnreadNotificationCountDto(count: 0);

  @override
  Future<Map<String, dynamic>> getMobileOperationalConfiguration() async =>
      MobileOperationalConfiguration.defaultRestrictive().toMap();

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
      isCheckedIn: serverSubmissionCount > 0,
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
    String? expectedTenantId,
    String? expectedUserId,
  }) async {
    if (!isOnline) {
      throw const SocketException('Network is unreachable (offline)');
    }

    serverSubmissionCount++;
    receivedEventIds.add(eventId);
    receivedLocationTime = location.timestamp;

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  group('T036 Android Process-Restart Offline Attendance Journey', () {
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

    testWidgets(
        'Step 1-5: Offline capture, restart survival, reconnect, and single terminal acceptance',
        (tester) async {
      // -------------------------------------------------------------
      // PHASE 1: App process starts offline, renders UI, captures event
      // -------------------------------------------------------------
      apiClient.isOnline = false;
      final outbox1 = AppDriftDatabase(NativeDatabase(dbFile));
      final authRepo1 =
          AuthRepositoryImpl(apiClient: apiClient, tokenStorage: tokenStorage);
      final attendanceRepo1 = AttendanceRepositoryImpl(
        apiClient: apiClient,
        outbox: outbox1,
        tokenStorage: tokenStorage,
      );

      await tester.pumpWidget(AttendApp(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        authRepository: authRepo1,
        attendanceRepository: attendanceRepo1,
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(AppStringsAr.attendanceTab),
      ));
      await tester.pumpAndSettle();

      // Verify the actual Attendance destination shows the current shift card
      expect(find.text('Morning Shift'), findsOneWidget);
      expect(find.text(AppStringsAr.checkIn), findsOneWidget);

      final eventId = 'journey-evt-001';
      final offlineResult = await attendanceRepo1.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-acceptance-001',
        location: GeoPoint(
            latitude: 30.0444,
            longitude: 31.2357,
            accuracyMeters: 10.0,
            timestamp:
                DateTime.now().toUtc().subtract(const Duration(seconds: 5))),
        clientEventId: eventId,
      );

      // Verify event is durably committed locally with pendingSync status
      expect(offlineResult.id, equals(eventId));
      expect(
          offlineResult.status, equals(AttendanceValidationStatus.pendingSync));

      final pendingBeforeRestart = await outbox1
          .watchPendingEvents(tenantId: 'tenant-alpha', userId: 'user-001')
          .first;
      expect(pendingBeforeRestart.length, equals(1));
      expect(pendingBeforeRestart.first.id, equals(eventId));
      final savedBefore = await outbox1.getEntry(
          tenantId: 'tenant-alpha', userId: 'user-001', eventId: eventId);
      expect(savedBefore?.nextRetryAt, isNotNull);

      // -------------------------------------------------------------
      // PHASE 2: SIMULATE PROCESS KILL & RESTART
      // Forcefully dispose in-memory state and database connection
      // -------------------------------------------------------------
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await outbox1.close();

      // -------------------------------------------------------------
      // PHASE 3: Re-open application (fresh process state from persistent Drift disk file)
      // -------------------------------------------------------------
      final outbox2 = AppDriftDatabase(NativeDatabase(dbFile));
      final authRepo2 =
          AuthRepositoryImpl(apiClient: apiClient, tokenStorage: tokenStorage);
      final attendanceRepo2 = AttendanceRepositoryImpl(
        apiClient: apiClient,
        outbox: outbox2,
        tokenStorage: tokenStorage,
      );

      // Verify event survived the process restart on disk
      final pendingAfterRestart = await outbox2
          .watchPendingEvents(tenantId: 'tenant-alpha', userId: 'user-001')
          .first;
      expect(pendingAfterRestart.length, equals(1));
      expect(pendingAfterRestart.first.id, equals(eventId));
      expect(pendingAfterRestart.first.location.timestamp?.toUtc(),
          offlineResult.location.timestamp);
      final savedAfter = await outbox2.getEntry(
          tenantId: 'tenant-alpha', userId: 'user-001', eventId: eventId);
      expect(savedAfter?.nextRetryAt, savedBefore?.nextRetryAt);

      // Launch reopened app
      await tester.pumpWidget(AttendApp(
        apiClient: apiClient,
        tokenStorage: tokenStorage,
        authRepository: authRepo2,
        attendanceRepository: attendanceRepo2,
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(AppStringsAr.attendanceTab),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Morning Shift'), findsOneWidget);

      // -------------------------------------------------------------
      // PHASE 4: RESTORE CONNECTIVITY and Synchronize Outbox
      // -------------------------------------------------------------
      apiClient.isOnline = true;
      final readyRow = await outbox2.getEntry(
          tenantId: 'tenant-alpha', userId: 'user-001', eventId: eventId);
      final remaining =
          readyRow!.nextRetryAt!.toUtc().difference(DateTime.now().toUtc());
      if (remaining > Duration.zero) {
        await Future<void>.delayed(
            remaining + const Duration(milliseconds: 100));
      }
      await attendanceRepo2.synchronizeOutbox();
      await attendanceRepo2.synchronizeOutbox();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // -------------------------------------------------------------
      // PHASE 5: Assert single terminal acceptance
      // -------------------------------------------------------------
      expect(apiClient.serverSubmissionCount, equals(1));
      expect(apiClient.receivedEventIds.first, equals(eventId));
      expect(apiClient.receivedLocationTime?.toUtc(),
          offlineResult.location.timestamp);

      // Outbox no longer has pending sync items
      final pendingAfterSync = await outbox2
          .watchPendingEvents(tenantId: 'tenant-alpha', userId: 'user-001')
          .first;
      expect(pendingAfterSync, isEmpty);

      final accepted = await outbox2.getEntry(
          tenantId: 'tenant-alpha', userId: 'user-001', eventId: eventId);
      expect(accepted?.syncStatus, 'accepted');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await outbox2.close();
    });
  });
}
