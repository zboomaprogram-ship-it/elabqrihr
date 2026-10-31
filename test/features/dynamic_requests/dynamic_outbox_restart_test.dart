import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';

class MockDynamicSyncApiClient extends ApiClient {
  bool isOnline = false;
  bool shouldReturnConflict = false;
  int serverCallCount = 0;
  final List<String> receivedRequestIds = [];
  final List<String> receivedCommandIds = [];

  MockDynamicSyncApiClient({
    required super.baseUrl,
    required super.tokenStorage,
  });

  @override
  Future<Map<String, dynamic>> createDynamicRequest(dynamic payload,
      {String? expectedTenantId, String? expectedUserId}) async {
    if (!isOnline) {
      throw const SocketException('Network unreachable');
    }

    serverCallCount++;
    final map = payload is CreateDynamicRequest
        ? payload.toJson()
        : (payload as Map<String, dynamic>);
    final reqId = map['requestId'] as String;
    final cmdId = map['commandId'] as String;
    receivedRequestIds.add(reqId);
    receivedCommandIds.add(cmdId);

    if (shouldReturnConflict) {
      throw ApiException(
        statusCode: 409,
        code: 'CONFLICT_DUPLICATE',
        message: 'Duplicate dynamic request detected on server',
      );
    }

    return {
      'id': reqId,
      'typeKey': 'office_supply',
      'typeNameAr': 'طلب مستلزمات مكتبية',
      'definitionVersionId': map['definitionVersionId'],
      'state': 'submitted',
      'revision': 1,
      'values': map['values'],
      'timeline': [],
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class EphemeralTokenStorage extends TokenStorage {
  AuthSessionEntity? session;

  @override
  Future<void> saveSession(AuthSessionEntity s) async => session = s;

  @override
  Future<AuthSessionEntity?> getSession() async => session;

  @override
  Future<void> clearSession() async => session = null;
}

class SwitchingTokenStorage extends EphemeralTokenStorage {
  int? switchOnRead;
  AuthSessionEntity? replacement;
  @override
  Future<AuthSessionEntity?> getSession() async {
    if (switchOnRead != null) {
      switchOnRead = switchOnRead! - 1;
      if (switchOnRead == 0) {
        session = replacement;
        switchOnRead = null;
      }
    }
    return session;
  }
}

class CountingAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }
}

class SwitchAfterSelectionDatabase extends AppDriftDatabase {
  SwitchAfterSelectionDatabase(super.executor);
  Future<void> Function()? afterSelection;

  @override
  Future<List<LocalRequestRow>> getPendingRequests({
    required String tenantId,
    required String userId,
    DateTime? now,
    int? limit,
    bool? dynamicOnly,
  }) async {
    final rows = await super.getPendingRequests(
        tenantId: tenantId,
        userId: userId,
        now: now,
        limit: limit,
        dynamicOnly: dynamicOnly);
    await afterSelection?.call();
    return rows;
  }
}

void main() {
  group(
      'T063 Dynamic Outbox Replay & Android Process Restart Acceptance Journey',
      () {
    late Directory tempDir;
    late File dbFile;
    late EphemeralTokenStorage tokenStorage;
    late MockDynamicSyncApiClient apiClient;

    const testSession = AuthSessionEntity(
      accessToken: 'test-dyn-token',
      refreshToken: 'test-dyn-refresh',
      tenantId: 'tenant-restart-dyn',
      userId: 'user-restart-dyn-001',
      role: UserRole.employee,
      email: 'employee@test.com',
      displayName: 'مستخدم الاختبار',
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('attend_dyn_restart_');
      dbFile = File('${tempDir.path}/dynamic_outbox.sqlite');
      tokenStorage = EphemeralTokenStorage();
      await tokenStorage.saveSession(testSession);
      apiClient = MockDynamicSyncApiClient(
        baseUrl: 'http://127.0.0.1:8080/api/v1',
        tokenStorage: tokenStorage,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'Phase 1 offline dynamic enqueue -> Process Kill -> Phase 2 restore & replay exact IDs',
        () async {
      // -----------------------------------------------------------------------
      // PHASE 1: Process 1 (PID 1) - Offline Enqueue
      // -----------------------------------------------------------------------
      final db1 = AppDriftDatabase(NativeDatabase(dbFile));
      final repo1 = DynamicRequestRepositoryImpl(
        apiClient: apiClient,
        database: db1,
        tokenStorage: tokenStorage,
      );

      apiClient.isOnline = false;

      final offlineResult = await repo1.submitDynamicRequest(
        typeKey: 'office_supply',
        typeNameAr: 'طلب مستلزمات المكتب',
        definitionVersionId: 'ver-supply-1',
        values: {'item': 'ورق طباعة A4', 'quantity': 5},
      );

      expect(offlineResult.state, equals('pending_sync'));
      expect(offlineResult.reasonCode, equals('QUEUED_OFFLINE'));
      expect(apiClient.serverCallCount, equals(0));

      final originalRequestId = offlineResult.id;

      // Verify row is persisted in Drift SQLite
      final pending1 = await db1.getPendingRequests(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending1.length, equals(1));
      expect(pending1.first.id, equals(originalRequestId));
      expect(pending1.first.syncStatus, equals('pending_sync'));
      expect(pending1.first.retryCount, equals(0));
      expect(jsonDecode(pending1.first.payloadJson)['typeNameAr'],
          'طلب مستلزمات المكتب');

      // -----------------------------------------------------------------------
      // SIMULATE ANDROID PROCESS KILL (FORCE STOP)
      // -----------------------------------------------------------------------
      await db1.close();

      // -----------------------------------------------------------------------
      // PHASE 2: Process 2 (PID 2) - Fresh Instance Relaunch & Sync
      // -----------------------------------------------------------------------
      final db2 = AppDriftDatabase(NativeDatabase(dbFile));

      // 1. Verify persisted session survived across process restart
      final restoredSession = await tokenStorage.getSession();
      expect(restoredSession, isNotNull);
      expect(restoredSession!.tenantId, equals(testSession.tenantId));
      expect(restoredSession.userId, equals(testSession.userId));

      // 2. Verify offline dynamic row survived on disk
      final pending2 = await db2.getPendingRequests(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending2.length, equals(1));
      expect(pending2.first.id, equals(originalRequestId));

      // 3. Connect to network
      apiClient.isOnline = true;

      final repo2 = DynamicRequestRepositoryImpl(
        apiClient: apiClient,
        database: db2,
        tokenStorage: tokenStorage,
      );

      // 4. Trigger identity-scoped synchronization
      await repo2.synchronizeOutbox();

      // 5. Assert exact same requestId and commandId reached the server
      expect(apiClient.serverCallCount, equals(1));
      expect(apiClient.receivedRequestIds.first, equals(originalRequestId));
      expect(apiClient.receivedCommandIds.first, isNotEmpty);

      // 6. Verify row in database transitioned to submitted terminal state
      final rowAfterSync = await db2.getRequestEntry(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: originalRequestId,
      );
      expect(rowAfterSync, isNotNull);
      expect(rowAfterSync!.syncStatus, equals('submitted'));

      // 7. Verify outbox has 0 pending items left
      final pendingAfterSync = await db2.getPendingRequests(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pendingAfterSync.isEmpty, isTrue);

      await db2.close();
    });

    test('identity switch after selection does not send or change old rows',
        () async {
      final db = SwitchAfterSelectionDatabase(NativeDatabase(dbFile));
      final repo = DynamicRequestRepositoryImpl(
          apiClient: apiClient, database: db, tokenStorage: tokenStorage);
      final queued = await repo.submitDynamicRequest(
        typeKey: 'office_supply',
        typeNameAr: 'طلب مستلزمات المكتب',
        definitionVersionId: 'ver-supply-1',
        values: {'item': 'paper'},
      );
      apiClient.isOnline = true;
      db.afterSelection = () => tokenStorage.clearSession();
      await repo.synchronizeOutbox();
      expect(apiClient.serverCallCount, 0);
      final row = await db.getRequestEntry(
          tenantId: testSession.tenantId,
          userId: testSession.userId,
          requestId: queued.id);
      expect(row?.syncStatus, 'pending_sync');
      await db.close();
    });

    test('identity switch at authorization never sends a queued request',
        () async {
      final storage = SwitchingTokenStorage()..session = testSession;
      final db = AppDriftDatabase(NativeDatabase(dbFile));
      final offlineApi = MockDynamicSyncApiClient(
          baseUrl: 'http://127.0.0.1:8080/api/v1', tokenStorage: storage);
      final offlineRepo = DynamicRequestRepositoryImpl(
          apiClient: offlineApi, database: db, tokenStorage: storage);
      final queued = await offlineRepo.submitDynamicRequest(
        typeKey: 'office_supply',
        typeNameAr: 'طلب مستلزمات المكتب',
        definitionVersionId: 'ver-supply-1',
        values: {'item': 'paper'},
      );
      const replacement = AuthSessionEntity(
        accessToken: 'other-token',
        tenantId: 'tenant-restart-dyn',
        userId: 'other-user',
        role: UserRole.employee,
        email: 'other@example.invalid',
        displayName: 'Other',
      );
      final adapter = CountingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8080'))
        ..httpClientAdapter = adapter;
      final api = ApiClient(
          baseUrl: 'http://127.0.0.1:8080/api/v1',
          tokenStorage: storage,
          dio: dio);
      final repo = DynamicRequestRepositoryImpl(
          apiClient: api, database: db, tokenStorage: storage);
      storage.replacement = replacement;
      storage.switchOnRead = 3;
      await repo.synchronizeOutbox();
      expect(adapter.calls, 0);
      final row = await db.getRequestEntry(
          tenantId: testSession.tenantId,
          userId: testSession.userId,
          requestId: queued.id);
      expect(row?.syncStatus, 'pending_sync');
      expect(row?.retryCount, 0);
      await db.close();
    });

    test(
        'Bounded retries: marks as rejected with MAX_RETRIES_EXCEEDED when retryCount reaches 5',
        () async {
      final db = AppDriftDatabase(NativeDatabase(dbFile));
      final repo = DynamicRequestRepositoryImpl(
        apiClient: apiClient,
        database: db,
        tokenStorage: tokenStorage,
      );

      apiClient.isOnline = false;

      final offlineResult = await repo.submitDynamicRequest(
        typeKey: 'office_supply',
        definitionVersionId: 'ver-supply-1',
        values: {'item': 'أقلام حبر', 'quantity': 10},
      );

      // Simulate 5 prior failed sync attempts
      await db.updateRequestStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
        status: 'pending_sync',
        isRetryAttempt: true,
      );
      await db.updateRequestStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
        status: 'pending_sync',
        isRetryAttempt: true,
      );
      await db.updateRequestStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
        status: 'pending_sync',
        isRetryAttempt: true,
      );
      await db.updateRequestStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
        status: 'pending_sync',
        isRetryAttempt: true,
      );
      await db.updateRequestStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
        status: 'pending_sync',
        isRetryAttempt: true,
      );

      final rowBefore = await db.getRequestEntry(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
      );
      expect(rowBefore!.retryCount, equals(5));

      // Synchronize outbox
      await repo.synchronizeOutbox();

      // Bounded retry policy stops attempts and marks rejected with MAX_RETRIES_EXCEEDED
      final rowAfter = await db.getRequestEntry(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
      );
      expect(rowAfter!.syncStatus, equals('rejected'));
      expect(rowAfter.reasonCode, equals('MAX_RETRIES_EXCEEDED'));

      await db.close();
    });

    test(
        '409 Conflict stops retry and transitions cleanly to conflict without duplicates',
        () async {
      final db = AppDriftDatabase(NativeDatabase(dbFile));
      final repo = DynamicRequestRepositoryImpl(
        apiClient: apiClient,
        database: db,
        tokenStorage: tokenStorage,
      );

      apiClient.isOnline = false;

      final offlineResult = await repo.submitDynamicRequest(
        typeKey: 'office_supply',
        definitionVersionId: 'ver-supply-1',
        values: {'item': 'كرسي مكتب', 'quantity': 1},
      );

      // Bring online but server returns 409 conflict
      apiClient.isOnline = true;
      apiClient.shouldReturnConflict = true;

      await repo.synchronizeOutbox();

      final rowAfter = await db.getRequestEntry(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        requestId: offlineResult.id,
      );
      expect(rowAfter!.syncStatus, equals('conflict'));
      expect(rowAfter.reasonCode, equals('CONFLICT_DUPLICATE'));

      await db.close();
    });
  });
}
