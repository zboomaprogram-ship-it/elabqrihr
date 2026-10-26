// ignore_for_file: avoid_print
// Integration test: captures 4-role matrix across Navigation, Requests,
// Finance-when-authorized, Notifications, and Profile at 100% and 200% text scale
// on a real Android device (vivo V2254, Android 13) or emulator.
//
// Run with:
//   flutter test integration_test/emulator_screenshot_test.dart -d 10JE1B00ZB000E8
//
// Screenshots are saved in the app-private documents directory, which is
// writable on Android 13+ without broad storage permission. Inspect them with:
//   adb -s 10JE1B00ZB000E8 shell run-as com.zbooma.elabqrihr \
//     ls app_flutter/emulator_screenshots

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/localization/language_cubit.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_list_screen.dart';
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
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_list_screen.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/profile/presentation/screens/active_sessions_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/password_change_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/requests_home_screen.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _StubTokenStorage extends TokenStorage {
  String? _lang;
  @override
  Future<String?> getLanguage() async => _lang ?? 'ar';
  @override
  Future<void> saveLanguage(String languageCode) async {
    _lang = languageCode;
  }
}

class _StubAuthRepo implements AuthRepository {
  final AuthSessionEntity session;
  _StubAuthRepo(this.session);

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

class _StubProfileRepo implements ProfileRepository {
  final UserProfile _profile;
  _StubProfileRepo(this._profile);

  @override
  Future<UserProfile> getMyProfile() async => _profile;
  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async =>
      _profile;
  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) async =>
      _profile;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<List<AccountSession>> getActiveSessions() async => [
        AccountSession(
          id: 'sess-current',
          clientType: 'android',
          createdAt: DateTime.utc(2026, 9, 20, 10, 0),
          expiresAt: DateTime.utc(2026, 10, 20, 10, 0),
          current: true,
        ),
        AccountSession(
          id: 'sess-web',
          clientType: 'web',
          createdAt: DateTime.utc(2026, 9, 15, 8, 0),
          expiresAt: DateTime.utc(2026, 10, 15, 8, 0),
          current: false,
        ),
      ];
  @override
  Future<void> revokeSession(String sessionId) async {}
}

class _StubRequestRepo implements RequestRepository {
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
  }) async =>
      [
        RequestEntity(
          id: 'req-001',
          employeeId: 'emp-001',
          type: RequestType.leave,
          state: RequestState.approved,
          submittedAt: DateTime.utc(2026, 9, 25, 9, 0),
          revision: 2,
          requestedMinutes: 1440,
          steps: const [],
          details: const {
            'leaveType': 'annual',
            'days': 3,
            'reason': 'إجازة سنوية اعتيادية'
          },
        ),
        RequestEntity(
          id: 'req-002',
          employeeId: 'emp-001',
          type: RequestType.permission,
          state: RequestState.pendingApproval,
          submittedAt: DateTime.utc(2026, 9, 28, 11, 0),
          revision: 1,
          requestedMinutes: 120,
          steps: const [],
          details: const {'hours': 2, 'reason': 'استئذان طبي'},
        ),
        RequestEntity(
          id: 'req-dyn-001',
          employeeId: 'emp-001',
          type: RequestType.dynamic,
          state: RequestState.submitted,
          submittedAt: DateTime.utc(2026, 9, 29, 14, 0),
          revision: 1,
          requestedMinutes: 0,
          isDynamic: true,
          dynamicTypeNameAr: 'طلب تدريب خارجي',
          steps: const [],
          details: const {
            'typeNameAr': 'طلب تدريب خارجي',
            'category': 'general'
          },
        ),
      ];

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
  }) async =>
      [
        RequestEntity(
          id: 'inbox-001',
          employeeId: 'emp-202',
          employeeName: 'أحمد محمود',
          type: RequestType.leave,
          state: RequestState.pendingApproval,
          submittedAt: DateTime.utc(2026, 9, 28, 10, 0),
          revision: 1,
          requestedMinutes: 960,
          steps: const [],
          details: const {
            'leaveType': 'annual',
            'days': 2,
            'reason': 'ظرف عائلي'
          },
        ),
        RequestEntity(
          id: 'inbox-dyn-002',
          employeeId: 'emp-203',
          employeeName: 'سارة خالد',
          type: RequestType.dynamic,
          state: RequestState.submitted,
          submittedAt: DateTime.utc(2026, 9, 29, 9, 30),
          revision: 1,
          requestedMinutes: 0,
          isDynamic: true,
          dynamicTypeNameAr: 'طلب بدل سفر وانتقال',
          steps: const [],
          details: const {'typeNameAr': 'طلب بدل سفر وانتقال', 'amount': 1500},
        ),
      ];

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

class _StubNotifRepo implements NotificationRepository {
  @override
  Future<NotificationEntity?> getNotification(String notificationId) async =>
      null;

  @override
  Future<NotificationPageEntity> listNotifications({
    String? cursor,
    int limit = 50,
  }) async =>
      NotificationPageEntity(
        items: [
          NotificationEntity(
            id: 'notif-001',
            kind: 'request.decided',
            titleKey: 'notification.request.decided.title',
            bodyKey: 'notification.request.decided.body',
            readState: NotificationReadState.unread,
            createdAt: DateTime.utc(2026, 9, 28, 10, 0),
            destinationKind: NotificationDestinationKind.request,
            destinationId: 'req-001',
          ),
          NotificationEntity(
            id: 'notif-002',
            kind: 'attendance.accepted',
            titleKey: 'notification.attendance.accepted.title',
            bodyKey: 'notification.attendance.accepted.body',
            readState: NotificationReadState.read,
            createdAt: DateTime.utc(2026, 9, 27, 8, 30),
            destinationKind: NotificationDestinationKind.attendance,
            destinationId: 'att-001',
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<int> getUnreadCount() async => 1;
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

class _StubReportRepo implements ReportRepository {
  @override
  Future<WorkforceReportSummaryEntity> getWorkforceSummary({
    required DateTime from,
    required DateTime to,
  }) async =>
      WorkforceReportSummaryEntity(
        from: from.toIso8601String().split('T').first,
        to: to.toIso8601String().split('T').first,
        activeEmployees: 38,
        suspendedEmployees: 2,
        archivedEmployees: 2,
        activeLocations: 3,
        unassignedEmployees: 1,
        generatedAt: DateTime.now(),
      );

  @override
  Future<AttendanceLeaveReportEntity> getAttendanceLeaveReport({
    required DateTime from,
    required DateTime to,
    String? cursor,
    int limit = 25,
    String? state,
  }) async =>
      const AttendanceLeaveReportEntity(
        totals: AttendanceLeaveTotalsEntity(
          employees: 10,
          attendanceExceptions: 0,
          leaveMinutes: 0,
          requests: 0,
        ),
        items: [],
      );

  @override
  Future<ExportJobEntity> createExport({
    required DateTime from,
    required DateTime to,
    String? state,
  }) =>
      throw UnimplementedError();

  @override
  Future<ExportJobEntity> getExport(String exportId) async =>
      ExportJobEntity(id: exportId, state: 'ready');
}

class _StubPayslipRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips({
    String? cursor,
    int limit = 25,
  }) async =>
      PayslipPageEntity(
        items: [
          PayslipEntity(
            id: 'ps-2026-09',
            cycleKey: '2026-09',
            gross: const MoneyEntity(currency: 'SAR', amount: '15000.00'),
            deductions: const MoneyEntity(currency: 'SAR', amount: '2500.00'),
            net: const MoneyEntity(currency: 'SAR', amount: '12500.00'),
            issuedAt: DateTime.utc(2026, 9, 30),
            documentState: PayslipState.ready,
            periodStart: '2026-09-01',
            periodEnd: '2026-09-30',
            lines: const [],
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<PayslipEntity> getPayslip(String payslipId) async => PayslipEntity(
        id: payslipId,
        cycleKey: '2026-09',
        gross: const MoneyEntity(currency: 'SAR', amount: '15000.00'),
        deductions: const MoneyEntity(currency: 'SAR', amount: '2500.00'),
        net: const MoneyEntity(currency: 'SAR', amount: '12500.00'),
        issuedAt: DateTime.utc(2026, 9, 30),
        documentState: PayslipState.ready,
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        lines: const [],
      );
}

class _StubAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances({
    String? cursor,
    int limit = 25,
    String? state,
  }) async =>
      AdvancePageEntity(
        items: [
          const AdvanceEntity(
            id: 'adv-001',
            employeeId: 'emp-001',
            principal: MoneyEntity(currency: 'SAR', amount: '3000.00'),
            postedAmount: MoneyEntity(currency: 'SAR', amount: '1000.00'),
            remainingBalance: MoneyEntity(currency: 'SAR', amount: '2000.00'),
            state: AdvanceLifecycleState.approved,
            revision: 1,
          ),
        ],
        nextCursor: null,
      );
}

class _StubDynamicRequestRepo implements DynamicRequestRepository {
  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async => [];
  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async => [];
  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = true,
    String? typeNameAr,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests({
    String? typeKey,
    String? state,
  }) async =>
      [];
  @override
  Future<DynamicRequestEntity> getDynamicRequest(String id) =>
      throw UnimplementedError();
  @override
  Future<DynamicRequestEntity> cancelDynamicRequest({
    required String id,
    required int expectedRevision,
    required String reason,
  }) =>
      throw UnimplementedError();
  @override
  Future<DynamicRequestEntity> decideDynamicRequest({
    required String id,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> synchronizeOutbox() async {}
  @override
  Future<List<ApprovalActivitySummary>> getApprovalActivity({
    String? cursor,
    int? limit,
  }) async =>
      [];
  @override
  Future<List<RequestActivitySummary>> getRequestActivity({
    String? cursor,
    int? limit,
  }) async =>
      [];
  @override
  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  }) async =>
      [];
}

// ---------------------------------------------------------------------------
// Harness builder
// ---------------------------------------------------------------------------

Widget buildHarness({
  required Widget child,
  required AuthSessionEntity session,
  required DashboardSummary summary,
  required double textScale,
}) {
  final tokenStorage = _StubTokenStorage();
  final authRepo = _StubAuthRepo(session);
  final authCubit = AuthCubit(authRepo)..checkSession();

  final shift = ShiftContextEntity(
    shiftInstanceId: 'shift-emu-001',
    branchName: 'مكتب الرياض',
    shiftName: 'الوردية الصباحية',
    scheduledStart: DateTime.utc(2026, 9, 27, 8, 0),
    scheduledEnd: DateTime.utc(2026, 9, 27, 16, 0),
    branchLocation: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
    allowedRadiusMeters: 100.0,
    isCheckedIn: false,
  );

  final attendRepo = _StubAttendanceRepo(shift);
  final attendCubit = AttendanceCubit(attendRepo)..loadShiftContext();
  final dashRepo = _StubDashboardRepo(summary);
  final dashCubit = DashboardCubit(repository: dashRepo)..loadDashboard();
  final reqRepo = _StubRequestRepo();
  final dynamicRepo = _StubDynamicRequestRepo();
  final empReqCubit = EmployeeRequestsCubit(
    repository: reqRepo,
    dynamicRepository: dynamicRepo,
  )..loadRequests();
  final notifRepo = _StubNotifRepo();
  final notifCubit = NotificationCubit(repository: notifRepo)
    ..loadNotifications();
  final profileRepo = _StubProfileRepo(summary.profile);
  final profileCubit = ProfileCubit(repository: profileRepo)..loadProfile();
  final reportRepo = _StubReportRepo();
  final payslipRepo = _StubPayslipRepo();
  final payslipCubit = PayslipListCubit(repository: payslipRepo)..load();
  final advanceRepo = _StubAdvanceRepo();
  final advanceCubit = AdvanceListCubit(repository: advanceRepo)..load();
  final inboxCubit = ManagerInboxCubit(
    repository: reqRepo,
    dynamicRepository: dynamicRepo,
  )..loadInbox();
  final dynamicCubit = DynamicRequestCubit(repository: dynamicRepo);
  final languageCubit = LanguageCubit(tokenStorage: tokenStorage);

  final apiClient = ApiClient(
    baseUrl: 'https://api.attend.sa/api/v1',
    tokenStorage: tokenStorage,
  );

  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<ApiClient>.value(value: apiClient),
      RepositoryProvider<TokenStorage>.value(value: tokenStorage),
      RepositoryProvider<AuthRepository>.value(value: authRepo),
      RepositoryProvider<AttendanceRepository>.value(value: attendRepo),
      RepositoryProvider<DashboardRepository>.value(value: dashRepo),
      RepositoryProvider<RequestRepository>.value(value: reqRepo),
      RepositoryProvider<NotificationRepository>.value(value: notifRepo),
      RepositoryProvider<ReportRepository>.value(value: reportRepo),
      RepositoryProvider<ProfileRepository>.value(value: profileRepo),
      RepositoryProvider<PayslipRepository>.value(value: payslipRepo),
      RepositoryProvider<AdvanceRepository>.value(value: advanceRepo),
      RepositoryProvider<DynamicRequestRepository>.value(value: dynamicRepo),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<LanguageCubit>.value(value: languageCubit),
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<AttendanceCubit>.value(value: attendCubit),
        BlocProvider<DashboardCubit>.value(value: dashCubit),
        BlocProvider<EmployeeRequestsCubit>.value(value: empReqCubit),
        BlocProvider<NotificationCubit>.value(value: notifCubit),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
        BlocProvider<DynamicRequestCubit>.value(value: dynamicCubit),
        BlocProvider<PayslipListCubit>.value(value: payslipCubit),
        BlocProvider<AdvanceListCubit>.value(value: advanceCubit),
        BlocProvider<ManagerInboxCubit>.value(value: inboxCubit),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child,
          ),
        ),
      ),
    ),
  );
}

// Save PNG bytes from takeScreenshot to device storage
Future<void> _saveScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String filename,
) async {
  try {
    await binding.convertFlutterSurfaceToImage();
  } catch (_) {
    // Surface already converted for this session
  }
  await tester.pumpAndSettle();
  final List<int> pngBytes = await binding.takeScreenshot(filename);

  final baseDir = await getApplicationDocumentsDirectory();
  final outputDir = Directory('${baseDir.path}/emulator_screenshots');
  await outputDir.create(recursive: true);
  final file = File('${outputDir.path}/$filename');
  if (file.existsSync()) {
    await file.delete();
  }
  await file.writeAsBytes(pngBytes, flush: true);
  print(
      '[SCREENSHOT] $filename — ${pngBytes.length} bytes → ${outputDir.path}');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final roles = [
    (UserRole.employee, 'employee', 'سارة خالد'),
    (UserRole.manager, 'manager', 'خالد الفيصل'),
    (UserRole.hr, 'hr', 'منى العتيبي'),
    (UserRole.companyAdmin, 'admin', 'عبدالله السديري'),
  ];

  testWidgets(
    'vivo_v2254: 4-role full-journey matrix at 100% and 200% text scale',
    timeout: const Timeout(Duration(minutes: 15)),
    (tester) async {
      for (final (role, rolePrefix, name) in roles) {
        final policy = RoleNavigationPolicy(role);
        final session = AuthSessionEntity(
          accessToken: 'capture-token-$rolePrefix',
          tenantId: 'tenant-capture-001',
          userId: 'user-$rolePrefix',
          role: role,
          email: '$rolePrefix@attend.sa',
          displayName: name,
        );

        final profile = UserProfile(
          userId: 'user-$rolePrefix',
          tenantId: 'tenant-capture-001',
          companyName: 'شركة العبقري',
          displayName: name,
          email: '$rolePrefix@attend.sa',
          role: role,
          branchName: 'مكتب الرياض',
          revision: 1,
        );

        final summary = DashboardSummary(
          profile: profile,
          pendingRequests: 2,
          pendingApprovals: role == UserRole.manager ? 5 : 0,
          attendanceState: 'not_started',
        );

        for (final scale in [1.0, 2.0]) {
          final scaleLabel = scale == 1.0 ? '100' : '200';

          // 1. Home Destination
          await tester.pumpWidget(buildHarness(
            child: const HomeScreen(),
            session: session,
            summary: summary,
            textScale: scale,
          ));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          await _saveScreenshot(
              binding, tester, 'vivo_${rolePrefix}_home_$scaleLabel.png');

          // 2. Attendance Destination
          await tester.pumpWidget(buildHarness(
            child: const AttendanceScreen(),
            session: session,
            summary: summary,
            textScale: scale,
          ));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          await _saveScreenshot(
              binding, tester, 'vivo_${rolePrefix}_attendance_$scaleLabel.png');

          // 3. Requests Destination
          await tester.pumpWidget(buildHarness(
            child: RequestsHomeScreen(userRole: role),
            session: session,
            summary: summary,
            textScale: scale,
          ));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          await _saveScreenshot(
              binding, tester, 'vivo_${rolePrefix}_requests_$scaleLabel.png');

          // 4. Reviewer Inbox (for Manager)
          if (policy.canAccessReviewerInbox && role == UserRole.manager) {
            await tester.pumpWidget(buildHarness(
              child: const ManagerInboxScreen(),
              session: session,
              summary: summary,
              textScale: scale,
            ));
            await tester.pumpAndSettle(const Duration(milliseconds: 500));
            await _saveScreenshot(
                binding, tester, 'vivo_${rolePrefix}_inbox_$scaleLabel.png');
          }

          // 5. Finance Destinations when authorized
          if (policy.canViewPayslips) {
            await tester.pumpWidget(buildHarness(
              child: const PayslipListScreen(),
              session: session,
              summary: summary,
              textScale: scale,
            ));
            await tester.pumpAndSettle(const Duration(milliseconds: 500));
            await _saveScreenshot(
                binding, tester, 'vivo_${rolePrefix}_payslips_$scaleLabel.png');
          }

          if (policy.canRequestAdvance) {
            await tester.pumpWidget(buildHarness(
              child: const AdvanceListScreen(),
              session: session,
              summary: summary,
              textScale: scale,
            ));
            await tester.pumpAndSettle(const Duration(milliseconds: 500));
            await _saveScreenshot(
                binding, tester, 'vivo_${rolePrefix}_advances_$scaleLabel.png');
          }

          // 6. Notifications Destination
          await tester.pumpWidget(buildHarness(
            child: const NotificationCenterScreen(),
            session: session,
            summary: summary,
            textScale: scale,
          ));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          await _saveScreenshot(binding, tester,
              'vivo_${rolePrefix}_notifications_$scaleLabel.png');

          // 7. Profile Destination (includes Language preference tile and role-gated sections)
          await tester.pumpWidget(buildHarness(
            child: const ProfileScreen(),
            session: session,
            summary: summary,
            textScale: scale,
          ));
          await tester.pumpAndSettle(const Duration(milliseconds: 500));
          await _saveScreenshot(
              binding, tester, 'vivo_${rolePrefix}_profile_$scaleLabel.png');
        }
      }

      // --- Security & Profile Detail Journeys at 100% and 200% ---
      final defaultSession = AuthSessionEntity(
        accessToken: 'capture-token-profile',
        tenantId: 'tenant-capture-001',
        userId: 'user-profile',
        role: UserRole.employee,
        email: 'employee@attend.sa',
        displayName: 'سارة خالد',
      );
      final defaultProfile = UserProfile(
        userId: 'user-profile',
        tenantId: 'tenant-capture-001',
        companyName: 'شركة العبقري',
        displayName: 'سارة خالد',
        email: 'employee@attend.sa',
        role: UserRole.employee,
        branchName: 'مكتب الرياض',
        revision: 1,
      );
      final defaultSummary = DashboardSummary(
        profile: defaultProfile,
        pendingRequests: 0,
        pendingApprovals: 0,
        attendanceState: 'not_started',
      );

      for (final scale in [1.0, 2.0]) {
        final scaleLabel = scale == 1.0 ? '100' : '200';

        await tester.pumpWidget(buildHarness(
          child: const PasswordChangeScreen(),
          session: defaultSession,
          summary: defaultSummary,
          textScale: scale,
        ));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        await _saveScreenshot(
            binding, tester, 'vivo_password_change_$scaleLabel.png');

        await tester.pumpWidget(buildHarness(
          child: const ActiveSessionsScreen(),
          session: defaultSession,
          summary: defaultSummary,
          textScale: scale,
        ));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        await _saveScreenshot(
            binding, tester, 'vivo_active_sessions_$scaleLabel.png');

        await tester.pumpWidget(buildHarness(
          child: ProfileEditScreen(profile: defaultProfile),
          session: defaultSession,
          summary: defaultSummary,
          textScale: scale,
        ));
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
        await _saveScreenshot(
            binding, tester, 'vivo_profile_edit_$scaleLabel.png');
      }
    },
  );
}
