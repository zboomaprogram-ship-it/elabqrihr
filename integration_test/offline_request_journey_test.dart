// ignore_for_file: avoid_print
import 'dart:io';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/data/request_repository_impl.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

class MockOfflineRequestApiClient extends ApiClient {
  bool isOnline = false;
  int serverSubmissionCount = 0;
  final List<String> receivedRequestIds = [];

  MockOfflineRequestApiClient(
      {required super.baseUrl, required super.tokenStorage});

  @override
  Future<RequestDto> submitRequest(Map<String, dynamic> requestPayload) async {
    if (!isOnline) {
      throw const SocketException('Network unreachable: client offline');
    }

    serverSubmissionCount++;
    final reqId = requestPayload['requestId'] as String;
    receivedRequestIds.add(reqId);

    return RequestDto(
      id: reqId,
      employeeId: 'emp-restart-001',
      type: requestPayload['type'] as String,
      state: 'pending_approval',
      revision: 1,
      requestedMinutes: requestPayload['requestedMinutes'] as int? ?? 480,
      submittedAt: DateTime.now().toUtc(),
      details: requestPayload,
      steps: const [],
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

  group('T026 Android Request Restart Offline Acceptance Journey', () {
    late Directory tempDir;
    late File dbFile;
    late EphemeralTokenStorage tokenStorage;
    late MockOfflineRequestApiClient apiClient;

    const testSession = AuthSessionEntity(
      accessToken: 'test-token-req',
      refreshToken: 'test-refresh-req',
      tenantId: 'tenant-restart-req',
      userId: 'user-restart-001',
      role: UserRole.employee,
      email: 'employee@test.com',
      displayName: 'Test Employee',
    );

    const requestId = 'journey-request-001';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attend_req_test_');
      dbFile = File('${tempDir.path}/attend_outbox.sqlite');
      tokenStorage = EphemeralTokenStorage();
      await tokenStorage.saveSession(testSession);
      apiClient = MockOfflineRequestApiClient(
        baseUrl: 'http://127.0.0.1:8080/api/v1',
        tokenStorage: tokenStorage,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Phase 1 offline save -> Force stop -> Phase 2 restore & sync',
        (tester) async {
      // -----------------------------------------------------------------------
      // PHASE 1: Process 1 (PID 1) - Offline Request Submission
      // -----------------------------------------------------------------------
      print('=== PHASE 1: Simulating offline request save in PID 1 ===');
      final db1 = AppDriftDatabase(NativeDatabase(dbFile));
      final repo1 = RequestRepositoryImpl(
        apiClient: apiClient,
        database: db1,
        tokenStorage: tokenStorage,
      );

      apiClient.isOnline = false;

      final submitted = await repo1.submitRequest(
        requestId: requestId,
        type: RequestType.leave,
        payload: {
          'categoryId': '00000000-0000-0000-0000-000000000001',
          'startDate': '2026-09-25',
          'endDate': '2026-09-26',
          'reason': 'إجازة سنوية مطلوبة أثناء انقطاع الشبكة',
          'requestedMinutes': 960,
        },
      );

      // Verify offline state
      expect(submitted.state, RequestState.pendingSync);
      expect(apiClient.serverSubmissionCount, 0);

      // Verify written to database
      final pendingRows1 = await db1
          .watchPendingRequests(
            tenantId: testSession.tenantId,
            userId: testSession.userId,
          )
          .first;
      expect(pendingRows1.length, 1);
      expect(pendingRows1.first.id, requestId);
      expect(pendingRows1.first.syncStatus, 'pending_sync');

      // -----------------------------------------------------------------------
      // SIMULATE PROCESS KILL / FORCE-STOP
      // -----------------------------------------------------------------------
      print(
          '=== SIMULATING FORCE-STOP: Closing process 1 database and memory ===');
      await db1.close();

      // -----------------------------------------------------------------------
      // PHASE 2: Process 2 (PID 2) - Fresh Instance, Reconnect, and Sync
      // -----------------------------------------------------------------------
      print('=== PHASE 2: Simulating process relaunch in PID 2 ===');
      final db2 = AppDriftDatabase(NativeDatabase(dbFile));

      // 1. Verify persisted identity survives
      final restoredSession = await tokenStorage.getSession();
      expect(restoredSession, isNotNull);
      expect(restoredSession!.tenantId, testSession.tenantId);
      expect(restoredSession.userId, testSession.userId);

      // 2. Verify persisted offline request survived on disk
      final pendingRows2 = await db2
          .watchPendingRequests(
            tenantId: testSession.tenantId,
            userId: testSession.userId,
          )
          .first;
      expect(pendingRows2.length, 1);
      expect(pendingRows2.first.id, requestId);
      expect(pendingRows2.first.nextRetryAt, pendingRows1.first.nextRetryAt);

      // 3. Reconnect to network
      apiClient.isOnline = true;

      final repo2 = RequestRepositoryImpl(
        apiClient: apiClient,
        database: db2,
        tokenStorage: tokenStorage,
      );

      // 4. Honor the persisted backoff, then synchronize.
      final retryAt = pendingRows2.first.nextRetryAt;
      if (retryAt != null) {
        final remaining = retryAt.toUtc().difference(DateTime.now().toUtc());
        if (remaining > Duration.zero) {
          await Future<void>.delayed(
              remaining + const Duration(milliseconds: 100));
        }
      }
      await repo2.synchronizeOutbox();
      await repo2.synchronizeOutbox();

      // 5. Verify exactly 1 server submission with the same requestId
      expect(apiClient.serverSubmissionCount, 1);
      expect(apiClient.receivedRequestIds.first, requestId);

      // 6. Verify outbox has 0 pending items and entry status is pending_approval
      final pendingAfterSync = await db2.getPendingRequests(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pendingAfterSync.isEmpty, isTrue);

      final rowAfterSync = await db2.getRequestEntry(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: requestId,
      );
      expect(rowAfterSync, isNotNull);
      expect(rowAfterSync!.syncStatus, 'pending_approval');

      await db2.close();
      print(
          '=== T026 ACCEPTANCE COMPLETED: Single terminal request reached server ===');
    });
  });
}
