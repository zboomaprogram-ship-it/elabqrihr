import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_state.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_request_screen.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_detail_screen.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

class _MockAdvanceRepository extends Mock
    implements AdvanceRepository, AdvanceEligibilityRepository {}

Widget _buildTestApp({
  required AdvanceEligibilityRepository repository,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(1080, 2400),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: BlocProvider(
          create: (_) => AdvanceRequestCubit(repository: repository),
          child: const AdvanceRequestScreen(),
        ),
      ),
    ),
  );
}

void main() {
  MoneyDto money(String amount) => MoneyDto(currency: 'SDG', amount: amount);
  late _MockAdvanceRepository repository;

  setUpAll(() {
    registerFallbackValue(
        const MoneyEntity(currency: 'SDG', amount: '10000.00'));
  });

  setUp(() {
    repository = _MockAdvanceRepository();
  });

  group('User Story 3: Advance Request and Repayment (T059)', () {
    test(
        'renders approved advance with zero posted amount and zero pre-disbursement collection',
        () {
      final dto = AdvanceDto(
        id: 'adv-001',
        employeeId: 'emp-101',
        principal: money('50000.00'),
        postedAmount: money('0.00'),
        remainingBalance: money('50000.00'),
        state: AdvanceState.approved,
        revision: 1,
      );

      final entity = AdvanceEntity.fromDto(dto);

      expect(entity.state, AdvanceLifecycleState.approved);
      expect(entity.state.arabicLabel, 'معتمدة');
      expect(entity.postedAmount.amount, '0.00');
      expect(entity.postedAmount.amount, isNot(entity.principal.amount));
    });

    test(
        'renders disbursed advance with active collection and derived remaining balance',
        () {
      final dto = AdvanceDto(
        id: 'adv-002',
        employeeId: 'emp-101',
        principal: money('60000.00'),
        postedAmount: money('20000.00'),
        remainingBalance: money('40000.00'),
        state: AdvanceState.collecting,
        revision: 3,
      );

      final entity = AdvanceEntity.fromDto(dto);

      expect(entity.state, AdvanceLifecycleState.collecting);
      expect(entity.state.arabicLabel, 'قيد السداد');
      expect(entity.principal.amount, '60000.00');
      expect(entity.postedAmount.amount, '20000.00');
      expect(entity.remainingBalance.amount, '40000.00');
    });

    test('handles settled advance when all installments have posted', () {
      final dto = AdvanceDto(
        id: 'adv-003',
        employeeId: 'emp-101',
        principal: money('30000.00'),
        postedAmount: money('30000.00'),
        remainingBalance: money('0.00'),
        state: AdvanceState.settled,
        revision: 5,
      );

      final entity = AdvanceEntity.fromDto(dto);

      expect(entity.state, AdvanceLifecycleState.settled);
      expect(entity.state.arabicLabel, 'تمت التسوية');
      expect(entity.remainingBalance.amount, '0.00');
      expect(entity.postedAmount.amount, entity.principal.amount);
    });

    test('maps all lifecycle states to Arabic user labels without throwing',
        () {
      for (final state in AdvanceState.values) {
        final lifecycle = AdvanceLifecycleState.fromDto(state);
        expect(lifecycle.arabicLabel, isNotEmpty);
      }
    });

    test('client does not mutate or round financial balances', () {
      final dto = AdvanceDto(
        id: 'adv-004',
        employeeId: 'emp-101',
        principal: money('12345.67'),
        postedAmount: money('345.67'),
        remainingBalance: money('12000.00'),
        state: AdvanceState.disbursed,
        revision: 2,
      );

      final entity = AdvanceEntity.fromDto(dto);

      expect(entity.principal.amount, '12345.67');
      expect(entity.postedAmount.amount, '345.67');
      expect(entity.remainingBalance.amount, '12000.00');
    });

    testWidgets(
        'shows approval route and refuses to imply collection before disbursement',
        (tester) async {
      const advance = AdvanceEntity(
        id: 'adv-route-001',
        employeeId: 'emp-101',
        principal: MoneyEntity(currency: 'SDG', amount: '30000.00'),
        postedAmount: MoneyEntity(currency: 'SDG', amount: '0.00'),
        remainingBalance: MoneyEntity(currency: 'SDG', amount: '30000.00'),
        state: AdvanceLifecycleState.approved,
        approvalStage: 'finance_review',
        approvalRoute: [
          AdvanceApprovalStageEntity(position: 1, role: 'hr'),
          AdvanceApprovalStageEntity(position: 2, role: 'finance'),
        ],
        hrReviewed: true,
        financeReviewed: false,
        revision: 2,
      );

      await tester.pumpWidget(const MaterialApp(
        home: AdvanceDetailScreen(advance: advance),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مراجعة الموارد البشرية'), findsOneWidget);
      expect(find.text('اعتماد الإدارة المالية'), findsOneWidget);
      expect(find.text('اكتملت'), findsOneWidget);
      expect(find.text('بانتظار المراجعة'), findsOneWidget);
      expect(
        find.byKey(const Key('advance-no-collection-before-disbursement')),
        findsOneWidget,
      );
    });

    testWidgets('renders server-owned installment schedule after disbursement',
        (tester) async {
      const advance = AdvanceEntity(
        id: 'adv-schedule-001',
        employeeId: 'emp-101',
        principal: MoneyEntity(currency: 'SDG', amount: '30000.00'),
        postedAmount: MoneyEntity(currency: 'SDG', amount: '10000.00'),
        remainingBalance: MoneyEntity(currency: 'SDG', amount: '20000.00'),
        state: AdvanceLifecycleState.collecting,
        approvalStage: 'completed',
        hrReviewed: true,
        financeReviewed: true,
        installmentSchedule: [
          AdvanceScheduleItemEntity(
            sequence: 1,
            dueDate: '2026-11-25',
            amount: MoneyEntity(currency: 'SDG', amount: '10000.00'),
          ),
        ],
        revision: 4,
      );

      await tester.pumpWidget(const MaterialApp(
        home: AdvanceDetailScreen(advance: advance),
      ));
      await tester.pumpAndSettle();

      expect(find.text('القسط 1'), findsOneWidget);
      expect(find.text('تاريخ الاستحقاق: 2026-11-25'), findsOneWidget);
      expect(find.text('10000.00 SDG'), findsWidgets);
    });

    test('AdvanceRequestCubit previews eligibility and provisional schedule',
        () async {
      final preview = AdvanceEligibilityPreviewEntity(
        evaluationId: 'eval-101',
        policyVersionId: 'pol-001',
        eligible: true,
        reasonCodes: const [],
        expiresAt: DateTime.parse('2026-10-18T18:00:00Z'),
        provisionalSchedule: const [
          AdvanceScheduleItemEntity(
            sequence: 1,
            dueDate: '2026-11-01',
            amount: MoneyEntity(currency: 'SDG', amount: '10000.00'),
          ),
          AdvanceScheduleItemEntity(
            sequence: 2,
            dueDate: '2026-12-01',
            amount: MoneyEntity(currency: 'SDG', amount: '10000.00'),
          ),
        ],
      );

      when(() => repository.previewEligibility(
            amount: any(named: 'amount'),
            installmentCount: any(named: 'installmentCount'),
          )).thenAnswer((_) async => preview);

      final cubit = AdvanceRequestCubit(repository: repository);
      await cubit.previewEligibility(amount: '20000.00', installmentCount: 2);

      expect(cubit.state, isA<AdvanceRequestPreviewLoaded>());
      final loaded = cubit.state as AdvanceRequestPreviewLoaded;
      expect(loaded.preview.eligible, isTrue);
      expect(loaded.preview.provisionalSchedule.length, 2);
    });

    test('AdvanceRequestCubit surfaces ineligible reasons from server',
        () async {
      final preview = AdvanceEligibilityPreviewEntity(
        evaluationId: 'eval-102',
        policyVersionId: 'pol-001',
        eligible: false,
        reasonCodes: const ['ADVANCE_ACTIVE_EXISTS'],
        expiresAt: DateTime.parse('2026-10-18T18:00:00Z'),
        provisionalSchedule: const [],
      );

      when(() => repository.previewEligibility(
            amount: any(named: 'amount'),
            installmentCount: any(named: 'installmentCount'),
          )).thenAnswer((_) async => preview);

      final cubit = AdvanceRequestCubit(repository: repository);
      await cubit.previewEligibility(amount: '50000.00', installmentCount: 3);

      expect(cubit.state, isA<AdvanceRequestPreviewLoaded>());
      final loaded = cubit.state as AdvanceRequestPreviewLoaded;
      expect(loaded.preview.eligible, isFalse);
      expect(loaded.preview.localizedReasonText,
          contains('لديك سلفة نشطة حالية لم يكتمل سدادها بعد'));
    });

    test('AdvanceRequestCubit submits advance and emits success', () async {
      final preview = AdvanceEligibilityPreviewEntity(
        evaluationId: 'eval-103',
        policyVersionId: 'pol-001',
        eligible: true,
        reasonCodes: const [],
        expiresAt: DateTime.parse('2026-10-18T18:00:00Z'),
        provisionalSchedule: const [
          AdvanceScheduleItemEntity(
            sequence: 1,
            dueDate: '2026-11-01',
            amount: MoneyEntity(currency: 'SDG', amount: '15000.00'),
          ),
        ],
      );

      final createdAdvance = AdvanceEntity(
        id: 'adv-new-001',
        employeeId: 'emp-101',
        principal: const MoneyEntity(currency: 'SDG', amount: '15000.00'),
        postedAmount: const MoneyEntity(currency: 'SDG', amount: '0.00'),
        remainingBalance:
            const MoneyEntity(currency: 'SDG', amount: '15000.00'),
        state: AdvanceLifecycleState.submitted,
        revision: 1,
      );

      when(() => repository.previewEligibility(
            amount: any(named: 'amount'),
            installmentCount: any(named: 'installmentCount'),
          )).thenAnswer((_) async => preview);

      when(() => repository.submitAdvanceRequest(
            commandId: any(named: 'commandId'),
            principal: any(named: 'principal'),
            installmentAmount: any(named: 'installmentAmount'),
            reason: any(named: 'reason'),
            eligibilityEvaluationId: any(named: 'eligibilityEvaluationId'),
            installmentCount: any(named: 'installmentCount'),
          )).thenAnswer((_) async => createdAdvance);

      final cubit = AdvanceRequestCubit(repository: repository);
      await cubit.previewEligibility(amount: '15000.00', installmentCount: 1);
      await cubit.submitAdvance(reason: 'مصاريف علاجية طارئة');

      expect(cubit.state, isA<AdvanceRequestSuccess>());
      final success = cubit.state as AdvanceRequestSuccess;
      expect(success.advance.state, AdvanceLifecycleState.submitted);
      expect(success.advance.postedAmount.amount, '0.00');
    });

    testWidgets('renders Arabic AdvanceRequestScreen and validates amount',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('طلب سلفة راتب جديدة'), findsOneWidget);
      expect(find.text('بيانات السلفة المطلوبة'), findsOneWidget);
      expect(find.text('معاينة الأهلية والجدول المؤقت'), findsOneWidget);

      // Tap preview without entering amount
      await tester.tap(find.byKey(const Key('advance-preview-button')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال مبلغ السلفة'), findsOneWidget);
    });

    testWidgets(
        'renders cleanly at 200% font scale without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        repository: repository,
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text('طلب سلفة راتب جديدة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
