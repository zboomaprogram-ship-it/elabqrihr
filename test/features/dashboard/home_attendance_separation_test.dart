import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/checkin_radar_button.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_screen.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:attend_mobile/features/dashboard/presentation/screens/home_screen.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/attendance_status_teaser_card.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_priority_strip.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_quick_actions_grid.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_summary_cards.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/month_activity_section.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/my_status_card.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/recent_requests_preview.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/team_summary_card.dart';
import 'package:attend_mobile/features/navigation/main_navigation_shell.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';

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
  final ShiftContextEntity shiftContext;
  _StubAttendanceRepo(this.shiftContext);

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async => shiftContext;
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

class _StubDashboardRepo implements DashboardRepository {
  final DashboardSummary summary;
  _StubDashboardRepo(this.summary);

  @override
  Future<DashboardSummary> getDashboardSummary() async => summary;
}

class _StubRequestRepo implements RequestRepository {
  final List<RequestEntity> requests;
  _StubRequestRepo([this.requests = const []]);

  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async =>
      requests;

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

class _StubNotificationRepo implements NotificationRepository {
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

void main() {
  group('T056 Home and Attendance Separation Tests', () {
    const session = AuthSessionEntity(
      accessToken: 'token-123',
      tenantId: 'tenant-456',
      userId: 'user-789',
      role: UserRole.employee,
      email: 'sara@attend.app',
      displayName: 'سارة خالد',
    );

    final shift = ShiftContextEntity(
      shiftInstanceId: 'shift-100',
      branchName: 'مكتب الرياض',
      shiftName: 'الوردية الصباحية',
      scheduledStart: DateTime.utc(2026, 9, 23, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 23, 16, 0),
      branchLocation: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
      allowedRadiusMeters: 100.0,
      isCheckedIn: false,
    );

    final summary = DashboardSummary(
      profile: const UserProfile(
        userId: 'user-789',
        tenantId: 'tenant-456',
        companyName: 'شركة تجريبية',
        displayName: 'سارة خالد',
        email: 'sara@attend.app',
        role: UserRole.employee,
        branchName: 'مكتب الرياض',
        revision: 1,
      ),
      pendingRequests: 2,
      pendingApprovals: 0,
      attendanceState: 'not_started',
    );

    final sampleRequests = <RequestEntity>[
      RequestEntity(
        id: 'req-1',
        employeeId: 'user-789',
        type: RequestType.leave,
        state: RequestState.submitted,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.utc(2026, 9, 22),
        details: const {'leaveType': 'annual'},
        steps: const [],
      ),
    ];

    Widget createTestHarness({
      required Widget child,
      ValueNotifier<int>? tabNotifier,
    }) {
      final authRepo = _FakeAuthRepo(session);
      final authCubit = AuthCubit(authRepo)..checkSession();
      final attendRepo = _StubAttendanceRepo(shift);
      final attendCubit = AttendanceCubit(attendRepo)..loadShiftContext();
      final dashRepo = _StubDashboardRepo(summary);
      final dashCubit = DashboardCubit(repository: dashRepo)..loadDashboard();
      final reqRepo = _StubRequestRepo(sampleRequests);
      final notifRepo = _StubNotificationRepo();
      final notifCubit = NotificationCubit(repository: notifRepo);

      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AuthRepository>.value(value: authRepo),
          RepositoryProvider<AttendanceRepository>.value(value: attendRepo),
          RepositoryProvider<DashboardRepository>.value(value: dashRepo),
          RepositoryProvider<RequestRepository>.value(value: reqRepo),
          RepositoryProvider<NotificationRepository>.value(value: notifRepo),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<AttendanceCubit>.value(value: attendCubit),
            BlocProvider<DashboardCubit>.value(value: dashCubit),
            BlocProvider<NotificationCubit>.value(value: notifCubit),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: tabNotifier != null
                ? MainTabController(tabNotifier: tabNotifier, child: child)
                : child,
          ),
        ),
      );
    }

    testWidgets(
        'HomeScreen contains executive role widgets and STRICTLY EXCLUDES operational attendance widgets',
        (tester) async {
      await tester.pumpWidget(createTestHarness(child: const HomeScreen()));
      await tester.pumpAndSettle();

      // Positive assertions: Home owns these widgets
      expect(find.byType(DashboardHeader), findsOneWidget);
      expect(find.byType(AttendanceStatusTeaserCard), findsOneWidget);
      expect(find.byType(EmployeePriorityStrip), findsOneWidget);
      expect(find.byType(EmployeeQuickActionsGrid), findsOneWidget);
      expect(find.byType(EmployeeSummaryCards), findsOneWidget);
      expect(find.byType(RecentRequestsPreview), findsOneWidget);

      // Negative assertions: Forbidden on Home (must NOT appear)
      expect(find.byType(CheckInRadarButton), findsNothing,
          reason: 'CheckInRadarButton is strictly owned by AttendanceScreen');
      expect(find.byType(MyStatusCard), findsNothing,
          reason: 'MyStatusCard is removed from Home to avoid duplication');
      expect(find.byType(MonthActivitySection), findsNothing,
          reason: 'MonthActivitySection is strictly owned by AttendanceScreen');
      expect(find.byKey(const Key('attendance_refresh_location_btn')),
          findsNothing,
          reason:
              'Location refresh is strictly operational in AttendanceScreen');
      expect(find.text('نطاق العمل:'), findsNothing,
          reason:
              'Geofence meter distance details belong exclusively to AttendanceScreen');
      expect(find.text(AppStringsAr.checkIn), findsNothing,
          reason: 'Check-in CTA must never appear on Home');
      expect(find.text(AppStringsAr.checkOut), findsNothing,
          reason: 'Check-out CTA must never appear on Home');
    });

    testWidgets(
        'AttendanceScreen contains operational workspace and STRICTLY EXCLUDES dashboard executive widgets',
        (tester) async {
      await tester
          .pumpWidget(createTestHarness(child: const AttendanceScreen()));
      await tester.pumpAndSettle();

      // Positive assertions: Attendance owns these widgets
      expect(find.byType(CheckInRadarButton), findsOneWidget);
      expect(find.text('الوردية الصباحية'), findsOneWidget);
      expect(find.text('مكتب الرياض'), findsOneWidget);
      expect(find.byKey(const Key('attendance_refresh_location_btn')),
          findsOneWidget);
      expect(find.byType(MonthActivitySection), findsOneWidget);

      // Negative assertions: Forbidden on Attendance (must NOT appear)
      expect(find.byType(DashboardHeader), findsNothing,
          reason: 'DashboardHeader is strictly owned by HomeScreen');
      expect(find.byType(AttendanceStatusTeaserCard), findsNothing,
          reason: 'AttendanceStatusTeaserCard is only on HomeScreen');
      expect(find.byType(EmployeePriorityStrip), findsNothing,
          reason: 'EmployeePriorityStrip is strictly owned by HomeScreen');
      expect(find.byType(EmployeeQuickActionsGrid), findsNothing,
          reason: 'EmployeeQuickActionsGrid is strictly owned by HomeScreen');
      expect(find.byType(EmployeeSummaryCards), findsNothing,
          reason: 'EmployeeSummaryCards is strictly owned by HomeScreen');
      expect(find.byType(TeamSummaryCard), findsNothing,
          reason: 'TeamSummaryCard is strictly owned by HomeScreen');
      expect(find.byType(RecentRequestsPreview), findsNothing,
          reason: 'RecentRequestsPreview is strictly owned by HomeScreen');
      expect(find.text('الإجراءات السريعة'), findsNothing,
          reason: 'Quick actions belong to HomeScreen');
    });

    testWidgets(
        'AttendanceStatusTeaserCard on HomeScreen navigates to Attendance tab on tap',
        (tester) async {
      final tabNotifier = ValueNotifier<int>(0);

      await tester.pumpWidget(createTestHarness(
        child: const HomeScreen(),
        tabNotifier: tabNotifier,
      ));
      await tester.pumpAndSettle();

      expect(tabNotifier.value, equals(0));

      final teaserFinder = find.byType(AttendanceStatusTeaserCard);
      expect(teaserFinder, findsOneWidget);

      await tester.tap(teaserFinder);
      await tester.pumpAndSettle();

      expect(tabNotifier.value, equals(1),
          reason:
              'Tapping attendance status teaser must switch to Attendance tab (index 1)');
    });
  });
}
