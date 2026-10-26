import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

class MockDynamicRequestRepository extends Mock
    implements DynamicRequestRepository {}

void main() {
  late MockRequestRepository requestRepo;
  late MockDynamicRequestRepository dynamicRepo;

  setUpAll(() {
    registerFallbackValue(RequestType.leave);
    registerFallbackValue(RequestState.submitted);
  });

  setUp(() {
    requestRepo = MockRequestRepository();
    dynamicRepo = MockDynamicRequestRepository();
    when(() => requestRepo.watchPendingRequests())
        .thenAnswer((_) => Stream.value([]));
    when(() => requestRepo.getMyLeaveBalances()).thenAnswer((_) async => []);
  });

  final legacyRequests = [
    RequestEntity(
      id: 'req-leg-1',
      employeeId: 'emp-1',
      type: RequestType.leave,
      state: RequestState.submitted,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.parse('2026-09-20T10:00:00Z'),
      details: const {},
      steps: const [],
    ),
  ];

  final dynamicActivities = [
    RequestActivitySummary(
      kind: RequestKind.dynamic,
      id: 'dyn-act-1',
      typeKey: 'financial_advance',
      typeNameAr: 'سلفة مالية',
      state: 'submitted',
      revision: 1,
      currentStageLabel: 'بانتظار المراجعة',
      submittedAt: DateTime.parse('2026-09-21T10:00:00Z'),
    ),
  ];

  group('EmployeeRequestsCubit Dynamic Requests Integration (T003/T004)', () {
    blocTest<EmployeeRequestsCubit, EmployeeRequestsState>(
      'merges dynamic request activity with distinct RequestType.dynamic and sorts by date',
      build: () {
        when(() => requestRepo.listMyRequests(
              type: any(named: 'type'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => legacyRequests);
        when(() => dynamicRepo.getRequestActivity())
            .thenAnswer((_) async => dynamicActivities);

        return EmployeeRequestsCubit(
          repository: requestRepo,
          dynamicRepository: dynamicRepo,
        );
      },
      act: (cubit) => cubit.loadRequests(),
      expect: () => [
        const EmployeeRequestsLoading(),
        isA<EmployeeRequestsLoaded>()
            .having((s) => s.requests.length, 'total count', 2)
            .having((s) => s.requests.first.id, 'first id (newer)', 'dyn-act-1')
            .having((s) => s.requests.first.type, 'first type is dynamic',
                RequestType.dynamic)
            .having((s) => s.requests.first.isDynamic, 'first isDynamic', true)
            .having((s) => s.requests.first.dynamicTypeNameAr,
                'first arabic name', 'سلفة مالية')
            .having((s) => s.requests.last.id, 'last id (older)', 'req-leg-1')
            .having((s) => s.requests.last.type, 'last type is leave',
                RequestType.leave),
      ],
    );

    blocTest<EmployeeRequestsCubit, EmployeeRequestsState>(
      'filterByType for RequestType.dynamic returns only dynamic requests',
      build: () {
        when(() => requestRepo.listMyRequests(
              type: any(named: 'type'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => legacyRequests);
        when(() => dynamicRepo.getRequestActivity())
            .thenAnswer((_) async => dynamicActivities);

        return EmployeeRequestsCubit(
          repository: requestRepo,
          dynamicRepository: dynamicRepo,
        );
      },
      seed: () => EmployeeRequestsLoaded(
        requests: [
          ...legacyRequests,
          RequestEntity(
            id: 'dyn-act-1',
            employeeId: '',
            type: RequestType.dynamic,
            state: RequestState.submitted,
            revision: 1,
            requestedMinutes: 0,
            submittedAt: DateTime.parse('2026-09-21T10:00:00Z'),
            details: const {},
            steps: const [],
            isDynamic: true,
            dynamicTypeNameAr: 'سلفة مالية',
          ),
        ],
        balances: const [],
      ),
      act: (cubit) => cubit.filterByType(RequestType.dynamic),
      expect: () => [
        isA<EmployeeRequestsLoaded>()
            .having((s) => s.filterType, 'filterType', RequestType.dynamic)
            .having((s) => s.requests.length, 'dynamic requests count', 1)
            .having((s) => s.requests.first.id, 'id', 'dyn-act-1')
            .having((s) => s.requests.first.type, 'type', RequestType.dynamic),
      ],
    );
  });
}
