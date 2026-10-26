import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'attendance_correction_state.dart';

class AttendanceCorrectionCubit extends Cubit<AttendanceCorrectionState> {
  final RequestRepository _repository;
  final EmployeeShiftRepository? _shiftRepository;
  final RequestAttachmentRepository? _attachmentRepository;
  final Uuid _uuid = const Uuid();

  AttendanceCorrectionCubit({
    required RequestRepository repository,
    EmployeeShiftRepository? shiftRepository,
    RequestAttachmentRepository? attachmentRepository,
  })  : _repository = repository,
        _shiftRepository = shiftRepository,
        _attachmentRepository = attachmentRepository ??
            (repository is RequestAttachmentRepository
                ? repository as RequestAttachmentRepository
                : null),
        super(const AttendanceCorrectionInitial());

  Future<void> loadPastShifts({
    required String startDate,
    required String endDate,
  }) async {
    final current = state is AttendanceCorrectionInitial
        ? state as AttendanceCorrectionInitial
        : const AttendanceCorrectionInitial();

    emit(current.copyWith(isLoadingShifts: true, shiftError: null));

    final shiftRepo = _shiftRepository;
    if (shiftRepo == null) {
      emit(current.copyWith(
        isLoadingShifts: false,
        shiftError: 'سجل الورديات غير متاح حالياً.',
      ));
      return;
    }

    try {
      final shifts = await shiftRepo.listMyShiftInstances(
        startDate: startDate,
        endDate: endDate,
      );
      if (isClosed) return;
      emit(current.copyWith(
        shifts: shifts,
        isLoadingShifts: false,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(current.copyWith(
        isLoadingShifts: false,
        shiftError: failure.message,
      ));
    }
  }

  Future<void> uploadEvidence({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    final current = state is AttendanceCorrectionInitial
        ? state as AttendanceCorrectionInitial
        : const AttendanceCorrectionInitial();

    emit(current.copyWith(isUploadingAttachment: true, attachmentError: null));

    final attRepo = _attachmentRepository;
    if (attRepo == null) {
      emit(current.copyWith(
        isUploadingAttachment: false,
        attachmentError: 'خدمة رفع المرفقات غير متاحة حالياً.',
      ));
      return;
    }

    try {
      final attachment = await attRepo.uploadAttachment(
        bytes: bytes,
        filename: filename,
        mediaType: mediaType,
      );
      if (isClosed) return;
      emit(current.copyWith(
        attachment: attachment,
        isUploadingAttachment: false,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(current.copyWith(
        isUploadingAttachment: false,
        attachmentError: failure.message,
      ));
    }
  }

  void clearEvidence() {
    if (state is AttendanceCorrectionInitial) {
      emit((state as AttendanceCorrectionInitial).copyWith(clearAttachment: true));
    }
  }

  Future<void> submitCorrection({
    required String shiftInstanceId,
    String? sourceEventId,
    required String correctionKind,
    DateTime? proposedAt,
    DateTime? proposedCheckInAt,
    DateTime? proposedCheckOutAt,
    required String reason,
    String? evidenceAttachmentId,
    String? clientRequestId,
  }) async {
    if (isClosed) return;
    emit(const AttendanceCorrectionSubmitting());

    final id = clientRequestId ?? _uuid.v4();
    final payload = <String, dynamic>{
      'shiftInstanceId': shiftInstanceId,
      if (sourceEventId != null) 'sourceEventId': sourceEventId,
      'correctionKind': correctionKind,
      if (proposedAt != null)
        'proposedAt': proposedAt.toUtc().toIso8601String(),
      if (proposedCheckInAt != null)
        'proposedCheckInAt': proposedCheckInAt.toUtc().toIso8601String(),
      if (proposedCheckOutAt != null)
        'proposedCheckOutAt': proposedCheckOutAt.toUtc().toIso8601String(),
      if (evidenceAttachmentId != null)
        'evidenceAttachmentId': evidenceAttachmentId,
      'reason': reason,
    };

    try {
      final result = await _repository.submitRequest(
        requestId: id,
        type: RequestType.attendanceCorrection,
        payload: payload,
      );

      final isOffline = result.state == RequestState.pendingSync;
      if (isClosed) return;
      emit(AttendanceCorrectionSuccess(
        request: result,
        isQueuedOffline: isOffline,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      emit(AttendanceCorrectionError(
        message: failure.message,
        isConflict: isConflict,
      ));
    }
  }
}
