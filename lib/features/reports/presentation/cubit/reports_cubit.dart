import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/report_models.dart';
import '../../domain/report_repository.dart';
import 'reports_state.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final ReportRepository repository;

  ReportsCubit({required this.repository}) : super(const ReportsInitial());

  @override
  void emit(ReportsState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Loads report data for current or default date window.
  Future<void> loadReports({
    DateTime? from,
    DateTime? to,
    ReportViewMode? viewMode,
  }) async {
    final now = DateTime.now();
    final effectiveTo =
        to ?? (state is ReportsLoaded ? (state as ReportsLoaded).to : now);
    final effectiveFrom = from ??
        (state is ReportsLoaded
            ? (state as ReportsLoaded).from
            : DateTime(effectiveTo.year, effectiveTo.month, 1));
    final effectiveMode = viewMode ??
        (state is ReportsLoaded
            ? (state as ReportsLoaded).viewMode
            : ReportViewMode.workforce);

    emit(const ReportsLoading());

    try {
      final summary = await repository.getWorkforceSummary(
        from: effectiveFrom,
        to: effectiveTo,
      );

      AttendanceLeaveReportEntity? attendanceReport;
      try {
        attendanceReport = await repository.getAttendanceLeaveReport(
          from: effectiveFrom,
          to: effectiveTo,
        );
      } catch (_) {}

      emit(ReportsLoaded(
        viewMode: effectiveMode,
        from: effectiveFrom,
        to: effectiveTo,
        summary: summary,
        attendanceReport: attendanceReport,
      ));
    } on AuthFailure catch (e) {
      emit(ReportsError(e.message, isForbidden: true));
    } catch (e) {
      emit(const ReportsError('تعذر تحميل تقارير العمل. حاول مرة أخرى.'));
    }
  }

  /// Switches active report view mode between workforce summary and attendance.
  void switchViewMode(ReportViewMode mode) {
    if (state is! ReportsLoaded) return;
    emit((state as ReportsLoaded).copyWith(viewMode: mode));
  }

  /// Filters attendance report by request state.
  Future<void> filterAttendanceRequestState(String? requestState) async {
    if (state is! ReportsLoaded) return;
    final current = state as ReportsLoaded;

    try {
      final report = await repository.getAttendanceLeaveReport(
        from: current.from,
        to: current.to,
        state: requestState,
      );

      emit(current.copyWith(
        attendanceReport: report,
        selectedRequestState: requestState,
      ));
    } catch (_) {
      emit(current.copyWith(
        actionError: 'تعذر تصفية تقرير الحضور والإجازات.',
      ));
    }
  }

  /// Paginates attendance report items using cursor.
  Future<void> loadMoreAttendance() async {
    if (state is! ReportsLoaded) return;
    final current = state as ReportsLoaded;
    final cursor = current.attendanceReport?.nextCursor;
    if (cursor == null || cursor.isEmpty) return;

    try {
      final nextPage = await repository.getAttendanceLeaveReport(
        from: current.from,
        to: current.to,
        cursor: cursor,
        state: current.selectedRequestState,
      );

      final existingItems = current.attendanceReport?.items ?? [];
      final existingKeys = existingItems.map(_reportItemKey).toSet();
      final newItems = nextPage.items
          .where((item) => existingKeys.add(_reportItemKey(item)))
          .toList();
      final combinedItems = [...existingItems, ...newItems];

      emit(current.copyWith(
        attendanceReport: AttendanceLeaveReportEntity(
          totals: nextPage.totals,
          items: combinedItems,
          nextCursor: nextPage.nextCursor,
        ),
      ));
    } catch (_) {
      emit(current.copyWith(
        actionError: 'تعذر تحميل المزيد من سجلات الحضور.',
      ));
    }
  }

  /// Requests a private CSV export job.
  Future<void> requestExport() async {
    if (state is! ReportsLoaded) return;
    final current = state as ReportsLoaded;

    emit(current.copyWith(isExporting: true, clearActionError: true));

    try {
      final job = await repository.createExport(
        from: current.from,
        to: current.to,
        state: current.selectedRequestState,
      );

      emit(current.copyWith(
        exportJob: job,
        isExporting: false,
        actionMessage: 'تم إنشاء طلب تصدير التقرير بنجاح.',
      ));
    } on AuthFailure catch (e) {
      emit(current.copyWith(
        isExporting: false,
        actionError: e.message,
      ));
    } catch (_) {
      emit(current.copyWith(
        isExporting: false,
        actionError: 'تعذر إنشاء ملف التصدير. حاول مرة أخرى.',
      ));
    }
  }

  Future<void> refreshExportStatus() async {
    if (state is! ReportsLoaded) return;
    final current = state as ReportsLoaded;
    final export = current.exportJob;
    if (export == null) return;

    emit(current.copyWith(isExporting: true, clearActionError: true));
    try {
      final refreshed = await repository.getExport(export.id);
      emit(current.copyWith(exportJob: refreshed, isExporting: false));
    } on AuthFailure catch (e) {
      emit(current.copyWith(isExporting: false, actionError: e.message));
    } catch (_) {
      emit(current.copyWith(
        isExporting: false,
        actionError: 'تعذر تحديث حالة ملف التصدير. حاول مرة أخرى.',
      ));
    }
  }

  String _reportItemKey(AttendanceLeaveItemEntity item) =>
      '${item.employeeId}|${item.businessDate}|${item.attendanceState}|'
      '${item.leaveMinutes}|${item.requestState ?? ''}';

  void clearActionMessage() {
    if (state is ReportsLoaded) {
      emit((state as ReportsLoaded).copyWith(clearActionMessage: true));
    }
  }

  void clearActionError() {
    if (state is ReportsLoaded) {
      emit((state as ReportsLoaded).copyWith(clearActionError: true));
    }
  }
}
