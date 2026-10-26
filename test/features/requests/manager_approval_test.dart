import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

class MockDynamicRequestRepository extends Mock
    implements DynamicRequestRepository {}

List<RequestEntity> get testRequests => [
      RequestEntity(
        id: 'req-mgr-1',
        employeeId: 'emp-001',
        employeeName: 'أحمد محمود',
        type: RequestType.leave,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.parse('2026-09-21T08:30:00Z'),
        details: const {'reason': 'إجازة عائلية'},
        steps: const [
          ApprovalStepEntity(
            id: 'step-1',
            position: 1,
            reviewerRole: 'manager',
            reviewerName: 'مدير الفرع',
            state: 'pending',
          ),
        ],
      ),
    ];

void main() {
  late MockRequestRepository repository;

  setUpAll(() {
    registerFallbackValue(RequestState.pendingApproval);
  });

  setUp(() {
    repository = MockRequestRepository();
  });

  test('multi-stage approval reloads the authoritative actor-scoped inbox',
      () async {
    when(() => repository.decideRequest(
            requestId: 'req-mgr-1',
            decisionId: any(named: 'decisionId'),
            expectedRevision: 1,
            decision: 'approve',
            comment: any(named: 'comment')))
        .thenAnswer((_) async => testRequests.first
            .copyWith(state: RequestState.pendingApproval, revision: 2));
    when(() =>
            repository.listApprovalInbox(state: RequestState.pendingApproval))
        .thenAnswer((_) async => []);
    final cubit = ManagerInboxCubit(repository: repository);
    addTearDown(cubit.close);
    cubit.emit(ManagerInboxLoaded(
        requests: testRequests, filterState: RequestState.pendingApproval));
    await cubit.decideRequest(
        requestId: 'req-mgr-1', expectedRevision: 1, decision: 'approve');
    expect((cubit.state as ManagerInboxLoaded).requests, isEmpty);
  });

  test(
      'conflict refresh keeps pending dynamic stages and excludes approved stages',
      () async {
    final dynamicRepo = MockDynamicRequestRepository();
    ApprovalActivitySummary activity(String id, String state) =>
        ApprovalActivitySummary(
            kind: RequestKind.dynamic,
            requestId: id,
            typeNameAr: 'طلب معدات',
            requesterDisplayName: 'Synthetic Employee',
            state: state,
            expectedRevision: 7,
            submittedAt: DateTime.utc(2026, 10, 25));
    when(() =>
            repository.listApprovalInbox(state: RequestState.pendingApproval))
        .thenAnswer((_) async => testRequests);
    when(() => repository.decideRequest(
            requestId: 'req-mgr-1',
            decisionId: any(named: 'decisionId'),
            expectedRevision: 1,
            decision: 'approve',
            comment: any(named: 'comment')))
        .thenThrow(const ConflictFailure('Synthetic conflict'));
    when(() => dynamicRepo.getApprovalActivity()).thenAnswer((_) async => [
          activity('pending-dynamic', 'pending'),
          activity('approved-dynamic', 'approved')
        ]);
    final cubit = ManagerInboxCubit(
        repository: repository, dynamicRepository: dynamicRepo);
    addTearDown(cubit.close);
    await cubit.loadInbox(stateFilter: RequestState.pendingApproval);
    await cubit.decideRequest(
        requestId: 'req-mgr-1', expectedRevision: 1, decision: 'approve');
    final loaded = cubit.state as ManagerInboxLoaded;
    final pending =
        loaded.requests.singleWhere((r) => r.id == 'pending-dynamic');
    expect(pending.state, RequestState.pendingApproval);
    expect(pending.revision, 7);
    expect(loaded.requests.any((r) => r.id == 'approved-dynamic'), isFalse);
    expect(loaded.conflictMessage, isNotNull);
  });

  group('ManagerInboxCubit Unit Tests (T035/T036)', () {
    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'loadInbox fetches assigned reviewer requests',
      build: () {
        when(() => repository.listApprovalInbox(
                state: RequestState.pendingApproval))
            .thenAnswer((_) async => testRequests);
        return ManagerInboxCubit(repository: repository);
      },
      act: (cubit) =>
          cubit.loadInbox(stateFilter: RequestState.pendingApproval),
      expect: () => [
        const ManagerInboxLoading(),
        ManagerInboxLoaded(
          requests: testRequests,
          filterState: RequestState.pendingApproval,
        ),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'decideRequest successfully approves request',
      build: () {
        final approved = testRequests.first
            .copyWith(state: RequestState.approved, revision: 2);
        when(() => repository.decideRequest(
              requestId: 'req-mgr-1',
              decisionId: any(named: 'decisionId'),
              expectedRevision: 1,
              decision: 'approve',
              comment: any(named: 'comment'),
            )).thenAnswer((_) async => approved);
        return ManagerInboxCubit(repository: repository);
      },
      seed: () => ManagerInboxLoaded(
        requests: testRequests,
        filterState: RequestState.pendingApproval,
      ),
      act: (cubit) => cubit.decideRequest(
        requestId: 'req-mgr-1',
        expectedRevision: 1,
        decision: 'approve',
        comment: 'موافق',
      ),
      expect: () => [
        ManagerInboxLoaded(
          requests: testRequests,
          filterState: RequestState.pendingApproval,
          isDeciding: true,
          decidedRequestId: 'req-mgr-1',
        ),
        ManagerInboxLoaded(
          requests: [
            testRequests.first
                .copyWith(state: RequestState.approved, revision: 2)
          ],
          filterState: RequestState.pendingApproval,
          isDeciding: false,
          decidedRequestId: null,
        ),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'decideRequest 409 conflict recovers without claiming success and refreshes inbox',
      build: () {
        when(() => repository.decideRequest(
                  requestId: 'req-mgr-1',
                  decisionId: any(named: 'decisionId'),
                  expectedRevision: 1,
                  decision: 'approve',
                  comment: any(named: 'comment'),
                ))
            .thenThrow(Exception(
                'HTTP 409 Conflict: Stale revision or already decided'));
        when(() => repository.listApprovalInbox(state: any(named: 'state')))
            .thenAnswer((_) async => testRequests);
        return ManagerInboxCubit(repository: repository);
      },
      seed: () => ManagerInboxLoaded(
        requests: testRequests,
        filterState: RequestState.pendingApproval,
      ),
      act: (cubit) => cubit.decideRequest(
        requestId: 'req-mgr-1',
        expectedRevision: 1,
        decision: 'approve',
      ),
      expect: () => [
        ManagerInboxLoaded(
          requests: testRequests,
          filterState: RequestState.pendingApproval,
          isDeciding: true,
          decidedRequestId: 'req-mgr-1',
        ),
        ManagerInboxLoaded(
          requests: testRequests,
          filterState: RequestState.pendingApproval,
          isDeciding: false,
          decidedRequestId: null,
          conflictMessage:
              'تم اتخاذ قرار بشأن هذا الطلب أو تم تحديثه مسبقاً من قِبل مراجع آخر.',
        ),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'loads built-in and dynamic requests into unified inbox',
      build: () {
        final dynamicRepo = MockDynamicRequestRepository();
        when(() => repository.listApprovalInbox(
                state: RequestState.pendingApproval))
            .thenAnswer((_) async => testRequests);
        when(() => dynamicRepo.getApprovalActivity()).thenAnswer((_) async => [
              ApprovalActivitySummary(
                kind: RequestKind.dynamic,
                requestId: 'dyn-req-1',
                typeNameAr: 'طلب جهاز',
                requesterDisplayName: 'محمد علي',
                state: 'pending',
                stageLabel: 'المراجعة الإدارية',
                expectedRevision: 1,
                submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
              ),
            ]);
        return ManagerInboxCubit(
          repository: repository,
          dynamicRepository: dynamicRepo,
        );
      },
      act: (cubit) =>
          cubit.loadInbox(stateFilter: RequestState.pendingApproval),
      expect: () => [
        const ManagerInboxLoading(),
        isA<ManagerInboxLoaded>()
            .having((s) => s.requests.length, 'requests count', 2)
            .having((s) => s.requests.firstWhere((r) => r.isDynamic).state,
                'dynamic pending state', RequestState.pendingApproval)
            .having(
                (s) => s.requests.firstWhere((r) => r.isDynamic).employeeName,
                'requester display name',
                'محمد علي')
            .having((s) => s.requests.firstWhere((r) => r.isDynamic).employeeId,
                'display name is not an employee identifier', ''),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'decideRequest on dynamic request delegates to dynamicRepository preserving revision',
      build: () {
        final dynamicRepo = MockDynamicRequestRepository();
        when(() => dynamicRepo.getDynamicRequest('dyn-req-1')).thenAnswer(
          (_) async => DynamicRequestEntity(
            id: 'dyn-req-1',
            typeKey: 'hardware',
            typeNameAr: 'طلب جهاز',
            definitionVersionId: 'v1',
            state: 'pending_approval',
            revision: 1,
            values: const {},
            timeline: const [],
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
          ),
        );
        when(() => dynamicRepo.decideDynamicRequest(
              id: 'dyn-req-1',
              decisionId: any(named: 'decisionId'),
              expectedRevision: 1,
              decision: 'approve',
              comment: any(named: 'comment'),
            )).thenAnswer((_) async => DynamicRequestEntity(
              id: 'dyn-req-1',
              typeKey: 'hardware',
              typeNameAr: 'طلب جهاز',
              definitionVersionId: 'v1',
              state: 'approved',
              revision: 2,
              values: const {},
              timeline: const [],
              submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
            ));
        return ManagerInboxCubit(
          repository: repository,
          dynamicRepository: dynamicRepo,
        );
      },
      seed: () => ManagerInboxLoaded(
        requests: [
          RequestEntity(
            id: 'dyn-req-1',
            employeeId: 'emp-1',
            type: RequestType.dynamic,
            state: RequestState.pendingApproval,
            revision: 1,
            requestedMinutes: 0,
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
            details: const {},
            steps: const [],
            isDynamic: true,
            dynamicTypeNameAr: 'طلب جهاز',
          ),
        ],
        filterState: RequestState.pendingApproval,
      ),
      act: (cubit) => cubit.decideRequest(
        requestId: 'dyn-req-1',
        expectedRevision: 1,
        decision: 'approve',
        isDynamic: true,
      ),
      expect: () => [
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', true),
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', false)
            .having(
                (s) => s.requests.first.state, 'state', RequestState.approved)
            .having((s) => s.requests.first.type, 'type', RequestType.dynamic)
            .having((s) => s.requests.first.revision, 'revision', 2),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'decideRequest on dynamic request rejects request and updates state',
      build: () {
        final dynamicRepo = MockDynamicRequestRepository();
        when(() => dynamicRepo.getDynamicRequest('dyn-req-1')).thenAnswer(
          (_) async => DynamicRequestEntity(
            id: 'dyn-req-1',
            typeKey: 'hardware',
            typeNameAr: 'طلب جهاز',
            definitionVersionId: 'v1',
            state: 'pending_approval',
            revision: 1,
            values: const {},
            timeline: const [],
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
          ),
        );
        when(() => dynamicRepo.decideDynamicRequest(
              id: 'dyn-req-1',
              decisionId: any(named: 'decisionId'),
              expectedRevision: 1,
              decision: 'reject',
              comment: 'غير مطابق للسياسة',
            )).thenAnswer((_) async => DynamicRequestEntity(
              id: 'dyn-req-1',
              typeKey: 'hardware',
              typeNameAr: 'طلب جهاز',
              definitionVersionId: 'v1',
              state: 'rejected',
              revision: 2,
              values: const {},
              timeline: const [],
              submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
            ));
        return ManagerInboxCubit(
          repository: repository,
          dynamicRepository: dynamicRepo,
        );
      },
      seed: () => ManagerInboxLoaded(
        requests: [
          RequestEntity(
            id: 'dyn-req-1',
            employeeId: 'emp-1',
            type: RequestType.dynamic,
            state: RequestState.pendingApproval,
            revision: 1,
            requestedMinutes: 0,
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
            details: const {},
            steps: const [],
            isDynamic: true,
            dynamicTypeNameAr: 'طلب جهاز',
          ),
        ],
        filterState: RequestState.pendingApproval,
      ),
      act: (cubit) => cubit.decideRequest(
        requestId: 'dyn-req-1',
        expectedRevision: 1,
        decision: 'reject',
        comment: 'غير مطابق للسياسة',
        isDynamic: true,
      ),
      expect: () => [
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', true),
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', false)
            .having(
                (s) => s.requests.first.state, 'state', RequestState.rejected)
            .having((s) => s.requests.first.type, 'type', RequestType.dynamic)
            .having((s) => s.requests.first.revision, 'revision', 2),
      ],
    );

    blocTest<ManagerInboxCubit, ManagerInboxState>(
      'decideRequest on dynamic 409 Conflict reloads both legacy and dynamic requests without dropping dynamic rows',
      build: () {
        final dynamicRepo = MockDynamicRequestRepository();
        when(() => dynamicRepo.getDynamicRequest('dyn-req-1')).thenAnswer(
          (_) async => DynamicRequestEntity(
            id: 'dyn-req-1',
            typeKey: 'hardware',
            typeNameAr: 'طلب جهاز',
            definitionVersionId: 'v1',
            state: 'pending_approval',
            revision: 1,
            values: const {},
            timeline: const [],
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
          ),
        );
        when(() => dynamicRepo.decideDynamicRequest(
              id: 'dyn-req-1',
              decisionId: any(named: 'decisionId'),
              expectedRevision: 1,
              decision: 'approve',
              comment: any(named: 'comment'),
            )).thenThrow(const ConflictFailure('Revision conflict'));
        when(() => repository.listApprovalInbox(
                state: RequestState.pendingApproval))
            .thenAnswer((_) async => testRequests);
        when(() => dynamicRepo.getApprovalActivity()).thenAnswer((_) async => [
              ApprovalActivitySummary(
                kind: RequestKind.dynamic,
                requestId: 'dyn-req-1',
                typeNameAr: 'طلب جهاز',
                requesterDisplayName: 'محمد علي',
                state: 'approved',
                stageLabel: 'معتمد من مراجع آخر',
                expectedRevision: 2,
                submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
              ),
            ]);
        return ManagerInboxCubit(
          repository: repository,
          dynamicRepository: dynamicRepo,
        );
      },
      seed: () => ManagerInboxLoaded(
        requests: [
          RequestEntity(
            id: 'dyn-req-1',
            employeeId: 'emp-1',
            type: RequestType.dynamic,
            state: RequestState.pendingApproval,
            revision: 1,
            requestedMinutes: 0,
            submittedAt: DateTime.parse('2026-09-22T10:00:00Z'),
            details: const {},
            steps: const [],
            isDynamic: true,
            dynamicTypeNameAr: 'طلب جهاز',
          ),
        ],
        filterState: RequestState.pendingApproval,
      ),
      act: (cubit) => cubit.decideRequest(
        requestId: 'dyn-req-1',
        expectedRevision: 1,
        decision: 'approve',
        isDynamic: true,
      ),
      expect: () => [
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', true),
        isA<ManagerInboxLoaded>()
            .having((s) => s.isDeciding, 'isDeciding', false)
            .having((s) => s.conflictMessage, 'conflictMessage', isNotNull)
            .having((s) => s.requests.length, 'reloaded requests count', 2)
            .having(
                (s) =>
                    s.requests.any((r) => r.isDynamic && r.id == 'dyn-req-1'),
                'retains dynamic row',
                true),
      ],
    );
  });

  group('Manager Approval UI & Accessibility (T035/T036/T062)', () {
    Widget buildSubject() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepositoryProvider<RequestRepository>.value(
            value: repository,
            child: const ManagerInboxScreen(),
          ),
        ),
      );
    }

    testWidgets(
        'Renders manager inbox, Arabic RTL directionality, and action buttons',
        (tester) async {
      when(() => repository.listApprovalInbox(state: any(named: 'state')))
          .thenAnswer((_) async => testRequests);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('إدارة الطلبات'), findsOneWidget);
      expect(find.text('أحمد محمود'), findsOneWidget);
      expect(find.text('اعتماد الطلب'), findsOneWidget);
      expect(find.text('رفض الطلب'), findsOneWidget);

      // Verify RTL directionality
      final directionality =
          Directionality.of(tester.element(find.text('إدارة الطلبات')));
      expect(directionality, TextDirection.rtl);
    });

    testWidgets(
        'Satisfies minimum 44x44 pixel touch targets for all decision actions',
        (tester) async {
      when(() => repository.listApprovalInbox(state: any(named: 'state')))
          .thenAnswer((_) async => testRequests);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find approve and reject buttons
      final approveFinder =
          find.byKey(const ValueKey('approve_request_req-mgr-1'));
      final rejectFinder =
          find.byKey(const ValueKey('reject_request_req-mgr-1'));

      expect(approveFinder, findsOneWidget);
      expect(rejectFinder, findsOneWidget);

      final approveSize = tester.getSize(approveFinder);
      final rejectSize = tester.getSize(rejectFinder);

      expect(approveSize.width, greaterThanOrEqualTo(44.0));
      expect(approveSize.height, greaterThanOrEqualTo(44.0));
      expect(rejectSize.width, greaterThanOrEqualTo(44.0));
      expect(rejectSize.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Supports 200% dynamic text enlargement without layout errors',
        (tester) async {
      when(() => repository.listApprovalInbox(state: any(named: 'state')))
          .thenAnswer((_) async => testRequests);

      tester.view.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('إدارة الطلبات'), findsOneWidget);
    });
  });
}
