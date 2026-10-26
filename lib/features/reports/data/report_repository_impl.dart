import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../domain/report_models.dart';
import '../domain/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ApiClient apiClient;
  final Uuid _uuid;
  String? _pendingExportCommandId;
  String? _pendingExportSignature;

  ReportRepositoryImpl({
    required this.apiClient,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  String _formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Future<WorkforceReportSummaryEntity> getWorkforceSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final dto = await apiClient.getWorkforceSummary(
        from: from,
        to: to,
      );

      return WorkforceReportSummaryEntity(
        from: dto.from,
        to: dto.to,
        activeEmployees: dto.activeEmployees,
        suspendedEmployees: dto.suspendedEmployees,
        archivedEmployees: dto.archivedEmployees,
        activeLocations: dto.activeLocations,
        unassignedEmployees: dto.unassignedEmployees,
        generatedAt: dto.generatedAt,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw const AuthFailure('ليس لديك صلاحية لعرض هذا التقرير.');
      }
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw const ServerFailure('تعذر تحميل ملخص القوى العاملة.');
    }
  }

  @override
  Future<AttendanceLeaveReportEntity> getAttendanceLeaveReport({
    required DateTime from,
    required DateTime to,
    String? cursor,
    int limit = 25,
    String? state,
  }) async {
    try {
      final dto = await apiClient.getAttendanceLeaveReport(
        from: from,
        to: to,
        cursor: cursor,
        limit: limit,
        requestState: state,
      );

      return AttendanceLeaveReportEntity(
        totals: AttendanceLeaveTotalsEntity(
          employees: dto.totals.employees,
          attendanceExceptions: dto.totals.attendanceExceptions,
          leaveMinutes: dto.totals.leaveMinutes,
          requests: dto.totals.requests,
        ),
        items: dto.items
            .map(
              (item) => AttendanceLeaveItemEntity(
                employeeId: item.employeeId,
                employeeName: item.employeeName,
                businessDate: item.businessDate,
                attendanceState: item.attendanceState,
                leaveMinutes: item.leaveMinutes,
                requestState: item.requestState,
              ),
            )
            .toList(),
        nextCursor: dto.nextCursor,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw const AuthFailure('ليس لديك صلاحية لعرض هذا التقرير.');
      }
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw const ServerFailure('تعذر تحميل تقرير الحضور والإجازات.');
    }
  }

  @override
  Future<ExportJobEntity> createExport({
    required DateTime from,
    required DateTime to,
    String? state,
  }) async {
    final signature = '${_formatDate(from)}|${_formatDate(to)}|${state ?? ''}';
    if (_pendingExportSignature != signature) {
      _pendingExportSignature = signature;
      _pendingExportCommandId = _uuid.v4();
    }
    try {
      final request = CreateExportRequestDto(
        commandId: _pendingExportCommandId!,
        reportType: 'attendance_leave',
        format: 'csv',
        filter: ReportFilterDto(
          startDate: _formatDate(from),
          endDate: _formatDate(to),
          requestState: state != null && state.isNotEmpty ? state : null,
        ),
      );

      final dto = await apiClient.createExport(request: request);
      _pendingExportCommandId = null;
      _pendingExportSignature = null;

      return _toExportEntity(dto);
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw const AuthFailure('ليس لديك صلاحية لتصدير هذا التقرير.');
      }
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw const ServerFailure('تعذر إنشاء ملف التصدير.');
    }
  }

  @override
  Future<ExportJobEntity> getExport(String exportId) async {
    try {
      return _toExportEntity(await apiClient.getExport(exportId));
    } on ApiException catch (e) {
      if (e.statusCode == 403 || e.statusCode == 404) {
        throw const AuthFailure('لم يعد ملف التصدير متاحاً لك.');
      }
      throw ServerFailure(e.message);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw const ServerFailure('تعذر تحديث حالة ملف التصدير.');
    }
  }

  ExportJobEntity _toExportEntity(ExportJobDto dto) => ExportJobEntity(
        id: dto.id,
        state: dto.state,
        rowCount: dto.rowCount,
        reasonCode: dto.reasonCode,
        expiresAt: dto.expiresAt,
      );
}
