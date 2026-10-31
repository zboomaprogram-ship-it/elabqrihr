import 'dart:async';
import 'package:attend_mobile/core/database/local_attendance_outbox.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

class MemoryAttendanceOutbox implements LocalAttendanceOutbox {
  final Map<String, List<LocalOutboxRecord>> _storage = {};
  final _streamController =
      StreamController<Map<String, List<LocalOutboxRecord>>>.broadcast();

  String _key(String tenantId, String userId) => '$tenantId:$userId';

  @override
  Future<void> saveEvent({
    required String tenantId,
    required String userId,
    required AttendanceEventEntity event,
  }) async {
    final key = _key(tenantId, userId);
    final list = _storage.putIfAbsent(key, () => []);

    final record = LocalOutboxRecord(
      id: event.id,
      tenantId: tenantId,
      userId: userId,
      shiftInstanceId: event.shiftInstanceId,
      eventType: event.eventType,
      capturedAt: event.capturedAt,
      location: event.location,
      deviceId: event.deviceId,
      syncStatus: AttendanceValidationStatus.pendingSync,
      reasonCode: event.reasonCode,
    );

    list.removeWhere((r) => r.id == event.id);
    list.add(record);
    _streamController.add(_storage);
  }

  @override
  Future<List<AttendanceEventEntity>> getPendingEvents({
    required String tenantId,
    required String userId,
    int? limit,
  }) async {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than zero');
    }
    final key = _key(tenantId, userId);
    final list = _storage[key] ?? [];
    return list
        .where((r) => r.syncStatus == AttendanceValidationStatus.pendingSync)
        .map((r) => r.toDomain())
        .take(limit ?? 0x7fffffff)
        .toList();
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents({
    required String tenantId,
    required String userId,
  }) {
    final key = _key(tenantId, userId);
    return _streamController.stream.map((storage) {
      final list = storage[key] ?? [];
      return list
          .where((r) => r.syncStatus == AttendanceValidationStatus.pendingSync)
          .map((r) => r.toDomain())
          .toList();
    });
  }

  @override
  Future<void> updateEventStatus({
    required String tenantId,
    required String userId,
    required String eventId,
    required AttendanceValidationStatus status,
    String? reasonCode,
    bool isRetryAttempt = false,
    DateTime? nextRetryAt,
  }) async {
    final key = _key(tenantId, userId);
    final list = _storage[key];
    if (list != null) {
      final index = list.indexWhere((r) => r.id == eventId);
      if (index != -1) {
        final old = list[index];
        list[index] = LocalOutboxRecord(
          id: old.id,
          tenantId: old.tenantId,
          userId: old.userId,
          shiftInstanceId: old.shiftInstanceId,
          eventType: old.eventType,
          capturedAt: old.capturedAt,
          location: old.location,
          deviceId: old.deviceId,
          syncStatus: status,
          reasonCode: reasonCode ?? old.reasonCode,
          retryCount: isRetryAttempt ? old.retryCount + 1 : old.retryCount,
          nextRetryAt: nextRetryAt,
        );
        _streamController.add(_storage);
      }
    }
  }

  void dispose() {
    _streamController.close();
  }
}
