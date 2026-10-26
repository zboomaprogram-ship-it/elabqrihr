import 'package:equatable/equatable.dart';
import '../../domain/manual_attendance_models.dart';

enum ReconciliationActionOutcome {
  idle,
  loadingItems,
  loadingCycles,
  previewing,
  previewReady,
  saving,
  decisionSuccess,
  conflict,
  policyRejection,
  forbidden,
  networkError,
  failure,
}

class ReconciliationQuickActionsState extends Equatable {
  final List<DetailedReconciliationItem> items;
  final List<OpenPayrollCycle> openCycles;
  final String? filterState;
  final DetailedReconciliationItem? selectedItem;
  final String? selectedCycleId;
  final AdministrativeAdjustmentMode mode;
  final String units;
  final String fixedAmount;
  final String reason;
  final AdministrativeAdjustmentPreview? preview;
  final ReconciliationActionOutcome outcome;
  final String? errorMessage;

  const ReconciliationQuickActionsState({
    this.items = const [],
    this.openCycles = const [],
    this.filterState,
    this.selectedItem,
    this.selectedCycleId,
    this.mode = AdministrativeAdjustmentMode.waived,
    this.units = '0.25',
    this.fixedAmount = '100.00',
    this.reason = '',
    this.preview,
    this.outcome = ReconciliationActionOutcome.idle,
    this.errorMessage,
  });

  bool get isDecisionValid {
    if (selectedItem == null) return false;
    if (selectedCycleId == null || selectedCycleId!.isEmpty) return false;
    if (reason.trim().length < 3) return false;
    if (mode == AdministrativeAdjustmentMode.customHours &&
        (double.tryParse(units) == null || double.parse(units) <= 0)) {
      return false;
    }
    if (mode == AdministrativeAdjustmentMode.fixed &&
        (double.tryParse(fixedAmount) == null ||
            double.parse(fixedAmount) <= 0)) {
      return false;
    }
    return true;
  }

  ReconciliationQuickActionsState copyWith({
    List<DetailedReconciliationItem>? items,
    List<OpenPayrollCycle>? openCycles,
    String? filterState,
    DetailedReconciliationItem? selectedItem,
    bool clearSelectedItem = false,
    String? selectedCycleId,
    AdministrativeAdjustmentMode? mode,
    String? units,
    String? fixedAmount,
    String? reason,
    AdministrativeAdjustmentPreview? preview,
    bool clearPreview = false,
    ReconciliationActionOutcome? outcome,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReconciliationQuickActionsState(
      items: items ?? this.items,
      openCycles: openCycles ?? this.openCycles,
      filterState: filterState ?? this.filterState,
      selectedItem:
          clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      selectedCycleId: selectedCycleId ?? this.selectedCycleId,
      mode: mode ?? this.mode,
      units: units ?? this.units,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      reason: reason ?? this.reason,
      preview: clearPreview ? null : (preview ?? this.preview),
      outcome: outcome ?? this.outcome,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        items,
        openCycles,
        filterState,
        selectedItem,
        selectedCycleId,
        mode,
        units,
        fixedAmount,
        reason,
        preview,
        outcome,
        errorMessage,
      ];
}
