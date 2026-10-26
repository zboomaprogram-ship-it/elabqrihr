import 'package:equatable/equatable.dart';
import '../../domain/report_models.dart';

enum ReportViewMode {
  workforce,
  attendance,
}

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportsLoaded extends ReportsState {
  final ReportViewMode viewMode;
  final DateTime from;
  final DateTime to;
  final WorkforceReportSummaryEntity? summary;
  final AttendanceLeaveReportEntity? attendanceReport;
  final String? selectedRequestState;
  final ExportJobEntity? exportJob;
  final bool isExporting;
  final String? actionMessage;
  final String? actionError;

  const ReportsLoaded({
    required this.viewMode,
    required this.from,
    required this.to,
    this.summary,
    this.attendanceReport,
    this.selectedRequestState,
    this.exportJob,
    this.isExporting = false,
    this.actionMessage,
    this.actionError,
  });

  bool get isEmpty {
    if (viewMode == ReportViewMode.workforce) {
      return summary != null && summary!.totalEmployees == 0;
    } else {
      return attendanceReport != null && attendanceReport!.items.isEmpty;
    }
  }

  ReportsLoaded copyWith({
    ReportViewMode? viewMode,
    DateTime? from,
    DateTime? to,
    WorkforceReportSummaryEntity? summary,
    AttendanceLeaveReportEntity? attendanceReport,
    String? selectedRequestState,
    ExportJobEntity? exportJob,
    bool? isExporting,
    String? actionMessage,
    String? actionError,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return ReportsLoaded(
      viewMode: viewMode ?? this.viewMode,
      from: from ?? this.from,
      to: to ?? this.to,
      summary: summary ?? this.summary,
      attendanceReport: attendanceReport ?? this.attendanceReport,
      selectedRequestState: selectedRequestState ?? this.selectedRequestState,
      exportJob: exportJob ?? this.exportJob,
      isExporting: isExporting ?? this.isExporting,
      actionMessage:
          clearActionMessage ? null : (actionMessage ?? this.actionMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
    );
  }

  @override
  List<Object?> get props => [
        viewMode,
        from,
        to,
        summary,
        attendanceReport,
        selectedRequestState,
        exportJob,
        isExporting,
        actionMessage,
        actionError,
      ];
}

class ReportsError extends ReportsState {
  final String message;
  final bool isForbidden;

  const ReportsError(
    this.message, {
    this.isForbidden = false,
  });

  @override
  List<Object?> get props => [message, isForbidden];
}
