import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

abstract class RequestFormState extends Equatable {
  const RequestFormState();

  @override
  List<Object?> get props => [];
}

class RequestFormInitial extends RequestFormState {
  final List<LeaveBalanceEntity> balances;
  final List<EmployeeShiftEntity> shifts;
  final bool balancesLoading;
  final bool shiftsLoading;
  final String? balanceError;
  final String? shiftError;

  const RequestFormInitial({
    this.balances = const [],
    this.shifts = const [],
    this.balancesLoading = false,
    this.shiftsLoading = false,
    this.balanceError,
    this.shiftError,
  });

  @override
  List<Object?> get props => [
        balances,
        shifts,
        balancesLoading,
        shiftsLoading,
        balanceError,
        shiftError
      ];
}

class RequestFormSubmitting extends RequestFormState {
  const RequestFormSubmitting();
}

class RequestFormSuccess extends RequestFormState {
  final RequestEntity request;
  final bool isQueuedOffline;

  const RequestFormSuccess({
    required this.request,
    this.isQueuedOffline = false,
  });

  @override
  List<Object?> get props => [request, isQueuedOffline];
}

class RequestFormError extends RequestFormState {
  final String message;
  final bool isConflict;

  const RequestFormError({
    required this.message,
    this.isConflict = false,
  });

  @override
  List<Object?> get props => [message, isConflict];
}

class RequestFormCubit extends Cubit<RequestFormState> {
  final RequestRepository _repository;
  final EmployeeShiftRepository? _shiftRepository;
  final Uuid _uuid = const Uuid();
  List<LeaveBalanceEntity> _balances = const [];
  List<EmployeeShiftEntity> _shifts = const [];

  RequestFormCubit({
    required RequestRepository repository,
    EmployeeShiftRepository? shiftRepository,
  })  : _repository = repository,
        _shiftRepository = shiftRepository,
        super(const RequestFormInitial());

  Future<void> loadBalances() async {
    if (isClosed) return;
    emit(RequestFormInitial(
        balances: _balances, shifts: _shifts, balancesLoading: true));
    try {
      _balances = await _repository.getMyLeaveBalances();
      if (isClosed) return;
      emit(RequestFormInitial(balances: _balances, shifts: _shifts));
    } catch (_) {
      if (isClosed) return;
      emit(RequestFormInitial(
        balances: _balances,
        shifts: _shifts,
        balanceError:
            'تعذر تحميل أنواع وأرصدة الإجازات. تحقق من الاتصال ثم أعد المحاولة.',
      ));
    }
  }

  Future<void> loadShiftInstances({
    required String startDate,
    required String endDate,
  }) async {
    if (isClosed) return;
    emit(RequestFormInitial(
        balances: _balances, shifts: _shifts, shiftsLoading: true));
    final repository = _shiftRepository;
    if (repository == null) {
      if (isClosed) return;
      emit(RequestFormInitial(
        balances: _balances,
        shifts: _shifts,
        shiftError: 'سجل الورديات غير متاح حالياً.',
      ));
      return;
    }
    try {
      _shifts = await repository.listMyShiftInstances(
        startDate: startDate,
        endDate: endDate,
      );
      if (isClosed) return;
      emit(RequestFormInitial(balances: _balances, shifts: _shifts));
    } catch (_) {
      if (isClosed) return;
      emit(RequestFormInitial(
        balances: _balances,
        shifts: _shifts,
        shiftError:
            'تعذر تحميل الورديات السابقة. تحقق من الاتصال ثم أعد المحاولة.',
      ));
    }
  }

  Future<void> submitLeaveRequest({
    required String categoryId,
    required String startDate,
    required String endDate,
    String? partialStartTime,
    String? partialEndTime,
    required String reason,
    String? clientRequestId,
  }) async {
    if (isClosed) return;
    emit(const RequestFormSubmitting());

    final id = clientRequestId ?? _uuid.v4();
    final payload = <String, dynamic>{
      'categoryId': categoryId,
      'startDate': startDate,
      'endDate': endDate,
      if (partialStartTime != null && partialStartTime.isNotEmpty)
        'partialStartTime': partialStartTime,
      if (partialEndTime != null && partialEndTime.isNotEmpty)
        'partialEndTime': partialEndTime,
      'reason': reason,
    };

    try {
      final result = await _repository.submitRequest(
        requestId: id,
        type: RequestType.leave,
        payload: payload,
      );

      final isOffline = result.state == RequestState.pendingSync;
      if (isClosed) return;
      emit(RequestFormSuccess(
        request: result,
        isQueuedOffline: isOffline,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      emit(RequestFormError(message: failure.message, isConflict: isConflict));
    }
  }

  Future<void> submitPermissionRequest({
    required String shiftInstanceId,
    required String categoryCode,
    required DateTime startsAt,
    required DateTime endsAt,
    required String reason,
    String? clientRequestId,
  }) async {
    if (isClosed) return;
    emit(const RequestFormSubmitting());

    final id = clientRequestId ?? _uuid.v4();
    final payload = <String, dynamic>{
      'shiftInstanceId': shiftInstanceId,
      'categoryCode': categoryCode,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'endsAt': endsAt.toUtc().toIso8601String(),
      'reason': reason,
    };

    try {
      final result = await _repository.submitRequest(
        requestId: id,
        type: RequestType.permission,
        payload: payload,
      );

      final isOffline = result.state == RequestState.pendingSync;
      if (isClosed) return;
      emit(RequestFormSuccess(
        request: result,
        isQueuedOffline: isOffline,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      emit(RequestFormError(message: failure.message, isConflict: isConflict));
    }
  }

  Future<void> submitAttendanceCorrection({
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
    emit(const RequestFormSubmitting());

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
      emit(RequestFormSuccess(
        request: result,
        isQueuedOffline: isOffline,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      emit(RequestFormError(message: failure.message, isConflict: isConflict));
    }
  }
}
