/// Presentation-safe contracts for device trust and optional background work.
///
/// Concrete Android/iOS bridges live outside presentation code. None of these
/// interfaces expose private keys, FCM tokens, coordinates, or raw provider
/// verdicts to widgets or Cubits.
library;

enum DeviceIntegrityDisposition { allow, review, reject, unavailable }

/// Deliberately contains no provider detail. UI maps this to safe guidance.
final class AttendanceTrustUnavailableException implements Exception {
  const AttendanceTrustUnavailableException();
}

final class ProtectedInstallation {
  const ProtectedInstallation({
    required this.id,
    required this.publicKey,
    required this.publicKeyThumbprint,
    required this.keyVersion,
  });

  final String id;
  final String publicKey;
  final String publicKeyThumbprint;
  final int keyVersion;
}

final class IntegrityEvidence {
  const IntegrityEvidence({
    required this.installationId,
    required this.signature,
    required this.platformAssertion,
    required this.keyVersion,
  });

  final String installationId;
  final String signature;
  final String? platformAssertion;
  final int keyVersion;
}

abstract interface class InstallationIdentityPort {
  Future<ProtectedInstallation> ensureInstallation();
  Future<void> revokeLocalInstallation();
}

abstract interface class DeviceAttestationPort {
  Future<IntegrityEvidence> signCanonicalEnvelope({
    required String canonicalEnvelope,
    required String challenge,
  });
}

/// Signs immutable event facts without contacting an integrity provider.
abstract interface class OfflineCaptureSigningPort {
  Future<String> signCaptureDigest(String digest);
}

/// Authenticated registration boundary shared by attendance and optional push.
/// It exposes the server installation UUID only, never a private key or token.
abstract interface class RegisteredInstallationPort {
  Future<String> ensureRegisteredInstallation();
}

enum PushPermissionState { unknown, granted, denied, unavailable }

abstract interface class PushNotificationPort {
  Future<PushPermissionState> currentPermission();
  Future<PushPermissionState> requestPermission();
  Future<String?> enableAndGetToken();
  Stream<String> get tokenRefreshes;
  Stream<String> get foregroundMessageIds;

  /// Opaque notification IDs from a system-notification tap while the app is
  /// running in the background. The destination must be reauthorized before
  /// the app navigates anywhere.
  Stream<String> get openedMessageIds;

  /// Opaque notification ID that launched the app from a terminated state.
  /// Returns null when the app was opened normally.
  Future<String?> initialMessageId();
  Future<void> disable();
}

/// Presentation-safe consent boundary. Implementations may register a provider
/// destination but must never expose FCM tokens or provider errors to widgets.
enum PushRegistrationOutcome {
  enabled,
  permissionUnavailable,
  tokenUnavailable,
  registrationUnavailable,
}

abstract interface class PushRegistrationPort {
  Future<PushRegistrationOutcome> enable({required String locale});
  Future<void> disable();
  Future<void> dispose();
}

abstract interface class BackgroundSyncScheduler {
  Future<void> scheduleForIdentity({
    required String tenantId,
    required String userId,
  });
  Future<void> cancelForIdentity({
    required String tenantId,
    required String userId,
  });
}

abstract interface class MobileDiagnosticsPort {
  Future<void> initialize();
  void captureHandledFailure(String category);
}
