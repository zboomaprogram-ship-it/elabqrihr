/// Contract for coordinating reminder feed synchronization and device scheduling.
abstract class ReminderCoordinator {
  /// Reconciles device scheduled notifications with the current feed and user preferences.
  Future<void> reconcile();

  /// Cancels all scheduled reminders and clears stored preferences on sign-out or tenant change.
  Future<void> onSignOutOrTenantSwitch();

  /// Called when attendance checkout is recorded locally to cancel pending checkout reminder.
  Future<void> onCheckoutRecorded(String shiftId);

  /// Called when device timezone changes to reschedule reminders in the new timezone.
  Future<void> onTimezoneChanged();
}
