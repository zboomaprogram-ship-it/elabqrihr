import 'package:equatable/equatable.dart';

enum RequestType {
  leave,
  permission,
  attendanceCorrection,
  dynamic,
}

extension RequestTypeX on RequestType {
  String toApiValue() {
    switch (this) {
      case RequestType.leave:
        return 'leave';
      case RequestType.permission:
        return 'permission';
      case RequestType.attendanceCorrection:
        return 'attendance_correction';
      case RequestType.dynamic:
        return 'dynamic';
    }
  }

  static RequestType fromApiValue(String val) {
    switch (val) {
      case 'leave':
        return RequestType.leave;
      case 'permission':
        return RequestType.permission;
      case 'dynamic':
        return RequestType.dynamic;
      case 'attendance_correction':
      default:
        return RequestType.attendanceCorrection;
    }
  }
}

enum RequestState {
  submitted,
  pendingApproval,
  approved,
  rejected,
  cancelled,
  processingFailed,
  pendingSync, // Offline local outbox state
  conflict, // Duplicate or revision collision
}

extension RequestStateX on RequestState {
  String toApiValue() {
    switch (this) {
      case RequestState.submitted:
        return 'submitted';
      case RequestState.pendingApproval:
        return 'pending_approval';
      case RequestState.approved:
        return 'approved';
      case RequestState.rejected:
        return 'rejected';
      case RequestState.cancelled:
        return 'cancelled';
      case RequestState.processingFailed:
        return 'processing_failed';
      case RequestState.pendingSync:
        return 'pending_sync';
      case RequestState.conflict:
        return 'conflict';
    }
  }

  static RequestState fromApiValue(String val) {
    switch (val) {
      case 'submitted':
        return RequestState.submitted;
      case 'pending_approval':
        return RequestState.pendingApproval;
      case 'approved':
        return RequestState.approved;
      case 'rejected':
        return RequestState.rejected;
      case 'cancelled':
        return RequestState.cancelled;
      case 'pending_sync':
        return RequestState.pendingSync;
      case 'conflict':
        return RequestState.conflict;
      case 'processing_failed':
      default:
        return RequestState.processingFailed;
    }
  }
}

class ApprovalStepEntity extends Equatable {
  final String id;
  final int position;
  final String reviewerRole;
  final String? reviewerName;
  final String state; // waiting | pending | approved | rejected | cancelled
  final DateTime? decidedAt;
  final String? comment;

  const ApprovalStepEntity({
    required this.id,
    required this.position,
    required this.reviewerRole,
    this.reviewerName,
    required this.state,
    this.decidedAt,
    this.comment,
  });

  @override
  List<Object?> get props =>
      [id, position, reviewerRole, reviewerName, state, decidedAt, comment];
}

class RequestEntity extends Equatable {
  final String id;
  final String employeeId;
  final String? employeeName;
  final RequestType type;
  final RequestState state;
  final int revision;
  final int requestedMinutes;
  final DateTime submittedAt;
  final DateTime? decidedAt;
  final DateTime? cancelledAt;
  final String? reasonCode;
  final Map<String, dynamic> details;
  final List<ApprovalStepEntity> steps;
  final bool isDynamic;
  final String? dynamicTypeNameAr;

  const RequestEntity({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.type,
    required this.state,
    required this.revision,
    required this.requestedMinutes,
    required this.submittedAt,
    this.decidedAt,
    this.cancelledAt,
    this.reasonCode,
    required this.details,
    required this.steps,
    this.isDynamic = false,
    this.dynamicTypeNameAr,
  });

  RequestEntity copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    RequestType? type,
    RequestState? state,
    int? revision,
    int? requestedMinutes,
    DateTime? submittedAt,
    DateTime? decidedAt,
    DateTime? cancelledAt,
    String? reasonCode,
    Map<String, dynamic>? details,
    List<ApprovalStepEntity>? steps,
    bool? isDynamic,
    String? dynamicTypeNameAr,
  }) {
    return RequestEntity(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      state: state ?? this.state,
      revision: revision ?? this.revision,
      requestedMinutes: requestedMinutes ?? this.requestedMinutes,
      submittedAt: submittedAt ?? this.submittedAt,
      decidedAt: decidedAt ?? this.decidedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      reasonCode: reasonCode ?? this.reasonCode,
      details: details ?? this.details,
      steps: steps ?? this.steps,
      isDynamic: isDynamic ?? this.isDynamic,
      dynamicTypeNameAr: dynamicTypeNameAr ?? this.dynamicTypeNameAr,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        employeeName,
        type,
        state,
        revision,
        requestedMinutes,
        submittedAt,
        decidedAt,
        cancelledAt,
        reasonCode,
        details,
        steps,
        isDynamic,
        dynamicTypeNameAr,
      ];
}

class LeaveBalanceEntity extends Equatable {
  final String employeeId;
  final String categoryId;
  final String categoryName;
  final String periodStart;
  final String periodEnd;
  final int balanceMinutes;

  const LeaveBalanceEntity({
    required this.employeeId,
    required this.categoryId,
    required this.categoryName,
    required this.periodStart,
    required this.periodEnd,
    required this.balanceMinutes,
  });

  @override
  List<Object?> get props => [
        employeeId,
        categoryId,
        categoryName,
        periodStart,
        periodEnd,
        balanceMinutes
      ];
}

class EmployeeShiftEntity extends Equatable {
  final String shiftInstanceId;
  final String businessDate;
  final DateTime startsAt;
  final DateTime endsAt;
  final String branchName;
  final String state;

  const EmployeeShiftEntity({
    required this.shiftInstanceId,
    required this.businessDate,
    required this.startsAt,
    required this.endsAt,
    required this.branchName,
    required this.state,
  });

  @override
  List<Object?> get props => [
        shiftInstanceId,
        businessDate,
        startsAt,
        endsAt,
        branchName,
        state,
      ];
}

class RequestAttachmentEntity extends Equatable {
  final String id;
  final String displayName;
  final String mediaType;
  final int sizeBytes;
  final String state;
  final DateTime expiresAt;

  const RequestAttachmentEntity({
    required this.id,
    required this.displayName,
    required this.mediaType,
    required this.sizeBytes,
    required this.state,
    required this.expiresAt,
  });

  @override
  List<Object?> get props =>
      [id, displayName, mediaType, sizeBytes, state, expiresAt];
}

enum AttendanceCorrectionKind {
  addCheckIn,
  changeCheckIn,
  addCheckOut,
  changeCheckOut,
  both,
}

extension AttendanceCorrectionKindX on AttendanceCorrectionKind {
  String toApiValue() {
    switch (this) {
      case AttendanceCorrectionKind.addCheckIn:
        return 'add_check_in';
      case AttendanceCorrectionKind.changeCheckIn:
        return 'change_check_in';
      case AttendanceCorrectionKind.addCheckOut:
        return 'add_check_out';
      case AttendanceCorrectionKind.changeCheckOut:
        return 'change_check_out';
      case AttendanceCorrectionKind.both:
        return 'both';
    }
  }

  static AttendanceCorrectionKind fromApiValue(String val) {
    switch (val) {
      case 'add_check_in':
        return AttendanceCorrectionKind.addCheckIn;
      case 'change_check_in':
        return AttendanceCorrectionKind.changeCheckIn;
      case 'add_check_out':
        return AttendanceCorrectionKind.addCheckOut;
      case 'change_check_out':
        return AttendanceCorrectionKind.changeCheckOut;
      case 'both':
      default:
        return AttendanceCorrectionKind.both;
    }
  }

  String get arabicLabel {
    switch (this) {
      case AttendanceCorrectionKind.addCheckIn:
        return 'إضافة تسجيل دخول';
      case AttendanceCorrectionKind.changeCheckIn:
        return 'تعديل تسجيل دخول';
      case AttendanceCorrectionKind.addCheckOut:
        return 'إضافة تسجيل انصراف';
      case AttendanceCorrectionKind.changeCheckOut:
        return 'تعديل تسجيل انصراف';
      case AttendanceCorrectionKind.both:
        return 'تصحيح الحضور والانصراف معاً';
    }
  }
}
