import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

abstract class AttendanceCorrectionState extends Equatable {
  const AttendanceCorrectionState();

  @override
  List<Object?> get props => [];
}

class AttendanceCorrectionInitial extends AttendanceCorrectionState {
  final List<EmployeeShiftEntity> shifts;
  final bool isLoadingShifts;
  final String? shiftError;
  final RequestAttachmentEntity? attachment;
  final bool isUploadingAttachment;
  final String? attachmentError;

  const AttendanceCorrectionInitial({
    this.shifts = const [],
    this.isLoadingShifts = false,
    this.shiftError,
    this.attachment,
    this.isUploadingAttachment = false,
    this.attachmentError,
  });

  AttendanceCorrectionInitial copyWith({
    List<EmployeeShiftEntity>? shifts,
    bool? isLoadingShifts,
    String? shiftError,
    RequestAttachmentEntity? attachment,
    bool? isUploadingAttachment,
    String? attachmentError,
    bool clearAttachment = false,
  }) {
    return AttendanceCorrectionInitial(
      shifts: shifts ?? this.shifts,
      isLoadingShifts: isLoadingShifts ?? this.isLoadingShifts,
      shiftError: shiftError,
      attachment: clearAttachment ? null : (attachment ?? this.attachment),
      isUploadingAttachment:
          isUploadingAttachment ?? this.isUploadingAttachment,
      attachmentError: attachmentError,
    );
  }

  @override
  List<Object?> get props => [
        shifts,
        isLoadingShifts,
        shiftError,
        attachment,
        isUploadingAttachment,
        attachmentError,
      ];
}

class AttendanceCorrectionSubmitting extends AttendanceCorrectionState {
  const AttendanceCorrectionSubmitting();
}

class AttendanceCorrectionSuccess extends AttendanceCorrectionState {
  final RequestEntity request;
  final bool isQueuedOffline;

  const AttendanceCorrectionSuccess({
    required this.request,
    this.isQueuedOffline = false,
  });

  @override
  List<Object?> get props => [request, isQueuedOffline];
}

class AttendanceCorrectionError extends AttendanceCorrectionState {
  final String message;
  final bool isConflict;

  const AttendanceCorrectionError({
    required this.message,
    this.isConflict = false,
  });

  @override
  List<Object?> get props => [message, isConflict];
}
