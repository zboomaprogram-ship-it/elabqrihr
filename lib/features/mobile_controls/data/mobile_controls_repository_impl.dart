import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';

class MobileControlsRepositoryImpl implements MobileControlsRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final MobileControlsCachePort _cache;

  MobileOperationalConfiguration _currentConfiguration;

  MobileControlsRepositoryImpl({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required MobileControlsCachePort cache,
    MobileOperationalConfiguration? initialConfiguration,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _cache = cache,
        _currentConfiguration = initialConfiguration ??
            MobileOperationalConfiguration.defaultRestrictive();

  @override
  MobileOperationalConfiguration get currentConfiguration =>
      _currentConfiguration;

  @override
  Future<MobileOperationalConfiguration> getConfiguration({
    bool forceRefresh = false,
  }) async {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      return _currentConfiguration;
    }

    // 1. Return in-memory if fresh and not forced
    if (!forceRefresh &&
        !_currentConfiguration.isExpired() &&
        _currentConfiguration.version != '1') {
      return _currentConfiguration;
    }

    // 2. Check local secure cache
    final cached = await _cache.getCached(
      tenantId: session.tenantId,
      userId: session.userId,
    );

    if (!forceRefresh && cached != null && !cached.isExpired()) {
      _currentConfiguration = cached;
      return cached;
    }

    // 3. Fetch from server
    try {
      final json = await _apiClient.getMobileOperationalConfiguration();
      final fresh = MobileOperationalConfiguration.fromMap(json);

      await _cache.save(
        tenantId: session.tenantId,
        userId: session.userId,
        config: fresh,
      );

      _currentConfiguration = fresh;
      return fresh;
    } catch (_) {
      // 4. On network or server failure: fall back to cached (even if stale) or current
      if (cached != null) {
        _currentConfiguration = cached;
        return cached;
      }
      return _currentConfiguration;
    }
  }

  @override
  Future<bool> isActionAllowed(MobileControlKey key) async {
    // If current configuration is expired, attempt a background refresh
    if (_currentConfiguration.isExpired()) {
      await getConfiguration();
    }
    return _currentConfiguration.isActionAllowed(key);
  }

  @override
  Future<MobileControlEntry?> getControl(MobileControlKey key) async {
    if (_currentConfiguration.isExpired()) {
      await getConfiguration();
    }
    return _currentConfiguration.getControl(key);
  }
}
