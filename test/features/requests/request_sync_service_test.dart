import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/requests/data/request_sync_service.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

void main() {
  late MockRequestRepository repository;
  late RequestSyncService syncService;

  setUpAll(() {
    registerFallbackValue(RequestType.leave);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockRequestRepository();
    syncService = RequestSyncService(
      repository: repository,
      maxRetries: 3,
      backoffStep: const Duration(milliseconds: 10),
    );
  });

  group('RequestSyncService (T021, T025)', () {
    final pendingLeave = RequestEntity(
      id: 'req-001',
      employeeId: 'emp-101',
      type: RequestType.leave,
      state: RequestState.pendingSync,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.parse('2026-09-21T09:00:00Z'),
      details: const {'reason': 'ظرف طارئ'},
      steps: const [],
    );

    test('successful sync returns synchronized outcome with terminal state',
        () async {
      when(() => repository.submitRequest(
                requestId: any(named: 'requestId'),
                type: any(named: 'type'),
                payload: any(named: 'payload'),
              ))
          .thenAnswer((_) async =>
              pendingLeave.copyWith(state: RequestState.pendingApproval));

      final results = await syncService.syncBatch([pendingLeave]);

      expect(results.length, 1);
      expect(results.first.outcome, RequestSyncOutcome.synchronized);
      expect(results.first.entity?.state, RequestState.pendingApproval);
      verify(() => repository.submitRequest(
            requestId: 'req-001',
            type: RequestType.leave,
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('409 Conflict halts immediately without retrying', () async {
      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: any(named: 'type'),
            payload: any(named: 'payload'),
          )).thenThrow(Exception('HTTP 409 Conflict: Request already exists'));

      final results = await syncService.syncBatch([pendingLeave]);

      expect(results.length, 1);
      expect(results.first.outcome, RequestSyncOutcome.conflict);
      // Verify exactly 1 call (no retries on 409 conflict!)
      verify(() => repository.submitRequest(
            requestId: 'req-001',
            type: RequestType.leave,
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('bounded retries on network failure before returning networkFailure',
        () async {
      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: any(named: 'type'),
            payload: any(named: 'payload'),
          )).thenThrow(Exception('SocketException: Connection refused'));

      final results = await syncService.syncBatch([pendingLeave]);

      expect(results.length, 1);
      expect(results.first.outcome, RequestSyncOutcome.networkFailure);
      // Verified maxRetries = 3 attempts executed
      verify(() => repository.submitRequest(
            requestId: 'req-001',
            type: RequestType.leave,
            payload: any(named: 'payload'),
          )).called(3);
    });

    for (final status in [400, 422]) {
      test('$status validation failure is terminal and consumes one attempt',
          () async {
        when(() => repository.submitRequest(
              requestId: any(named: 'requestId'),
              type: any(named: 'type'),
              payload: any(named: 'payload'),
            )).thenThrow(ApiException(
          statusCode: status,
          message: 'Validation failed',
          code: 'VALIDATION_FAILED',
        ));

        final results = await syncService.syncBatch([pendingLeave]);

        expect(results.single.outcome, RequestSyncOutcome.validationFailure);
        expect(results.single.message, 'VALIDATION_FAILED');
        verify(() => repository.submitRequest(
              requestId: 'req-001',
              type: RequestType.leave,
              payload: any(named: 'payload'),
            )).called(1);
      });
    }
  });
}
