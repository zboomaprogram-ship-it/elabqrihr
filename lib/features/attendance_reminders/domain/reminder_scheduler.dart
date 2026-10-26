import 'reminder_models.dart';

/// Platform-agnostic port for scheduling, cancelling, and delivering local reminders.
abstract class ReminderScheduler {
  /// Schedules a local notification at [instance.scheduledAt].
  Future<void> schedule(ScheduledReminderInstance instance);

  /// Cancels a scheduled local notification by ID.
  Future<void> cancel(int notificationId);

  /// Cancels all pending notifications managed by this scheduler.
  Future<void> cancelAll();

  /// Returns the set of currently active notification IDs.
  Future<List<int>> getPendingNotificationIds();

  /// Checks if system notification permission is currently granted.
  Future<bool> hasPermission();

  /// Requests notification permission from the system.
  Future<bool> requestPermission();

  /// Shows an immediate test notification with standard gentle sound.
  Future<void> showTestNotification({
    required String titleAr,
    required String bodyAr,
  });
}
