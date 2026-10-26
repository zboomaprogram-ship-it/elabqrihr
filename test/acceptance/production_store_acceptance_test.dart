import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import '../test_doubles/fake_dynamic_request_repo.dart';
import '../test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class _AcceptanceAuthRepo implements AuthRepository {
  AuthSessionEntity? session;
  _AcceptanceAuthRepo(this.session);

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
      'admin@elabqrihr.com' => UserRole.companyAdmin,
      'manager@elabqrihr.com' => UserRole.manager,
      'hr@elabqrihr.com' => UserRole.hr,
      _ => UserRole.employee,
    };
    final newSession = AuthSessionEntity(
      accessToken: 'synth-token-$role',
      tenantId: 'tenant-demo',
      userId: 'user-synth-$role',
      role: role,
      email: email,
      displayName: 'المستخدم ($email)',
    );
    session = newSession;
    return newSession;
  }

  @override
  Future<void> logout() async {
    session = null;
  }

  @override
  Future<AuthSessionEntity> refreshSession() async => session!;

  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class _AcceptanceAttendanceRepo implements AttendanceRepository {
  final UserRole role;
  final bool outsideGeofence;

  _AcceptanceAttendanceRepo({
    required this.role,
    this.outsideGeofence = false,
  });

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    if (role == UserRole.companyAdmin) {
      throw Exception('404 Not Found: SHIFT_NOT_FOUND');
    }
    return ShiftContextEntity(
      shiftInstanceId: 'shift-acceptance-1',
      branchName: 'فرع الإنتاج التجريبي',
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
              shiftInstanceId: 'shift-acceptance-1',
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
    return AttendanceEventEntity(
      id: clientEventId ?? 'evt-accepted',
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

class _AcceptanceRequestRepo implements RequestRepository {
  final UserRole role;
  _AcceptanceRequestRepo({required this.role});

  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<RequestEntity>> listMyRequests(
          {String? cursor,
          int limit = 50,
          RequestType? type,
          RequestState? state}) async =>
      [];

  @override
  Future<RequestEntity> getRequestDetail(String requestId) =>
      throw UnimplementedError();

  @override
  Future<RequestEntity> cancelRequest(
          {required String requestId,
          required int expectedRevision,
          required String reason}) =>
      throw UnimplementedError();

  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => [];

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
      throw Exception('403 Forbidden: employee cannot access approvals inbox');
    }
    return [];
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

class _AcceptanceNotificationRepo implements NotificationRepository {
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

Widget _buildAcceptanceApp({
  required AuthSessionEntity session,
  bool outsideGeofence = false,
  double textScale = 1.0,
}) {
  final authRepo = _AcceptanceAuthRepo(session);
  final attendanceRepo = _AcceptanceAttendanceRepo(
    role: session.role,
    outsideGeofence: outsideGeofence,
  );
  final requestRepo = _AcceptanceRequestRepo(role: session.role);
  final profileRepo = StubProfileRepository(role: session.role);
  final dashboardRepo = StubDashboardRepository(role: session.role);

  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      size: const Size(414, 896),
    ),
    child: AttendApp(
      authRepository: authRepo,
      attendanceRepository: attendanceRepo,
      requestRepository: requestRepo,
      dynamicRequestRepository: FakeDynamicRequestRepo(),
      profileRepository: profileRepo,
      dashboardRepository: dashboardRepo,
      notificationRepository: _AcceptanceNotificationRepo(),
    ),
  );
}

void main() {
  group(
      'Production Store Acceptance Journey (Feature 012 - Four-Role Acceptance)',
      () {
    testWidgets('1. Employee Journey at 100% and 200% text scale in Arabic RTL',
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
      expect(policy.canAccessReviewerInbox, isFalse);

      // 100% Text Scale
      await tester.pumpWidget(
          _buildAcceptanceApp(session: employeeSession, textScale: 1.0));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(find.text(AppStringsAr.requestsTab), findsOneWidget);
      expect(find.text(AppStringsAr.reviewerInboxTitle), findsNothing);

      // 200% Text Scale
      await tester.pumpWidget(
          _buildAcceptanceApp(session: employeeSession, textScale: 2.0));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Zero RenderFlex overflow at 200% text scale');
    });

    testWidgets(
        '2. Manager Persona: accesses team and reviewer inbox with self-attendance',
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
      expect(policy.canAccessReviewerInbox, isTrue);

      await tester.pumpWidget(_buildAcceptanceApp(session: managerSession));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.reviewerInboxTitle), findsOneWidget);
      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3. HR Persona: accesses organization requests and self-attendance',
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
      expect(policy.canAccessReviewerInbox, isTrue);

      await tester.pumpWidget(_buildAcceptanceApp(session: hrSession));
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
      expect(find.text(AppStringsAr.requestsTab), findsOneWidget);
      expect(find.text('حسابي'), findsOneWidget);

      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      expect(find.text('الوردية الصباحية المعتمدة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '4. Company Admin Persona: graceful administrative notice without raw 403 or technical leak',
        (tester) async {
      const adminSession = AuthSessionEntity(
        accessToken: 'synth-token-admin',
        tenantId: 'tenant-demo',
        userId: 'user-synth-admin',
        role: UserRole.companyAdmin,
        email: 'reviewer@elabqrihr.com',
        displayName: 'مراجع المتجر - إدارة المنشأة',
      );

      final policy = RoleNavigationPolicy(adminSession.role);
      expect(policy.isPureCompanyAdmin, isTrue);

      await tester.pumpWidget(_buildAcceptanceApp(session: adminSession));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
      expect(
          find.textContaining('تسجيل الحضور الذاتي مخصص للموظفين التشغيليين'),
          findsOneWidget);
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('SHIFT_NOT_FOUND'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '5. Geofence Boundary Check: outside geofence renders clear explanation',
        (tester) async {
      const employeeSession = AuthSessionEntity(
        accessToken: 'synth-token-employee',
        tenantId: 'tenant-demo',
        userId: 'user-synth-employee',
        role: UserRole.employee,
        email: 'reviewer.employee@elabqrihr.com',
        displayName: 'مراجع المتجر - موظف',
      );

      await tester.pumpWidget(_buildAcceptanceApp(
        session: employeeSession,
        outsideGeofence: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.attendanceTab));
      await tester.pumpAndSettle();

      expect(
          find.textContaining(
              'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي'),
          findsOneWidget);
      expect(find.textContaining('OUTSIDE_GEOFENCE'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
