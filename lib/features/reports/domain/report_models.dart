import 'package:attend_mobile/features/auth/domain/auth_models.dart';

class WorkforceReportSummaryEntity {
  final String from;
  final String to;
  final int activeEmployees;
  final int suspendedEmployees;
  final int archivedEmployees;
  final int activeLocations;
  final int unassignedEmployees;
  final DateTime generatedAt;

  const WorkforceReportSummaryEntity({
    required this.from,
    required this.to,
    required this.activeEmployees,
    required this.suspendedEmployees,
    required this.archivedEmployees,
    required this.activeLocations,
    required this.unassignedEmployees,
    required this.generatedAt,
  });

  int get totalEmployees =>
      activeEmployees + suspendedEmployees + archivedEmployees;
}

class AttendanceLeaveTotalsEntity {
  final int employees;
  final int attendanceExceptions;
  final int leaveMinutes;
  final int requests;

  const AttendanceLeaveTotalsEntity({
    required this.employees,
    required this.attendanceExceptions,
    required this.leaveMinutes,
    required this.requests,
  });
}

class AttendanceLeaveItemEntity {
  final String employeeId;
  final String employeeName;
  final String businessDate;
  final String attendanceState;
  final int leaveMinutes;
  final String? requestState;

  const AttendanceLeaveItemEntity({
    required this.employeeId,
    required this.employeeName,
    required this.businessDate,
    required this.attendanceState,
    required this.leaveMinutes,
    this.requestState,
  });
}

class AttendanceLeaveReportEntity {
  final AttendanceLeaveTotalsEntity totals;
  final List<AttendanceLeaveItemEntity> items;
  final String? nextCursor;

  const AttendanceLeaveReportEntity({
    required this.totals,
    required this.items,
    this.nextCursor,
  });
}

class ExportJobEntity {
  final String id;
  final String state;
  final int? rowCount;
  final String? reasonCode;
  final DateTime? expiresAt;

  const ExportJobEntity({
    required this.id,
    required this.state,
    this.rowCount,
    this.reasonCode,
    this.expiresAt,
  });

  bool get isReady => state == 'ready';
  bool get isFailed => state == 'failed';
  bool get isExpired => state == 'expired';
}

class ReportScopeHelper {
  static String titleForRole(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return 'تقريري الشخصي';
      case UserRole.manager:
        return 'تقرير فريقي';
      case UserRole.hr:
      case UserRole.companyAdmin:
        return 'تقرير الشركة';
    }
  }

  static String subtitleForRole(UserRole role) {
    switch (role) {
      case UserRole.employee:
        return 'ملخص حي محسوب من سجلات حضورك وطلباتك المصرح بها.';
      case UserRole.manager:
        return 'ملخص حي محسوب من سجلات أعضاء فريقك المصرح بها.';
      case UserRole.hr:
      case UserRole.companyAdmin:
        return 'ملخص حي محسوب من سجلات الموظفين والتكليفات ومواقع العمل المصرح بها.';
    }
  }
}
