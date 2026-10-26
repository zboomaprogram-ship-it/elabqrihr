import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

AttendanceEventEntity event({double latitude = 30.0444}) =>
    AttendanceEventEntity(
      id: 'c3d2f625-b42a-4c04-b263-eb84d95f61a7',
      eventType: AttendanceEventType.checkIn,
      capturedAt: DateTime.utc(2026, 10, 6, 8, 30),
      location: GeoPoint(
        latitude: latitude,
        longitude: 31.2357,
        accuracyMeters: 12,
      ),
      shiftInstanceId: '8c52084c-cb14-41d9-813a-773cefb180a0',
      status: AttendanceValidationStatus.pendingSync,
    );

void main() {
  test('canonical digest is stable across unchanged retry state', () {
    final first = AttendanceEvidenceService.canonicalDigest(event());
    final retry = AttendanceEvidenceService.canonicalDigest(
      event().copyWith(status: AttendanceValidationStatus.pendingSync),
    );

    expect(first, retry);
    expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
  });

  test('canonical digest changes when signed location data changes', () {
    expect(
      AttendanceEvidenceService.canonicalDigest(event()),
      isNot(AttendanceEvidenceService.canonicalDigest(event(latitude: 30.1))),
    );
  });
}
