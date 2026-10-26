import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';

/// Android-only boundary for protected installation identity and Play
/// Integrity. Widgets receive only safe failures; private keys and raw Android
/// provider diagnostics never cross this boundary.
final class AndroidAttendanceTrustBridge
    implements InstallationIdentityPort, DeviceAttestationPort {
  static const _channel =
      MethodChannel('com.zbooma.elabqrihr/attendance_trust');

  @override
  Future<ProtectedInstallation> ensureInstallation() async {
    _requireAndroid();
    try {
      final identity = await _channel.invokeMapMethod<String, dynamic>(
        'installationIdentity',
      );
      final id = identity?['installationId'];
      final key = identity?['publicKeySpki'];
      final thumbprint = identity?['publicKeyThumbprint'];
      if (id is! String ||
          key is! String ||
          thumbprint is! String ||
          id.isEmpty ||
          key.isEmpty ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(thumbprint)) {
        throw PlatformException(code: 'KEYSTORE_UNAVAILABLE');
      }
      return ProtectedInstallation(
        id: id,
        publicKey: key,
        publicKeyThumbprint: thumbprint,
        keyVersion: 1,
      );
    } on PlatformException {
      throw const AttendanceTrustUnavailableException();
    }
  }

  @override
  Future<IntegrityEvidence> signCanonicalEnvelope({
    required String canonicalEnvelope,
    required String challenge,
  }) async {
    _requireAndroid();
    final installation = await ensureInstallation();
    try {
      final signature = await _channel.invokeMethod<String>(
        'signAttendanceDigest',
        {'contentDigest': canonicalEnvelope},
      );
      final integrityToken = await _channel.invokeMethod<String>(
        'requestIntegrityToken',
        {'nonce': challenge},
      );
      if (signature == null ||
          signature.isEmpty ||
          integrityToken == null ||
          integrityToken.isEmpty) {
        throw PlatformException(code: 'INTEGRITY_UNAVAILABLE');
      }
      return IntegrityEvidence(
        installationId: installation.id,
        signature: signature,
        platformAssertion: integrityToken,
        keyVersion: installation.keyVersion,
      );
    } on PlatformException {
      throw const AttendanceTrustUnavailableException();
    }
  }

  @override
  Future<void> revokeLocalInstallation() async {
    _requireAndroid();
    try {
      await _channel.invokeMethod<void>('revokeLocalInstallation');
    } on PlatformException {
      throw const AttendanceTrustUnavailableException();
    }
  }

  void _requireAndroid() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const AttendanceTrustUnavailableException();
    }
  }
}
