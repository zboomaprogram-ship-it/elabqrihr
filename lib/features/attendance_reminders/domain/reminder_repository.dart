import 'reminder_models.dart';

/// Contract for loading reminder feeds and persisting client-side preferences.
abstract class ReminderRepository {
  /// Fetches the authoritative reminder feed from the server.
  Future<ReminderFeed> getReminderFeed({
    DateTime? from,
    DateTime? to,
  });

  /// Loads stored reminder preferences for the current tenant and user.
  Future<ReminderPreferences> getPreferences();

  /// Saves updated reminder preferences for the current tenant and user.
  Future<void> savePreferences(ReminderPreferences preferences);

  /// Clears stored preferences when signing out or switching tenants.
  Future<void> clearPreferences();
}
