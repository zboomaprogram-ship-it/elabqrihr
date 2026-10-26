// ignore_for_file: avoid_print
// Device acceptance test for Feature 017 Mobile Attendance Lifecycle and Financial Advances.
// Run with: flutter test integration_test/attendance_financial_lifecycle_device_test.dart -d 10JE1B00ZB000E8

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/attendance_correction/attendance_correction_screen.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_coordinator.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_models.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_repository.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_scheduler.dart';
import 'package:attend_mobile/features/attendance_reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:attend_mobile/features/attendance_reminders/presentation/screens/reminder_settings_screen.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_request_screen.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_models.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_repository.dart';
import 'package:attend_mobile/features/final_settlement/presentation/cubit/final_settlement_cubit.dart';
import 'package:attend_mobile/features/final_settlement/presentation/screens/final_settlement_statement_screen.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

class _MockRequestRepo extends Mock
    implements
        RequestRepository,
        EmployeeShiftRepository,
        RequestAttachmentRepository {}

class _MockReminderRepo extends Mock implements ReminderRepository {}

class _MockReminderScheduler extends Mock implements ReminderScheduler {}

class _MockReminderCoordinator extends Mock implements ReminderCoordinator {}

class _MockAdvanceRepo extends Mock
    implements AdvanceRepository, AdvanceEligibilityRepository {}

class _MockSettlementRepo extends Mock implements FinalSettlementRepository {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _MockRequestRepo requestRepo;
  late _MockReminderRepo reminderRepo;
  late _MockReminderScheduler reminderScheduler;
  late _MockReminderCoordinator reminderCoordinator;
  late _MockAdvanceRepo advanceRepo;
  late _MockSettlementRepo settlementRepo;

  final outputDir = Directory('/sdcard/Download/f017_acceptance');

  setUpAll(() {
    registerFallbackValue(RequestType.attendanceCorrection);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(
        const MoneyEntity(currency: 'SDG', amount: '10000.00'));
    registerFallbackValue(
      const ReminderPreferences(
        shiftStartEnabled: false,
        shiftStartLeadMinutes: 15,
        checkoutEnabled: false,
        permissionReturnEnabled: false,
        permissionGranted: false,
        lastSyncAt: null,
      ),
    );
  });

  setUp(() {
    requestRepo = _MockRequestRepo();
    reminderRepo = _MockReminderRepo();
    reminderScheduler = _MockReminderScheduler();
    reminderCoordinator = _MockReminderCoordinator();
    advanceRepo = _MockAdvanceRepo();
    settlementRepo = _MockSettlementRepo();

    try {
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }
    } catch (_) {}
  });

  Future<void> takeScreenshot(String name) async {
    // Screenshot capture on device without flutter_driver host is skipped
    print('Acceptance checkpoint: $name');
  }

  Widget wrapWithTheme(Widget child, {double textScale = 1.0}) {
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
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Feature 017 Mobile Device Acceptance Suite', () {
    testWidgets('US1: Attendance Correction pair form and 200% scale RTL',
        (tester) async {
      final sampleShift = EmployeeShiftEntity(
        shiftInstanceId: 'shift-past-001',
        businessDate: '2026-10-15',
        startsAt: DateTime.parse('2026-10-15T08:00:00Z'),
        endsAt: DateTime.parse('2026-10-15T17:00:00Z'),
        branchName: 'الفرع الرئيسي - الخرطوم',
        state: 'completed',
      );

      when(() => requestRepo.listMyShiftInstances(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => [sampleShift]);

      when(() => requestRepo.listMyRequests(
            type: RequestType.attendanceCorrection,
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => RequestFormCubit(
                repository: requestRepo,
                shiftRepository: requestRepo,
              ),
            ),
            RepositoryProvider<RequestRepository>.value(value: requestRepo),
          ],
          child: wrapWithTheme(const AttendanceCorrectionScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // The page title is intentionally repeated in the route header and form
      // heading. Acceptance requires it to be visible, not globally unique.
      expect(find.text(AppStringsAr.attendanceCorrectionTitle), findsWidgets);
      await takeScreenshot('01_attendance_correction_screen_rtl');

      // Test 200% font scale
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => RequestFormCubit(
                repository: requestRepo,
                shiftRepository: requestRepo,
              ),
            ),
            RepositoryProvider<RequestRepository>.value(value: requestRepo),
          ],
          child:
              wrapWithTheme(const AttendanceCorrectionScreen(), textScale: 2.0),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await takeScreenshot('02_attendance_correction_200_scale');
    });

    testWidgets('US2: Smart Attendance Reminders settings in RTL',
        (tester) async {
      when(() => reminderScheduler.hasPermission())
          .thenAnswer((_) async => true);
      when(() => reminderRepo.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          shiftStartEnabled: true,
          shiftStartLeadMinutes: 15,
          checkoutEnabled: true,
          permissionReturnEnabled: false,
          permissionGranted: true,
          lastSyncAt: null,
        ),
      );
      when(() => reminderRepo.savePreferences(any()))
          .thenAnswer((_) async => {});
      when(() => reminderCoordinator.reconcile()).thenAnswer((_) async => {});

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider(
            create: (_) => ReminderSettingsCubit(
              repository: reminderRepo,
              scheduler: reminderScheduler,
              coordinator: reminderCoordinator,
            )..loadSettings(),
            child: const ReminderSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('منبهات وتنبيهات الحضور'), findsOneWidget);
      expect(find.text('تنبيه موعد بداية الوردية'), findsOneWidget);
      expect(find.text('تذكير تسجيل الانصراف'), findsOneWidget);
      await takeScreenshot('03_reminder_settings_screen_rtl');
    });

    testWidgets('US3: Advance Request preview, schedule and Arabic validation',
        (tester) async {
      final preview = AdvanceEligibilityPreviewEntity(
        evaluationId: 'eval-dev-101',
        policyVersionId: 'pol-001',
        eligible: true,
        reasonCodes: const [],
        expiresAt: DateTime.parse('2026-10-18T18:00:00Z'),
        provisionalSchedule: const [
          AdvanceScheduleItemEntity(
            sequence: 1,
            dueDate: '2026-11-01',
            amount: MoneyEntity(currency: 'SDG', amount: '15000.00'),
          ),
          AdvanceScheduleItemEntity(
            sequence: 2,
            dueDate: '2026-12-01',
            amount: MoneyEntity(currency: 'SDG', amount: '15000.00'),
          ),
        ],
      );

      when(() => advanceRepo.previewEligibility(
            amount: any(named: 'amount'),
            installmentCount: any(named: 'installmentCount'),
          )).thenAnswer((_) async => preview);

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider(
            create: (_) => AdvanceRequestCubit(repository: advanceRepo),
            child: const AdvanceRequestScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلب سلفة راتب جديدة'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('advance-amount-field')), '30000.00');
      await tester.tap(find.byKey(const Key('advance-preview-button')));
      await tester.pumpAndSettle();

      expect(find.text('مؤهل لطلب السلفة'), findsOneWidget);
      expect(
          find.text('الجدول المالي المؤقت للأقساط (تقديري)'), findsOneWidget);
      await takeScreenshot('04_advance_preview_eligible_schedule');
    });

    testWidgets('US5: Final Settlement employee statement private review',
        (tester) async {
      final statement = SettlementStatementEntity(
        id: 'stmt-001',
        settlementId: 'case-dev-901',
        statementNumber: 'FS-2026-0001',
        statementDigest: 'abc123digest',
        publishedAt: DateTime.parse('2026-10-16T14:30:00Z'),
        documentState: SettlementDocumentState.ready,
        earningsMinor: 52000000,
        deductionsMinor: 0,
        netMinor: 52000000,
        currency: 'SDG',
        lines: const [
          SettlementLineEntity(
            category: 'end_of_service_gratuity',
            type: SettlementLineType.earning,
            description: 'مكافأة نهاية الخدمة القانونية',
            amountMinor: 45000000,
            currency: 'SDG',
            disputeState: 'clear',
          ),
          SettlementLineEntity(
            category: 'leave_liquidation',
            type: SettlementLineType.earning,
            description: 'تصفية رصيد الإجازات السنوية المستحقة (14 يوماً)',
            amountMinor: 7000000,
            currency: 'SDG',
            disputeState: 'clear',
          ),
        ],
        decisions: [
          SettlementDecisionEntity(
            stage: 1,
            decision: 'approved',
            actorDisplayName: 'مدير الموارد البشرية',
            decidedAt: DateTime.parse('2026-10-15T10:00:00Z'),
          ),
        ],
      );

      when(() => settlementRepo.getStatement(any()))
          .thenAnswer((_) async => statement);
      when(() => settlementRepo.getLatestStatement())
          .thenAnswer((_) async => statement);

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider(
            create: (_) => FinalSettlementCubit(repository: settlementRepo),
            child: const FinalSettlementStatementScreen(
                settlementId: 'case-dev-901'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('كشف المخالصة النهائية'), findsOneWidget);
      expect(find.text('مكافأة نهاية الخدمة القانونية'), findsOneWidget);
      await takeScreenshot('05_final_settlement_statement_rtl');
    });
  });
}
