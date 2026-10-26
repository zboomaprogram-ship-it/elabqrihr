import 'attendance_models.dart';

abstract class AttendanceRepository {
  /// Fetches the current employee attendance and shift context.
  Future<ShiftContextEntity> getCurrentShiftContext();

  /// Submits an attendance event (check-in or check-out).
  ///
  /// In offline scenarios, this saves to the local outbox first and returns
  /// a local AttendanceEventEntity with [AttendanceValidationStatus.pendingSync].
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  });

  /// Streams pending sync events for the active identity.
  Stream<List<AttendanceEventEntity>> watchPendingEvents();

  /// Triggers outbox synchronization when network connectivity is available.
  Future<void> synchronizeOutbox();
}

/// Interface for repositories capable of fresh foreground location capture.
abstract interface class HasCurrentLocationCapture {
  Future<GeoPoint> captureCurrentLocation();
}

extension AttendanceRepositoryLocationX on AttendanceRepository {
  /// Captures a fresh high-accuracy foreground device location.
  Future<GeoPoint> captureCurrentLocation() async {
    final self = this;
    if (self is HasCurrentLocationCapture) {
      return self.captureCurrentLocation();
    }
    final context = await getCurrentShiftContext();
    return context.branchLocation;
  }
}
