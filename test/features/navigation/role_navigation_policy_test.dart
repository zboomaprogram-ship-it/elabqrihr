import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';

void main() {
  group('RoleNavigationPolicy (T006)', () {
    test(
        'Employee role has self-attendance, personal finance, payslips, and notifications',
        () {
      const policy = RoleNavigationPolicy(UserRole.employee);

      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.canViewPayslips, isTrue);
      expect(policy.canRequestAdvance, isTrue);
      expect(policy.canAccessFinancialRequests, isTrue);
      expect(policy.canAccessFinanceSection, isTrue);
      expect(policy.canAccessNotifications, isTrue);
      expect(policy.canAccessReviewerInbox, isFalse);
      expect(policy.canAccessTeamRoster, isFalse);
      expect(policy.isEmployee, isTrue);
      expect(policy.isPureCompanyAdmin, isFalse);
      expect(policy.hasOperationalSelfAttendance, isTrue);
      expect(policy.requiresShiftSchedule, isTrue);
      expect(policy.attendanceRoleGuidance, contains('جدول الورديات'));
    });

    test(
        'Manager role preserves self-attendance, personal finance, inboxes, and team access',
        () {
      const policy = RoleNavigationPolicy(UserRole.manager);

      // Manager is an employee too — self-attendance MUST be reachable
      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.canViewPayslips, isTrue);
      expect(policy.canRequestAdvance, isTrue);
      expect(policy.canAccessFinancialRequests, isTrue);
      expect(policy.canAccessFinanceSection, isTrue);
      expect(policy.canAccessNotifications, isTrue);
      expect(policy.canAccessReviewerInbox, isTrue);
      expect(policy.canAccessTeamRoster, isTrue);
      expect(policy.isManager, isTrue);
      expect(policy.isPureCompanyAdmin, isFalse);
      expect(policy.hasOperationalSelfAttendance, isTrue);
      expect(policy.requiresShiftSchedule, isTrue);
      expect(policy.attendanceRoleGuidance, contains('جدول الورديات'));
    });

    test(
        'HR role has self-attendance, company request approval, notifications, and finance access',
        () {
      const policy = RoleNavigationPolicy(UserRole.hr);

      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.canViewPayslips, isTrue);
      expect(policy.canRequestAdvance, isTrue);
      expect(policy.canAccessFinancialRequests, isTrue);
      expect(policy.canAccessFinanceSection, isTrue);
      expect(policy.canAccessNotifications, isTrue);
      expect(policy.canAccessReviewerInbox, isTrue);
      expect(policy.canAccessTeamRoster, isTrue);
      expect(policy.isHr, isTrue);
      expect(policy.isPureCompanyAdmin, isFalse);
      expect(policy.hasOperationalSelfAttendance, isTrue);
      expect(policy.requiresShiftSchedule, isTrue);
      expect(policy.attendanceRoleGuidance, contains('جدول الورديات'));
    });

    test(
        'Company Admin role has organizational review access, but NO personal finance',
        () {
      const policy = RoleNavigationPolicy(UserRole.companyAdmin);

      expect(policy.canRecordSelfAttendance, isTrue);
      // Pure Company Admin does NOT have personal payslips or personal advances (avoids 403 Forbidden)
      expect(policy.canViewPayslips, isFalse);
      expect(policy.canRequestAdvance, isFalse);
      expect(policy.canAccessFinancialRequests, isFalse);
      expect(policy.canAccessFinanceSection, isFalse);
      expect(policy.canAccessNotifications, isTrue);
      expect(policy.canAccessReviewerInbox, isTrue);
      expect(policy.canAccessTeamRoster, isTrue);
      expect(policy.isCompanyAdmin, isTrue);
      expect(policy.isPureCompanyAdmin, isTrue);
      expect(policy.hasOperationalSelfAttendance, isFalse);
      expect(policy.requiresShiftSchedule, isFalse);
      expect(
          policy.attendanceRoleGuidance, contains('حساب الإدارة مخصص للإشراف'));
    });
  });
}
