import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

class _Api extends Mock implements ApiClient {}

class _Storage extends Mock implements TokenStorage {}

class _Identity extends Mock implements InstallationIdentityPort {}

class _Attestation extends Mock
    implements DeviceAttestationPort, OfflineCaptureSigningPort {}

AttendanceEventEntity event({double latitude = 30.0444}) =>
    AttendanceEventEntity(
      id: 'c3d2f625-b42a-4c04-b263-eb84d95f61a7',
      eventType: AttendanceEventType.checkIn,
      capturedAt: DateTime.utc(2026, 10, 6, 8, 30),
      location: GeoPoint(
        latitude: latitude,
        longitude: 31.2357,
        accuracyMeters: 12,
      ),
      shiftInstanceId: '8c52084c-cb14-41d9-813a-773cefb180a0',
      status: AttendanceValidationStatus.pendingSync,
    );

void main() {
  test('canonical digest is stable across unchanged retry state', () {
    final first = AttendanceEvidenceService.canonicalDigest(event());
    final retry = AttendanceEvidenceService.canonicalDigest(
      event().copyWith(status: AttendanceValidationStatus.pendingSync),
    );

    expect(first, retry);
    expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
  });

  test('canonical digest changes when signed location data changes', () {
    expect(
      AttendanceEvidenceService.canonicalDigest(event()),
      isNot(AttendanceEvidenceService.canonicalDigest(event(latitude: 30.1))),
    );
  });

  test('canonical digest binds the actual location capture time', () {
    final original = event();
    final older = original.copyWith(
      location: original.location.copyWith(
        timestamp: original.capturedAt.subtract(const Duration(seconds: 20)),
      ),
    );
    expect(AttendanceEvidenceService.canonicalDigest(older),
        isNot(AttendanceEvidenceService.canonicalDigest(original)));
  });

  test('tampered queued facts fail before obtaining new integrity evidence',
      () async {
    final api = _Api();
    final service = AttendanceEvidenceService(
        apiClient: api,
        tokenStorage: _Storage(),
        installationIdentity: _Identity(),
        deviceAttestation: _Attestation());
    final altered = event().copyWith(
        captureProof: const OfflineAttendanceProof(
      installationId: 'registered-installation',
      digest: 'original-digest',
      signature: 'original-signature',
    ));
    await expectLater(service.prepareReplay(altered),
        throwsA(isA<AttendanceTrustUnavailableException>()));
    verifyZeroInteractions(api);
  });
  test(
      'offline capture uses the registered installation and replay retains its signature',
      () async {
    final api = _Api();
    final storage = _Storage();
    final attestation = _Attestation();
    const session = AuthSessionEntity(
        accessToken: 'token',
        tenantId: 'tenant',
        userId: 'user',
        role: UserRole.employee,
        email: 'test@example.invalid',
        displayName: 'Test');
    when(() => storage.getSession()).thenAnswer((_) async => session);
    when(() => storage.getDeviceInstallationRegistration(
        tenantId: 'tenant',
        userId: 'user')).thenAnswer((_) async => 'registered-installation');
    final input = event();
    final digest = AttendanceEvidenceService.canonicalDigest(input);
    when(() => attestation.signCaptureDigest(digest))
        .thenAnswer((_) async => 'capture-signature');
    final service = AttendanceEvidenceService(
        apiClient: api,
        tokenStorage: storage,
        installationIdentity: _Identity(),
        deviceAttestation: attestation);
    final proof = await service.captureForOffline(input);
    verifyZeroInteractions(api);
    expect(proof.signature, 'capture-signature');
    when(() => api.createAttendanceIntegrityChallenge(
            eventId: input.id,
            installationId: 'registered-installation',
            contentDigest: digest))
        .thenAnswer((_) async => IntegrityChallengeDto(
            challengeId: 'challenge',
            nonce: 'nonce',
            expiresAt: DateTime.utc(2099)));
    when(() => attestation.signCanonicalEnvelope(
            canonicalEnvelope: digest, challenge: 'nonce'))
        .thenAnswer((_) async => const IntegrityEvidence(
            installationId: 'local-installation',
            signature: 'new-signature',
            platformAssertion: 'fresh-token',
            keyVersion: 1));
    final replay =
        await service.prepareReplay(input.copyWith(captureProof: proof));
    expect(replay.signature, 'capture-signature');
    expect(replay.integrityToken, 'fresh-token');
    expect(replay.contentDigest, digest);
    clearInteractions(api);
    when(() => storage.getDeviceInstallationRegistration(
        tenantId: 'tenant',
        userId: 'user')).thenAnswer((_) async => 'replacement-installation');
    await expectLater(
        service.prepareReplay(input.copyWith(captureProof: proof)),
        throwsA(isA<AttendanceTrustUnavailableException>()));
    verifyZeroInteractions(api);
  });
}
