import 'dart:math' as math;
import 'package:equatable/equatable.dart';

enum AttendanceEventType {
  checkIn,
  checkOut,
}

extension AttendanceEventTypeX on AttendanceEventType {
  String toApiValue() {
    switch (this) {
      case AttendanceEventType.checkIn:
        return 'check_in';
      case AttendanceEventType.checkOut:
        return 'check_out';
    }
  }

  static AttendanceEventType fromApiValue(String value) {
    switch (value) {
      case 'check_in':
        return AttendanceEventType.checkIn;
      case 'check_out':
        return AttendanceEventType.checkOut;
      default:
        throw ArgumentError('Unknown attendance event type: $value');
    }
  }
}

enum AttendanceValidationStatus {
  accepted,
  rejected,
  pendingReview,
  pendingSync, // Client-side local outbox state
  conflict, // Terminal HTTP 409 conflict
}

extension AttendanceValidationStatusX on AttendanceValidationStatus {
  String toApiValue() {
    switch (this) {
      case AttendanceValidationStatus.accepted:
        return 'accepted';
      case AttendanceValidationStatus.rejected:
        return 'rejected';
      case AttendanceValidationStatus.pendingReview:
        return 'pending_review';
      case AttendanceValidationStatus.pendingSync:
        return 'pending_sync';
      case AttendanceValidationStatus.conflict:
        return 'conflict';
    }
  }

  static AttendanceValidationStatus fromApiValue(String value) {
    switch (value) {
      case 'accepted':
        return AttendanceValidationStatus.accepted;
      case 'rejected':
        return AttendanceValidationStatus.rejected;
      case 'pending_review':
        return AttendanceValidationStatus.pendingReview;
      case 'pending_sync':
        return AttendanceValidationStatus.pendingSync;
      case 'conflict':
        return AttendanceValidationStatus.conflict;
      default:
        throw ArgumentError('Unknown validation status: $value');
    }
  }
}

class GeoPoint extends Equatable {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;
  final bool isMocked;

  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.timestamp,
    this.isMocked = false,
  });

  /// Computes approximate distance in meters to another [GeoPoint] using Haversine formula.
  double distanceTo(GeoPoint other) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? timestamp,
    bool? isMocked,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      timestamp: timestamp ?? this.timestamp,
      isMocked: isMocked ?? this.isMocked,
    );
  }

  @override
  List<Object?> get props =>
      [latitude, longitude, accuracyMeters, timestamp, isMocked];
}

class AttendanceEventEntity extends Equatable {
  final String id;
  final AttendanceEventType eventType;
  final DateTime capturedAt;
  final GeoPoint location;
  final String shiftInstanceId;
  final String? deviceId;
  final AttendanceValidationStatus status;
  final String? reasonCode;

  const AttendanceEventEntity({
    required this.id,
    required this.eventType,
    required this.capturedAt,
    required this.location,
    required this.shiftInstanceId,
    this.deviceId,
    required this.status,
    this.reasonCode,
  });

  AttendanceEventEntity copyWith({
    String? id,
    AttendanceEventType? eventType,
    DateTime? capturedAt,
    GeoPoint? location,
    String? shiftInstanceId,
    String? deviceId,
    AttendanceValidationStatus? status,
    String? reasonCode,
  }) {
    return AttendanceEventEntity(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      capturedAt: capturedAt ?? this.capturedAt,
      location: location ?? this.location,
      shiftInstanceId: shiftInstanceId ?? this.shiftInstanceId,
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      reasonCode: reasonCode ?? this.reasonCode,
    );
  }

  @override
  List<Object?> get props => [
        id,
        eventType,
        capturedAt,
        location,
        shiftInstanceId,
        deviceId,
        status,
        reasonCode,
      ];
}

class ShiftContextEntity extends Equatable {
  final String shiftInstanceId;
  final String branchName;
  final String? branchTimezone;
  final String shiftName;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final GeoPoint branchLocation;
  final double allowedRadiusMeters;
  final bool isCheckedIn;
  final bool isCompleted;
  final AttendanceEventEntity? lastEvent;

  const ShiftContextEntity({
    required this.shiftInstanceId,
    required this.branchName,
    this.branchTimezone,
    required this.shiftName,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.branchLocation,
    required this.allowedRadiusMeters,
    required this.isCheckedIn,
    this.isCompleted = false,
    this.lastEvent,
  });

  ShiftContextEntity copyWith({
    String? shiftInstanceId,
    String? branchName,
    String? branchTimezone,
    String? shiftName,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    GeoPoint? branchLocation,
    double? allowedRadiusMeters,
    bool? isCheckedIn,
    bool? isCompleted,
    AttendanceEventEntity? lastEvent,
  }) {
    return ShiftContextEntity(
      shiftInstanceId: shiftInstanceId ?? this.shiftInstanceId,
      branchName: branchName ?? this.branchName,
      branchTimezone: branchTimezone ?? this.branchTimezone,
      shiftName: shiftName ?? this.shiftName,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      branchLocation: branchLocation ?? this.branchLocation,
      allowedRadiusMeters: allowedRadiusMeters ?? this.allowedRadiusMeters,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      isCompleted: isCompleted ?? this.isCompleted,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }

  @override
  List<Object?> get props => [
        shiftInstanceId,
        branchName,
        branchTimezone,
        shiftName,
        scheduledStart,
        scheduledEnd,
        branchLocation,
        allowedRadiusMeters,
        isCheckedIn,
        isCompleted,
        lastEvent,
      ];
}
