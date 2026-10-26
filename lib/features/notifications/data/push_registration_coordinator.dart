import 'dart:async';

import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';

/// Binds an explicitly granted OS notification permission to the current
/// protected installation. It never asks for permission during login or app
/// startup, and it never logs tokens or provider responses.
final class PushRegistrationCoordinator implements PushRegistrationPort {
  PushRegistrationCoordinator({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required PushNotificationPort pushNotifications,
    required RegisteredInstallationPort installationEvidence,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _pushNotifications = pushNotifications,
        _installationEvidence = installationEvidence;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final PushNotificationPort _pushNotifications;
  final RegisteredInstallationPort _installationEvidence;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Called only from the explicit notification preference action.
  @override
  Future<PushRegistrationOutcome> enable({required String locale}) async {
    var permission = await _pushNotifications.currentPermission();
    // On Android 13+ Firebase can report `denied` before the first system
    // prompt has been displayed. Permission is still requested only after the
    // person explicitly enables the switch; this lets Android show that first
    // prompt while a previously declined request remains safely declined.
    if (permission != PushPermissionState.granted) {
      permission = await _pushNotifications.requestPermission();
    }
    if (permission != PushPermissionState.granted) {
      return PushRegistrationOutcome.permissionUnavailable;
    }
    final token = await _pushNotifications.enableAndGetToken();
    if (token == null) return PushRegistrationOutcome.tokenUnavailable;
    try {
      await _register(token, locale: locale);
      _observeTokenRefreshes(locale);
      return PushRegistrationOutcome.enabled;
    } catch (_) {
      // Provider, integrity, and transport details stay outside the UI. A
      // later explicit action safely retries without persisting an FCM token.
      return PushRegistrationOutcome.registrationUnavailable;
    }
  }

  /// Remote revocation completes before the locally held FCM token is removed.
  /// This avoids presenting a disabled state while the server can still send.
  @override
  Future<void> disable() async {
    final session = await _tokenStorage.getSession();
    if (session != null) {
      final installationId =
          await _tokenStorage.getDeviceInstallationRegistration(
        tenantId: session.tenantId,
        userId: session.userId,
      );
      if (installationId != null) {
        await _apiClient.revokeNotificationDevice(installationId);
      }
    }
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    await _pushNotifications.disable();
  }

  @override
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  void _observeTokenRefreshes(String locale) {
    _tokenRefreshSubscription ??= _pushNotifications.tokenRefreshes.listen(
      (token) async {
        try {
          await _register(token, locale: locale);
        } catch (_) {
          // A later refresh or explicit settings action retries. The token and
          // provider failure are deliberately not retained in diagnostics.
        }
      },
    );
  }

  Future<void> _register(String token, {required String locale}) async {
    final installationId =
        await _installationEvidence.ensureRegisteredInstallation();
    await _apiClient.upsertNotificationDevice(
      installationId: installationId,
      token: token,
      locale: locale == 'en' ? 'en' : 'ar',
    );
  }
}
