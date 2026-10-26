// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/dynamic_form_builder.dart';
import 'package:attend_mobile/features/requests/presentation/screens/manager_inbox_screen.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/requests_home_screen.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_list_screen.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_detail_screen.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_list_screen.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/financial_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/screens/financial_request_screen.dart';

class _CaptureAuthRepo implements AuthRepository {
  AuthSessionEntity session;
  _CaptureAuthRepo(this.session);

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

class _CaptureAttendanceRepo implements AttendanceRepository {
  final ShiftContextEntity shiftContext;
  _CaptureAttendanceRepo(this.shiftContext);

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

class _CaptureDashboardRepo implements DashboardRepository {
  DashboardSummary summary;
  _CaptureDashboardRepo(this.summary);

  @override
  Future<DashboardSummary> getDashboardSummary() async => summary;
}

class _CaptureProfileRepo implements ProfileRepository {
  UserProfile profile;
  _CaptureProfileRepo(this.profile);

  @override
  Future<UserProfile> getMyProfile() async => profile;
  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async =>
      profile;
  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) async =>
      profile;
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<List<AccountSession>> getActiveSessions() async => [];
  @override
  Future<void> revokeSession(String sessionId) async {}
}

class _CaptureRequestRepo implements RequestRepository {
  final List<RequestEntity> requests;
  _CaptureRequestRepo([this.requests = const []]);

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
  Future<RequestEntity> getRequestDetail(String requestId) async =>
      requests.firstWhere((r) => r.id == requestId,
          orElse: () => requests.isNotEmpty
              ? requests.first
              : throw StateError('No request'));

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
      requests;
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

class _CaptureDynamicRepo implements DynamicRequestRepository {
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
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async {
    return [
      const RequestTypeCategory(
        id: 'ver-fin-1',
        key: 'financial_expense_claim',
        nameAr: 'طلب صرف مستحقات مالية',
        descriptionAr: 'طلب استرداد مصاريف عمل أو فواتير رسمية معتمدة',
        iconKey: 'receipt_long',
        offlineEligible: false,
        fields: [
          RequestFieldDefinition(
            key: 'expense_title',
            position: 1,
            kind: FieldKind.shortText,
            labelAr: 'بيان المصروف المالي',
            required: true,
          ),
          RequestFieldDefinition(
            key: 'expense_amount',
            position: 2,
            kind: FieldKind.decimal,
            labelAr: 'المبلغ المطلوب (SDG)',
            required: true,
          ),
          RequestFieldDefinition(
            key: 'expense_date',
            position: 3,
            kind: FieldKind.date,
            labelAr: 'تاريخ الفاتورة / الصرف',
            required: true,
          ),
          RequestFieldDefinition(
            key: 'receipt_attachment',
            position: 4,
            kind: FieldKind.attachment,
            labelAr: 'مستند الصرف الخاص',
            required: true,
          ),
          RequestFieldDefinition(
            key: 'notes',
            position: 5,
            kind: FieldKind.longText,
            labelAr: 'ملاحظات إضافية',
            required: false,
          ),
        ],
      ),
    ];
  }

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
    String? typeNameAr,
  }) async {
    return DynamicRequestEntity(
      id: 'req-fin-001',
      typeKey: typeKey,
      typeNameAr: 'طلب صرف مستحقات مالية',
      definitionVersionId: definitionVersionId,
      state: 'submitted',
      revision: 1,
      values: values,
      timeline: const [],
      submittedAt: DateTime.now().toUtc(),
    );
  }

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
      const [];
}

class _CaptureNotifRepo implements NotificationRepository {
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

class _CaptureReportRepo implements ReportRepository {
  @override
  Future<WorkforceReportSummaryEntity> getWorkforceSummary({
    required DateTime from,
    required DateTime to,
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
    required DateTime from,
    required DateTime to,
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

class _CapturePayslipRepo implements PayslipRepository {
  static MoneyDto _m(String a) => MoneyDto(currency: 'SDG', amount: a);

  @override
  Future<PayslipPageEntity> listMyPayslips(
          {String? cursor, int limit = 25}) async =>
      PayslipPageEntity(
        items: [
          PayslipSummaryEntity.fromDto(PayslipSummaryDto(
            id: 'ps-1',
            cycleKey: '2026-09',
            gross: _m('5000.00'),
            deductions: _m('500.00'),
            net: _m('4500.00'),
            issuedAt: DateTime(2026, 9, 1),
            documentState: PayslipDocumentState.ready,
          )),
          PayslipSummaryEntity.fromDto(PayslipSummaryDto(
            id: 'ps-2',
            cycleKey: '2026-08',
            gross: _m('4800.00'),
            deductions: _m('480.00'),
            net: _m('4320.00'),
            issuedAt: DateTime(2026, 8, 1),
            documentState: PayslipDocumentState.queued,
          )),
        ],
        nextCursor: null,
      );

  @override
  Future<PayslipEntity> getPayslip(String id) async {
    final lines = [
      PayrollLineDto(
        id: 'line-1',
        kind: PayrollLineKind.earning,
        code: 'الراتب الأساسي (Basic)',
        amount: _m('5000.00'),
        sourceType: 'compensation',
        sourceId: 'comp-1',
      ),
      PayrollLineDto(
        id: 'line-2',
        kind: PayrollLineKind.deduction,
        code: 'التأمينات الاجتماعية (GOSI)',
        amount: _m('500.00'),
        sourceType: 'statutory',
        sourceId: 'stat-1',
      ),
    ];
    return PayslipEntity.fromDto(PayslipDto(
      id: id,
      cycleKey: '2026-09',
      gross: _m('5000.00'),
      deductions: _m('500.00'),
      net: _m('4500.00'),
      issuedAt: DateTime(2026, 9, 1),
      documentState: PayslipDocumentState.ready,
      employeeId: 'emp-talkback-001',
      periodStart: '2026-09-26',
      periodEnd: '2026-10-25',
      lines: lines,
      downloadUrl: 'https://storage.example.com/payslips/$id.pdf',
      downloadExpiresAt: DateTime(2026, 10, 1),
    ));
  }
}

class _CaptureAdvanceRepo implements AdvanceRepository {
  static MoneyDto _m(String a) => MoneyDto(currency: 'SDG', amount: a);

  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      AdvancePageEntity(
        items: [
          AdvanceEntity.fromDto(AdvanceDto(
            id: 'adv-1',
            employeeId: 'emp-talkback-001',
            principal: _m('10000.00'),
            postedAmount: _m('2500.00'),
            remainingBalance: _m('7500.00'),
            state: AdvanceState.collecting,
            revision: 1,
          )),
          AdvanceEntity.fromDto(AdvanceDto(
            id: 'adv-2',
            employeeId: 'emp-talkback-001',
            principal: _m('5000.00'),
            postedAmount: _m('0.00'),
            remainingBalance: _m('5000.00'),
            state: AdvanceState.approved,
            revision: 1,
          )),
        ],
        nextCursor: null,
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExperienceCaptureApp());
}

class ExperienceCaptureApp extends StatefulWidget {
  const ExperienceCaptureApp({super.key});

  @override
  State<ExperienceCaptureApp> createState() => ExperienceCaptureAppState();
}

class ExperienceCaptureAppState extends State<ExperienceCaptureApp> {
  static ExperienceCaptureAppState? instance;

  String _screen = 'employee_home';
  double _scale = 1.0;
  HttpServer? _server;

  final ShiftContextEntity _shift = ShiftContextEntity(
    shiftInstanceId: 'shift-100',
    branchName: 'مكتب الرياض',
    shiftName: 'الوردية الصباحية',
    scheduledStart: DateTime.utc(2026, 9, 23, 8, 0),
    scheduledEnd: DateTime.utc(2026, 9, 23, 16, 0),
    branchLocation: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
    allowedRadiusMeters: 100.0,
    isCheckedIn: false,
  );

  final List<RequestEntity> _sampleRequests = [
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
  ];

  late final _CaptureDynamicRepo _dynRepo;
  late final _CaptureNotifRepo _notifRepo;
  late final _CaptureReportRepo _reportRepo;
  late final _CapturePayslipRepo _payslipRepo;
  late final _CaptureAdvanceRepo _advanceRepo;

  @override
  void initState() {
    super.initState();
    instance = this;
    _dynRepo = _CaptureDynamicRepo();
    _notifRepo = _CaptureNotifRepo();
    _reportRepo = _CaptureReportRepo();
    _payslipRepo = _CapturePayslipRepo();
    _advanceRepo = _CaptureAdvanceRepo();
    _startHttpServer();
  }

  Future<void> _startHttpServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8889);
      print('[EXPERIENCE_CAPTURE_APP] Listening on http://0.0.0.0:8889');

      _server!.listen((HttpRequest req) async {
        req.response.headers.contentType = ContentType.json;

        if (req.method == 'GET' && req.uri.path == '/status') {
          req.response.write(jsonEncode({
            'ready': true,
            'screen': _screen,
            'scale': _scale,
          }));
          await req.response.close();
          return;
        }

        if (req.method == 'POST' && req.uri.path == '/view') {
          final bodyStr = await utf8.decodeStream(req);
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;
          final newScreen = body['screen'] as String? ?? _screen;
          final newScale = (body['scale'] as num?)?.toDouble() ?? _scale;

          setState(() {
            _screen = newScreen;
            _scale = newScale;
          });

          // Wait a frame for widget build
          await Future.delayed(const Duration(milliseconds: 100));

          req.response.write(jsonEncode({
            'status': 'ok',
            'screen': _screen,
            'scale': _scale,
          }));
          await req.response.close();
          return;
        }

        req.response.statusCode = HttpStatus.notFound;
        req.response.write(jsonEncode({'error': 'Not found'}));
        await req.response.close();
      });
    } catch (e) {
      print('[EXPERIENCE_CAPTURE_APP] Error starting HTTP server: $e');
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  (UserRole, String, String, String) _getRoleConfig(String screenKey) {
    if (screenKey.startsWith('manager_')) {
      return (UserRole.manager, 'manager', 'خالد الفيصل', 'مدير الفريق التقني');
    } else if (screenKey.startsWith('hr_')) {
      return (UserRole.hr, 'hr', 'منى العتيبي', 'مدير الموارد البشرية');
    } else if (screenKey.startsWith('admin_')) {
      return (
        UserRole.companyAdmin,
        'admin',
        'عبدالله السديري',
        'الرئيس التنفيذي'
      );
    }
    return (UserRole.employee, 'employee', 'سارة خالد', 'مهندس برمجيات');
  }

  Widget _buildContent() {
    final (role, rolePrefix, name, _) = _getRoleConfig(_screen);

    final session = AuthSessionEntity(
      accessToken: 'token-$rolePrefix',
      tenantId: 'tenant-001',
      userId: 'user-$rolePrefix',
      role: role,
      email: '$rolePrefix@attend.sa',
      displayName: name,
    );

    final profile = UserProfile(
      userId: 'user-$rolePrefix',
      tenantId: 'tenant-001',
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

    final authRepo = _CaptureAuthRepo(session);
    final authCubit = AuthCubit(authRepo)..checkSession();
    final attendRepo = _CaptureAttendanceRepo(_shift);
    final attendCubit = AttendanceCubit(attendRepo)..loadShiftContext();
    final dashRepo = _CaptureDashboardRepo(summary);
    final dashCubit = DashboardCubit(repository: dashRepo)..loadDashboard();
    final profileRepo = _CaptureProfileRepo(profile);
    final profileCubit = ProfileCubit(repository: profileRepo)..loadProfile();
    final reqRepo = _CaptureRequestRepo(_sampleRequests);
    final notifCubit = NotificationCubit(repository: _notifRepo);
    final dynamicCubit = DynamicRequestCubit(repository: _dynRepo);

    Widget screenWidget;
    switch (_screen) {
      case 'employee_home':
      case 'manager_home':
      case 'hr_home':
      case 'admin_home':
        screenWidget = const HomeScreen();
        break;
      case 'employee_attendance':
      case 'manager_attendance':
      case 'hr_attendance':
      case 'admin_attendance':
        screenWidget = const AttendanceScreen();
        break;
      case 'dynamic_form':
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
        screenWidget = Scaffold(
          appBar: AppBar(title: const Text('طلب ديناميكي جديد')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DynamicFormBuilder(
              fields: testFields,
              onSubmit: (_) {},
            ),
          ),
        );
        break;
      case 'dynamic_history':
        screenWidget = const RequestsHomeScreen(userRole: UserRole.employee);
        break;
      case 'assigned_approval':
        final inboxCubit = ManagerInboxCubit(
          repository: reqRepo,
          dynamicRepository: _dynRepo,
        )..loadInbox();
        screenWidget = BlocProvider<ManagerInboxCubit>.value(
          value: inboxCubit,
          child: const ManagerInboxScreen(),
        );
        break;
      case 'payslip_list':
        final listCubit = PayslipListCubit(repository: _payslipRepo)..load();
        screenWidget = BlocProvider<PayslipListCubit>.value(
          value: listCubit,
          child: const PayslipListScreen(),
        );
        break;
      case 'payslip_detail':
        final detailCubit = PayslipDetailCubit(repository: _payslipRepo)
          ..load('ps-1');
        screenWidget = BlocProvider<PayslipDetailCubit>.value(
          value: detailCubit,
          child: const PayslipDetailScreen(payslipId: 'ps-1'),
        );
        break;
      case 'advance_list':
        final advCubit = AdvanceListCubit(repository: _advanceRepo)..load();
        screenWidget = BlocProvider<AdvanceListCubit>.value(
          value: advCubit,
          child: const AdvanceListScreen(),
        );
        break;
      case 'financial_request':
        final finCubit = FinancialRequestCubit(repository: _dynRepo)
          ..loadCatalog();
        screenWidget = BlocProvider<FinancialRequestCubit>.value(
          value: finCubit,
          child: const FinancialRequestScreen(),
        );
        break;
      default:
        screenWidget = const HomeScreen();
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<AttendanceRepository>.value(value: attendRepo),
        RepositoryProvider<DashboardRepository>.value(value: dashRepo),
        RepositoryProvider<ProfileRepository>.value(value: profileRepo),
        RepositoryProvider<RequestRepository>.value(value: reqRepo),
        RepositoryProvider<DynamicRequestRepository>.value(value: _dynRepo),
        RepositoryProvider<NotificationRepository>.value(value: _notifRepo),
        RepositoryProvider<ReportRepository>.value(value: _reportRepo),
        RepositoryProvider<PayslipRepository>.value(value: _payslipRepo),
        RepositoryProvider<AdvanceRepository>.value(value: _advanceRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<AttendanceCubit>.value(value: attendCubit),
          BlocProvider<DashboardCubit>.value(value: dashCubit),
          BlocProvider<ProfileCubit>.value(value: profileCubit),
          BlocProvider<NotificationCubit>.value(value: notifCubit),
          BlocProvider<DynamicRequestCubit>.value(value: dynamicCubit),
        ],
        child: screenWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_scale),
          ),
          child: _buildContent(),
        ),
      ),
    );
  }
}
