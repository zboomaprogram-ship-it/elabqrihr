import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/attendance_failure_classifier.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

/// Creates evidence only from immutable event data. A retry recreates the same
/// digest, obtains a fresh one-use server challenge, and never changes time or
/// location captured in the outbox.
class AttendanceEvidenceService implements RegisteredInstallationPort {
  AttendanceEvidenceService({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required InstallationIdentityPort installationIdentity,
    required DeviceAttestationPort deviceAttestation,
    Future<PackageInfo> Function()? packageInfo,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _installationIdentity = installationIdentity,
        _deviceAttestation = deviceAttestation,
        _packageInfo = packageInfo ?? PackageInfo.fromPlatform;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final InstallationIdentityPort _installationIdentity;
  final DeviceAttestationPort _deviceAttestation;
  final Future<PackageInfo> Function() _packageInfo;
  final Map<String, Future<String>> _inFlightRegistrations = {};

  Future<AttendanceEvidenceDto> prepare(AttendanceEventEntity event) async {
    final String installation;
    try {
      installation = await ensureRegisteredInstallation();
    } catch (e) {
      if (e is AttendanceSubmissionStageException) rethrow;
      throw AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.installationRegistration,
        causalError: e,
        reasonCode: 'DEVICE_REGISTRATION_FAILED',
      );
    }

    final digest = canonicalDigest(event);

    final IntegrityChallengeDto challenge;
    try {
      challenge = await _apiClient.createAttendanceIntegrityChallenge(
        eventId: event.id,
        installationId: installation,
        contentDigest: digest,
      );
    } catch (e) {
      String? reasonCode;
      if (e is ApiException) {
        reasonCode = e.code;
      } else if (e is DioException) {
        if (e.error is ApiException) {
          reasonCode = (e.error as ApiException).code;
        } else if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          reasonCode = data['code'] as String? ?? data['reasonCode'] as String?;
        }
      }
      throw AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.integrityChallenge,
        causalError: e,
        reasonCode: reasonCode,
      );
    }

    final IntegrityEvidence signed;
    try {
      signed = await _deviceAttestation.signCanonicalEnvelope(
        canonicalEnvelope: digest,
        challenge: challenge.nonce,
      );
    } catch (e) {
      throw AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.signature,
        causalError: e,
        reasonCode: 'INTEGRITY_UNAVAILABLE',
      );
    }

    if (signed.installationId.isEmpty || signed.signature.isEmpty) {
      throw const AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.signature,
        causalError: AttendanceTrustUnavailableException(),
        reasonCode: 'INTEGRITY_UNAVAILABLE',
      );
    }

    return AttendanceEvidenceDto(
      contentDigest: digest,
      installationId: installation,
      challengeId: challenge.challengeId,
      signature: signed.signature,
      integrityToken: signed.platformAssertion ?? '',
    );
  }

  /// Revokes the local protected device key and installation identity.
  Future<void> revokeLocalInstallation() async {
    await _installationIdentity.revokeLocalInstallation();
  }

  /// Registers the Android public key after a normal authenticated login.
  /// The server stores only public material and classifies disabled provider
  /// verdicts as review-required; private key material never leaves Android.
  /// Reuses or creates the authenticated server-side installation record.
  /// Push registration calls this only after the user explicitly opts in.
  @override
  Future<String> ensureRegisteredInstallation() async {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      throw const AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.installationRegistration,
        causalError: AttendanceTrustUnavailableException(),
        reasonCode: 'DEVICE_REGISTRATION_FAILED',
      );
    }

    final key = '${session.tenantId}:${session.userId}';

    // 1. Check local secure storage before starting or joining registration.
    final cached = await _tokenStorage.getDeviceInstallationRegistration(
      tenantId: session.tenantId,
      userId: session.userId,
    );
    if (cached != null) return cached;

    // 2. Share one in-flight registration future across concurrent callers.
    final inFlight = _inFlightRegistrations[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _registerInstallationSingleFlight(session);
    _inFlightRegistrations[key] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightRegistrations[key], future)) {
        _inFlightRegistrations.remove(key);
      }
    }
  }

  Future<String> _registerInstallationSingleFlight(
      AuthSessionEntity session) async {
    try {
      // Re-check secure storage after acquiring the in-flight slot
      final existing = await _tokenStorage.getDeviceInstallationRegistration(
        tenantId: session.tenantId,
        userId: session.userId,
      );
      if (existing != null) return existing;

      final identity = await _installationIdentity.ensureInstallation();
      final package = await _packageInfo();
      final challenge = await _apiClient.createInstallationChallenge(
        platform: 'android',
        appIdentifier: 'com.zbooma.elabqrihr',
      );
      final signed = await _deviceAttestation.signCanonicalEnvelope(
        canonicalEnvelope: _registrationDigest(identity.id),
        challenge: challenge.nonce,
      );
      final registration = await _apiClient.registerDeviceInstallation(
        InstallationRegistrationRequestDto(
          challengeId: challenge.challengeId,
          platform: 'android',
          appIdentifier: 'com.zbooma.elabqrihr',
          appVersion: package.version,
          buildNumber: int.tryParse(package.buildNumber) ?? 0,
          publicKeySpki: identity.publicKey,
          publicKeyThumbprint: identity.publicKeyThumbprint,
          integrityToken: signed.platformAssertion ?? '',
        ),
      );

      // Never cache a registration response unless status == active.
      // Treat pending_review and any rejected/review-only integrity result as a typed,
      // terminal registration failure with clear Arabic recovery guidance.
      if (registration.status != 'active') {
        final reasonCode = (registration.reasonCode != null &&
                registration.reasonCode!.isNotEmpty)
            ? registration.reasonCode!
            : (registration.status == 'pending_review'
                ? 'DEVICE_REGISTRATION_PENDING_REVIEW'
                : 'DEVICE_REGISTRATION_FAILED');

        try {
          await _tokenStorage.clearDeviceInstallationRegistration(
            tenantId: session.tenantId,
            userId: session.userId,
          );
        } catch (_) {}

        throw AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.installationRegistration,
          causalError: StateError(
            'Installation registration status is ${registration.status}: $reasonCode',
          ),
          reasonCode: reasonCode,
        );
      }

      await _tokenStorage.saveDeviceInstallationRegistration(
        tenantId: session.tenantId,
        userId: session.userId,
        installationId: registration.installationId,
      );
      return registration.installationId;
    } catch (e) {
      if (e is AttendanceSubmissionStageException) rethrow;
      String? reasonCode;
      if (e is ApiException) {
        reasonCode = e.code;
      } else if (e is DioException) {
        if (e.error is ApiException) {
          reasonCode = (e.error as ApiException).code;
        } else if (e.response?.data is Map) {
          final data = e.response!.data as Map;
          reasonCode = data['code'] as String? ?? data['reasonCode'] as String?;
        }
      }
      throw AttendanceSubmissionStageException(
        stage: AttendanceSubmissionStage.installationRegistration,
        causalError: e,
        reasonCode: reasonCode ?? 'DEVICE_REGISTRATION_FAILED',
      );
    }
  }

  static String canonicalDigest(AttendanceEventEntity event) {
    final occurredAt = event.capturedAt.toUtc().toIso8601String();
    final canonical = <String, dynamic>{
      'eventId': event.id,
      'shiftInstanceId': event.shiftInstanceId,
      'type': event.eventType.toApiValue(),
      'occurredAt': occurredAt,
      'location': <String, dynamic>{
        'latitude': event.location.latitude,
        'longitude': event.location.longitude,
        'accuracyMeters': event.location.accuracyMeters ?? 10.0,
        'capturedAt': occurredAt,
      },
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static String _registrationDigest(String installationId) => sha256
      .convert(
        utf8.encode(
          jsonEncode(<String, String>{
            'installationId': installationId,
            'platform': 'android',
            'appIdentifier': 'com.zbooma.elabqrihr',
          }),
        ),
      )
      .toString();
}
