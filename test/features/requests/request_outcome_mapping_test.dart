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
      backoffStep: const Duration(milliseconds: 5),
    );
  });

  group('Truthful Outcome Mapping (T020)', () {
    final pendingLeave = RequestEntity(
      id: 'req-001',
      employeeId: 'emp-101',
      type: RequestType.leave,
      state: RequestState.pendingSync,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.parse('2026-10-11T09:00:00Z'),
      details: const {'reason': 'إجازة سنوية'},
      steps: const [],
    );

    for (final status in [400, 401, 403, 404, 422]) {
      test(
          'HTTP $status rejection terminates immediately as validationFailure without retry',
          () async {
        when(() => repository.submitRequest(
              requestId: any(named: 'requestId'),
              type: any(named: 'type'),
              payload: any(named: 'payload'),
            )).thenThrow(ApiException(
          statusCode: status,
          message: 'Server rejection',
          code: 'POLICY_REJECTED',
        ));

        final results = await syncService.syncBatch([pendingLeave]);

        expect(results.length, 1);
        expect(results.single.outcome, RequestSyncOutcome.validationFailure);
        expect(results.single.message, 'POLICY_REJECTED');
        verify(() => repository.submitRequest(
              requestId: 'req-001',
              type: RequestType.leave,
              payload: any(named: 'payload'),
            )).called(1); // Never retried
      });
    }
  });
}
