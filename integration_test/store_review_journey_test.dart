import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import '../test/test_doubles/fake_dynamic_request_repo.dart';
import '../test/test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class _SyntheticReviewerAuthRepo implements AuthRepository {
  AuthSessionEntity? session;

  _SyntheticReviewerAuthRepo(this.session);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => session;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async {
    if (tenantSlug != 'demo') {
      throw Exception('403 Forbidden: cross_tenant_access_refused');
    }

    final role = switch (email) {
      'reviewer@elabqrihr.com' => UserRole.companyAdmin,
      'reviewer.manager@elabqrihr.com' => UserRole.manager,
      'reviewer.hr@elabqrihr.com' => UserRole.hr,
      'reviewer.employee@elabqrihr.com' => UserRole.employee,
      _ => throw Exception('401 Unauthorized: invalid_credentials'),
    };

    final newSession = AuthSessionEntity(
      accessToken: 'synth-token-$role',
      tenantId: 'tenant-demo',
      userId: 'user-synth-$role',
      role: role,
      email: email,
      displayName: 'مراجع المتجر ($email)',
    );
    session = newSession;
    return newSession;
  }

  @override
  Future<void> logout() async {
    session = null;
  }

  @override
  Future<AuthSessionEntity> refreshSession() async {
    if (session == null) throw Exception('401 Unauthorized');
    return session!;
  }

  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class _SyntheticReviewerAttendanceRepo implements AttendanceRepository {
  final UserRole role;
  final bool outsideGeofence;

  _SyntheticReviewerAttendanceRepo({
    required this.role,
    this.outsideGeofence = false,
  });

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    // Company admins without operational employee records do not have scheduled shifts
    if (role == UserRole.companyAdmin) {
      throw Exception('404 Not Found: SHIFT_NOT_FOUND');
    }

    return ShiftContextEntity(
      shiftInstanceId: 'shift-demo-001',
      branchName: 'فرع الرياض التجريبي',
      shiftName: 'الوردية الصباحية المعتمدة',
      scheduledStart: DateTime.utc(2026, 10, 6, 8, 0),
      scheduledEnd: DateTime.utc(2026, 10, 6, 16, 0),
      branchLocation: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
      lastEvent: outsideGeofence
          ? AttendanceEventEntity(
              id: 'evt-geofence-rejected',
              eventType: AttendanceEventType.checkIn,
              capturedAt: DateTime.utc(2026, 10, 6, 8, 30),
              location: const GeoPoint(latitude: 25.5000, longitude: 47.5000),
              shiftInstanceId: 'shift-demo-001',
              status: AttendanceValidationStatus.rejected,
              reasonCode: 'OUTSIDE_GEOFENCE',
            )
          : null,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    if (outsideGeofence) {
      return AttendanceEventEntity(
        id: clientEventId ?? 'evt-geofence-rejected',
        eventType: eventType,
        capturedAt: capturedAt ?? DateTime.utc(2026, 10, 6, 8, 30),
        location:
            location ?? const GeoPoint(latitude: 25.5000, longitude: 47.5000),
        shiftInstanceId: shiftInstanceId,
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'OUTSIDE_GEOFENCE',
      );
    }

    return AttendanceEventEntity(
      id: clientEventId ?? 'evt-accepted-1',
      eventType: eventType,
      capturedAt: capturedAt ?? DateTime.utc(2026, 10, 6, 8, 0),
      location:
          location ?? const GeoPoint(latitude: 24.7136, longitude: 46.6753),
      shiftInstanceId: shiftInstanceId,
      status: AttendanceValidationStatus.accepted,
    );
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() =>
      Stream.value(const []);

  @override
  Future<void> synchronizeOutbox() async {}
}

class _SyntheticReviewerRequestRepo implements RequestRepository {
  final UserRole role;

  _SyntheticReviewerRequestRepo({required this.role});

  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async {
    return [
      RequestEntity(
        id: 'req-leave-001',
        employeeId: 'emp-demo-001',
        type: RequestType.leave,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.utc(2026, 10, 5, 10, 0),
        details: const {'leaveType': 'annual', 'days': 2},
        steps: const [],
      ),
    ];
  }

  @override
  Future<RequestEntity> getRequestDetail(String requestId) =>
      throw UnimplementedError();

  @override
  Future<RequestEntity> cancelRequest({
    required String requestId,
    required int expectedRevision,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => [
        const LeaveBalanceEntity(
          employeeId: 'emp-demo-001',
          categoryId: 'cat-annual',
          categoryName: 'إجازة سنوية',
          periodStart: '2026-01-01',
          periodEnd: '2026-12-31',
          balanceMinutes: 14400,
        ),
      ];

  @override
  Stream<List<RequestEntity>> watchPendingRequests() => Stream.value([]);

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<List<RequestEntity>> listApprovalInbox({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
    String? employeeId,
    String? effectiveFrom,
    String? effectiveTo,
  }) async {
    if (role == UserRole.employee) {
      throw Exception(
          '403 Forbidden: employees cannot access reviewer approval inboxes');
    }
    return [
      RequestEntity(
        id: 'req-team-approval-001',
        employeeId: 'emp-demo-002',
        employeeName: 'أحمد السعيد',
        type: RequestType.leave,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.utc(2026, 10, 5, 12, 0),
        details: const {'leaveType': 'annual', 'days': 1},
        steps: const [],
      ),
    ];
  }

  @override
  Future<RequestEntity> decideRequest({
    required String requestId,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) =>
      throw UnimplementedError();
}

class _SyntheticNotificationRepo implements NotificationRepository {
  @override
  Future<NotificationEntity?> getNotification(String notificationId) async =>
      null;

  @override
  Future<NotificationPageEntity> listNotifications(
          {String? cursor, int limit = 50}) async =>
      const NotificationPageEntity(items: [], nextCursor: null);

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<NotificationEntity> markAsRead(String notificationId) =>
      throw UnimplementedError();

  @override
  Future<int> markAllAsRead({String? commandId, DateTime? before}) async => 0;

  @override
  Future<ReauthorizationResult> reauthorizeDestination(
    NotificationDestinationKind kind,
    String destinationId,
  ) async =>
      ReauthorizationResult.authorized;
}

Widget _createSyntheticTestApp({
  required AuthSessionEntity session,
  bool outsideGeofence = false,
}) {
  final authRepo = _SyntheticReviewerAuthRepo(session);
  final attendanceRepo = _SyntheticReviewerAttendanceRepo(
    role: session.role,
    outsideGeofence: outsideGeofence,
  );
  final requestRepo = _SyntheticReviewerRequestRepo(role: session.role);
  final profileRepo = StubProfileRepository(role: session.role);
  final dashboardRepo = StubDashboardRepository(role: session.role);

  return AttendApp(
    authRepository: authRepo,
    attendanceRepository: attendanceRepo,
    requestRepository: requestRepo,
    dynamicRequestRepository: FakeDynamicRequestRepo(),
    profileRepository: profileRepo,
    dashboardRepository: dashboardRepo,
    notificationRepository: _SyntheticNotificationRepo(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 012 Task T018: Four-Persona Store Review Journeys', () {
    testWidgets(
        '1. Employee Persona (reviewer.employee@elabqrihr.com): authorized shift & requests, forbidden reviewer inbox',
        (tester) async {
      const employeeSession = AuthSessionEntity(
        accessToken: 'synth-token-employee',
        tenantId: 'tenant-demo',
        userId: 'user-synth-employee',
        role: UserRole.employee,
        email: 'reviewer.employee@elabqrihr.com',
        displayName: 'مراجع المتجر - موظف',
      );

      final policy = RoleNavigationPolicy(employeeSession.role);
      expect(policy.isEmployee, isTrue);
      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.requiresShiftSchedule, isTrue);
      expect(policy.hasOperationalSelfAttendance, isTrue);
      expect(policy.canViewPayslips, isTrue);
      expect(policy.canRequestAdvance, isTrue);
      expect(policy.canAccessReviewerInbox, isFalse,
          reason: 'Reviewer inbox is strictly forbidden for employee persona');
      expect(policy.canAccessTeamRoster, isFalse,
          reason: 'Team roster is strictly forbidden for employee persona');

      await tester
          .pumpWidget(_createSyntheticTestApp(session: employeeSession));
      await tester.pumpAndSettle();

      // Navigation bar displays Home, Attendance, Requests, Profile
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(find.text(AppStringsAr.requestsTab), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      // Forbidden reviewer destinations are absent from navigation
      expect(find.text('فريقي'), findsNothing);
      expect(find.text(AppStringsAr.reviewerInboxTitle), findsNothing);

      // Navigate to Attendance Tab
      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      // Operational shift schedule is rendered cleanly
      expect(find.text('الوردية الصباحية المعتمدة'), findsOneWidget);
      expect(find.text('فرع الرياض التجريبي'), findsOneWidget);
      expect(find.text(AppStringsAr.checkIn), findsOneWidget);
    });

    testWidgets(
        '2. Manager Persona (reviewer.manager@elabqrihr.com): preserves self-attendance, accesses team and approval inboxes',
        (tester) async {
      const managerSession = AuthSessionEntity(
        accessToken: 'synth-token-manager',
        tenantId: 'tenant-demo',
        userId: 'user-synth-manager',
        role: UserRole.manager,
        email: 'reviewer.manager@elabqrihr.com',
        displayName: 'مراجع المتجر - مدير',
      );

      final policy = RoleNavigationPolicy(managerSession.role);
      expect(policy.isManager, isTrue);
      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.canAccessTeamRoster, isTrue);
      expect(policy.canAccessReviewerInbox, isTrue);
      expect(policy.hasOperationalSelfAttendance, isTrue);

      await tester.pumpWidget(_createSyntheticTestApp(session: managerSession));
      await tester.pumpAndSettle();

      // Manager navigation bar contains team roster and reviewer inbox
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(find.text('فريقي'), findsOneWidget);
      expect(find.text(AppStringsAr.reviewerInboxTitle), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      // Navigate to Attendance: self-attendance remains fully accessible
      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      expect(find.text('الوردية الصباحية المعتمدة'), findsOneWidget);
      expect(find.text(AppStringsAr.checkIn), findsOneWidget);
    });

    testWidgets(
        '3. HR Persona (reviewer.hr@elabqrihr.com): authorized requests, approvals, notifications, and finance access',
        (tester) async {
      const hrSession = AuthSessionEntity(
        accessToken: 'synth-token-hr',
        tenantId: 'tenant-demo',
        userId: 'user-synth-hr',
        role: UserRole.hr,
        email: 'reviewer.hr@elabqrihr.com',
        displayName: 'مراجع المتجر - موارد بشرية',
      );

      final policy = RoleNavigationPolicy(hrSession.role);
      expect(policy.isHr, isTrue);
      expect(policy.canRecordSelfAttendance, isTrue);
      expect(policy.canAccessReviewerInbox, isTrue);
      expect(policy.canAccessTeamRoster, isTrue);
      expect(policy.canAccessFinanceSection, isTrue);

      await tester.pumpWidget(_createSyntheticTestApp(session: hrSession));
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(find.text(AppStringsAr.requestsTab), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      // Self-attendance is functional
      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      expect(find.text('الوردية الصباحية المعتمدة'), findsOneWidget);
    });

    testWidgets(
        '4. Company Admin Persona (reviewer@elabqrihr.com): displays administrative role card in attendance, strictly excludes personal finance to avoid 403',
        (tester) async {
      const adminSession = AuthSessionEntity(
        accessToken: 'synth-token-admin',
        tenantId: 'tenant-demo',
        userId: 'user-synth-admin',
        role: UserRole.companyAdmin,
        email: 'reviewer@elabqrihr.com',
        displayName: 'مراجع المتجر - مسؤول الشركة',
      );

      final policy = RoleNavigationPolicy(adminSession.role);
      expect(policy.isPureCompanyAdmin, isTrue);
      expect(policy.hasOperationalSelfAttendance, isFalse);
      expect(policy.canViewPayslips, isFalse,
          reason:
              'Personal payslips forbidden for pure admin to avoid 403 Forbidden');
      expect(policy.canRequestAdvance, isFalse,
          reason:
              'Personal advances forbidden for pure admin to avoid 403 Forbidden');
      expect(policy.canAccessFinanceSection, isFalse);
      expect(policy.canAccessReviewerInbox, isTrue);

      await tester.pumpWidget(_createSyntheticTestApp(session: adminSession));
      await tester.pumpAndSettle();

      // Navigate to Attendance Tab
      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      // Respectful administrative notice is rendered without 403 or raw errors
      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
      expect(
        find.textContaining('تسجيل الحضور الذاتي مخصص للموظفين التشغيليين'),
        findsOneWidget,
      );
      expect(
          find.textContaining(
              'أدوات الإشراف والاعتماد متاحة في التبويبات الأخرى'),
          findsOneWidget);

      // Zero technical error strings leak
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('Forbidden'), findsNothing);
      expect(find.textContaining('SHIFT_NOT_FOUND'), findsNothing);
    });

    testWidgets(
        '5. Geofence Boundary Check: outside geofence renders clear explanation without accepting false events',
        (tester) async {
      const employeeSession = AuthSessionEntity(
        accessToken: 'synth-token-employee',
        tenantId: 'tenant-demo',
        userId: 'user-synth-employee',
        role: UserRole.employee,
        email: 'reviewer.employee@elabqrihr.com',
        displayName: 'مراجع المتجر - موظف',
      );

      await tester.pumpWidget(_createSyntheticTestApp(
        session: employeeSession,
        outsideGeofence: true,
      ));
      await tester.pumpAndSettle();

      // Navigate to attendance
      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      // Displays Arabic out-of-radius guidance
      expect(
        find.textContaining(
            'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.'),
        findsOneWidget,
      );

      // Zero coordinates or raw exception stacks leak
      expect(find.textContaining('25.5000'), findsNothing);
      expect(find.textContaining('OUTSIDE_GEOFENCE'), findsNothing);
    });

    test(
        '6. Cross-Tenant Refusal: synthetic reviewer refuses non-demo tenant access',
        () async {
      final authRepo = _SyntheticReviewerAuthRepo(null);

      // Attempt login to unauthorized tenant
      expect(
        () => authRepo.login(
          email: 'reviewer.employee@elabqrihr.com',
          password: 'synthetic-password',
          tenantSlug: 'unauthorized-tenant',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('403') &&
            e.toString().contains('cross_tenant_access_refused'))),
      );
    });
  });
}
