import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/reconciliation_quick_actions_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/reconciliation_quick_actions_state.dart';

class FakeReconciliationRepo implements ManualAttendanceRepository {
  List<DetailedReconciliationItem> items = [
    DetailedReconciliationItem(
      id: 'rec-1',
      employeeId: 'emp-1',
      shiftInstanceId: 'shift-1',
      causeType: 'absence_scan',
      state: 'conflicted',
      attempts: 2,
      reasonCode: 'CHECK_OUT_MISSING',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
      employeeName: 'عمر عثمان',
      businessDate: '2026-10-17',
    ),
  ];

  List<OpenPayrollCycle> cycles = [
    const OpenPayrollCycle(
      id: 'cycle-1',
      cycleKey: '2026-10',
      state: 'draft',
      revision: 1,
      periodStart: '2026-10-01',
      periodEnd: '2026-10-31',
    ),
  ];

  AdministrativeAdjustmentRequest? lastPreviewRequest;
  AdministrativeAdjustmentRequest? lastSubmittedRequest;
  Object? previewError;
  Object? submitError;

  @override
  Future<List<ManualAttendanceEmployeeOption>> getEmployees(
          {String? search}) async =>
      [];

  @override
  Future<ManualAttendanceActionResult> submitManualAttendance(
    ManualAttendanceActionRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DetailedReconciliationItem>> getReconciliationItems(
          {String? state}) async =>
      items;

  @override
  Future<List<OpenPayrollCycle>> getOpenPayrollCycles() async => cycles;

  @override
  Future<AdministrativeAdjustmentPreview> previewAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    lastPreviewRequest = request;
    if (previewError != null) throw previewError!;
    return AdministrativeAdjustmentPreview(
      amount: const MoneyAmount(currency: 'SDG', amount: '25.00'),
      dailyRate: const MoneyAmount(currency: 'SDG', amount: '100.00'),
      units: request.units ?? '0.25',
    );
  }

  @override
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    lastSubmittedRequest = request;
    if (submitError != null) throw submitError!;
    return AdministrativeAdjustmentResult(
      id: 'adj-1',
      financialAdjustmentId: 'fin-1',
      employeeId: request.employeeId,
      businessDate: request.businessDate,
      kind: 'deduction',
      mode: request.mode,
      amount: const MoneyAmount(currency: 'SDG', amount: '25.00'),
      state: 'applied',
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  late FakeReconciliationRepo repo;
  late ReconciliationQuickActionsCubit cubit;

  setUp(() {
    repo = FakeReconciliationRepo();
    cubit = ReconciliationQuickActionsCubit(repository: repo);
  });

  tearDown(() => cubit.close());

  group('ReconciliationQuickActionsCubit', () {
    test('loadItems populates unresolved reconciliation exceptions', () async {
      await cubit.loadItems();
      expect(cubit.state.items.length, 1);
      expect(cubit.state.items.first.employeeName, 'عمر عثمان');
    });

    test('selectItem resets decision form and auto-loads open cycles',
        () async {
      await cubit.loadItems();
      await cubit.selectItem(cubit.state.items.first);

      expect(cubit.state.selectedItem?.id, 'rec-1');
      expect(cubit.state.mode, AdministrativeAdjustmentMode.waived);
      expect(cubit.state.openCycles.length, 1);
      expect(cubit.state.selectedCycleId, 'cycle-1');
      expect(cubit.state.isDecisionValid, isFalse); // reason required
    });

    test('isDecisionValid validates reason and mode parameters', () async {
      await cubit.loadItems();
      await cubit.selectItem(cubit.state.items.first);

      cubit.setReason('م');
      expect(cubit.state.isDecisionValid, isFalse);

      cubit.setReason('إعفاء بموجب إذن عمل كتابي');
      expect(cubit.state.isDecisionValid, isTrue);

      cubit.setMode(AdministrativeAdjustmentMode.customHours);
      cubit.setUnits('-1');
      expect(cubit.state.isDecisionValid, isFalse);

      cubit.setUnits('2.5');
      expect(cubit.state.isDecisionValid, isTrue);
    });

    test('previewAdjustment calls server and populates calculated preview',
        () async {
      await cubit.loadItems();
      await cubit.selectItem(cubit.state.items.first);
      cubit.setMode(AdministrativeAdjustmentMode.dayFraction);
      cubit.setUnits('0.25');
      cubit.setReason('تأخير ساعة وربع');

      await cubit.previewAdjustment();

      expect(cubit.state.outcome, ReconciliationActionOutcome.previewReady);
      expect(cubit.state.preview?.amount.amount, '25.00');
      expect(cubit.state.preview?.amount.currency, 'SDG');
      expect(repo.lastPreviewRequest?.units, '0.25');
    });

    test('submitDecision saves adjustment and reloads items', () async {
      await cubit.loadItems();
      await cubit.selectItem(cubit.state.items.first);
      cubit.setReason('إعفاء كامل بتفويض الإدارة');

      await cubit.submitDecision();

      expect(cubit.state.outcome, ReconciliationActionOutcome.decisionSuccess);
      expect(cubit.state.selectedItem, isNull);
      expect(
          repo.lastSubmittedRequest?.reasonCode, 'ATTENDANCE_PENALTY_WAIVED');
      expect(repo.lastSubmittedRequest?.targetCycleId, 'cycle-1');
    });

    test('truthfully classifies 409 conflict during reconciliation decision',
        () async {
      repo.submitError = Exception('HTTP 409 Conflict: task already resolved');
      await cubit.loadItems();
      await cubit.selectItem(cubit.state.items.first);
      cubit.setReason('سبب معتمد');

      await cubit.submitDecision();

      expect(cubit.state.outcome, ReconciliationActionOutcome.conflict);
      expect(cubit.state.errorMessage, contains('تغيّرت حالة المهمة'));
    });

    test(
        'selectItem on late arrival proposal pre-populates suggested hours and reason',
        () async {
      final lateProposal = DetailedReconciliationItem(
        id: 'rec-late-99',
        employeeId: 'emp-1',
        shiftInstanceId: 'shift-1',
        causeType: 'late_arrival',
        state: 'queued',
        attempts: 1,
        reasonCode: 'LATE_ARRIVAL_REVIEW_REQUIRED',
        createdAt: DateTime.utc(2026, 10, 17, 10, 0),
        employeeName: 'عمر عثمان',
        businessDate: '2026-10-17',
        lateMinutes: 45,
        suggestedDeduction: const SuggestedDeduction(
          mode: AdministrativeAdjustmentMode.customHours,
          units: '0.75',
          requiresApproval: true,
        ),
      );

      await cubit.selectItem(lateProposal);

      expect(cubit.state.mode, AdministrativeAdjustmentMode.customHours);
      expect(cubit.state.units, '0.75');
      expect(cubit.state.reason, 'اعتماد خصم التأخير بعد المراجعة');
      expect(cubit.state.isDecisionValid, isTrue);

      await cubit.submitDecision();
      expect(repo.lastSubmittedRequest?.reasonCode, 'LATE_ARRIVAL');
      expect(repo.lastSubmittedRequest?.mode,
          AdministrativeAdjustmentMode.customHours);
      expect(repo.lastSubmittedRequest?.units, '0.75');
    });

    test(
        'waiving late arrival proposal explicitly sets ATTENDANCE_PENALTY_WAIVED',
        () async {
      final lateProposal = DetailedReconciliationItem(
        id: 'rec-late-99',
        employeeId: 'emp-1',
        shiftInstanceId: 'shift-1',
        causeType: 'late_arrival',
        state: 'queued',
        attempts: 1,
        reasonCode: 'LATE_ARRIVAL_REVIEW_REQUIRED',
        createdAt: DateTime.utc(2026, 10, 17, 10, 0),
        employeeName: 'عمر عثمان',
        businessDate: '2026-10-17',
        lateMinutes: 30,
      );

      await cubit.selectItem(lateProposal);
      cubit.setMode(AdministrativeAdjustmentMode.waived);
      cubit.setReason('إعفاء التأخير لظروف طارئة موثقة');

      await cubit.submitDecision();
      expect(
          repo.lastSubmittedRequest?.reasonCode, 'ATTENDANCE_PENALTY_WAIVED');
      expect(
          repo.lastSubmittedRequest?.mode, AdministrativeAdjustmentMode.waived);
    });
  });
}
