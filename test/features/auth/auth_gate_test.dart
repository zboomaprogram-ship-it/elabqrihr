import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import '../../test_doubles/fake_dynamic_request_repo.dart';
import '../../test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class _FakeAuthRepo implements AuthRepository {
  final AuthSessionEntity? session;
  final Future<AuthSessionEntity?>? delayedSession;
  final Future<AuthSessionEntity>? delayedRefresh;
  _FakeAuthRepo(this.session, {this.delayedSession, this.delayedRefresh});

  @override
  Future<AuthSessionEntity?> getCachedSession() async =>
      delayedSession == null ? session : await delayedSession;
  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async =>
      session!;
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSessionEntity> refreshSession() =>
      delayedRefresh ?? (throw UnimplementedError());

  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class _SpyAttendanceRepo implements AttendanceRepository {
  int getContextCallCount = 0;

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    getContextCallCount++;
    return ShiftContextEntity(
      shiftInstanceId: 'shift-1',
      branchName: 'Branch HQ',
      shiftName: 'Morning',
      scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0, longitude: 31.0),
      allowedRadiusMeters: 100,
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

class _SpyRequestRepo implements RequestRepository {
  int listRequestsCallCount = 0;

  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async {
    listRequestsCallCount++;
    return const [];
  }

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

void main() {
  group('AuthGate Isolation Tests (FR-001, US1)', () {
    testWidgets(
        'cached session restores through refresh directly to home without a login frame',
        (tester) async {
      final cached = Completer<AuthSessionEntity?>();
      final refreshed = Completer<AuthSessionEntity>();
      final attendanceRepo = _SpyAttendanceRepo();
      final requestRepo = _SpyRequestRepo();
      const session = AuthSessionEntity(
          accessToken: 'cached-test',
          refreshToken: 'refresh-test',
          tenantId: 'tenant-1',
          userId: 'user-1',
          role: UserRole.employee,
          email: 'employee@example.test',
          displayName: 'Synthetic User');
      await tester.pumpWidget(AttendApp(
          authRepository: _FakeAuthRepo(session,
              delayedSession: cached.future, delayedRefresh: refreshed.future),
          attendanceRepository: attendanceRepo,
          requestRepository: requestRepo,
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(),
          dashboardRepository: StubDashboardRepository()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('login_email_field')), findsNothing);
      expect(attendanceRepo.getContextCallCount, 0);
      cached.complete(session);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('login_email_field')), findsNothing);
      expect(requestRepo.listRequestsCallCount, 0);
      refreshed.complete(session);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_email_field')), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets(
        'Unauthenticated session NEVER calls protected attendance or request APIs',
        (tester) async {
      final attendanceRepo = _SpyAttendanceRepo();
      final requestRepo = _SpyRequestRepo();

      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(null),
          attendanceRepository: attendanceRepo,
          requestRepository: requestRepo,
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(),
          dashboardRepository: StubDashboardRepository(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Login screen is shown
      expect(find.byKey(const Key('login_button')), findsOneWidget);
      // Protected repositories were NOT called
      expect(attendanceRepo.getContextCallCount, equals(0));
      expect(requestRepo.listRequestsCallCount, equals(0));
    });

    testWidgets(
        'Authenticated session enters app shell and initializes context',
        (tester) async {
      final attendanceRepo = _SpyAttendanceRepo();
      final requestRepo = _SpyRequestRepo();
      const session = AuthSessionEntity(
        accessToken: 'valid-jwt',
        tenantId: 'tenant-1',
        userId: 'user-1',
        role: UserRole.employee,
        email: 'emp@corp.com',
        displayName: 'Ahmad User',
      );

      await tester.pumpWidget(
        AttendApp(
          authRepository: _FakeAuthRepo(session),
          attendanceRepository: attendanceRepo,
          requestRepository: requestRepo,
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(),
          dashboardRepository: StubDashboardRepository(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Dashboard is shown
      expect(
          find.descendant(
              of: find.byType(BottomNavigationBar),
              matching: find.text('الرئيسية')),
          findsOneWidget);
      expect(find.textContaining('مستخدم الاختبار'), findsOneWidget);

      // Switch to Attendance tab
      await tester.tap(find.descendant(
          of: find.byType(BottomNavigationBar), matching: find.text('الحضور')));
      await tester.pumpAndSettle();
      expect(find.text('Branch HQ'), findsOneWidget);

      // Protected repositories were called once session was authenticated
      expect(attendanceRepo.getContextCallCount, greaterThanOrEqualTo(1));
    });
  });
}
