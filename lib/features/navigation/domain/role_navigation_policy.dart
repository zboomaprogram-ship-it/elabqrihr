import 'package:attend_mobile/features/auth/domain/auth_models.dart';

/// Pure domain policy governing client-side navigation and action access
/// across user roles. Ensures users are never presented with entry points
/// that lead to a server 403 Forbidden response.
class RoleNavigationPolicy {
  final UserRole role;

  const RoleNavigationPolicy(this.role);

  /// Whether the user can view personal payslips.
  /// Allowed for Employee, Manager, and HR with employee profiles.
  /// Forbidden for pure Company Admin without employee identity.
  bool get canViewPayslips =>
      role == UserRole.employee ||
      role == UserRole.manager ||
      role == UserRole.hr;

  /// Whether the user can request salary advances and view advance obligations.
  /// Allowed for Employee, Manager, and HR. Forbidden for Company Admin.
  bool get canRequestAdvance =>
      role == UserRole.employee ||
      role == UserRole.manager ||
      role == UserRole.hr;

  /// Whether the user can access financial request forms (e.g. expenses, allowances).
  /// Allowed for Employee, Manager, and HR. Forbidden for pure Company Admin.
  bool get canAccessFinancialRequests =>
      role == UserRole.employee ||
      role == UserRole.manager ||
      role == UserRole.hr;

  /// Overall access to the financial services section in Profile or menus.
  bool get canAccessFinanceSection =>
      canViewPayslips || canRequestAdvance || canAccessFinancialRequests;

  /// Whether the user can record self-attendance (check-in/check-out).
  /// Explicitly preserves Manager Self-Attendance alongside review roles.
  bool get canRecordSelfAttendance => true;

  /// Whether the user can access notifications center and badge.
  /// Permitted for all authenticated roles.
  bool get canAccessNotifications => true;

  /// Whether the user can access reviewer approval inboxes.
  bool get canAccessReviewerInbox =>
      role == UserRole.manager ||
      role == UserRole.hr ||
      role == UserRole.companyAdmin;

  /// Whether the user can access the team roster.
  bool get canAccessTeamRoster =>
      role == UserRole.manager ||
      role == UserRole.hr ||
      role == UserRole.companyAdmin;

  /// Role category convenience getters
  bool get isEmployee => role == UserRole.employee;
  bool get isManager => role == UserRole.manager;
  bool get isHr => role == UserRole.hr;
  bool get isCompanyAdmin => role == UserRole.companyAdmin;
  bool get isHrOrAdmin =>
      role == UserRole.hr || role == UserRole.companyAdmin;

  /// Whether this role routinely follows an operational shift schedule.
  bool get requiresShiftSchedule =>
      role == UserRole.employee ||
      role == UserRole.manager ||
      role == UserRole.hr;

  /// Pure company administrator account (without personal employee records).
  bool get isPureCompanyAdmin => role == UserRole.companyAdmin;

  /// Whether the user persona has active self-attendance operational capabilities.
  /// Operational employees (Employee, Manager, HR) have shift-based attendance.
  /// Pure Company Admins oversee operations rather than clocking in personal shifts.
  bool get hasOperationalSelfAttendance =>
      role == UserRole.employee ||
      role == UserRole.manager ||
      role == UserRole.hr;

  /// Descriptive guidance for self-attendance access per persona.
  String get attendanceRoleGuidance {
    if (isPureCompanyAdmin) {
      return 'حساب الإدارة مخصص للإشراف والمتابعة واعتماد العمليات. تسجيل الحضور الذاتي مخصص للموظفين التشغيليين.';
    }
    return 'تسجيل الحضور والانصراف متاح وفق جدول الورديات المعتمد.';
  }
}

