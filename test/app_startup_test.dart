import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'test_doubles/fake_dynamic_request_repo.dart';
import 'test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class TestAuthRepo implements AuthRepository {
  final AuthSessionEntity? initialSession;
  TestAuthRepo([this.initialSession]);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => initialSession;
  @override
  Future<AuthSessionEntity> login(
          {required String email,
          required String password,
          required String tenantSlug,
          String? deviceInstallationId}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSessionEntity> refreshSession() => throw UnimplementedError();
  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();
  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class TestAttendanceRepo implements AttendanceRepository {
  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-1',
      branchName: 'Cairo HQ',
      shiftName: 'Morning Shift',
      scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent(
          {required AttendanceEventType eventType,
          required String shiftInstanceId,
          GeoPoint? location,
          String? clientEventId,
          DateTime? capturedAt}) =>
      throw UnimplementedError();
  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
}

class TestRequestRepo implements RequestRepository {
  @override
  Future<RequestEntity> submitRequest(
          {required String requestId,
          required RequestType type,
          required Map<String, dynamic> payload}) =>
      throw UnimplementedError();
  @override
  Future<List<RequestEntity>> listMyRequests(
          {String? cursor,
          int limit = 50,
          RequestType? type,
          RequestState? state}) async =>
      const [];
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
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => const [];
  @override
  Stream<List<RequestEntity>> watchPendingRequests() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
  @override
  Future<List<RequestEntity>> listApprovalInbox(
          {String? cursor,
          int limit = 50,
          RequestType? type,
          RequestState? state,
          String? employeeId,
          String? effectiveFrom,
          String? effectiveTo}) async =>
      const [];
  @override
  Future<RequestEntity> decideRequest(
          {required String requestId,
          required String decisionId,
          required int expectedRevision,
          required String decision,
          String? comment}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('AttendApp renders LoginScreen when unauthenticated',
      (tester) async {
    await tester.pumpWidget(
      AttendApp(
        authRepository: TestAuthRepo(null),
        attendanceRepository: TestAttendanceRepo(),
        requestRepository: TestRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_button')), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
  });

  testWidgets('AttendApp starts and renders dashboard when authenticated',
      (tester) async {
    const employeeSession = AuthSessionEntity(
      accessToken: 'token',
      tenantId: 'tenant-1',
      userId: 'user-1',
      role: UserRole.employee,
      email: 'emp@example.com',
      displayName: 'Employee User',
    );

    await tester.pumpWidget(
      AttendApp(
        authRepository: TestAuthRepo(employeeSession),
        attendanceRepository: TestAttendanceRepo(),
        requestRepository: TestRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('الرئيسية')),
        findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Switch to Attendance tab
    await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar), matching: find.text('الحضور')));
    await tester.pumpAndSettle();

    expect(find.text('Morning Shift'), findsOneWidget);
    expect(find.text('Cairo HQ'), findsOneWidget);
  });

  testWidgets('Employee navigation shows Attendance and Requests tabs',
      (tester) async {
    const employeeSession = AuthSessionEntity(
      accessToken: 'token',
      tenantId: 'tenant-1',
      userId: 'user-1',
      role: UserRole.employee,
      email: 'emp@example.com',
      displayName: 'Employee User',
    );

    await tester.pumpWidget(
      AttendApp(
        authRepository: TestAuthRepo(employeeSession),
        attendanceRepository: TestAttendanceRepo(),
        requestRepository: TestRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('الرئيسية')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('الحضور')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text(AppStringsAr.myRequestsTitle)),
        findsOneWidget);
    expect(find.text(AppStringsAr.reviewerInboxTitle), findsNothing);

    // Switch to Requests tab
    await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(AppStringsAr.myRequestsTitle)));
    await tester.pumpAndSettle();

    expect(find.text(AppStringsAr.requestsManagementTitle), findsOneWidget);
  });

  testWidgets('Manager navigation shows attendance, team, and approvals tabs',
      (tester) async {
    const managerSession = AuthSessionEntity(
      accessToken: 'token',
      tenantId: 'tenant-1',
      userId: 'manager-1',
      role: UserRole.manager,
      email: 'mgr@example.com',
      displayName: 'Manager User',
    );

    await tester.pumpWidget(
      AttendApp(
        authRepository: TestAuthRepo(managerSession),
        attendanceRepository: TestAttendanceRepo(),
        requestRepository: TestRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(role: UserRole.manager),
        dashboardRepository: StubDashboardRepository(role: UserRole.manager),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text('الرئيسية')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar), matching: find.text('فريقي')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text(AppStringsAr.attendanceTab)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.text(AppStringsAr.reviewerInboxTitle)),
        findsOneWidget);

    // Switch to Approvals tab
    await tester.tap(find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text(AppStringsAr.reviewerInboxTitle)));
    await tester.pumpAndSettle();

    expect(find.text('بانتظار الموافقة'), findsOneWidget);
  });
}
