import 'dart:async';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

class LocalOutboxRecord {
  final String id;
  final String tenantId;
  final String userId;
  final String shiftInstanceId;
  final AttendanceEventType eventType;
  final DateTime capturedAt;
  final GeoPoint location;
  final String? deviceId;
  final AttendanceValidationStatus syncStatus;
  final String? reasonCode;
  final int retryCount;
  final DateTime? nextRetryAt;

  const LocalOutboxRecord({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.shiftInstanceId,
    required this.eventType,
    required this.capturedAt,
    required this.location,
    this.deviceId,
    required this.syncStatus,
    this.reasonCode,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  AttendanceEventEntity toDomain() {
    return AttendanceEventEntity(
      id: id,
      eventType: eventType,
      capturedAt: capturedAt,
      location: location,
      shiftInstanceId: shiftInstanceId,
      deviceId: deviceId,
      status: syncStatus,
      reasonCode: reasonCode,
    );
  }
}

abstract class LocalAttendanceOutbox {
  Future<void> saveEvent({
    required String tenantId,
    required String userId,
    required AttendanceEventEntity event,
  });

  Future<List<AttendanceEventEntity>> getPendingEvents({
    required String tenantId,
    required String userId,
  });

  Stream<List<AttendanceEventEntity>> watchPendingEvents({
    required String tenantId,
    required String userId,
  });

  Future<void> updateEventStatus({
    required String tenantId,
    required String userId,
    required String eventId,
    required AttendanceValidationStatus status,
    String? reasonCode,
    bool isRetryAttempt = false,
    DateTime? nextRetryAt,
  });
}
