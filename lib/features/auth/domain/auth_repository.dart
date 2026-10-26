import 'auth_models.dart';

abstract class AuthRepository {
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  });

  Future<AuthSessionEntity?> getCachedSession();

  Future<void> logout();

  Future<AuthSessionEntity> refreshSession();

  Future<void> requestPasswordReset({
    required String email,
    required String tenantSlug,
  });

  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  });
}

