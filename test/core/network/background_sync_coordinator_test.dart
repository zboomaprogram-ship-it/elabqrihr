import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/network/background_sync_coordinator.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

class MockAttendanceRepository extends Mock implements AttendanceRepository {}

class MockRequestRepository extends Mock implements RequestRepository {}

class MockBackgroundSyncScheduler extends Mock
    implements BackgroundSyncScheduler {}

void main() {
  late MockAttendanceRepository attendanceRepo;
  late MockRequestRepository requestRepo;
  late MockBackgroundSyncScheduler scheduler;
  late BackgroundSyncCoordinator coordinator;

  setUp(() {
    attendanceRepo = MockAttendanceRepository();
    requestRepo = MockRequestRepository();
    scheduler = MockBackgroundSyncScheduler();

    coordinator = BackgroundSyncCoordinator(
      attendanceRepository: attendanceRepo,
      requestRepository: requestRepo,
      scheduler: scheduler,
    );
  });

  group('Feature 012 Task T063: BackgroundSyncCoordinator Tests', () {
    test(
        'synchronizeAll triggers attendance and request outbox synchronization',
        () async {
      when(() => attendanceRepo.synchronizeOutbox()).thenAnswer((_) async {});
      when(() => requestRepo.synchronizeOutbox()).thenAnswer((_) async {});

      await coordinator.synchronizeAll();

      verify(() => attendanceRepo.synchronizeOutbox()).called(1);
      verify(() => requestRepo.synchronizeOutbox()).called(1);
    });

    test('concurrent synchronizeAll calls are deduplicated (re-entrant guard)',
        () async {
      var attendanceSyncCalls = 0;
      when(() => attendanceRepo.synchronizeOutbox()).thenAnswer((_) async {
        attendanceSyncCalls++;
        await Future.delayed(const Duration(milliseconds: 50));
      });
      when(() => requestRepo.synchronizeOutbox()).thenAnswer((_) async {});

      // Launch two concurrent synchronizations
      final future1 = coordinator.synchronizeAll();
      final future2 = coordinator.synchronizeAll();

      await Future.wait([future1, future2]);

      expect(attendanceSyncCalls, equals(1));
    });

    test(
        'onSessionAuthenticated schedules WorkManager job with tenant and user IDs',
        () async {
      when(() => scheduler.scheduleForIdentity(
            tenantId: any(named: 'tenantId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      await coordinator.onSessionAuthenticated(
        tenantId: 'tenant-demo',
        userId: 'user-emp-01',
      );

      verify(() => scheduler.scheduleForIdentity(
            tenantId: 'tenant-demo',
            userId: 'user-emp-01',
          )).called(1);
    });

    test('onSessionRevoked cancels WorkManager job for identity', () async {
      when(() => scheduler.cancelForIdentity(
            tenantId: any(named: 'tenantId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      await coordinator.onSessionRevoked(
        tenantId: 'tenant-demo',
        userId: 'user-emp-01',
      );

      verify(() => scheduler.cancelForIdentity(
            tenantId: 'tenant-demo',
            userId: 'user-emp-01',
          )).called(1);
    });
  });
}
