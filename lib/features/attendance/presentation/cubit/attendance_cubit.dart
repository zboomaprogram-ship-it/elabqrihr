import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository? _repository;
  StreamSubscription<List<AttendanceEventEntity>>? _pendingSub;

  AttendanceCubit([this._repository]) : super(const AttendanceInitial());

  Future<void> loadShiftContext() async {
    if (_repository == null) return;
    if (isClosed) return;
    emit(const AttendanceLoading());
    try {
      final context = await _repository.getCurrentShiftContext();
      if (isClosed) return;
      emit(AttendanceReady(shiftContext: context));

      await _pendingSub?.cancel();
      _pendingSub = _repository.watchPendingEvents().listen((pendingList) {
        if (isClosed) return;
        final current = state;
        if (current is AttendanceReady) {
          emit(current.copyWith(pendingEvents: pendingList));
        }
      });
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(AttendanceFailure(message: failure.message, code: failure.code));
    }
  }

  void updateLocation(GeoPoint location) {
    if (isClosed) return;
    final current = state;
    if (current is AttendanceReady) {
      emit(current.copyWith(currentLocation: location));
    }
  }

  /// Obtains a fresh foreground location fix and updates the advisory status card.
  /// Does not submit an attendance event.
  Future<void> refreshLocation() async {
    final current = state;
    if (current is! AttendanceReady || _repository == null) return;
    if (current.isLocating) return;

    if (isClosed) return;
    emit(current.copyWith(
      isLocating: true,
      clearLocationError: true,
    ));

    try {
      final loc = await _repository.captureCurrentLocation();
      if (isClosed) return;
      final ready = state;
      if (ready is AttendanceReady) {
        emit(ready.copyWith(
          isLocating: false,
          currentLocation: loc,
          clearLocationError: true,
        ));
      }
    } catch (e) {
      if (isClosed) return;
      final ready = state;
      if (ready is AttendanceReady) {
        final errStr = e.toString().toLowerCase();
        String message;
        if (e.toString().contains('الموقع التقريبي')) {
          message = e.toString().replaceAll('Exception: ', '').replaceAll('PermissionDeniedException: ', '');
        } else if (errStr.contains('permissiondeniedforever') ||
            errStr.contains('permanently denied')) {
          message = AppStringsAr.locationPermissionPermanentlyDenied;
        } else if (errStr.contains('permissiondenied') ||
            errStr.contains('permission denied')) {
          message = AppStringsAr.locationPermissionRequired;
        } else if (errStr.contains('locationservicedisabled') ||
            errStr.contains('gps is disabled')) {
          message = AppStringsAr.locationServiceDisabled;
        } else if (errStr.contains('timeout')) {
          message = AppStringsAr.locationTimeout;
        } else if (errStr.contains('mocklocationdetected')) {
          message = AppStringsAr.locationIntegrityFailed;
        } else {
          message = 'تعذر تحديد موقعك بدقة. يرجى تفعيل GPS والمحاولة مجدداً.';
        }
        emit(ready.copyWith(
          isLocating: false,
          locationError: message,
        ));
      }
    }
  }

  Future<void> recordEvent({
    required AttendanceEventType eventType,
  }) async {
    final current = state;
    if (current is! AttendanceReady ||
        current.isSubmitting ||
        _repository == null) {
      return;
    }

    if (isClosed) return;
    emit(current.copyWith(isSubmitting: true, clearErrorMessage: true));

    try {
      // Passes current location if already cached, or delegates to locationService in repository
      final event = await _repository.submitAttendanceEvent(
        eventType: eventType,
        shiftInstanceId: current.shiftContext.shiftInstanceId,
        location: current.currentLocation,
      );

      // A terminal decision and an offline queue result must be shown even if
      // a follow-up context refresh cannot run (for example, no assignment is
      // exactly the reason the server rejected the command).
      final updatedContext = event.status == AttendanceValidationStatus.accepted
          ? (await _repository.getCurrentShiftContext())
              .copyWith(lastEvent: event)
          : current.shiftContext.copyWith(lastEvent: event);

      if (isClosed) return;
      emit(AttendanceSuccess(event: event, shiftContext: updatedContext));
      emit(AttendanceReady(
        shiftContext: updatedContext,
        currentLocation: event.location,
        isSubmitting: false,
      ));
    } catch (e) {
      if (isClosed) return;
      final errStr = e.toString().toLowerCase();
      String message;
      if (e.toString().contains('الموقع التقريبي')) {
        message = e.toString().replaceAll('Exception: ', '').replaceAll('PermissionDeniedException: ', '');
      } else if (errStr.contains('permissiondeniedforever') ||
          errStr.contains('permanently denied')) {
        message = AppStringsAr.locationPermissionPermanentlyDenied;
      } else if (errStr.contains('permissiondenied') ||
          errStr.contains('permission denied')) {
        message = AppStringsAr.locationPermissionRequired;
      } else if (errStr.contains('locationservicedisabled') ||
          errStr.contains('gps is disabled')) {
        message = AppStringsAr.locationServiceDisabled;
      } else if (errStr.contains('timeout')) {
        message = AppStringsAr.locationTimeout;
      } else if (errStr.contains('mocklocationdetected')) {
        message = AppStringsAr.locationIntegrityFailed;
      } else {
        message = AppFailureMapper.fromGeneric(e).message;
      }
      emit(current.copyWith(
        isSubmitting: false,
        errorMessage: message,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _pendingSub?.cancel();
    return super.close();
  }
}
