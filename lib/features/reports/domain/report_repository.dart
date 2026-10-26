import 'report_models.dart';

abstract class ReportRepository {
  /// Fetches role-scoped workforce summary totals for the date window [from]..[to].
  Future<WorkforceReportSummaryEntity> getWorkforceSummary({
    required DateTime from,
    required DateTime to,
  });

  /// Fetches paginated attendance and leave report totals and detail items for [from]..[to].
  Future<AttendanceLeaveReportEntity> getAttendanceLeaveReport({
    required DateTime from,
    required DateTime to,
    String? cursor,
    int limit = 25,
    String? state,
  });

  /// Creates an export job for attendance and leave report.
  Future<ExportJobEntity> createExport({
    required DateTime from,
    required DateTime to,
    String? state,
  });

  /// Refreshes an existing private export job through the authorized endpoint.
  Future<ExportJobEntity> getExport(String exportId);
}
