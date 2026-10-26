import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';

abstract interface class MobileControlsRepository {
  /// Returns the current configuration, refreshing from API if expired or forced.
  /// Falls back safely to tenant/user cached configuration or shipped conservative defaults.
  Future<MobileOperationalConfiguration> getConfiguration({
    bool forceRefresh = false,
  });

  /// Quick check whether a specific action is currently permitted on mobile.
  Future<bool> isActionAllowed(MobileControlKey key);

  /// Returns the control entry for the requested action key, or null if unconfigured.
  Future<MobileControlEntry?> getControl(MobileControlKey key);

  /// Synchronous snapshot of the last known configuration.
  MobileOperationalConfiguration get currentConfiguration;
}

abstract interface class MobileControlsCachePort {
  /// Retrieves cached configuration for the specific tenant and user identity.
  Future<MobileOperationalConfiguration?> getCached({
    required String tenantId,
    required String userId,
  });

  /// Persists schema-valid configuration scoped to the tenant and user identity.
  Future<void> save({
    required String tenantId,
    required String userId,
    required MobileOperationalConfiguration config,
  });

  /// Clears cached configuration on logout or identity invalidation.
  Future<void> clear({
    required String tenantId,
    required String userId,
  });
}
