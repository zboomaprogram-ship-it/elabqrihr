import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:attend_mobile/features/reports/presentation/cubit/reports_state.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockReportRepository repository;

  setUp(() {
    repository = MockReportRepository();
  });

  final testFrom = DateTime(2026, 9, 1);
  final testTo = DateTime(2026, 9, 27);

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
    nextCursor: 'cursor-att-1',
  );

  group('ReportsCubit - Load and Modes', () {
    test('initial state is ReportsInitial', () {
      final cubit = ReportsCubit(repository: repository);
      expect(cubit.state, equals(const ReportsInitial()));
      cubit.close();
    });

    blocTest<ReportsCubit, ReportsState>(
      'loadReports emits [ReportsLoading, ReportsLoaded] on success',
      build: () {
        when(() => repository.getWorkforceSummary(
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenAnswer((_) async => testSummary);
        when(() => repository.getAttendanceLeaveReport(
              from: any(named: 'from'),
              to: any(named: 'to'),
            )).thenAnswer((_) async => testAttendance);
        return ReportsCubit(repository: repository);
      },
      act: (cubit) => cubit.loadReports(from: testFrom, to: testTo),
      expect: () => [
        const ReportsLoading(),
        isA<ReportsLoaded>()
            .having((s) => s.summary?.totalEmployees, 'totalEmployees', 13)
            .having((s) => s.attendanceReport?.items.length, 'items', 1)
            .having((s) => s.viewMode, 'viewMode', ReportViewMode.workforce),
      ],
    );

    blocTest<ReportsCubit, ReportsState>(
      'loadReports emits [ReportsLoading, ReportsError(isForbidden: true)] on 403',
      build: () {
        when(() => repository.getWorkforceSummary(
                  from: any(named: 'from'),
                  to: any(named: 'to'),
                ))
            .thenThrow(const AuthFailure('ليس لديك صلاحية لعرض هذا التقرير.'));
        return ReportsCubit(repository: repository);
      },
      act: (cubit) => cubit.loadReports(from: testFrom, to: testTo),
      expect: () => [
        const ReportsLoading(),
        const ReportsError(
          'ليس لديك صلاحية لعرض هذا التقرير.',
          isForbidden: true,
        ),
      ],
    );

    blocTest<ReportsCubit, ReportsState>(
      'switchViewMode updates active view mode without re-fetching',
      build: () => ReportsCubit(repository: repository),
      seed: () => ReportsLoaded(
        viewMode: ReportViewMode.workforce,
        from: testFrom,
        to: testTo,
        summary: testSummary,
      ),
      act: (cubit) => cubit.switchViewMode(ReportViewMode.attendance),
      expect: () => [
        isA<ReportsLoaded>().having(
          (s) => s.viewMode,
          'viewMode',
          ReportViewMode.attendance,
        ),
      ],
    );

    blocTest<ReportsCubit, ReportsState>(
      'exportReport triggers export and updates exportJob',
      build: () {
        when(() => repository.createExport(
              from: any(named: 'from'),
              to: any(named: 'to'),
              state: any(named: 'state'),
            )).thenAnswer((_) async => const ExportJobEntity(
              id: 'export-123',
              state: 'ready',
              rowCount: 10,
            ));
        return ReportsCubit(repository: repository);
      },
      seed: () => ReportsLoaded(
        viewMode: ReportViewMode.workforce,
        from: testFrom,
        to: testTo,
        summary: testSummary,
      ),
      act: (cubit) => cubit.requestExport(),
      expect: () => [
        isA<ReportsLoaded>().having((s) => s.isExporting, 'isExporting', true),
        isA<ReportsLoaded>()
            .having((s) => s.isExporting, 'isExporting', false)
            .having((s) => s.exportJob?.id, 'jobId', 'export-123'),
      ],
    );

    blocTest<ReportsCubit, ReportsState>(
      'pagination removes overlapping report rows',
      build: () {
        when(() => repository.getAttendanceLeaveReport(
              from: any(named: 'from'),
              to: any(named: 'to'),
              cursor: 'cursor-att-1',
              state: any(named: 'state'),
            )).thenAnswer(
          (_) async => AttendanceLeaveReportEntity(
            totals: testAttendance.totals,
            items: const [
              AttendanceLeaveItemEntity(
                employeeId: 'emp-1',
                employeeName: 'أحمد علي',
                businessDate: '2026-09-26',
                attendanceState: 'present',
                leaveMinutes: 0,
              ),
              AttendanceLeaveItemEntity(
                employeeId: 'emp-2',
                employeeName: 'سارة محمد',
                businessDate: '2026-09-26',
                attendanceState: 'absent',
                leaveMinutes: 0,
              ),
            ],
          ),
        );
        return ReportsCubit(repository: repository);
      },
      seed: () => ReportsLoaded(
        viewMode: ReportViewMode.attendance,
        from: testFrom,
        to: testTo,
        summary: testSummary,
        attendanceReport: testAttendance,
      ),
      act: (cubit) => cubit.loadMoreAttendance(),
      expect: () => [
        isA<ReportsLoaded>().having(
          (s) => s.attendanceReport?.items.map((item) => item.employeeId),
          'unique employee rows',
          ['emp-1', 'emp-2'],
        ),
      ],
    );

    blocTest<ReportsCubit, ReportsState>(
      'refreshExportStatus replaces queued state with server-confirmed state',
      build: () {
        when(() => repository.getExport('export-123')).thenAnswer(
          (_) async => const ExportJobEntity(
            id: 'export-123',
            state: 'ready',
            rowCount: 10,
          ),
        );
        return ReportsCubit(repository: repository);
      },
      seed: () => ReportsLoaded(
        viewMode: ReportViewMode.attendance,
        from: testFrom,
        to: testTo,
        summary: testSummary,
        attendanceReport: testAttendance,
        exportJob: const ExportJobEntity(
          id: 'export-123',
          state: 'queued',
        ),
      ),
      act: (cubit) => cubit.refreshExportStatus(),
      expect: () => [
        isA<ReportsLoaded>().having((s) => s.isExporting, 'refreshing', true),
        isA<ReportsLoaded>()
            .having((s) => s.isExporting, 'refreshing', false)
            .having((s) => s.exportJob?.state, 'state', 'ready'),
      ],
    );
  });
}
