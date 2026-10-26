import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_models.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_repository.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/disciplinary_case_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/disciplinary_case_detail_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/widgets/grievance_submission_dialog.dart';

class MockHrOperationsRepository extends Mock
    implements HrOperationsRepository {}

void main() {
  late MockHrOperationsRepository mockRepository;

  final sampleDisciplinary = DisciplinaryDetail(
    policyTitle: 'مخالفة تأخير متكرر بدون إذن مسبق',
    incidentAt: DateTime(2026, 10, 15, 9, 30),
    noticeRevision: 1,
    acknowledgmentState: 'not_acknowledged',
    grievanceDueAt: DateTime(2026, 10, 25, 23, 59),
    consequenceState: 'proposed',
    grievances: const [],
  );

  final sampleDetail = HrOperationDetail(
    id: 'op-disc-101',
    operationKind: OperationKind.disciplinaryCase,
    employeeId: 'emp-456',
    employeeName: 'أحمد محمود',
    state: 'notice_delivered',
    revision: 1,
    submittedAt: DateTime(2026, 10, 16, 14, 0),
    nextActionLabelAr: 'مطلوب العلم والاستلام',
    disciplinary: sampleDisciplinary,
    permissions: const ['acknowledge_notice', 'submit_grievance'],
    timeline: [
      TimelineItem(
        id: 'tl-d1',
        kind: 'notice_issued',
        occurredAt: DateTime(2026, 10, 16, 14, 0),
        labelAr: 'تم إصدار الإشعار الإداري من إدارة الموارد البشرية',
        actorLabel: 'مسؤول الموارد البشرية',
      ),
    ],
  );

  setUp(() {
    mockRepository = MockHrOperationsRepository();
  });

  group('Disciplinary Cases Cubit Tests', () {
    test('DisciplinaryCaseDetailCubit emits loaded on success', () async {
      when(() => mockRepository.getOperationDetail('op-disc-101'))
          .thenAnswer((_) async => sampleDetail);

      final cubit = DisciplinaryCaseDetailCubit(repository: mockRepository);

      expect(
        cubit.stream,
        emitsInOrder([
          const DisciplinaryCaseDetailLoading(),
          DisciplinaryCaseDetailLoaded(detail: sampleDetail),
        ]),
      );

      await cubit.loadDetail('op-disc-101');
      await cubit.close();
    });

    test('DisciplinaryCaseDetailCubit records acknowledgment as receipt only',
        () async {
      final ack = Acknowledgment(
        id: 'ack-1',
        noticeRevision: 1,
        acknowledgedAt: DateTime(2026, 10, 17, 10, 0),
        meaning: 'receipt_only',
      );

      when(() => mockRepository.getOperationDetail('op-disc-101'))
          .thenAnswer((_) async => sampleDetail);
      when(() => mockRepository.acknowledgeDisciplinaryNotice(
            operationId: 'op-disc-101',
            commandId: any(named: 'commandId'),
            expectedRevision: 1,
            noticeRevision: 1,
          )).thenAnswer((_) async => ack);

      final cubit = DisciplinaryCaseDetailCubit(repository: mockRepository);
      await cubit.loadDetail('op-disc-101');

      await cubit.acknowledgeNotice(
        operationId: 'op-disc-101',
        commandId: 'cmd-ack-1',
        expectedRevision: 1,
        noticeRevision: 1,
      );

      expect(cubit.state, isA<DisciplinaryCaseDetailLoaded>());
      final loaded = cubit.state as DisciplinaryCaseDetailLoaded;
      expect(loaded.detail.disciplinary?.isAcknowledged, isTrue);
      expect(loaded.actionSuccessMessage,
          contains('تم تسجيل استلام الإشعار بالعلم فقط'));
      await cubit.close();
    });

    test('DisciplinaryCaseDetailCubit submits grievance successfully',
        () async {
      final grievance = Grievance(
        id: 'grv-1',
        state: 'submitted',
        submittedAt: DateTime(2026, 10, 17, 11, 0),
        deadlineState: 'on_time',
        statement: 'التأخير كان بسبب عطل في وسيلة النقل الجماعي التابعة للشركة',
      );

      when(() => mockRepository.getOperationDetail('op-disc-101'))
          .thenAnswer((_) async => sampleDetail);
      when(() => mockRepository.submitDisciplinaryGrievance(
            operationId: 'op-disc-101',
            commandId: any(named: 'commandId'),
            expectedRevision: 1,
            statement:
                'التأخير كان بسبب عطل في وسيلة النقل الجماعي التابعة للشركة',
          )).thenAnswer((_) async => grievance);

      final cubit = DisciplinaryCaseDetailCubit(repository: mockRepository);
      await cubit.loadDetail('op-disc-101');

      await cubit.submitGrievance(
        operationId: 'op-disc-101',
        commandId: 'cmd-grv-1',
        expectedRevision: 1,
        statement: 'التأخير كان بسبب عطل في وسيلة النقل الجماعي التابعة للشركة',
      );

      expect(cubit.state, isA<DisciplinaryCaseDetailLoaded>());
      final loaded = cubit.state as DisciplinaryCaseDetailLoaded;
      expect(loaded.detail.disciplinary?.grievances.length, 1);
      expect(loaded.actionSuccessMessage, contains('تم قيد التظلم بنجاح'));
      await cubit.close();
    });
  });

  group('Disciplinary Cases Widget Tests', () {
    testWidgets(
        'Notice displays receipt-only legal semantics and grievance button',
        (tester) async {
      when(() => mockRepository.getOperationDetail('op-disc-101'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) =>
                DisciplinaryCaseDetailCubit(repository: mockRepository)
                  ..loadDetail('op-disc-101'),
            child:
                const DisciplinaryCaseDetailScreen(operationId: 'op-disc-101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Proves acknowledgment text says receipt only and does not waive grievance
      expect(
        find.textContaining('تأكيد الاستلام يُعد إقراراً بالعلم بالواقعة فقط'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
            'ولا يعني بالضرورة الإقرار بصحة المنسوب أو التنازل عن حق التظلم'),
        findsOneWidget,
      );

      // Proves grievance option is rendered
      expect(find.text('تقديم تظلم أو التماس كتابي'), findsOneWidget);
    });

    testWidgets(
        'Proposed monetary consequence is NEVER rendered as posted or deducted',
        (tester) async {
      when(() => mockRepository.getOperationDetail('op-disc-101'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) =>
                DisciplinaryCaseDetailCubit(repository: mockRepository)
                  ..loadDetail('op-disc-101'),
            child:
                const DisciplinaryCaseDetailScreen(operationId: 'op-disc-101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Proves proposed badge is displayed, not deducted
      expect(find.text('مقترح غير مخصوم'), findsOneWidget);
      expect(find.text('مخصوم من الراتب'), findsNothing);
      expect(find.text('تم الخصم'), findsNothing);

      // Proves explanation explicitly states not deducted
      expect(
        find.textContaining('ولم يتم خصم أي مبالغ من راتبك حتى تاريخه'),
        findsOneWidget,
      );
    });

    testWidgets(
        'GrievanceSubmissionDialog validates input and invokes callback',
        (tester) async {
      var wasSubmitted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrievanceSubmissionDialog(
              operationId: 'op-disc-101',
              expectedRevision: 1,
              onSubmit: ({
                required commandId,
                required expectedRevision,
                required statement,
              }) async {
                wasSubmitted = true;
              },
            ),
          ),
        ),
      );

      // Tap submit with empty statement
      await tester.tap(find.text('إرسال التظلم'));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'يرجى كتابة نص التظلم والبيان التوضيحي (3 أحرف على الأقل).'),
          findsOneWidget);
      expect(wasSubmitted, isFalse);

      // Enter valid statement
      await tester.enterText(
          find.byType(TextField), 'أرجو مراجعة تسجيل كاميرات المراقبة');
      await tester.tap(find.text('إرسال التظلم'));
      await tester.pumpAndSettle();

      expect(wasSubmitted, isTrue);
    });

    testWidgets(
        'Disciplinary screen renders correctly at 200% font scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      when(() => mockRepository.getOperationDetail('op-disc-101'))
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
            create: (_) =>
                DisciplinaryCaseDetailCubit(repository: mockRepository)
                  ..loadDetail('op-disc-101'),
            child:
                const DisciplinaryCaseDetailScreen(operationId: 'op-disc-101'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('إقرار الاستلام والعلم'), findsOneWidget);
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
