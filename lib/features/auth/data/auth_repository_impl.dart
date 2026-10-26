import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final Future<void> Function()? _onLogout;

  AuthRepositoryImpl({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    Future<void> Function()? onLogout,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _onLogout = onLogout;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) {
    return _apiClient.login(
      email: email,
      password: password,
      tenantSlug: tenantSlug,
      deviceInstallationId: deviceInstallationId,
    );
  }

  @override
  Future<AuthSessionEntity?> getCachedSession() {
    return _tokenStorage.getSession();
  }

  @override
  Future<void> logout() async {
    try {
      if (_onLogout != null) {
        await _onLogout();
      }
    } catch (_) {}
    return _apiClient.logout();
  }

  @override
  Future<AuthSessionEntity> refreshSession() {
    return _apiClient.refreshSession();
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    required String tenantSlug,
  }) {
    return _apiClient.requestPasswordReset(
      email: email,
      tenantSlug: tenantSlug,
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    await _apiClient.confirmPasswordReset(
      resetToken: resetToken,
      newPassword: newPassword,
    );
    // Purge local session if any exists
    await _tokenStorage.clearSession();
  }
}

