import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_models.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_repository.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/clearance_case_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/resignation_clearance_detail_screen.dart';

class MockHrOperationsRepository extends Mock
    implements HrOperationsRepository {}

void main() {
  late MockHrOperationsRepository mockRepository;

  final sampleItems = [
    const ClearanceItem(
      id: 'item-laptop',
      titleAr: 'تسليم جهاز الحاسب المحمول وملحقاته',
      mandatory: true,
      evidenceRequired: true,
      state: 'pending',
      revision: 1,
      assigneeLabel: 'إدارة تكنولوجيا المعلومات',
    ),
    const ClearanceItem(
      id: 'item-sim',
      titleAr: 'تسليم شريحة الاتصال وبطاقة الدخول',
      mandatory: true,
      evidenceRequired: false,
      state: 'completed',
      revision: 1,
      assigneeLabel: 'الشؤون الإدارية',
    ),
  ];

  final sampleClearance = ClearanceCase(
    id: 'case-clr-1',
    employeeId: 'emp-456',
    state: 'in_progress',
    revision: 2,
    targetLastWorkingDate: DateTime(2026, 11, 15),
    items: sampleItems,
    handoffs: const {'it': 'requested', 'admin': 'confirmed'},
  );

  final sampleResignation = ResignationDetail(
    requestedLastWorkingDate: DateTime(2026, 11, 15),
    approvedLastWorkingDate: DateTime(2026, 11, 15),
    noticeDays: 30,
    state: 'accepted',
  );

  final sampleDetail = HrOperationDetail(
    id: 'op-res-1',
    operationKind: OperationKind.clearance,
    employeeId: 'emp-456',
    employeeName: 'أحمد محمود',
    state: 'clearance_in_progress',
    revision: 2,
    submittedAt: DateTime(2026, 10, 16, 9, 0),
    nextActionLabelAr: 'متابعة استيفاء بنود العهد المتبقية',
    resignation: sampleResignation,
    clearance: sampleClearance,
    permissions: const ['decide_clearance_item', 'finalize_clearance'],
    timeline: [
      TimelineItem(
        id: 'tl-c1',
        kind: 'resignation_accepted',
        occurredAt: DateTime(2026, 10, 16, 9, 0),
        labelAr: 'تم قبول الاستقالة وبدء مرحلة إخلاء الطرف',
        actorLabel: 'مدير الموارد البشرية',
      ),
    ],
  );

  setUp(() {
    mockRepository = MockHrOperationsRepository();
  });

  group('Clearance Cubit Tests', () {
    test('ClearanceCaseDetailCubit emits loaded on success', () async {
      when(() => mockRepository.getOperationDetail('op-res-1'))
          .thenAnswer((_) async => sampleDetail);

      final cubit = ClearanceCaseDetailCubit(repository: mockRepository);

      expect(
        cubit.stream,
        emitsInOrder([
          const ClearanceCaseDetailLoading(),
          ClearanceCaseDetailLoaded(detail: sampleDetail),
        ]),
      );

      await cubit.loadDetail('op-res-1');
      await cubit.close();
    });

    test('ClearanceCaseDetailCubit decides clearance item successfully',
        () async {
      const completedItem = ClearanceItem(
        id: 'item-laptop',
        titleAr: 'تسليم جهاز الحاسب المحمول وملحقاته',
        mandatory: true,
        evidenceRequired: true,
        state: 'completed',
        revision: 2,
        assigneeLabel: 'إدارة تكنولوجيا المعلومات',
      );

      when(() => mockRepository.getOperationDetail('op-res-1'))
          .thenAnswer((_) async => sampleDetail);
      when(() => mockRepository.decideClearanceItem(
            caseId: 'case-clr-1',
            itemId: 'item-laptop',
            commandId: any(named: 'commandId'),
            expectedRevision: 1,
            action: 'complete',
            reason: 'تم استلام العهدة والتأكد من سلامتها',
          )).thenAnswer((_) async => completedItem);

      final cubit = ClearanceCaseDetailCubit(repository: mockRepository);
      await cubit.loadDetail('op-res-1');

      await cubit.decideItem(
        caseId: 'case-clr-1',
        itemId: 'item-laptop',
        commandId: 'cmd-item-1',
        expectedRevision: 1,
        action: 'complete',
        reason: 'تم استلام العهدة والتأكد من سلامتها',
      );

      expect(cubit.state, isA<ClearanceCaseDetailLoaded>());
      final loaded = cubit.state as ClearanceCaseDetailLoaded;
      expect(loaded.detail.clearance?.completedCount, 2);
      expect(loaded.detail.clearance?.mandatoryOutstandingCount, 0);
      expect(loaded.actionSuccessMessage, contains('تم تحديث حالة بند'));
      await cubit.close();
    });

    test('ClearanceCaseDetailCubit finalizes clearance successfully', () async {
      final finalizedCase = ClearanceCase(
        id: 'case-clr-1',
        employeeId: 'emp-456',
        state: 'completed',
        revision: 3,
        targetLastWorkingDate: DateTime(2026, 11, 15),
        items: sampleItems,
      );

      when(() => mockRepository.getOperationDetail('op-res-1'))
          .thenAnswer((_) async => sampleDetail);
      when(() => mockRepository.finalizeClearance(
            caseId: 'case-clr-1',
            commandId: any(named: 'commandId'),
            expectedRevision: 2,
            reason: 'اكتمال جميع بنود إخلاء الطرف المعتمدة',
          )).thenAnswer((_) async => finalizedCase);

      final cubit = ClearanceCaseDetailCubit(repository: mockRepository);
      await cubit.loadDetail('op-res-1');

      await cubit.finalizeClearance(
        caseId: 'case-clr-1',
        commandId: 'cmd-fin-1',
        expectedRevision: 2,
        reason: 'اكتمال جميع بنود إخلاء الطرف المعتمدة',
      );

      expect(cubit.state, isA<ClearanceCaseDetailLoaded>());
      final loaded = cubit.state as ClearanceCaseDetailLoaded;
      expect(loaded.detail.state, 'clearance_completed');
      expect(loaded.actionSuccessMessage, contains('تم إنهاء واعتماد'));
      await cubit.close();
    });
  });

  group('Clearance Widget Tests', () {
    testWidgets('Detail screen displays resignation info and clearance items',
        (tester) async {
      when(() => mockRepository.getOperationDetail('op-res-1'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => ClearanceCaseDetailCubit(repository: mockRepository)
              ..loadDetail('op-res-1'),
            child:
                const ResignationClearanceDetailScreen(operationId: 'op-res-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تسليم جهاز الحاسب المحمول وملحقاته'), findsOneWidget);
      expect(find.text('تسليم شريحة الاتصال وبطاقة الدخول'), findsOneWidget);
      expect(find.text('1 من 2'), findsOneWidget);
      expect(find.textContaining('تظل حالة التوظيف والصلاحيات نشطة'),
          findsOneWidget);
      expect(find.text('تأكيد الاستلام'), findsOneWidget);
    });

    testWidgets(
        'Detail screen renders correctly at 200% font scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      when(() => mockRepository.getOperationDetail('op-res-1'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: BlocProvider(
            create: (_) => ClearanceCaseDetailCubit(repository: mockRepository)
              ..loadDetail('op-res-1'),
            child:
                const ResignationClearanceDetailScreen(operationId: 'op-res-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تسليم جهاز الحاسب المحمول وملحقاته'), findsOneWidget);
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
