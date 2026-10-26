import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_models.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_repository.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_scheduler.dart';
import 'package:attend_mobile/features/attendance_reminders/data/attendance_reminder_coordinator.dart';

class MockReminderRepository extends Mock implements ReminderRepository {}

class MockReminderScheduler extends Mock implements ReminderScheduler {}

void main() {
  late MockReminderRepository mockRepository;
  late MockReminderScheduler mockScheduler;
  late DateTime fixedNow;
  late AttendanceReminderCoordinator coordinator;

  setUpAll(() {
    registerFallbackValue(
      ScheduledReminderInstance(
        notificationId: 1,
        deterministicKey: 'dummy',
        category: ReminderCategory.shiftStart,
        scheduledAt: DateTime.utc(2026, 1, 1),
        titleAr: 'dummy',
        bodyAr: 'dummy',
      ),
    );
    registerFallbackValue(const ReminderPreferences());
  });

  setUp(() {
    mockRepository = MockReminderRepository();
    mockScheduler = MockReminderScheduler();
    fixedNow = DateTime.utc(2026, 10, 18, 8, 0);

    coordinator = AttendanceReminderCoordinator(
      repository: mockRepository,
      scheduler: mockScheduler,
      clock: () => fixedNow,
    );
  });

  group('AttendanceReminderCoordinator Unit Tests (T041)', () {
    test(
        'generateNotificationId produces deterministic positive 31-bit integers',
        () {
      final id1 = AttendanceReminderCoordinator.generateNotificationId(
          'shift_start_uuid1_1');
      final id2 = AttendanceReminderCoordinator.generateNotificationId(
          'shift_start_uuid1_1');
      final id3 = AttendanceReminderCoordinator.generateNotificationId(
          'shift_start_uuid2_1');

      expect(id1, equals(id2));
      expect(id1, isNot(equals(id3)));
      expect(id1, isNonNegative);
      expect(id1, lessThan(0x7FFFFFFF));
    });

    test('reconcile does nothing when notification permission is denied',
        () async {
      when(() => mockScheduler.hasPermission()).thenAnswer((_) async => false);
      when(() => mockRepository.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          shiftStartEnabled: true,
          permissionGranted: true,
        ),
      );
      when(() => mockRepository.savePreferences(any()))
          .thenAnswer((_) async {});

      await coordinator.reconcile();

      verify(() => mockScheduler.hasPermission()).called(1);
      verifyNever(() => mockRepository.getReminderFeed());
      verifyNever(() => mockScheduler.schedule(any()));
      verify(() => mockRepository.savePreferences(
            const ReminderPreferences(
              shiftStartEnabled: true,
              permissionGranted: false,
            ),
          )).called(1);
    });

    test('reconcile cancels all when all reminder toggles are disabled',
        () async {
      when(() => mockScheduler.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRepository.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          shiftStartEnabled: false,
          checkoutEnabled: false,
          permissionReturnEnabled: false,
        ),
      );
      when(() => mockScheduler.cancelAll()).thenAnswer((_) async {});
      when(() => mockRepository.savePreferences(any()))
          .thenAnswer((_) async {});

      await coordinator.reconcile();

      verify(() => mockScheduler.cancelAll()).called(1);
      verifyNever(() => mockRepository.getReminderFeed());
      verifyNever(() => mockScheduler.schedule(any()));
    });

    test('schedules shift start, checkout, and permission return when enabled',
        () async {
      when(() => mockScheduler.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRepository.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          shiftStartEnabled: true,
          shiftStartLeadMinutes: 30,
          checkoutEnabled: true,
          permissionReturnEnabled: true,
          permissionReturnLeadMinutes: 10,
        ),
      );

      final feed = ReminderFeed(
        feedRevision: 'rev-1',
        generatedAt: fixedNow,
        timezone: 'Africa/Cairo',
        items: [
          // Shift start at 9:00 -> should be scheduled at 8:30 (fixedNow is 8:00)
          ReminderFeedItem(
            sourceKind: ReminderSourceKind.shift,
            sourceId: 'shift-100',
            sourceRevision: 1,
            category: ReminderCategory.shiftStart,
            scheduledFor: DateTime.utc(2026, 10, 18, 9, 0),
            eligible: true,
          ),
          // Checkout at 17:00 -> should be scheduled at 17:00
          ReminderFeedItem(
            sourceKind: ReminderSourceKind.shift,
            sourceId: 'shift-100',
            sourceRevision: 1,
            category: ReminderCategory.checkout,
            scheduledFor: DateTime.utc(2026, 10, 18, 17, 0),
            eligible: true,
          ),
          // Permission return at 12:00 -> should be scheduled at 11:50
          ReminderFeedItem(
            sourceKind: ReminderSourceKind.permission,
            sourceId: 'perm-200',
            sourceRevision: 2,
            category: ReminderCategory.permissionReturn,
            scheduledFor: DateTime.utc(2026, 10, 18, 12, 0),
            eligible: true,
          ),
        ],
      );

      when(() => mockRepository.getReminderFeed())
          .thenAnswer((_) async => feed);
      when(() => mockScheduler.schedule(any())).thenAnswer((_) async {});
      when(() => mockRepository.savePreferences(any()))
          .thenAnswer((_) async {});

      await coordinator.reconcile();

      // Check scheduled instances
      final captured = verify(() => mockScheduler.schedule(captureAny()))
          .captured
          .cast<ScheduledReminderInstance>();

      expect(captured.length, equals(3));

      // 1. Shift start 30 min before
      expect(captured[0].category, equals(ReminderCategory.shiftStart));
      expect(
          captured[0].scheduledAt, equals(DateTime.utc(2026, 10, 18, 8, 30)));
      expect(captured[0].titleAr, contains('تنبيه موعد الوردية'));

      // 2. Checkout
      expect(captured[1].category, equals(ReminderCategory.checkout));
      expect(
          captured[1].scheduledAt, equals(DateTime.utc(2026, 10, 18, 17, 0)));
      expect(captured[1].titleAr, contains('تذكير تسجيل الانصراف'));

      // 3. Permission return 10 min before
      expect(captured[2].category, equals(ReminderCategory.permissionReturn));
      expect(
          captured[2].scheduledAt, equals(DateTime.utc(2026, 10, 18, 11, 50)));
      expect(captured[2].titleAr, contains('تنبيه استئناف العمل'));
    });

    test('cancels notification when feed item is ineligible or in the past',
        () async {
      when(() => mockScheduler.hasPermission()).thenAnswer((_) async => true);
      when(() => mockRepository.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          shiftStartEnabled: true,
          shiftStartLeadMinutes: 15,
        ),
      );

      final feed = ReminderFeed(
        feedRevision: 'rev-2',
        generatedAt: fixedNow,
        timezone: 'Africa/Cairo',
        items: [
          // Ineligible item
          ReminderFeedItem(
            sourceKind: ReminderSourceKind.shift,
            sourceId: 'shift-ineligible',
            sourceRevision: 1,
            category: ReminderCategory.shiftStart,
            scheduledFor: DateTime.utc(2026, 10, 18, 9, 0),
            eligible: false,
          ),
          // Past item (scheduledFor is 7:30, fixedNow is 8:00)
          ReminderFeedItem(
            sourceKind: ReminderSourceKind.shift,
            sourceId: 'shift-past',
            sourceRevision: 1,
            category: ReminderCategory.shiftStart,
            scheduledFor: DateTime.utc(2026, 10, 18, 7, 30),
            eligible: true,
          ),
        ],
      );

      when(() => mockRepository.getReminderFeed())
          .thenAnswer((_) async => feed);
      when(() => mockScheduler.cancel(any())).thenAnswer((_) async {});
      when(() => mockRepository.savePreferences(any()))
          .thenAnswer((_) async {});

      await coordinator.reconcile();

      verifyNever(() => mockScheduler.schedule(any()));
      verify(() => mockScheduler.cancel(any())).called(2);
    });

    test(
        'onSignOutOrTenantSwitch cancels all notifications and clears preferences',
        () async {
      when(() => mockScheduler.cancelAll()).thenAnswer((_) async {});
      when(() => mockRepository.clearPreferences()).thenAnswer((_) async {});

      await coordinator.onSignOutOrTenantSwitch();

      verify(() => mockScheduler.cancelAll()).called(1);
      verify(() => mockRepository.clearPreferences()).called(1);
    });

    test('onCheckoutRecorded cancels pending checkout reminder for the shift',
        () async {
      const shiftId = 'shift-abc-123';
      final activeId = AttendanceReminderCoordinator.generateNotificationId(
          'checkout_${shiftId}_1');

      when(() => mockScheduler.getPendingNotificationIds())
          .thenAnswer((_) async => [activeId, 99999]);
      when(() => mockScheduler.cancel(activeId)).thenAnswer((_) async {});

      await coordinator.onCheckoutRecorded(shiftId);

      verify(() => mockScheduler.cancel(activeId)).called(1);
    });
  });
}
