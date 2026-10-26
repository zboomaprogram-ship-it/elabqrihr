import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_screen.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/emergency_attendance_dialog.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/hr_attendance_controls_card.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/reconciliation_queue_sheet.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

class _FakeManualAttendanceRepo implements ManualAttendanceRepository {
  List<ManualAttendanceEmployeeOption> employees = [
    const ManualAttendanceEmployeeOption(
      id: 'emp-101',
      displayName: 'طارق عبد الله',
      employeeNumber: 'EMP-101',
    ),
    const ManualAttendanceEmployeeOption(
      id: 'emp-102',
      displayName: 'منى إبراهيم',
      employeeNumber: 'EMP-102',
    ),
  ];

  List<DetailedReconciliationItem> items = [
    DetailedReconciliationItem(
      id: 'rec-101',
      employeeId: 'emp-101',
      shiftInstanceId: 'shift-101',
      causeType: 'absence_scan',
      state: 'conflicted',
      attempts: 2,
      reasonCode: 'CHECK_OUT_MISSING',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
      employeeName: 'طارق عبد الله',
      businessDate: '2026-10-17',
    ),
    DetailedReconciliationItem(
      id: 'rec-late-102',
      employeeId: 'emp-102',
      shiftInstanceId: 'shift-102',
      causeType: 'late_arrival',
      state: 'queued',
      attempts: 1,
      reasonCode: 'LATE_ARRIVAL_REVIEW_REQUIRED',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
      employeeName: 'منى إبراهيم',
      businessDate: '2026-10-17',
      lateMinutes: 45,
      suggestedDeduction: const SuggestedDeduction(
        mode: AdministrativeAdjustmentMode.customHours,
        units: '0.75',
        requiresApproval: true,
      ),
    ),
  ];

  List<OpenPayrollCycle> cycles = [
    const OpenPayrollCycle(
      id: 'cycle-101',
      cycleKey: '2026-10',
      state: 'draft',
      revision: 1,
      periodStart: '2026-10-01',
      periodEnd: '2026-10-31',
    ),
  ];

  ManualAttendanceActionRequest? lastManualRequest;
  AdministrativeAdjustmentRequest? lastAdjustmentRequest;

  @override
  Future<List<ManualAttendanceEmployeeOption>> getEmployees(
          {String? search}) async =>
      employees;

  @override
  Future<ManualAttendanceActionResult> submitManualAttendance(
    ManualAttendanceActionRequest request,
  ) async {
    lastManualRequest = request;
    return ManualAttendanceActionResult(
      id: 'res-101',
      employeeId: request.employeeId,
      businessDate: request.businessDate,
      action: request.action,
      effectiveState: 'completed',
      reason: request.reason,
      source: 'hr_manual_override',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<DetailedReconciliationItem>> getReconciliationItems(
          {String? state}) async =>
      items;

  @override
  Future<List<OpenPayrollCycle>> getOpenPayrollCycles() async => cycles;

  @override
  Future<AdministrativeAdjustmentPreview> previewAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    return const AdministrativeAdjustmentPreview(
      amount: MoneyAmount(currency: 'SDG', amount: '50.00'),
      units: '0.5',
    );
  }

  @override
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    lastAdjustmentRequest = request;
    return AdministrativeAdjustmentResult(
      id: 'adj-101',
      employeeId: request.employeeId,
      businessDate: request.businessDate,
      kind: 'deduction',
      mode: request.mode,
      amount: const MoneyAmount(currency: 'SDG', amount: '50.00'),
      state: 'applied',
      createdAt: DateTime.now(),
    );
  }
}

class _StubAttendanceRepo implements AttendanceRepository {
  final ShiftContextEntity stubContext;
  _StubAttendanceRepo(this.stubContext);

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async => stubContext;

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async =>
      throw UnimplementedError();

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);

  @override
  Future<void> synchronizeOutbox() async {}
}

class _StubRequestRepo implements RequestRepository {
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
  Future<RequestEntity> cancelRequest({
    required String requestId,
    required int expectedRevision,
    required String reason,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => const [];
  @override
  Stream<List<RequestEntity>> watchPendingRequests() => Stream.value(const []);
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

Widget _buildTestApp({
  required Widget child,
  required ManualAttendanceRepository manualRepo,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: RepositoryProvider<ManualAttendanceRepository>.value(
        value: manualRepo,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
}

void main() {
  late _FakeManualAttendanceRepo fakeRepo;

  setUp(() {
    fakeRepo = _FakeManualAttendanceRepo();
  });

  group('HR Sovereign Controls UI (Feature 015)', () {
    testWidgets('renders HrAttendanceControlsCard in Arabic RTL',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: const HrAttendanceControlsCard(),
        manualRepo: fakeRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('التحكم الإداري السيادي'), findsOneWidget);
      expect(find.text('تسجيل حضور طارئ'), findsOneWidget);
      expect(find.text('تسوية الاستثناءات'), findsOneWidget);
    });

    testWidgets(
        'EmergencyAttendanceDialog: employee search, date selection, validation, and submission at 100% scale',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => EmergencyAttendanceDialog.show(context),
            child: const Text('Open'),
          ),
        ),
        manualRepo: fakeRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل حضور طارئ'), findsOneWidget);
      expect(find.byKey(const Key('manual_attendance_search_field')),
          findsOneWidget);

      // Verify filtered employees
      await tester.enterText(
          find.byKey(const Key('manual_attendance_search_field')), 'منى');
      await tester.pumpAndSettle();
      expect(find.text('منى إبراهيم'), findsOneWidget);

      await tester.tap(find.byKey(const Key('emp_option_emp-102')));
      await tester.pumpAndSettle();

      // Enter Arabic reason
      await tester.enterText(
        find.byKey(const Key('manual_attendance_reason_field')),
        'عطل في قارئ البصمة عند المدخل',
      );
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.byKey(const Key('manual_attendance_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitBtn).enabled, isTrue);

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.lastManualRequest?.employeeId, 'emp-102');
      expect(
          fakeRepo.lastManualRequest?.reason, 'عطل في قارئ البصمة عند المدخل');
    });

    testWidgets(
        'EmergencyAttendanceDialog: renders properly at 200% text scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => EmergencyAttendanceDialog.show(context),
            child: const Text('Open'),
          ),
        ),
        manualRepo: fakeRepo,
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل حضور طارئ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ReconciliationQueueSheet & Decision Dialog: lists exceptions, previews, and confirms',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ReconciliationQueueSheet.show(context),
            child: const Text('Open Sheet'),
          ),
        ),
        manualRepo: fakeRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('تسوية استثناءات الحضور'), findsOneWidget);
      expect(find.text('طارق عبد الله'), findsOneWidget);

      // Tap reconcile button
      await tester.tap(find.byKey(const Key('reconcile_item_btn_rec-101')));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('معالجة استثناء طارق عبد الله'), findsOneWidget);

      // Select mode: day fraction
      await tester.tap(find.byKey(const Key('decision_mode_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جزء من يوم').last);
      await tester.pumpAndSettle();

      // Enter reason
      await tester.enterText(
        find.byKey(const Key('decision_reason_field')),
        'تأخير غير مبرر عن الحضور',
      );
      await tester.pumpAndSettle();

      // Preview calculation
      await tester.tap(find.byKey(const Key('decision_preview_btn')));
      await tester.pumpAndSettle();

      expect(find.text('50.00 SDG'), findsOneWidget);

      // Confirm decision
      await tester.tap(find.byKey(const Key('decision_submit_btn')));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdjustmentRequest?.mode,
          AdministrativeAdjustmentMode.dayFraction);
      expect(fakeRepo.lastAdjustmentRequest?.targetCycleId, 'cycle-101');
    });

    testWidgets(
        'ReconciliationQueueSheet renders late-arrival proposal with non-deducted indicator and suggested hours',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ReconciliationQueueSheet.show(context),
            child: const Text('Open Sheet'),
          ),
        ),
        manualRepo: fakeRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('منى إبراهيم'), findsOneWidget);
      expect(find.textContaining('لم يُخصم شيء بعد'), findsOneWidget);
      expect(find.text('مقترح: 0.75 س'), findsOneWidget);

      // Tap 'معالجة المقترح'
      final reconcileBtn =
          find.byKey(const Key('reconcile_item_btn_rec-late-102'));
      await tester.tap(reconcileBtn);
      await tester.pumpAndSettle();

      expect(
          find.textContaining('اقتراح تأخير آلي (45 دقيقة)'), findsOneWidget);
      expect(find.textContaining('الساعات المقترحة: 0.75 س'), findsOneWidget);
      expect(find.text('اعتماد الخصم'), findsOneWidget);

      // Verify server calculation preview
      final previewBtn = find.byKey(const Key('decision_preview_btn'));
      await tester.ensureVisible(previewBtn);
      await tester.pumpAndSettle();
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.text('50.00 SDG'), findsOneWidget);

      // Switch to waived
      await tester.tap(find.byKey(const Key('decision_mode_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعفاء كامل').last);
      await tester.pumpAndSettle();

      expect(find.text('إعفاء التأخير'), findsOneWidget);

      // Confirm waiver
      final submitBtn = find.byKey(const Key('decision_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdjustmentRequest?.mode,
          AdministrativeAdjustmentMode.waived);
      expect(fakeRepo.lastAdjustmentRequest?.reasonCode,
          'ATTENDANCE_PENALTY_WAIVED');
    });

    testWidgets(
        'AttendanceScreen: displays HrAttendanceControlsCard for companyAdmin and hr roles',
        (tester) async {
      final shift = ShiftContextEntity(
        shiftInstanceId: 'shift-100',
        branchName: 'الفرع الرئيسي',
        shiftName: 'الوردية الصباحية',
        scheduledStart: DateTime.utc(2026, 10, 17, 8, 0),
        scheduledEnd: DateTime.utc(2026, 10, 17, 16, 0),
        branchLocation: const GeoPoint(latitude: 30.0, longitude: 31.0),
        allowedRadiusMeters: 200,
        isCheckedIn: false,
      );

      final attendRepo = _StubAttendanceRepo(shift);
      final attendCubit = AttendanceCubit(attendRepo);

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
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AttendanceRepository>.value(value: attendRepo),
              RepositoryProvider<ManualAttendanceRepository>.value(
                  value: fakeRepo),
              RepositoryProvider<RequestRepository>.value(
                  value: _StubRequestRepo()),
              RepositoryProvider<NotificationRepository>.value(
                  value: _StubNotificationRepo()),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AttendanceCubit>.value(value: attendCubit),
                BlocProvider<NotificationCubit>(
                  create: (_) =>
                      NotificationCubit(repository: _StubNotificationRepo()),
                ),
              ],
              child: const AttendanceScreen(userRole: UserRole.companyAdmin),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Renders the HR sovereign quick actions controls
      expect(find.byType(HrAttendanceControlsCard), findsOneWidget);
      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
    });
  });
}
