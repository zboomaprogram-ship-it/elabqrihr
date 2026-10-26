import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/manual_attendance_models.dart';
import '../../domain/manual_attendance_repository.dart';
import 'hr_manual_attendance_state.dart';

class HrManualAttendanceCubit extends Cubit<HrManualAttendanceState> {
  final ManualAttendanceRepository _repository;
  final Uuid _uuid;

  HrManualAttendanceCubit({
    required ManualAttendanceRepository repository,
    String? initialBusinessDate,
    Uuid? uuid,
  })  : _repository = repository,
        _uuid = uuid ?? const Uuid(),
        super(HrManualAttendanceState(
          businessDate: initialBusinessDate ?? _defaultDate(),
          occurredAt: DateTime.now(),
          checkInAt: DateTime.now().subtract(const Duration(hours: 8)),
          checkOutAt: DateTime.now(),
        ));

  static String _defaultDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> loadEmployees() async {
    if (isClosed) return;
    emit(state.copyWith(isLoadingEmployees: true, clearError: true));
    try {
      final list = await _repository.getEmployees();
      if (isClosed) return;
      final selected = state.selectedEmployeeId ?? (list.isNotEmpty ? list.first.id : null);
      emit(state.copyWith(
        employees: list,
        selectedEmployeeId: selected,
        isLoadingEmployees: false,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        isLoadingEmployees: false,
        errorMessage: 'تعذر تحميل قائمة الموظفين النشطين. يرجى إعادة المحاولة.',
      ));
    }
  }

  void updateSearch(String query) {
    if (isClosed) return;
    emit(state.copyWith(searchQuery: query));
  }

  void selectEmployee(String employeeId) {
    if (isClosed) return;
    emit(state.copyWith(selectedEmployeeId: employeeId));
  }

  void updateBusinessDate(String date) {
    if (isClosed) return;
    emit(state.copyWith(businessDate: date));
  }

  void updateActionType(ManualAttendanceActionType action) {
    if (isClosed) return;
    emit(state.copyWith(actionType: action));
  }

  void updateOccurredAt(DateTime time) {
    if (isClosed) return;
    emit(state.copyWith(occurredAt: time));
  }

  void updateFullDayTimes(DateTime checkIn, DateTime checkOut) {
    if (isClosed) return;
    emit(state.copyWith(checkInAt: checkIn, checkOutAt: checkOut));
  }

  void updateReason(String reason) {
    if (isClosed) return;
    emit(state.copyWith(reason: reason));
  }

  Future<void> submitManualAttendance() async {
    if (isClosed || !state.isValid || state.outcome == HrSubmissionOutcome.submitting) {
      return;
    }

    emit(state.copyWith(
      outcome: HrSubmissionOutcome.submitting,
      clearError: true,
    ));

    final request = ManualAttendanceActionRequest(
      commandId: _uuid.v4(),
      employeeId: state.selectedEmployeeId!,
      businessDate: state.businessDate,
      action: state.actionType,
      occurredAt: (state.actionType == ManualAttendanceActionType.checkIn ||
              state.actionType == ManualAttendanceActionType.checkOut)
          ? state.occurredAt
          : null,
      checkInAt: state.actionType == ManualAttendanceActionType.fullDay
          ? state.checkInAt
          : null,
      checkOutAt: state.actionType == ManualAttendanceActionType.fullDay
          ? state.checkOutAt
          : null,
      reason: state.reason.trim(),
    );

    try {
      final result = await _repository.submitManualAttendance(request);
      if (isClosed) return;
      emit(state.copyWith(
        outcome: HrSubmissionOutcome.success,
        successResult: result,
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

  HrSubmissionOutcome _classifyError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('403') || str.contains('forbidden')) {
      return HrSubmissionOutcome.forbidden;
    }
    if (str.contains('409') || str.contains('conflict') || str.contains('idempotency_key_reused')) {
      return HrSubmissionOutcome.conflict;
    }
    if (str.contains('422') || str.contains('validation') || str.contains('finalized')) {
      return HrSubmissionOutcome.policyRejection;
    }
    if (str.contains('socket') || str.contains('network') || str.contains('timeout')) {
      return HrSubmissionOutcome.networkError;
    }
    return HrSubmissionOutcome.failure;
  }

  String _errorMessageFor(HrSubmissionOutcome outcome) => switch (outcome) {
        HrSubmissionOutcome.forbidden =>
          'ليس لديك صلاحية لتنفيذ هذا الإجراء الإداري.',
        HrSubmissionOutcome.conflict =>
          'تعارض: تم تسجيل هذا الإجراء مسبقاً أو تغيّرت معطيات الوردية.',
        HrSubmissionOutcome.policyRejection =>
          'تعذر تطبيق التعديل: تحقق من توافق الوردية ودورة الرواتب المفتوحة.',
        HrSubmissionOutcome.networkError =>
          'تعذر الاتصال بالخادم. تتطلب العمليات السيادية اتصالاً مباشراً.',
        _ => 'تعذر حفظ الإجراء الإداري. يرجى إعادة المحاولة.',
      };
}
