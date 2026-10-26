import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/manual_attendance_models.dart';
import '../../domain/manual_attendance_repository.dart';
import 'reconciliation_quick_actions_state.dart';

class ReconciliationQuickActionsCubit
    extends Cubit<ReconciliationQuickActionsState> {
  final ManualAttendanceRepository _repository;
  final Uuid _uuid;

  ReconciliationQuickActionsCubit({
    required ManualAttendanceRepository repository,
    Uuid? uuid,
  })  : _repository = repository,
        _uuid = uuid ?? const Uuid(),
        super(const ReconciliationQuickActionsState());

  Future<void> loadItems() async {
    if (isClosed) return;
    emit(state.copyWith(
      outcome: ReconciliationActionOutcome.loadingItems,
      clearError: true,
    ));
    try {
      final items = await _repository.getReconciliationItems(
        state: state.filterState,
      );
      if (isClosed) return;
      emit(state.copyWith(
        items: items,
        outcome: ReconciliationActionOutcome.idle,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        outcome: ReconciliationActionOutcome.failure,
        errorMessage: 'تعذر تحميل مهام تسوية الحضور. يرجى إعادة المحاولة.',
      ));
    }
  }

  Future<void> loadOpenCycles() async {
    if (isClosed) return;
    try {
      final cycles = await _repository.getOpenPayrollCycles();
      if (isClosed) return;
      final selected = state.selectedCycleId ??
          (cycles.isNotEmpty ? cycles.first.id : null);
      emit(state.copyWith(
        openCycles: cycles,
        selectedCycleId: selected,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        errorMessage: 'تعذر تحميل دورات الرواتب المفتوحة.',
      ));
    }
  }

  void filterByState(String? filter) {
    if (isClosed) return;
    emit(state.copyWith(filterState: filter));
    loadItems();
  }

  Future<void> selectItem(DetailedReconciliationItem item) async {
    if (isClosed) return;
    final initialMode = item.isLateArrivalProposal
        ? (item.suggestedDeduction?.mode ??
            AdministrativeAdjustmentMode.customHours)
        : AdministrativeAdjustmentMode.waived;
    final initialUnits = item.isLateArrivalProposal
        ? (item.suggestedDeduction?.units ?? '0.25')
        : '0.25';
    final initialReason = item.isLateArrivalProposal
        ? 'اعتماد خصم التأخير بعد المراجعة'
        : '';

    emit(state.copyWith(
      selectedItem: item,
      mode: initialMode,
      units: initialUnits,
      fixedAmount: '100.00',
      reason: initialReason,
      clearPreview: true,
      clearError: true,
    ));
    if (state.openCycles.isEmpty) {
      await loadOpenCycles();
    } else if (state.selectedCycleId == null && state.openCycles.isNotEmpty) {
      emit(state.copyWith(selectedCycleId: state.openCycles.first.id));
    }
  }

  void clearSelection() {
    if (isClosed) return;
    emit(state.copyWith(
      clearSelectedItem: true,
      clearPreview: true,
      clearError: true,
    ));
  }

  void selectCycle(String cycleId) {
    if (isClosed) return;
    emit(state.copyWith(selectedCycleId: cycleId, clearPreview: true));
  }

  void setMode(AdministrativeAdjustmentMode mode) {
    if (isClosed) return;
    emit(state.copyWith(mode: mode, clearPreview: true));
  }

  void setUnits(String units) {
    if (isClosed) return;
    emit(state.copyWith(units: units, clearPreview: true));
  }

  void setFixedAmount(String amount) {
    if (isClosed) return;
    emit(state.copyWith(fixedAmount: amount, clearPreview: true));
  }

  void setReason(String reason) {
    if (isClosed) return;
    emit(state.copyWith(reason: reason));
  }

  AdministrativeAdjustmentRequest? _buildRequest() {
    final item = state.selectedItem;
    final cycleId = state.selectedCycleId;
    if (item == null || cycleId == null || !state.isDecisionValid) return null;

    final defaultReasonCode = state.mode == AdministrativeAdjustmentMode.waived
        ? 'ATTENDANCE_PENALTY_WAIVED'
        : (item.isLateArrivalProposal
            ? 'LATE_ARRIVAL'
            : 'ATTENDANCE_PENALTY_ADJUSTED');

    return AdministrativeAdjustmentRequest(
      commandId: _uuid.v4(),
      employeeId: item.employeeId,
      targetCycleId: cycleId,
      businessDate: item.businessDate,
      kind: 'deduction',
      mode: state.mode,
      units: (state.mode == AdministrativeAdjustmentMode.dayFraction ||
              state.mode == AdministrativeAdjustmentMode.customHours)
          ? state.units
          : null,
      fixedAmount: state.mode == AdministrativeAdjustmentMode.fixed
          ? MoneyAmount(currency: 'SDG', amount: state.fixedAmount)
          : null,
      reasonCode: defaultReasonCode,
      reason: state.reason.trim(),
      reconciliationItemId: item.id,
    );
  }

  Future<void> previewAdjustment() async {
    final req = _buildRequest();
    if (isClosed || req == null) {
      emit(state.copyWith(
        errorMessage: 'اختر دورة الرواتب واكتب سبباً واضحاً لمعاينة الحساب.',
      ));
      return;
    }

    emit(state.copyWith(
      outcome: ReconciliationActionOutcome.previewing,
      clearError: true,
    ));

    try {
      final preview = await _repository.previewAdministrativeAdjustment(req);
      if (isClosed) return;
      emit(state.copyWith(
        preview: preview,
        outcome: ReconciliationActionOutcome.previewReady,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        outcome: ReconciliationActionOutcome.failure,
        errorMessage:
            'تعذر حساب المعاينة. تحقق من راتب الموظف والدورة والوردية.',
      ));
    }
  }

  Future<void> submitDecision() async {
    final req = _buildRequest();
    if (isClosed || req == null) return;

    emit(state.copyWith(
      outcome: ReconciliationActionOutcome.saving,
      clearError: true,
    ));

    try {
      await _repository.submitAdministrativeAdjustment(req);
      if (isClosed) return;
      emit(state.copyWith(
        outcome: ReconciliationActionOutcome.decisionSuccess,
        clearSelectedItem: true,
        clearPreview: true,
      ));
    } catch (e) {
      if (isClosed) return;
      final outcome = _classifyError(e);
      emit(state.copyWith(
        outcome: outcome,
        errorMessage: _errorMessageFor(outcome),
      ));
    }
  }

  ReconciliationActionOutcome _classifyError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('403') || str.contains('forbidden')) {
      return ReconciliationActionOutcome.forbidden;
    }
    if (str.contains('409') || str.contains('conflict')) {
      return ReconciliationActionOutcome.conflict;
    }
    if (str.contains('422') || str.contains('validation') || str.contains('finalized')) {
      return ReconciliationActionOutcome.policyRejection;
    }
    if (str.contains('socket') || str.contains('network') || str.contains('timeout')) {
      return ReconciliationActionOutcome.networkError;
    }
    return ReconciliationActionOutcome.failure;
  }

  String _errorMessageFor(ReconciliationActionOutcome outcome) => switch (outcome) {
        ReconciliationActionOutcome.forbidden =>
          'ليس لديك صلاحية لتنفيذ هذا الإجراء الإداري.',
        ReconciliationActionOutcome.conflict =>
          'تغيّرت حالة المهمة أو تمت معالجتها مسبقاً. حدّث القائمة ثم أعد المحاولة.',
        ReconciliationActionOutcome.policyRejection =>
          'تعذر حفظ القرار: قد تكون دورة الرواتب مقفلة أو المعطيات غير متوافقة.',
        ReconciliationActionOutcome.networkError =>
          'تعذر الاتصال بالخادم. يرجى التحقق من الشبكة.',
        _ => 'تعذر حفظ القرار. يرجى إعادة المحاولة.',
      };
}
