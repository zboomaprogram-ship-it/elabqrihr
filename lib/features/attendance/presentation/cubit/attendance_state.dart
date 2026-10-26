import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();

  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {
  const AttendanceInitial();
}

class AttendanceLoading extends AttendanceState {
  const AttendanceLoading();
}

class AttendanceReady extends AttendanceState {
  final ShiftContextEntity shiftContext;
  final GeoPoint? currentLocation;
  final bool isSubmitting;
  final bool isLocating;
  final String? locationError;
  final String? errorMessage;
  final List<AttendanceEventEntity> pendingEvents;

  const AttendanceReady({
    required this.shiftContext,
    this.currentLocation,
    this.isSubmitting = false,
    this.isLocating = false,
    this.locationError,
    this.errorMessage,
    this.pendingEvents = const [],
  });

  /// Computes approximate distance in meters to the assigned branch location.
  double? get distanceMeters =>
      currentLocation?.distanceTo(shiftContext.branchLocation);

  /// Advisory status of whether the device is within the work radius.
  /// Server decisions remain authoritative.
  bool? get isInsideGeofence => distanceMeters != null
      ? distanceMeters! <= shiftContext.allowedRadiusMeters
      : null;

  AttendanceReady copyWith({
    ShiftContextEntity? shiftContext,
    GeoPoint? currentLocation,
    bool clearCurrentLocation = false,
    bool? isSubmitting,
    bool? isLocating,
    String? locationError,
    bool clearLocationError = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<AttendanceEventEntity>? pendingEvents,
  }) {
    return AttendanceReady(
      shiftContext: shiftContext ?? this.shiftContext,
      currentLocation:
          clearCurrentLocation ? null : currentLocation ?? this.currentLocation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLocating: isLocating ?? this.isLocating,
      locationError:
          clearLocationError ? null : locationError ?? this.locationError,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      pendingEvents: pendingEvents ?? this.pendingEvents,
    );
  }

  @override
  List<Object?> get props => [
        shiftContext,
        currentLocation,
        isSubmitting,
        isLocating,
        locationError,
        errorMessage,
        pendingEvents,
      ];
}

class AttendanceSuccess extends AttendanceState {
  final AttendanceEventEntity event;
  final ShiftContextEntity shiftContext;

  const AttendanceSuccess({
    required this.event,
    required this.shiftContext,
  });

  @override
  List<Object?> get props => [event, shiftContext];
}

class AttendanceFailure extends AttendanceState {
  final String message;
  final String? code;

  const AttendanceFailure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}
