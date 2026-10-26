import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

class TokenStorage {
  final FlutterSecureStorage _storage;

  static const _keySession = 'attend_auth_session';
  static const _keyLastTenantSlug = 'attend_last_tenant_slug';
  static const _keyOfflineDatabaseKey = 'attend_offline_database_key_v1';

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveSession(AuthSessionEntity session) async {
    final data = {
      'accessToken': session.accessToken,
      'refreshToken': session.refreshToken,
      'tenantId': session.tenantId,
      'userId': session.userId,
      'role': session.role.toApi(),
      'email': session.email,
      'displayName': session.displayName,
    };
    await _storage.write(key: _keySession, value: jsonEncode(data));
  }

  Future<AuthSessionEntity?> getSession() async {
    final value = await _storage.read(key: _keySession);
    if (value == null) return null;
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      return AuthSessionEntity(
        accessToken: map['accessToken'] as String,
        refreshToken: map['refreshToken'] as String?,
        tenantId: map['tenantId'] as String,
        userId: map['userId'] as String,
        role: UserRoleX.fromApi(map['role'] as String),
        email: map['email'] as String,
        displayName: map['displayName'] as String,
      );
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _keySession);
  }

  /// Stores the last successfully used company identifier for this device.
  ///
  /// This is deliberately separate from the authenticated session: logging out
  /// removes tokens, while keeping the company selection makes the next sign-in
  /// less error prone. It contains no credential or personal data.
  Future<void> saveLastTenantSlug(String tenantSlug) async {
    final normalized = tenantSlug.trim().toLowerCase();
    if (normalized.isEmpty) return;
    await _storage.write(key: _keyLastTenantSlug, value: normalized);
  }

  Future<String?> getLastTenantSlug() async {
    final value = await _storage.read(key: _keyLastTenantSlug);
    final normalized = value?.trim().toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> clearLastTenantSlug() async {
    await _storage.delete(key: _keyLastTenantSlug);
  }

  /// Returns the per-installation key used to encrypt the local outbox.
  ///
  /// The key is generated once and held by the platform-backed secure storage
  /// (Android Keystore on Android). It is deliberately independent of the
  /// authenticated identity so a pending event remains readable after an app
  /// restart, but never leaves the device as part of API traffic or backups.
  Future<String> getOrCreateOfflineDatabaseKey() async {
    final existing = await _storage.read(key: _keyOfflineDatabaseKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes);
    await _storage.write(key: _keyOfflineDatabaseKey, value: generated);
    return generated;
  }

  static const _keyDeviceInstallationRegistrations =
      'attend_device_installation_registrations_v1';

  Future<void> saveDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
    required String installationId,
  }) async {
    final raw = await _storage.read(key: _keyDeviceInstallationRegistrations);
    final values = <String, dynamic>{};
    if (raw != null) {
      try {
        values.addAll(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt local metadata is replaced. It contains no credential.
      }
    }
    values['$tenantId:$userId'] = installationId;
    await _storage.write(
      key: _keyDeviceInstallationRegistrations,
      value: jsonEncode(values),
    );
  }

  Future<String?> getDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
  }) async {
    final raw = await _storage.read(key: _keyDeviceInstallationRegistrations);
    if (raw == null) return null;
    try {
      final values = jsonDecode(raw) as Map<String, dynamic>;
      final value = values['$tenantId:$userId'];
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
  }) async {
    final raw = await _storage.read(key: _keyDeviceInstallationRegistrations);
    if (raw == null) return;
    try {
      final values = jsonDecode(raw) as Map<String, dynamic>;
      values.remove('$tenantId:$userId');
      await _storage.write(
        key: _keyDeviceInstallationRegistrations,
        value: jsonEncode(values),
      );
    } catch (_) {
      await _storage.delete(key: _keyDeviceInstallationRegistrations);
    }
  }

  static const _keyBaseUrl = 'attend_api_base_url';

  Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: _keyBaseUrl, value: url);
  }

  Future<String?> getBaseUrl() async {
    return await _storage.read(key: _keyBaseUrl);
  }

  Future<void> clearBaseUrl() async {
    await _storage.delete(key: _keyBaseUrl);
  }

  static const _keyLanguage = 'attend_language_preference';

  Future<void> saveLanguage(String languageCode) async {
    await _storage.write(key: _keyLanguage, value: languageCode);
  }

  Future<String?> getLanguage() async {
    return await _storage.read(key: _keyLanguage);
  }

  Future<void> clearLanguage() async {
    await _storage.delete(key: _keyLanguage);
  }
}
