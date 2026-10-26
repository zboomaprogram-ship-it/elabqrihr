import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
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
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/dynamic_form_builder.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_catalog_screen.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/screens/password_change_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/active_sessions_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_edit_screen.dart';

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

class _ScreenshotStubNotifRepo implements NotificationRepository {
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

class _ScreenshotStubReportRepo implements ReportRepository {
  @override
  Future<WorkforceReportSummaryEntity> getWorkforceSummary({
    DateTime? from,
    DateTime? to,
    String? departmentId,
    String? workLocationId,
  }) async =>
      WorkforceReportSummaryEntity(
        from: '2026-09-01',
        to: '2026-09-27',
        activeEmployees: 10,
        suspendedEmployees: 0,
        archivedEmployees: 0,
        activeLocations: 1,
        unassignedEmployees: 0,
        generatedAt: DateTime.now(),
      );

  @override
  Future<AttendanceLeaveReportEntity> getAttendanceLeaveReport({
    DateTime? from,
    DateTime? to,
    String? cursor,
    int? limit,
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
  Future<ExportJobEntity> getExport(String exportId) async => ExportJobEntity(
        id: exportId,
        state: 'ready',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dir = Directory('test-results/screenshots');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  Future<void> saveScreenshot(WidgetTester tester, String filename) async {
    await tester.runAsync(() async {
      final boundary =
          tester.renderObject(find.byKey(const Key('capture_boundary')))
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('test-results/screenshots/$filename');
      await file.writeAsBytes(bytes);
    });
  }

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

  final stubNotifRepo = _ScreenshotStubNotifRepo();
  final stubReportRepo = _ScreenshotStubReportRepo();

  Widget createHarness({
    required Widget child,
    required AuthSessionEntity session,
    required DashboardSummary summary,
    required double textScale,
  }) {
    final authRepo = _FakeAuthRepo(session);
    final authCubit = AuthCubit(authRepo)..checkSession();
    final attendRepo = _StubAttendanceRepo(shift);
    final attendCubit = AttendanceCubit(attendRepo)..loadShiftContext();
    final dashRepo = _StubDashboardRepo(summary);
    final dashCubit = DashboardCubit(repository: dashRepo)..loadDashboard();
    final reqRepo = _StubRequestRepo(sampleRequests);
    final notifCubit = NotificationCubit(repository: stubNotifRepo);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<AttendanceRepository>.value(value: attendRepo),
        RepositoryProvider<DashboardRepository>.value(value: dashRepo),
        RepositoryProvider<RequestRepository>.value(value: reqRepo),
        RepositoryProvider<NotificationRepository>.value(value: stubNotifRepo),
        RepositoryProvider<ReportRepository>.value(value: stubReportRepo),
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
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(412, 915),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: RepaintBoundary(
                key: const Key('capture_boundary'),
                child: SizedBox(
                  width: 412,
                  height: 915,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget createProfileHarness({
    required Widget child,
    required ProfileRepository profileRepo,
    double textScale = 1.0,
  }) {
    return RepositoryProvider<ProfileRepository>.value(
      value: profileRepo,
      child: MaterialApp(
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
            size: const Size(412, 915),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: RepaintBoundary(
              key: const Key('capture_boundary'),
              child: SizedBox(
                width: 412,
                height: 915,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Capture 4-role Home and Attendance screenshots at 100% and 200%',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 1.5, 915 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final roles = [
      (UserRole.employee, 'employee', 'سارة خالد', 'مهندس برمجيات'),
      (UserRole.manager, 'manager', 'خالد الفيصل', 'مدير الفريق التقني'),
      (UserRole.hr, 'hr', 'منى العتيبي', 'مدير الموارد البشرية'),
      (UserRole.companyAdmin, 'admin', 'عبدالله السديري', 'الرئيس التنفيذي'),
    ];

    for (final (role, rolePrefix, name, _) in roles) {
      for (final scale in [1.0, 2.0]) {
        final scaleLabel = scale == 1.0 ? '100' : '200';

        final session = AuthSessionEntity(
          accessToken: 'token-$rolePrefix',
          tenantId: 'tenant-001',
          userId: 'user-$rolePrefix',
          role: role,
          email: '$rolePrefix@attend.sa',
          displayName: name,
        );

        final summary = DashboardSummary(
          profile: UserProfile(
            userId: 'user-$rolePrefix',
            tenantId: 'tenant-001',
            companyName: 'شركة العبقري',
            displayName: name,
            email: '$rolePrefix@attend.sa',
            role: role,
            branchName: 'مكتب الرياض',
            revision: 1,
          ),
          pendingRequests: 2,
          pendingApprovals: role == UserRole.manager ? 5 : 0,
          attendanceState: 'not_started',
        );

        // 1. Home Screen
        await tester.pumpWidget(createHarness(
          child: const HomeScreen(),
          session: session,
          summary: summary,
          textScale: scale,
        ));
        await tester.pumpAndSettle();
        await saveScreenshot(tester, '${rolePrefix}_home_$scaleLabel.png');

        // 2. Attendance Screen
        await tester.pumpWidget(createHarness(
          child: const AttendanceScreen(),
          session: session,
          summary: summary,
          textScale: scale,
        ));
        await tester.pumpAndSettle();
        await saveScreenshot(
            tester, '${rolePrefix}_attendance_$scaleLabel.png');
      }
    }
  });

  testWidgets(
      'Capture dynamic requests, catalog, form, and manager approval screenshots',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 1.5, 915 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Dynamic Catalog
    final fakeDynamicRepo = _FakeDynamicRepo();
    final dynamicCubit = DynamicRequestCubit(repository: fakeDynamicRepo);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const Key('capture_boundary'),
            child: SizedBox(
              width: 412,
              height: 915,
              child: Scaffold(
                appBar: AppBar(title: const Text('دليل الطلبات')),
                body: RequestCatalogScreen(cubit: dynamicCubit),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'dynamic_catalog.png');

    // 2. Dynamic Form with Attachment
    const testFields = [
      RequestFieldDefinition(
        key: 'subject',
        position: 1,
        kind: FieldKind.shortText,
        labelAr: 'موضوع الطلب',
        required: true,
      ),
      RequestFieldDefinition(
        key: 'date',
        position: 2,
        kind: FieldKind.date,
        labelAr: 'تاريخ الحدث',
        required: true,
      ),
      RequestFieldDefinition(
        key: 'document',
        position: 3,
        kind: FieldKind.attachment,
        labelAr: 'المرفق أو المستند الداعم',
        required: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const Key('capture_boundary'),
            child: SizedBox(
              width: 412,
              height: 915,
              child: Scaffold(
                appBar: AppBar(title: const Text('طلب ديناميكي جديد')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DynamicFormBuilder(
                    fields: testFields,
                    onSubmit: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'dynamic_form_with_attachment.png');

    // 3. Manager Approval Screen with Dynamic Decisions
    final inboxCubit = ManagerInboxCubit(
      repository: _StubRequestRepo([
        RequestEntity(
          id: 'req-leave-01',
          employeeId: 'emp-01',
          type: RequestType.leave,
          state: RequestState.pendingApproval,
          revision: 1,
          requestedMinutes: 480,
          submittedAt: DateTime.utc(2026, 9, 23, 9, 0),
          details: const {'leaveType': 'annual', 'reason': 'إجازة سنوية مسبقة'},
          steps: const [],
        ),
      ]),
      dynamicRepository: fakeDynamicRepo,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: const Key('capture_boundary'),
            child: SizedBox(
              width: 412,
              height: 915,
              child: MultiRepositoryProvider(
                providers: [
                  RepositoryProvider<RequestRepository>.value(
                    value: _StubRequestRepo(),
                  ),
                  RepositoryProvider<DynamicRequestRepository>.value(
                    value: fakeDynamicRepo,
                  ),
                ],
                child: BlocProvider<ManagerInboxCubit>.value(
                  value: inboxCubit..loadInbox(),
                  child: const ManagerInboxScreen(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveScreenshot(tester, 'manager_approval_dynamic.png');
  });

  testWidgets(
      'Capture profile, password change, active sessions, and dynamic selector screenshots at 100% and 200%',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 1.5, 915 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profileRepo = _StubProfileRepo();

    for (final scale in [1.0, 2.0]) {
      final scaleLabel = scale == 1.0 ? '100' : '200';

      // 1. Password Change Screen
      await tester.pumpWidget(createProfileHarness(
        child: const PasswordChangeScreen(),
        profileRepo: profileRepo,
        textScale: scale,
      ));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, 'password_change_$scaleLabel.png');

      // 2. Active Sessions Screen
      await tester.pumpWidget(createProfileHarness(
        child: const ActiveSessionsScreen(),
        profileRepo: profileRepo,
        textScale: scale,
      ));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, 'active_sessions_$scaleLabel.png');

      // 3. Profile Edit Screen
      await tester.pumpWidget(createProfileHarness(
        child: ProfileEditScreen(
          profile: profileRepo.profile,
        ),
        profileRepo: profileRepo,
        textScale: scale,
      ));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, 'profile_edit_$scaleLabel.png');

      // 4. Dynamic Form with Async Searchable Selector
      final dynamicRepo = _FakeDynamicRepo();
      const fields = [
        RequestFieldDefinition(
          key: 'branch',
          position: 1,
          kind: FieldKind.singleChoice,
          labelAr: 'الفرع المستهدف',
          required: true,
          dataSource: RequestFieldDataSource(source: 'branches'),
        ),
        RequestFieldDefinition(
          key: 'notes',
          position: 2,
          kind: FieldKind.longText,
          labelAr: 'ملاحظات إضافية',
          required: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
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
              size: const Size(412, 915),
              textScaler: TextScaler.linear(scale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: RepaintBoundary(
                key: const Key('capture_boundary'),
                child: SizedBox(
                  width: 412,
                  height: 915,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('طلب نقل عهدة')),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DynamicFormBuilder(
                        definitionVersionId: 'ver-branch-1',
                        dynamicRequestRepository: dynamicRepo,
                        fields: fields,
                        onSubmit: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await saveScreenshot(tester, 'dynamic_selector_form_$scaleLabel.png');
    }
  });
}

class _FakeDynamicRepo implements DynamicRequestRepository {
  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async {
    return [
      ...RequestTypeCategory.builtInCategories,
      const RequestTypeCategory(
        id: 'cat-eq-1',
        key: 'equipment',
        nameAr: 'طلب أجهزة ومعدات',
        descriptionAr: 'طلب حاسوب محمول أو شاشة أو مستلزمات مكتبية',
        iconKey: 'devices',
      ),
    ];
  }

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async =>
      const [];

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
    String? typeNameAr,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests({
    String? typeKey,
    String? state,
  }) async =>
      const [];

  @override
  Future<DynamicRequestEntity> getDynamicRequest(String id) async {
    return DynamicRequestEntity(
      id: id,
      typeKey: 'equipment',
      typeNameAr: 'طلب أجهزة ومعدات',
      definitionVersionId: 'ver-eq-1',
      state: 'pending_approval',
      revision: 2,
      values: const {'subject': 'طلب شاشة 4K', 'reason': 'عمل برمجي'},
      timeline: const [],
      submittedAt: DateTime.utc(2026, 9, 23, 10, 0),
    );
  }

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
  Future<List<ApprovalActivitySummary>> getApprovalActivity({
    String? cursor,
    int? limit,
  }) async {
    return [
      ApprovalActivitySummary(
        kind: RequestKind.dynamic,
        requestId: 'req-dyn-1',
        typeNameAr: 'طلب أجهزة ومعدات',
        requesterDisplayName: 'محمد الشهري',
        state: 'pending_approval',
        expectedRevision: 2,
        submittedAt: DateTime.utc(2026, 9, 23, 10, 30),
      ),
    ];
  }

  @override
  Future<List<RequestActivitySummary>> getRequestActivity({
    String? cursor,
    int? limit,
  }) async =>
      const [];

  @override
  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  }) async =>
      const [
        RequestSelectorOption(
            value: 'opt-1',
            label: 'مكتب الرياض الرئيسي',
            subtitle: 'طريق الملك فهد'),
        RequestSelectorOption(
            value: 'opt-2', label: 'فرع جدة', subtitle: 'طريق الأندلس'),
        RequestSelectorOption(
            value: 'opt-3', label: 'فرع الدمام', subtitle: 'حي الشاطئ'),
      ];
}

class _StubProfileRepo implements ProfileRepository {
  UserProfile profile;
  _StubProfileRepo({UserProfile? profile})
      : profile = profile ??
            const UserProfile(
              userId: 'user-001',
              tenantId: 'tenant-001',
              companyName: 'شركة العبقري',
              displayName: 'سارة خالد',
              email: 'sara@attend.sa',
              secondaryEmail: 'sara.personal@example.com',
              phone: '+966501234567',
              role: UserRole.employee,
              branchName: 'مكتب الرياض',
              revision: 1,
            );

  @override
  Future<UserProfile> getMyProfile() async => profile;

  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async {
    profile = profile.copyWith(
        preferences: preferences, revision: profile.revision + 1);
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) async {
    profile = profile.copyWith(
      phone: phone ?? profile.phone,
      secondaryEmail: secondaryEmail ?? profile.secondaryEmail,
      preferences: preferences ?? profile.preferences,
      revision: profile.revision + 1,
    );
    return profile;
  }

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
