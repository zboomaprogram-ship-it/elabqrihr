import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_detail_cubit.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

class MockDynamicHistoryRepository extends Mock
    implements DynamicRequestRepository {}

void main() {
  late MockRequestRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestType.leave);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = MockRequestRepository();
    when(() => repository.watchPendingRequests())
        .thenAnswer((_) => Stream.value([]));
  });

  test(
      'merged custom request history contains one row per resource kind and ID',
      () async {
    final dynamicRepo = MockDynamicHistoryRepository();
    final now = DateTime.utc(2026, 10, 26);
    final dynamic = RequestEntity(
        id: 'shared-id',
        employeeId: 'employee',
        type: RequestType.dynamic,
        isDynamic: true,
        dynamicTypeNameAr: 'معدات',
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: now,
        details: {},
        steps: []);
    final builtin = RequestEntity(
        id: 'shared-id',
        employeeId: 'employee',
        type: RequestType.leave,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: now,
        details: {},
        steps: []);
    when(() => repository.listMyRequests(type: null, state: null))
        .thenAnswer((_) async => [dynamic, builtin]);
    when(() => repository.getMyLeaveBalances()).thenAnswer((_) async => []);
    when(() => dynamicRepo.getRequestActivity()).thenAnswer((_) async => [
          RequestActivitySummary(
              kind: RequestKind.dynamic,
              id: 'shared-id',
              typeKey: 'equipment',
              typeNameAr: 'معدات',
              state: 'pending_approval',
              revision: 1,
              submittedAt: now)
        ]);
    final cubit = EmployeeRequestsCubit(
        repository: repository, dynamicRepository: dynamicRepo);
    addTearDown(cubit.close);
    await cubit.loadRequests();
    final rows = (cubit.state as EmployeeRequestsLoaded).requests;
    expect(rows, hasLength(2));
    expect(rows.where((r) => r.isDynamic), hasLength(1));
    expect(rows.where((r) => !r.isDynamic), hasLength(1));
  });

  group('EmployeeRequestsCubit (T021, T024)', () {
    final sampleRequests = [
      RequestEntity(
        id: 'r-1',
        employeeId: 'emp-1',
        type: RequestType.leave,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.parse('2026-09-21T10:00:00Z'),
        details: const {},
        steps: const [],
      ),
    ];

    blocTest<EmployeeRequestsCubit, EmployeeRequestsState>(
      'loadRequests emits [Loading, Loaded] on success',
      build: () {
        when(() => repository.listMyRequests())
            .thenAnswer((_) async => sampleRequests);
        when(() => repository.getMyLeaveBalances()).thenAnswer((_) async => []);
        return EmployeeRequestsCubit(repository: repository);
      },
      act: (cubit) => cubit.loadRequests(),
      expect: () => [
        const EmployeeRequestsLoading(),
        EmployeeRequestsLoaded(requests: sampleRequests, balances: const []),
      ],
    );

    blocTest<EmployeeRequestsCubit, EmployeeRequestsState>(
      'filterByType emits updated Loaded state with filtered requests',
      build: () {
        when(() => repository.listMyRequests(
            type: RequestType.permission,
            state: null)).thenAnswer((_) async => []);
        return EmployeeRequestsCubit(repository: repository);
      },
      seed: () =>
          EmployeeRequestsLoaded(requests: sampleRequests, balances: const []),
      act: (cubit) => cubit.filterByType(RequestType.permission),
      expect: () => [
        EmployeeRequestsLoaded(
          requests: const [],
          balances: const [],
          filterType: RequestType.permission,
        ),
      ],
    );
  });

  group('RequestFormCubit (T021, T024)', () {
    final createdEntity = RequestEntity(
      id: 'req-new',
      employeeId: 'emp-1',
      type: RequestType.leave,
      state: RequestState.pendingApproval,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.parse('2026-09-21T11:00:00Z'),
      details: const {},
      steps: const [],
    );

    blocTest<RequestFormCubit, RequestFormState>(
      'submitLeaveRequest online emits [Submitting, Success]',
      build: () {
        when(() => repository.submitRequest(
              requestId: any(named: 'requestId'),
              type: any(named: 'type'),
              payload: any(named: 'payload'),
            )).thenAnswer((_) async => createdEntity);
        return RequestFormCubit(repository: repository);
      },
      act: (cubit) => cubit.submitLeaveRequest(
        categoryId: 'cat-1',
        startDate: '2026-09-25',
        endDate: '2026-09-25',
        reason: 'سبب الإجازة',
      ),
      expect: () => [
        const RequestFormSubmitting(),
        RequestFormSuccess(request: createdEntity, isQueuedOffline: false),
      ],
    );

    blocTest<RequestFormCubit, RequestFormState>(
      'submitLeaveRequest offline emits [Submitting, Success(isQueuedOffline: true)]',
      build: () {
        final offlineEntity =
            createdEntity.copyWith(state: RequestState.pendingSync);
        when(() => repository.submitRequest(
              requestId: any(named: 'requestId'),
              type: any(named: 'type'),
              payload: any(named: 'payload'),
            )).thenAnswer((_) async => offlineEntity);
        return RequestFormCubit(repository: repository);
      },
      act: (cubit) => cubit.submitLeaveRequest(
        categoryId: 'cat-1',
        startDate: '2026-09-25',
        endDate: '2026-09-25',
        reason: 'سبب الإجازة',
      ),
      expect: () => [
        const RequestFormSubmitting(),
        RequestFormSuccess(
          request: createdEntity.copyWith(state: RequestState.pendingSync),
          isQueuedOffline: true,
        ),
      ],
    );

    blocTest<RequestFormCubit, RequestFormState>(
      'submitLeaveRequest 409 conflict emits [Submitting, Error(isConflict: true)]',
      build: () {
        when(() => repository.submitRequest(
              requestId: any(named: 'requestId'),
              type: any(named: 'type'),
              payload: any(named: 'payload'),
            )).thenThrow(Exception('HTTP 409: Conflict duplicate'));
        return RequestFormCubit(repository: repository);
      },
      act: (cubit) => cubit.submitLeaveRequest(
        categoryId: 'cat-1',
        startDate: '2026-09-25',
        endDate: '2026-09-25',
        reason: 'سبب الإجازة',
      ),
      expect: () => [
        const RequestFormSubmitting(),
        const RequestFormError(
            message:
                'تعارض في البيانات؛ تمت معالجة هذا الطلب أو تم تعديله مسبقاً.',
            isConflict: true),
      ],
    );
  });

  group('RequestDetailCubit (T021, T024)', () {
    final detailEntity = RequestEntity(
      id: 'req-detail',
      employeeId: 'emp-1',
      type: RequestType.leave,
      state: RequestState.pendingApproval,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.parse('2026-09-21T11:00:00Z'),
      details: const {},
      steps: const [],
    );

    blocTest<RequestDetailCubit, RequestDetailState>(
      'loadDetail emits [Loading, Loaded]',
      build: () {
        when(() => repository.getRequestDetail('req-detail'))
            .thenAnswer((_) async => detailEntity);
        return RequestDetailCubit(repository: repository);
      },
      act: (cubit) => cubit.loadDetail('req-detail'),
      expect: () => [
        const RequestDetailLoading(),
        RequestDetailLoaded(request: detailEntity),
      ],
    );

    blocTest<RequestDetailCubit, RequestDetailState>(
      'cancelRequest emits [Loaded(isCancelling: true), Cancelled]',
      build: () {
        final cancelledEntity =
            detailEntity.copyWith(state: RequestState.cancelled);
        when(() => repository.cancelRequest(
              requestId: 'req-detail',
              expectedRevision: 1,
              reason: 'إلغاء لظرف طارئ',
            )).thenAnswer((_) async => cancelledEntity);
        return RequestDetailCubit(repository: repository);
      },
      seed: () => RequestDetailLoaded(request: detailEntity),
      act: (cubit) => cubit.cancelRequest(reason: 'إلغاء لظرف طارئ'),
      expect: () => [
        RequestDetailLoaded(request: detailEntity, isCancelling: true),
        RequestDetailCancelled(
            detailEntity.copyWith(state: RequestState.cancelled)),
      ],
    );
  });
}
