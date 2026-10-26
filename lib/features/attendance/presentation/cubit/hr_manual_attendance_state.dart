import 'package:equatable/equatable.dart';
import '../../domain/manual_attendance_models.dart';

enum HrSubmissionOutcome {
  idle,
  submitting,
  success,
  conflict,
  policyRejection,
  forbidden,
  networkError,
  failure,
}

class HrManualAttendanceState extends Equatable {
  final List<ManualAttendanceEmployeeOption> employees;
  final String? selectedEmployeeId;
  final String searchQuery;
  final String businessDate; // YYYY-MM-DD
  final ManualAttendanceActionType actionType;
  final DateTime? occurredAt;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String reason;
  final bool isLoadingEmployees;
  final HrSubmissionOutcome outcome;
  final String? errorMessage;
  final ManualAttendanceActionResult? successResult;

  const HrManualAttendanceState({
    this.employees = const [],
    this.selectedEmployeeId,
    this.searchQuery = '',
    required this.businessDate,
    this.actionType = ManualAttendanceActionType.checkIn,
    this.occurredAt,
    this.checkInAt,
    this.checkOutAt,
    this.reason = '',
    this.isLoadingEmployees = false,
    this.outcome = HrSubmissionOutcome.idle,
    this.errorMessage,
    this.successResult,
  });

  List<ManualAttendanceEmployeeOption> get filteredEmployees {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return employees;
    return employees.where((emp) {
      final name = emp.displayName.toLowerCase();
      final num = emp.employeeNumber.toLowerCase();
      return name.contains(q) || num.contains(q);
    }).toList();
  }

  ManualAttendanceEmployeeOption? get selectedEmployee {
    if (selectedEmployeeId == null) return null;
    try {
      return employees.firstWhere((e) => e.id == selectedEmployeeId);
    } catch (_) {
      return null;
    }
  }

  bool get isValid {
    if (selectedEmployeeId == null || selectedEmployeeId!.isEmpty) return false;
    if (reason.trim().length < 3) return false;
    if (actionType == ManualAttendanceActionType.fullDay) {
      if (checkInAt == null || checkOutAt == null) return false;
      if (!checkOutAt!.isAfter(checkInAt!)) return false;
    }
    return true;
  }

  HrManualAttendanceState copyWith({
    List<ManualAttendanceEmployeeOption>? employees,
    String? selectedEmployeeId,
    String? searchQuery,
    String? businessDate,
    ManualAttendanceActionType? actionType,
    DateTime? occurredAt,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    String? reason,
    bool? isLoadingEmployees,
    HrSubmissionOutcome? outcome,
    String? errorMessage,
    bool clearError = false,
    ManualAttendanceActionResult? successResult,
  }) {
    return HrManualAttendanceState(
      employees: employees ?? this.employees,
      selectedEmployeeId: selectedEmployeeId ?? this.selectedEmployeeId,
      searchQuery: searchQuery ?? this.searchQuery,
      businessDate: businessDate ?? this.businessDate,
      actionType: actionType ?? this.actionType,
      occurredAt: occurredAt ?? this.occurredAt,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      reason: reason ?? this.reason,
      isLoadingEmployees: isLoadingEmployees ?? this.isLoadingEmployees,
      outcome: outcome ?? this.outcome,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successResult: successResult ?? this.successResult,
    );
  }

  @override
  List<Object?> get props => [
        employees,
        selectedEmployeeId,
        searchQuery,
        businessDate,
        actionType,
        occurredAt,
        checkInAt,
        checkOutAt,
        reason,
        isLoadingEmployees,
        outcome,
        errorMessage,
        successResult,
      ];
}
