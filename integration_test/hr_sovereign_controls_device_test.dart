// ignore_for_file: avoid_print
// Physical device acceptance test for Feature 015 HR Sovereign Controls (T016).
// Exercises Arabic RTL flows on connected Android device at 100% and 200% text scale.
// Run with: flutter test integration_test/hr_sovereign_controls_device_test.dart -d 10JE1B00ZB000E8

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

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

class _DeviceManualAttendanceRepo implements ManualAttendanceRepository {
  List<ManualAttendanceEmployeeOption> employees = [
    const ManualAttendanceEmployeeOption(
      id: 'emp-v2254-001',
      displayName: 'محمد أحمد المصطفى',
      employeeNumber: 'EMP-001',
    ),
    const ManualAttendanceEmployeeOption(
      id: 'emp-v2254-002',
      displayName: 'سارة عبد الرحمن',
      employeeNumber: 'EMP-002',
    ),
  ];

  List<DetailedReconciliationItem> items = [
    DetailedReconciliationItem(
      id: 'rec-device-01',
      employeeId: 'emp-v2254-001',
      shiftInstanceId: 'shift-dev-01',
      causeType: 'absence_scan',
      state: 'conflicted',
      attempts: 2,
      reasonCode: 'CHECK_OUT_MISSING',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
      employeeName: 'محمد أحمد المصطفى',
      businessDate: '2026-10-17',
    ),
    DetailedReconciliationItem(
      id: 'rec-late-dev-02',
      employeeId: 'emp-v2254-002',
      shiftInstanceId: 'shift-dev-02',
      causeType: 'late_arrival',
      state: 'queued',
      attempts: 1,
      reasonCode: 'LATE_ARRIVAL_REVIEW_REQUIRED',
      createdAt: DateTime.utc(2026, 10, 17, 10, 0),
      employeeName: 'سارة عبد الرحمن',
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
      id: 'cycle-device-01',
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
      id: 'res-device-01',
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
      amount: MoneyAmount(currency: 'SDG', amount: '25.00'),
      units: '0.25',
    );
  }

  @override
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    lastAdjustmentRequest = request;
    return AdministrativeAdjustmentResult(
      id: 'adj-device-01',
      employeeId: request.employeeId,
      businessDate: request.businessDate,
      kind: 'deduction',
      mode: request.mode,
      amount: const MoneyAmount(currency: 'SDG', amount: '25.00'),
      state: 'applied',
      createdAt: DateTime.now(),
    );
  }
}

class _DeviceAttendanceRepo implements AttendanceRepository {
  final ShiftContextEntity stubContext;
  _DeviceAttendanceRepo(this.stubContext);

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
  Future<RequestEntity> cancelRequest(
          {required String requestId,
          required int expectedRevision,
          required String reason}) =>
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
          NotificationDestinationKind kind, String destinationId) async =>
      ReauthorizationResult.authorized;
}

Widget _buildDeviceHarness({
  required Widget child,
  required ManualAttendanceRepository manualRepo,
  double textScale = 1.0,
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
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _DeviceManualAttendanceRepo manualRepo;

  setUp(() {
    manualRepo = _DeviceManualAttendanceRepo();
  });

  group('Feature 015 Physical Device Verification (Android 13)', () {
    testWidgets(
        '1. Verifies HR Sovereign Emergency Attendance workflow in Arabic RTL at 100% scale',
        (tester) async {
      await tester.pumpWidget(_buildDeviceHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_emergency_btn'),
            onPressed: () => EmergencyAttendanceDialog.show(context),
            child: const Text('تسجيل حضور طارئ'),
          ),
        ),
        manualRepo: manualRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_emergency_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(EmergencyAttendanceDialog), findsOneWidget);

      // Select employee
      await tester.enterText(
        find.byKey(const Key('manual_attendance_search_field')),
        'محمد',
      );
      await tester.pumpAndSettle();
      expect(find.text('محمد أحمد المصطفى'), findsOneWidget);

      await tester.tap(find.byKey(const Key('emp_option_emp-v2254-001')));
      await tester.pumpAndSettle();

      // Enter valid reason
      await tester.enterText(
        find.byKey(const Key('manual_attendance_reason_field')),
        'مأمورية عمل خارجية موثقة من الإدارة',
      );
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.byKey(const Key('manual_attendance_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();

      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(manualRepo.lastManualRequest?.employeeId, 'emp-v2254-001');
      expect(manualRepo.lastManualRequest?.reason,
          'مأمورية عمل خارجية موثقة من الإدارة');
      print(
          'Device verification: Emergency attendance successfully submitted and verified.');
    });

    testWidgets(
        '2. Verifies Emergency Attendance dialog at 200% font scale without RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(_buildDeviceHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_emergency_200_btn'),
            onPressed: () => EmergencyAttendanceDialog.show(context),
            child: const Text('حضور 200%'),
          ),
        ),
        manualRepo: manualRepo,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_emergency_200_btn')));
      await tester.pumpAndSettle();

      expect(find.text('تسجيل حضور طارئ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      print(
          'Device verification: 200% text scale verified with zero layout overflows.');
    });

    testWidgets('3. Verifies Attendance Reconciliation Exception Decision flow',
        (tester) async {
      await tester.pumpWidget(_buildDeviceHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_reconciliation_btn'),
            onPressed: () => ReconciliationQueueSheet.show(context),
            child: const Text('تسوية الاستثناءات'),
          ),
        ),
        manualRepo: manualRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_reconciliation_btn')));
      await tester.pumpAndSettle();

      expect(find.text('تسوية استثناءات الحضور'), findsOneWidget);
      expect(find.text('محمد أحمد المصطفى'), findsOneWidget);

      await tester
          .tap(find.byKey(const Key('reconcile_item_btn_rec-device-01')));
      await tester.pumpAndSettle();

      expect(find.textContaining('معالجة استثناء محمد أحمد المصطفى'),
          findsOneWidget);

      // Select quarter day mode
      await tester.tap(find.byKey(const Key('decision_mode_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جزء من يوم').last);
      await tester.pumpAndSettle();

      // Enter reason
      await tester.enterText(
        find.byKey(const Key('decision_reason_field')),
        'خصم ربع يوم لعدم توثيق الانصراف',
      );
      await tester.pumpAndSettle();

      // Preview calculation
      final previewBtn = find.byKey(const Key('decision_preview_btn'));
      await tester.ensureVisible(previewBtn);
      await tester.pumpAndSettle();
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();
      expect(find.text('25.00 SDG'), findsOneWidget);

      // Submit decision
      final submitBtn = find.byKey(const Key('decision_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(manualRepo.lastAdjustmentRequest?.mode,
          AdministrativeAdjustmentMode.dayFraction);
      expect(
          manualRepo.lastAdjustmentRequest?.targetCycleId, 'cycle-device-01');
      print(
          'Device verification: Reconciliation adjustment preview and submission verified.');
    });

    testWidgets(
        '4. Verifies Company Admin and HR persona cards render truthfully on device',
        (tester) async {
      final shift = ShiftContextEntity(
        shiftInstanceId: 'shift-dev-01',
        branchName: 'الفرع الرئيسي - الخرطوم',
        shiftName: 'الوردية الصباحية',
        scheduledStart: DateTime.utc(2026, 10, 17, 8, 0),
        scheduledEnd: DateTime.utc(2026, 10, 17, 16, 0),
        branchLocation: const GeoPoint(latitude: 15.5007, longitude: 32.5599),
        allowedRadiusMeters: 200,
        isCheckedIn: false,
      );

      final attendRepo = _DeviceAttendanceRepo(shift);
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
                  value: manualRepo),
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

      expect(find.byType(HrAttendanceControlsCard), findsOneWidget);
      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
      expect(find.byIcon(Icons.security_outlined), findsOneWidget);
      print(
          'Device verification: Company admin sovereign controls card rendered successfully.');
    });

    testWidgets(
        '5. Verifies Automatic Late-Arrival Proposals with server-suggested hours, non-deducted indicator, preview, and explicit approval on device',
        (tester) async {
      await tester.pumpWidget(_buildDeviceHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_queue_btn_late'),
            onPressed: () => ReconciliationQueueSheet.show(context),
            child: const Text('Open Queue'),
          ),
        ),
        manualRepo: manualRepo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_queue_btn_late')));
      await tester.pumpAndSettle();

      expect(find.text('سارة عبد الرحمن'), findsOneWidget);
      expect(find.textContaining('لم يُخصم شيء بعد'), findsOneWidget);
      expect(find.text('مقترح: 0.75 س'), findsOneWidget);

      // Open late arrival decision dialog
      final reconcileBtn =
          find.byKey(const Key('reconcile_item_btn_rec-late-dev-02'));
      await tester.tap(reconcileBtn);
      await tester.pumpAndSettle();

      expect(
          find.textContaining('اقتراح تأخير آلي (45 دقيقة)'), findsOneWidget);
      expect(find.textContaining('الساعات المقترحة: 0.75 س'), findsOneWidget);
      expect(find.text('اعتماد الخصم'), findsOneWidget);

      // Verify preview calculation
      final previewBtn = find.byKey(const Key('decision_preview_btn'));
      await tester.ensureVisible(previewBtn);
      await tester.pumpAndSettle();
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.text('25.00 SDG'), findsOneWidget);

      // Explicitly approve proposal
      final submitBtn = find.byKey(const Key('decision_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(manualRepo.lastAdjustmentRequest?.mode,
          AdministrativeAdjustmentMode.customHours);
      expect(manualRepo.lastAdjustmentRequest?.reasonCode, 'LATE_ARRIVAL');
      expect(manualRepo.lastAdjustmentRequest?.units, '0.75');
      print(
          'Device verification: Automatic late-arrival proposal reviewed, previewed, and approved on device without premature deduction.');
    });
  });
}
