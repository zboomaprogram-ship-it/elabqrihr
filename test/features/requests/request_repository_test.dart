import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/data/request_repository_impl.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late AppDriftDatabase database;
  late MockApiClient mockApiClient;
  late MockTokenStorage mockTokenStorage;
  late RequestRepositoryImpl repository;

  const sessionUser1 = AuthSessionEntity(
    accessToken: 'token-user-1',
    tenantId: 'tenant-alpha',
    userId: 'user-001',
    role: UserRole.employee,
    email: 'user1@example.com',
    displayName: 'User One',
  );

  const sessionUser2 = AuthSessionEntity(
    accessToken: 'token-user-2',
    tenantId: 'tenant-beta',
    userId: 'user-002',
    role: UserRole.employee,
    email: 'user2@example.com',
    displayName: 'User Two',
  );

  setUp(() {
    database = AppDriftDatabase(NativeDatabase.memory());
    mockApiClient = MockApiClient();
    mockTokenStorage = MockTokenStorage();

    repository = RequestRepositoryImpl(
      apiClient: mockApiClient,
      database: database,
      tokenStorage: mockTokenStorage,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
      'built-in synchronization leaves dynamic outbox entries to their own coordinator',
      () async {
    when(() => mockTokenStorage.getSession())
        .thenAnswer((_) async => sessionUser1);
    await database.saveRequest(
        tenantId: sessionUser1.tenantId,
        userId: sessionUser1.userId,
        id: 'dynamic-only',
        requestType: 'dynamic:equipment_request',
        payloadJson: jsonEncode({
          'requestId': 'dynamic-only',
          'commandId': 'command-only',
          'definitionVersionId': 'equipment-v1',
          'values': {'business_reason': 'Synthetic'}
        }));
    await repository.synchronizeOutbox();
    final row = await database.getRequestEntry(
        tenantId: sessionUser1.tenantId,
        userId: sessionUser1.userId,
        requestId: 'dynamic-only');
    expect(row!.syncStatus, 'pending_sync');
    expect(row.retryCount, 0);
    expect(row.nextRetryAt, isNull);
    verifyNever(() => mockApiClient.submitRequest(any()));
  });

  test('offline dynamic request preserves its identity and display name',
      () async {
    when(() => mockTokenStorage.getSession())
        .thenAnswer((_) async => sessionUser1);
    when(() => mockApiClient.getMyRequests(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
          state: any(named: 'state'),
        )).thenThrow(const SocketException('offline'));
    await database.saveRequest(
      tenantId: sessionUser1.tenantId,
      userId: sessionUser1.userId,
      id: 'dynamic-pending',
      requestType: 'dynamic:equipment_request',
      payloadJson: jsonEncode({
        'typeKey': 'equipment_request',
        'typeNameAr': 'طلب معدات العمل',
        'values': {'business_reason': 'Synthetic'}
      }),
    );
    final requests = await repository.listMyRequests();
    expect(requests.single.isDynamic, isTrue);
    expect(requests.single.dynamicTypeNameAr, 'طلب معدات العمل');
    expect(requests.single.state, RequestState.pendingSync);
    final detail = await repository.getRequestDetail('dynamic-pending');
    expect(detail.isDynamic, isTrue);
    expect(detail.dynamicTypeNameAr, 'طلب معدات العمل');
  });

  group('RequestRepositoryImpl Offline Visibility & Outbox Merging (T023/T024)',
      () {
    test(
        'listMyRequests merges local pending requests with remote results without duplicating',
        () async {
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);

      // Save a local pending request (req-pending)
      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-pending-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'Local pending'}),
        syncStatus: 'pending_sync',
      );

      // Save a local request that is already synchronized remotely (req-synced)
      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-synced-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'Already synced'}),
        syncStatus: 'pending_sync',
      );

      // Remote returns req-synced-1 (authoritative) and req-remote-2
      when(() => mockApiClient.getMyRequests(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          )).thenAnswer((_) async => RequestPageDto(
            items: [
              RequestDto(
                id: 'req-synced-1',
                employeeId: 'user-001',
                type: 'leave',
                state: 'pending_approval',
                revision: 1,
                requestedMinutes: 480,
                submittedAt: DateTime.parse('2026-09-21T09:00:00Z'),
                details: {'reason': 'Already synced'},
                steps: const [],
              ),
              RequestDto(
                id: 'req-remote-2',
                employeeId: 'user-001',
                type: 'leave',
                state: 'approved',
                revision: 2,
                requestedMinutes: 960,
                submittedAt: DateTime.parse('2026-09-20T09:00:00Z'),
                details: {'reason': 'Remote only'},
                steps: const [],
              ),
            ],
          ));

      final results = await repository.listMyRequests();

      // req-pending-1 (local pending) + req-synced-1 (remote) + req-remote-2 (remote)
      // Exactly 3 items, req-synced-1 is NOT duplicated!
      expect(results.length, 3);
      expect(
          results.any((r) =>
              r.id == 'req-pending-1' && r.state == RequestState.pendingSync),
          isTrue);
      expect(
          results.any((r) =>
              r.id == 'req-synced-1' &&
              r.state == RequestState.pendingApproval),
          isTrue);
      expect(
          results.any((r) =>
              r.id == 'req-remote-2' && r.state == RequestState.approved),
          isTrue);
    });

    test(
        'listMyRequests returns local requests when remote call fails with SocketException (offline)',
        () async {
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);

      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-offline-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'Offline request'}),
        syncStatus: 'pending_sync',
      );

      when(() => mockApiClient.getMyRequests(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
            type: any(named: 'type'),
            state: any(named: 'state'),
          )).thenThrow(const SocketException('Failed host lookup'));

      final results = await repository.listMyRequests();

      expect(results.length, 1);
      expect(results.first.id, 'req-offline-1');
      expect(results.first.state, RequestState.pendingSync);
      expect(results.first.details['reason'], 'Offline request');
    });

    test('getRequestDetail retrieves local entry when remote call fails',
        () async {
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);

      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-local-detail-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'Inspecting local request'}),
        syncStatus: 'pending_sync',
      );

      when(() => mockApiClient.getRequestDetail('req-local-detail-1'))
          .thenThrow(const SocketException('Network offline'));

      final detail = await repository.getRequestDetail('req-local-detail-1');

      expect(detail.id, 'req-local-detail-1');
      expect(detail.state, RequestState.pendingSync);
      expect(detail.details['reason'], 'Inspecting local request');
    });
  });

  group('Outbox Idempotency & Failure Classification', () {
    test(
        'saveRequest does not overwrite existing terminal or conflict row back to pending_sync',
        () async {
      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-idempotent-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'First submission'}),
        syncStatus: 'conflict',
        reasonCode: 'CONFLICT_DUPLICATE',
      );

      // Attempt to save same requestId again as pending_sync
      await database.saveRequest(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        id: 'req-idempotent-1',
        requestType: 'leave',
        payloadJson: jsonEncode({'reason': 'Second submission'}),
        syncStatus: 'pending_sync',
      );

      final entry = await database.getRequestEntry(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        requestId: 'req-idempotent-1',
      );

      expect(entry, isNotNull);
      expect(entry!.syncStatus, 'conflict');
      expect(entry.reasonCode, 'CONFLICT_DUPLICATE');
    });

    test(
        'submitRequest marks 400/422 validation failure as rejected and does not queue as pending_sync',
        () async {
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);

      when(() => mockApiClient.submitRequest(any())).thenThrow(ApiException(
        statusCode: 422,
        message: 'Invalid date interval',
        code: 'INVALID_INTERVAL',
      ));

      await expectLater(
        repository.submitRequest(
          requestId: 'req-val-fail-1',
          type: RequestType.leave,
          payload: {'startDate': '2026-09-25', 'endDate': '2026-09-20'},
        ),
        throwsA(isA<ApiException>()),
      );

      // Verify row in DB is NOT pending_sync
      final pending = await database.getPendingRequests(
          tenantId: 'tenant-alpha', userId: 'user-001');
      expect(pending.any((r) => r.id == 'req-val-fail-1'), isFalse);

      final row = await database.getRequestEntry(
          tenantId: 'tenant-alpha',
          userId: 'user-001',
          requestId: 'req-val-fail-1');
      expect(row, isNotNull);
      expect(row!.syncStatus, 'rejected');
      expect(row.reasonCode, 'INVALID_INTERVAL');
    });

    test(
        'submitRequest marks a non-duplicate 409 policy rejection as rejected rather than a local conflict',
        () async {
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);
      when(() => mockApiClient.submitRequest(any())).thenThrow(ApiException(
        statusCode: 409,
        message: 'No eligible reviewer is available',
        code: 'APPROVAL_ROUTE_UNAVAILABLE',
      ));

      await expectLater(
        repository.submitRequest(
          requestId: 'req-route-unavailable-1',
          type: RequestType.leave,
          payload: {'reason': 'طلب إجازة للاختبار'},
        ),
        throwsA(isA<ApiException>()),
      );

      final row = await database.getRequestEntry(
        tenantId: 'tenant-alpha',
        userId: 'user-001',
        requestId: 'req-route-unavailable-1',
      );
      expect(row, isNotNull);
      expect(row!.syncStatus, 'rejected');
      expect(row.reasonCode, 'APPROVAL_ROUTE_UNAVAILABLE');
    });
  });

  group('Identity Isolation & Session Switching', () {
    test('User B cannot see or submit User A outbox requests', () async {
      // 1. User 1 submits offline request
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser1);
      when(() => mockApiClient.submitRequest(any()))
          .thenThrow(const SocketException('Offline'));

      await repository.submitRequest(
        requestId: 'req-user1-offline',
        type: RequestType.leave,
        payload: {'reason': 'User 1 leave'},
      );

      // Verify User 1 sees it in outbox
      final user1Pending = await database.getPendingRequests(
        tenantId: sessionUser1.tenantId,
        userId: sessionUser1.userId,
      );
      expect(user1Pending.length, 1);
      expect(user1Pending.first.id, 'req-user1-offline');

      // Switch identity to User 2 (different tenant and user)
      when(() => mockTokenStorage.getSession())
          .thenAnswer((_) async => sessionUser2);
      clearInteractions(mockApiClient);

      // Verify User 2 sees zero pending requests in outbox
      final user2Pending = await database.getPendingRequests(
        tenantId: sessionUser2.tenantId,
        userId: sessionUser2.userId,
      );
      expect(user2Pending, isEmpty);

      // User 2 synchronizeOutbox submits 0 requests
      await repository.synchronizeOutbox();
      verifyNever(() => mockApiClient.submitRequest(any()));

      // 3. User logs out (session == null)
      when(() => mockTokenStorage.getSession()).thenAnswer((_) async => null);

      await repository.synchronizeOutbox();
      verifyNever(() => mockApiClient.submitRequest(any()));
    });
  });
}
