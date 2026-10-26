import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/widgets/checkin_radar_button.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import '../../test_doubles/fake_dynamic_request_repo.dart';
import '../../test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class _FakeAuthRepo implements AuthRepository {
  final AuthSessionEntity session;
  _FakeAuthRepo(this.session);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => session;
  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async =>
      session;
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

class _StubAttendanceRepo implements AttendanceRepository {
  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-10',
      branchName: 'الفرع الرئيسي',
      shiftName: 'الوردية الصباحية',
      scheduledStart: DateTime.utc(2026, 9, 20, 9, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 17, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 100.0,
      isCheckedIn: false,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) =>
      throw UnimplementedError();
  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
}

class _StubRequestRepo implements RequestRepository {
  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async =>
      const [];

  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) =>
      throw UnimplementedError();
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
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => const [];
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
  }) async =>
      const [];
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

class _PendingManagerDashboardRepository extends StubDashboardRepository {
  _PendingManagerDashboardRepository() : super(role: UserRole.manager);
  @override
  Future<DashboardSummary> getDashboardSummary() async => DashboardSummary(
        profile: profileRepository.profile,
        pendingApprovals: 1,
      );
}

class _TrackingDynamicRequestRepo extends FakeDynamicRequestRepo {
  int syncCalls = 0;
  @override
  Future<void> synchronizeOutbox() async {
    syncCalls++;
  }
}

void main() {
  group('Role Dashboard and Navigation Tests (US2)', () {
    testWidgets('Employee navigation has Home, Attendance, Requests, Profile',
        (tester) async {
      const empSession = AuthSessionEntity(
        accessToken: 'jwt',
        tenantId: 't1',
        userId: 'u1',
        role: UserRole.employee,
        email: 'employee@corp.com',
        displayName: 'سارة خالد',
      );

      final dynamicRepo = _TrackingDynamicRequestRepo();
      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(empSession),
          attendanceRepository: _StubAttendanceRepo(),
          requestRepository: _StubRequestRepo(),
          dynamicRequestRepository: dynamicRepo,
          profileRepository: StubProfileRepository(),
          dashboardRepository: StubDashboardRepository(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();
      final previousSyncs = dynamicRepo.syncCalls;
      await BlocProvider.of<EmployeeRequestsCubit>(
              tester.element(find.byType(BottomNavigationBar)))
          .syncOutbox();
      expect(dynamicRepo.syncCalls, previousSyncs + 1);
      await tester.pumpAndSettle();

      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('الرئيسية')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text(AppStringsAr.attendanceTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text(AppStringsAr.requestsTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('حسابي')),
          findsOneWidget);
      expect(find.text(AppStringsAr.reviewerInboxTitle), findsNothing);
    });

    testWidgets(
        'Manager navigation shows Home, Attendance, Team, Approvals, Profile tabs',
        (tester) async {
      const mgrSession = AuthSessionEntity(
        accessToken: 'jwt',
        tenantId: 't1',
        userId: 'm1',
        role: UserRole.manager,
        email: 'manager@corp.com',
        displayName: 'عمر فؤاد',
      );

      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(mgrSession),
          attendanceRepository: _StubAttendanceRepo(),
          requestRepository: _StubRequestRepo(),
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
              of: find.byType(BottomNavigationBar),
              matching: find.text('فريقي')),
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
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('حسابي')),
          findsOneWidget);
    });

    testWidgets('Manager team shortcut opens the approval inbox',
        (tester) async {
      const session = AuthSessionEntity(
        accessToken: 'fixture-token',
        tenantId: 'fixture-tenant',
        userId: 'fixture-manager',
        role: UserRole.manager,
        email: 'manager@example.com',
        displayName: 'مدير الاختبار',
      );
      await tester.pumpWidget(AttendApp(
        authRepository: _FakeAuthRepo(session),
        attendanceRepository: _StubAttendanceRepo(),
        requestRepository: _StubRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(role: UserRole.manager),
        dashboardRepository: _PendingManagerDashboardRepository(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('فريقي'));
      await tester.pumpAndSettle();
      expect(find.text('فريق العمل'), findsOneWidget);
      final shortcut = find.text('مراجعة الطلبات المعلقة');
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.text('بانتظار الموافقة'), findsOneWidget);
      expect(find.text('فريق العمل'), findsNothing);
    });

    testWidgets('HR navigation shows Home, Attendance, Requests, Profile tabs',
        (tester) async {
      const hrSession = AuthSessionEntity(
        accessToken: 'jwt',
        tenantId: 't1',
        userId: 'hr1',
        role: UserRole.hr,
        email: 'hr@corp.com',
        displayName: 'منى أحمد',
      );

      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(hrSession),
          attendanceRepository: _StubAttendanceRepo(),
          requestRepository: _StubRequestRepo(),
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(role: UserRole.hr),
          dashboardRepository: StubDashboardRepository(role: UserRole.hr),
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
              matching: find.text(AppStringsAr.attendanceTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text(AppStringsAr.requestsTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('حسابي')),
          findsOneWidget);
    });

    testWidgets(
        'CompanyAdmin navigation shows Home, Attendance, Requests, Profile tabs',
        (tester) async {
      const adminSession = AuthSessionEntity(
        accessToken: 'jwt',
        tenantId: 't1',
        userId: 'admin1',
        role: UserRole.companyAdmin,
        email: 'admin@corp.com',
        displayName: 'أحمد الإداري',
      );

      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(adminSession),
          attendanceRepository: _StubAttendanceRepo(),
          requestRepository: _StubRequestRepo(),
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(role: UserRole.companyAdmin),
          dashboardRepository:
              StubDashboardRepository(role: UserRole.companyAdmin),
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
              matching: find.text(AppStringsAr.attendanceTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text(AppStringsAr.requestsTab)),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('حسابي')),
          findsOneWidget);
    });

    testWidgets('DashboardHeader renders branch name and geofence state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardHeader(
              userName: 'سارة خالد',
              branchName: 'مكتب الرياض',
              isWithinGeofence: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('مكتب الرياض'), findsOneWidget);
      expect(find.textContaining('داخل نطاق العمل'), findsOneWidget);
    });

    testWidgets('CheckInRadarButton renders and fires onTap callback',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheckInRadarButton(
              title: 'تسجيل الحضور',
              subtitle: 'اضغط للتسجيل',
              icon: Icons.fingerprint,
              disabled: false,
              loading: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('تسجيل الحضور'), findsOneWidget);
      await tester.tap(find.byType(CheckInRadarButton));
      expect(tapped, isTrue);
    });
  });
}
