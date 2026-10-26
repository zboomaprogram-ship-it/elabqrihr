import '../domain/reminder_coordinator.dart';
import '../domain/reminder_models.dart';
import '../domain/reminder_repository.dart';
import '../domain/reminder_scheduler.dart';

class AttendanceReminderCoordinator implements ReminderCoordinator {
  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  AttendanceReminderCoordinator({
    required ReminderRepository repository,
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
  })  : _repository = repository,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.now;

  static int generateNotificationId(String key) {
    // Generate a positive 31-bit integer hash from the key
    var hash = 0;
    for (var i = 0; i < key.length; i++) {
      hash = (31 * hash + key.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  @override
  Future<void> reconcile() async {
    final hasPermission = await _scheduler.hasPermission();
    var prefs = await _repository.getPreferences();

    if (!hasPermission) {
      if (prefs.permissionGranted) {
        prefs = prefs.copyWith(permissionGranted: false);
        await _repository.savePreferences(prefs);
      }
      return;
    }

    final anyEnabled = prefs.shiftStartEnabled ||
        prefs.checkoutEnabled ||
        prefs.permissionReturnEnabled;

    if (!anyEnabled) {
      await _scheduler.cancelAll();
      await _repository.savePreferences(
        prefs.copyWith(
          lastSyncAt: _clock(),
          permissionGranted: true,
        ),
      );
      return;
    }

    final feed = await _repository.getReminderFeed();
    final now = _clock();

    for (final item in feed.items) {
      final notifId = generateNotificationId(item.deterministicKey);

      final (shouldSchedule, scheduledAt, titleAr, bodyAr) =
          _evaluateItem(item, prefs);

      if (shouldSchedule && scheduledAt != null && scheduledAt.isAfter(now)) {
        await _scheduler.schedule(
          ScheduledReminderInstance(
            notificationId: notifId,
            deterministicKey: item.deterministicKey,
            category: item.category,
            scheduledAt: scheduledAt,
            titleAr: titleAr,
            bodyAr: bodyAr,
          ),
        );
      } else {
        await _scheduler.cancel(notifId);
      }
    }

    await _repository.savePreferences(
      prefs.copyWith(
        lastSyncAt: _clock(),
        permissionGranted: true,
      ),
    );
  }

  (bool, DateTime?, String, String) _evaluateItem(
    ReminderFeedItem item,
    ReminderPreferences prefs,
  ) {
    if (!item.eligible) {
      return (false, null, '', '');
    }

    switch (item.category) {
      case ReminderCategory.shiftStart:
        if (!prefs.shiftStartEnabled) return (false, null, '', '');
        final lead = prefs.shiftStartLeadMinutes;
        final target = item.scheduledFor.subtract(Duration(minutes: lead));
        return (
          true,
          target,
          'تنبيه موعد الوردية',
          'تبدأ ورديتك خلال $lead دقيقة. تذكر تسجيل الحضور عند الوصول.',
        );

      case ReminderCategory.checkout:
        if (!prefs.checkoutEnabled) return (false, null, '', '');
        return (
          true,
          item.scheduledFor,
          'تذكير تسجيل الانصراف',
          'حان موعد نهاية ورديتك. نرجو تسجيل الانصراف قبل مغادرة الموقع.',
        );

      case ReminderCategory.permissionReturn:
        if (!prefs.permissionReturnEnabled) return (false, null, '', '');
        final lead = prefs.permissionReturnLeadMinutes;
        final target = item.scheduledFor.subtract(Duration(minutes: lead));
        return (
          true,
          target,
          'تنبيه استئناف العمل',
          'ينتهي وقت إذنك خلال $lead دقيقة. نرجو العودة واستئناف العمل.',
        );
    }
  }

  @override
  Future<void> onSignOutOrTenantSwitch() async {
    await _scheduler.cancelAll();
    await _repository.clearPreferences();
  }

  @override
  Future<void> onCheckoutRecorded(String shiftId) async {
    // When checkout is recorded, cancel any pending checkout reminder for this shift
    final keyPrefix = 'checkout_${shiftId}_';
    final activeIds = await _scheduler.getPendingNotificationIds();

    for (var rev = 1; rev <= 10; rev++) {
      final id = generateNotificationId('$keyPrefix$rev');
      if (activeIds.contains(id)) {
        await _scheduler.cancel(id);
      }
    }
  }

  @override
  Future<void> onTimezoneChanged() async {
    await reconcile();
  }
}
