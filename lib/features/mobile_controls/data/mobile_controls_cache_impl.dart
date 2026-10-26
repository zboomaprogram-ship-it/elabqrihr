import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';

class MobileControlsCacheImpl implements MobileControlsCachePort {
  final FlutterSecureStorage _storage;

  const MobileControlsCacheImpl([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static String _storageKey(String tenantId, String userId) =>
      'attend_mobile_controls_${tenantId}_$userId';

  @override
  Future<MobileOperationalConfiguration?> getCached({
    required String tenantId,
    required String userId,
  }) async {
    try {
      final raw = await _storage.read(key: _storageKey(tenantId, userId));
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final config = MobileOperationalConfiguration.fromMap(decoded);
      // Discard expired cache
      if (config.isExpired()) {
        await clear(tenantId: tenantId, userId: userId);
        return null;
      }
      return config;
    } catch (_) {
      // Corrupt or invalid schema is safely discarded
      await clear(tenantId: tenantId, userId: userId);
      return null;
    }
  }

  @override
  Future<void> save({
    required String tenantId,
    required String userId,
    required MobileOperationalConfiguration config,
  }) async {
    try {
      final encoded = jsonEncode(config.toMap());
      await _storage.write(
        key: _storageKey(tenantId, userId),
        value: encoded,
      );
    } catch (_) {}
  }

  @override
  Future<void> clear({
    required String tenantId,
    required String userId,
  }) async {
    try {
      await _storage.delete(key: _storageKey(tenantId, userId));
    } catch (_) {}
  }
}
