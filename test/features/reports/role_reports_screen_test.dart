import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:attend_mobile/features/reports/presentation/screens/role_reports_screen.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockReportRepository mockReportRepo;
  late MockAuthRepository mockAuthRepo;

  final testSummary = WorkforceReportSummaryEntity(
    from: '2026-09-01',
    to: '2026-09-27',
    activeEmployees: 10,
    suspendedEmployees: 2,
    archivedEmployees: 1,
    activeLocations: 3,
    unassignedEmployees: 0,
    generatedAt: DateTime(2026, 9, 27, 8, 0),
  );

  final testAttendance = AttendanceLeaveReportEntity(
    totals: const AttendanceLeaveTotalsEntity(
      employees: 13,
      attendanceExceptions: 2,
      leaveMinutes: 120,
      requests: 5,
    ),
    items: [
      const AttendanceLeaveItemEntity(
        employeeId: 'emp-1',
        employeeName: 'أحمد علي',
        businessDate: '2026-09-26',
        attendanceState: 'present',
        leaveMinutes: 0,
      ),
    ],
  );

  setUp(() {
    mockReportRepo = MockReportRepository();
    mockAuthRepo = MockAuthRepository();

    when(() => mockReportRepo.getWorkforceSummary(
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer((_) async => testSummary);
    when(() => mockReportRepo.getAttendanceLeaveReport(
          from: any(named: 'from'),
          to: any(named: 'to'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          state: any(named: 'state'),
        )).thenAnswer((_) async => testAttendance);
  });

  Widget createWidgetUnderTest({
    UserRole role = UserRole.employee,
    ReportsCubit? cubit,
  }) {
    final authSession = AuthSessionEntity(
      accessToken: 'token',
      tenantId: 'tenant-1',
      userId: 'user-1',
      role: role,
      email: 'user@attend.app',
      displayName: 'مستخدم تجريبي',
    );

    when(() => mockAuthRepo.getCachedSession())
        .thenAnswer((_) async => authSession);

    final authCubit = AuthCubit(mockAuthRepo)..emit(Authenticated(authSession));
    final reportsCubit =
        cubit ?? (ReportsCubit(repository: mockReportRepo)..loadReports());

    return RepositoryProvider<ReportRepository>.value(
      value: mockReportRepo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<ReportsCubit>.value(value: reportsCubit),
        ],
        child: MaterialApp(
          home: RoleReportsScreen(role: role),
        ),
      ),
    );
  }

  group('RoleReportsScreen - Role Scopes and Titles', () {
    testWidgets('renders تقريري الشخصي for employee role', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(role: UserRole.employee));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('تقريري الشخصي'), findsWidgets);
      expect(find.text('ملخص حي محسوب من سجلات حضورك وطلباتك المصرح بها.'),
          findsOneWidget);
    });

    testWidgets('renders تقرير فريقي for manager role', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(role: UserRole.manager));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('تقرير فريقي'), findsWidgets);
      expect(find.text('ملخص حي محسوب من سجلات أعضاء فريقك المصرح بها.'),
          findsOneWidget);
    });

    testWidgets('renders تقرير الشركة for hr role', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(role: UserRole.hr));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('تقرير الشركة'), findsWidgets);
      expect(
          find.text(
              'ملخص حي محسوب من سجلات الموظفين والتكليفات ومواقع العمل المصرح بها.'),
          findsOneWidget);
    });
  });

  group('RoleReportsScreen - Strict Exclusions & Reconciled Totals', () {
    testWidgets('proves NO payroll, finance, KPI, tasks, or chat text exists',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(role: UserRole.hr));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('راتب'), findsNothing);
      expect(find.textContaining('الرواتب'), findsNothing);
      expect(find.textContaining('شؤون مالية'), findsNothing);
      expect(find.textContaining('المالية'), findsNothing);
      expect(find.textContaining('KPI'), findsNothing);
      expect(find.textContaining('مؤشرات الأداء'), findsNothing);
      expect(find.textContaining('المهام'), findsNothing);
      expect(find.textContaining('دردشة'), findsNothing);
      expect(find.textContaining('محادثة'), findsNothing);
    });

    testWidgets('renders reconciled total employee indicator', (tester) async {
      await tester
          .pumpWidget(createWidgetUnderTest(role: UserRole.companyAdmin));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('إجمالي الموظفين: 13'), findsOneWidget);
    });
  });

  group('RoleReportsScreen - Denied and Empty States', () {
    testWidgets('renders 403 denied state with retry button', (tester) async {
      final cubit = ReportsCubit(repository: mockReportRepo);
      when(() => mockReportRepo.getWorkforceSummary(
            from: any(named: 'from'),
            to: any(named: 'to'),
          )).thenThrow(Exception('403 Forbidden'));

      await tester.pumpWidget(createWidgetUnderTest(
        role: UserRole.employee,
        cubit: cubit,
      ));
      cubit.loadReports();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(
          find.text('تعذر تحميل تقارير العمل. حاول مرة أخرى.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });

  group('RoleReportsScreen - Accessibility and Touch Targets', () {
    testWidgets('interactive controls satisfy 44x44 minimum touch target',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(role: UserRole.manager));
      await tester.pump();
      await tester.pumpAndSettle();

      // Switch to attendance tab where export CSV button is present
      await tester.tap(find.byKey(const Key('reports_tab_attendance')));
      await tester.pumpAndSettle();

      final exportButton =
          tester.getRect(find.byKey(const Key('reports_export_csv_button')));
      expect(exportButton.width, greaterThanOrEqualTo(44.0));
      expect(exportButton.height, greaterThanOrEqualTo(44.0));

      final dateButton =
          tester.getRect(find.byKey(const Key('reports_filter_from')));
      expect(dateButton.height, greaterThanOrEqualTo(44.0));
    });
  });
}
