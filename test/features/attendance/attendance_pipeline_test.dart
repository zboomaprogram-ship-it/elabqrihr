import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/sqlite_attendance_outbox.dart';
import 'package:attend_mobile/core/location/location_service.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/data/attendance_failure_classifier.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocationService extends Mock implements LocationService {}

class MockAttendanceEvidenceService extends Mock
    implements AttendanceEvidenceService {}

class MockPushRegistrationPort extends Mock implements PushRegistrationPort {}

class MockInstallationIdentityPort extends Mock
    implements InstallationIdentityPort {}

class MockDeviceAttestationPort extends Mock implements DeviceAttestationPort {}

class FakeTokenStorage extends TokenStorage {
  AuthSessionEntity? session;
  bool registrationCleared = false;
  final Map<String, String> _registrations = {};

  FakeTokenStorage(this.session);

  @override
  Future<AuthSessionEntity?> getSession() async => session;

  @override
  Future<String?> getDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
  }) async =>
      _registrations['$tenantId:$userId'];

  @override
  Future<void> saveDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
    required String installationId,
  }) async {
    _registrations['$tenantId:$userId'] = installationId;
  }

  @override
  Future<void> clearDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
  }) async {
    registrationCleared = true;
    _registrations.remove('$tenantId:$userId');
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(AttendanceEventEntity(
      id: 'fallback-id',
      eventType: AttendanceEventType.checkIn,
      capturedAt: DateTime.utc(2026, 1, 1),
      location: const GeoPoint(latitude: 0, longitude: 0),
      shiftInstanceId: 'shift-fallback',
      status: AttendanceValidationStatus.pendingSync,
    ));
    registerFallbackValue(AttendanceEventType.checkIn);
    registerFallbackValue(const GeoPoint(latitude: 0, longitude: 0));
    registerFallbackValue(DateTime.now());
    registerFallbackValue(const InstallationRegistrationRequestDto(
      challengeId: 'fallback-challenge',
      platform: 'android',
      appIdentifier: 'com.zbooma.elabqrihr',
      appVersion: '1.0.0',
      buildNumber: 1,
      publicKeySpki: 'key',
      publicKeyThumbprint: 'thumb',
      integrityToken: 'token',
    ));
  });

  late MockApiClient mockApiClient;
  late MockLocationService mockLocationService;
  late MockAttendanceEvidenceService mockEvidenceService;
  late MockPushRegistrationPort mockPushRegistration;
  late SqliteAttendanceOutbox outbox;
  late FakeTokenStorage tokenStorage;
  late AttendanceRepositoryImpl repository;

  final testSession = AuthSessionEntity(
    accessToken: 'test-token',
    tenantId: 'tenant-demo',
    userId: 'user-emp-1',
    role: UserRole.employee,
    email: 'reviewer.employee@elabqrihr.com',
    displayName: 'Test Employee',
  );

  late GeoPoint testLocation;

  setUp(() {
    testLocation = GeoPoint(
        latitude: 31.0409,
        longitude: 31.3785,
        accuracyMeters: 12.0,
        timestamp: DateTime.now().toUtc());
    mockApiClient = MockApiClient();
    mockLocationService = MockLocationService();
    mockEvidenceService = MockAttendanceEvidenceService();
    mockPushRegistration = MockPushRegistrationPort();
    outbox = SqliteAttendanceOutbox.inMemory();
    tokenStorage = FakeTokenStorage(testSession);

    when(() => mockPushRegistration.disable()).thenAnswer((_) async {});

    repository = AttendanceRepositoryImpl(
      apiClient: mockApiClient,
      outbox: outbox,
      tokenStorage: tokenStorage,
      locationService: mockLocationService,
      evidenceService: mockEvidenceService,
      pushRegistrationCoordinator: mockPushRegistration,
    );

    when(() => mockLocationService.getCurrentLocation())
        .thenAnswer((_) async => testLocation);
  });

  tearDown(() {
    outbox.close();
  });

  group('Attendance Submission Pipeline Failure Modes & Outbox Invariants', () {
    test('offline before challenge retains a pending attendance event',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenThrow(
        AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.integrityChallenge,
          causalError: const SocketException('offline'),
        ),
      );
      when(() => mockEvidenceService.captureForOffline(any())).thenAnswer(
        (_) async => const OfflineAttendanceProof(
            installationId: 'inst',
            digest: 'digest',
            signature: 'capture-signature'),
      );
      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );
      expect(result.status, AttendanceValidationStatus.pendingSync);
      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, hasLength(1));
      expect(pending.single.captureProof?.signature, 'capture-signature');
    });
    test('missing location capture time is not invented for a new event',
        () async {
      const missingTime = GeoPoint(latitude: 31, longitude: 31);
      when(() => mockLocationService.getCurrentLocation())
          .thenAnswer((_) async => missingTime);
      await expectLater(
        repository.submitAttendanceEvent(
          eventType: AttendanceEventType.checkIn,
          shiftInstanceId: 'shift-101',
          location: missingTime,
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
    test('legacy queued event without capture proof is never sent unsigned',
        () async {
      final legacy = AttendanceEventEntity(
          id: 'legacy-event',
          eventType: AttendanceEventType.checkIn,
          capturedAt: DateTime.now().toUtc(),
          location: testLocation,
          shiftInstanceId: 'shift-101',
          status: AttendanceValidationStatus.pendingSync);
      await outbox.saveEvent(
          tenantId: testSession.tenantId,
          userId: testSession.userId,
          event: legacy);
      await repository.synchronizeOutbox();
      verifyNever(() => mockEvidenceService.prepareReplay(any()));
      verifyNever(() => mockApiClient.submitAttendanceEvent(
          eventId: any(named: 'eventId'),
          eventType: any(named: 'eventType'),
          shiftInstanceId: any(named: 'shiftInstanceId'),
          location: any(named: 'location'),
          capturedAt: any(named: 'capturedAt'),
          evidence: any(named: 'evidence'),
          expectedTenantId: any(named: 'expectedTenantId'),
          expectedUserId: any(named: 'expectedUserId')));
      expect(
          await outbox.getPendingEvents(
              tenantId: testSession.tenantId, userId: testSession.userId),
          isEmpty);
    });
    test(
        '1. granted location + integrity unavailable: terminal rejection, 0 outbox pending rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenThrow(
        const AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.signature,
          causalError: AttendanceTrustUnavailableException(),
          reasonCode: 'INTEGRITY_UNAVAILABLE',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('INTEGRITY_UNAVAILABLE'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason: 'Trust failures must never be persisted as pendingSync');
    });

    test(
        '2. wrapped DioException.unknown with non-transport cause: terminal rejection, 0 outbox pending rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'inst-1',
          challengeId: 'chal-1',
          signature: 'sig-1',
          integrityToken: 'token-1',
        ),
      );

      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/attendance'),
          type: DioExceptionType.unknown,
          error: StateError('Plugin platform channel failed'),
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('ATTENDANCE_SUBMISSION_FAILED'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason:
              'Non-transport unknown exceptions must never be stored in outbox');
    });

    test(
        '3. device-installation registration failure: terminal rejection, 0 outbox pending rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenThrow(
        AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.installationRegistration,
          causalError: Exception('Play services registration rejected'),
          reasonCode: 'DEVICE_REGISTRATION_FAILED',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('DEVICE_REGISTRATION_FAILED'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason:
              'Registration failures must never be persisted as pendingSync');
    });

    test(
        '4. server rejection (e.g. 403 or geofence policy): terminal rejection, 0 outbox pending rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'inst-1',
          challengeId: 'chal-1',
          signature: 'sig-1',
          integrityToken: 'token-1',
        ),
      );

      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        const ApiException(
          statusCode: 403,
          code: 'LOCATION_OUT_OF_RADIUS',
          message: 'Device is outside authorized geofence radius',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('LOCATION_OUT_OF_RADIUS'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason: 'Server policy rejections must never remain in outbox');
    });

    test(
        '5. genuine offline timeout/connection error: retryable, exactly 1 outbox pending row',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'inst-1',
          challengeId: 'chal-1',
          signature: 'sig-1',
          integrityToken: 'token-1',
        ),
      );

      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/attendance'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.pendingSync));
      expect(result.reasonCode, equals('NETWORK_UNAVAILABLE'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending.length, equals(1));
      expect(pending.first.shiftInstanceId, equals('shift-101'));
      expect(
          pending.first.status, equals(AttendanceValidationStatus.pendingSync));
    });

    test(
        '6. retry after genuine network recovery: synchronizes and clears pendingSync status',
        () async {
      when(() => mockEvidenceService.prepareReplay(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
            contentDigest: 'digest-1',
            installationId: 'inst-1',
            challengeId: 'new-challenge',
            signature: 'sig-1',
            integrityToken: 'fresh-token'),
      );
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'inst-1',
          challengeId: 'chal-1',
          signature: 'sig-1',
          integrityToken: 'token-1',
        ),
      );

      // First submit: offline failure saves to outbox
      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        const SocketException('Failed host lookup'),
      );

      final initial = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );
      expect(initial.status, equals(AttendanceValidationStatus.pendingSync));

      // Network recovers: synchronizeOutbox succeeds
      when(() => mockApiClient.submitAttendanceEvent(
            eventId: initial.id,
            eventType: initial.eventType,
            shiftInstanceId: initial.shiftInstanceId,
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenAnswer(
        (_) async => AttendanceEventEntity(
          id: initial.id,
          eventType: initial.eventType,
          capturedAt: initial.capturedAt,
          location: initial.location,
          shiftInstanceId: initial.shiftInstanceId,
          status: AttendanceValidationStatus.accepted,
        ),
      );

      // Make the saved event due before calling synchronizeOutbox()
      await outbox.updateEventStatus(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        eventId: initial.id,
        status: AttendanceValidationStatus.pendingSync,
        nextRetryAt: DateTime.now().toUtc(),
      );

      await repository.synchronizeOutbox();

      final replayed =
          verify(() => mockEvidenceService.prepareReplay(captureAny()))
              .captured
              .single as AttendanceEventEntity;
      expect(replayed.captureProof?.signature, 'sig-1');
      verify(() => mockApiClient.submitAttendanceEvent(
            eventId: initial.id,
            eventType: initial.eventType,
            shiftInstanceId: initial.shiftInstanceId,
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).called(2); // Original send and exactly one replay.

      final remaining = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(remaining, isEmpty,
          reason: 'Synchronized event transitions out of pendingSync status');
    });

    test('identity change during replay leaves signed attendance row untouched',
        () async {
      final event = AttendanceEventEntity(
        id: 'event-identity-bound-replay',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 10, 29, 8),
        location: testLocation,
        shiftInstanceId: 'shift-101',
        status: AttendanceValidationStatus.pendingSync,
        captureProof: const OfflineAttendanceProof(
          installationId: 'installation-1',
          digest: 'digest-1',
          signature: 'capture-signature',
        ),
      );
      await outbox.saveEvent(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        event: event,
      );
      when(() => mockEvidenceService.prepareReplay(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'installation-1',
          challengeId: 'challenge-1',
          signature: 'capture-signature',
          integrityToken: 'fresh-token',
        ),
      );
      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: testSession.tenantId,
            expectedUserId: testSession.userId,
          )).thenThrow(const SessionIdentityChangedException());

      await expectLater(
        repository.synchronizeOutbox(),
        throwsA(isA<SessionIdentityChangedException>()),
      );

      final stillPending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(stillPending.single.id, event.id);
      expect(
          stillPending.single.status, AttendanceValidationStatus.pendingSync);
      expect(stillPending.single.captureProof?.signature, 'capture-signature');
    });

    test(
        '7. revoked device outcome: purges local key and registration, terminal rejection with Arabic guidance, 0 outbox pending rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'revoked-inst-1',
          challengeId: 'challenge-1',
          signature: 'sig',
          integrityToken: 'token',
        ),
      );
      when(() => mockEvidenceService.revokeLocalInstallation())
          .thenAnswer((_) async {});

      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        const ApiException(
          statusCode: 422,
          code: 'DEVICE_NOT_ACTIVE',
          message: 'Device is not active for employee',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('DEVICE_NOT_ACTIVE'));
      expect(tokenStorage.registrationCleared, isTrue);
      verify(() => mockEvidenceService.revokeLocalInstallation()).called(1);

      final arabicMessage =
          AppFailureMapper.attendanceReasonMessage(result.reasonCode);
      expect(arabicMessage, contains('تم إلغاء تسجيل هذا الجهاز'));

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason: 'Revoked device outcomes must never be stored in outbox');
    });

    test(
        '8. 409 DEVICE_REENROLL_REQUIRED during challenge: purges local key, push, and registration, terminal rejection with Arabic guidance, 0 outbox rows',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenThrow(
        const AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.integrityChallenge,
          causalError: ApiException(
            statusCode: 409,
            code: 'DEVICE_REENROLL_REQUIRED',
            message: 'Device re-enrollment required after reset',
          ),
          reasonCode: 'DEVICE_REENROLL_REQUIRED',
        ),
      );
      when(() => mockEvidenceService.revokeLocalInstallation())
          .thenAnswer((_) async {});

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('DEVICE_REENROLL_REQUIRED'));
      expect(tokenStorage.registrationCleared, isTrue);
      verify(() => mockEvidenceService.revokeLocalInstallation()).called(1);
      verify(() => mockPushRegistration.disable()).called(1);

      final arabicMessage =
          AppFailureMapper.attendanceReasonMessage(result.reasonCode);
      expect(
        arabicMessage,
        equals(
          'تم إلغاء تسجيل هذا الجهاز من قِبل إدارة الموارد البشرية. يرجى تسجيل الدخول مجدداً لتفعيل الجهاز.',
        ),
      );

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason: 'DEVICE_REENROLL_REQUIRED must never be queued into outbox');
    });

    test(
        '9. post-reset re-enrolment lifecycle: generates and registers fresh installation ID rather than reusing revoked identity',
        () async {
      // 1. Initial state: revoked installation stored
      const revokedInstallationId = 'revoked-inst-111';
      const freshInstallationId = 'fresh-inst-222';
      await tokenStorage.saveDeviceInstallationRegistration(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
        installationId: revokedInstallationId,
      );

      expect(
        await tokenStorage.getDeviceInstallationRegistration(
          tenantId: testSession.tenantId,
          userId: testSession.userId,
        ),
        equals(revokedInstallationId),
      );

      // 2. Revocation / purge occurs (as done on 409 DEVICE_REENROLL_REQUIRED)
      final mockInstallationIdentity = MockInstallationIdentityPort();
      final mockDeviceAttestation = MockDeviceAttestationPort();
      when(() => mockInstallationIdentity.revokeLocalInstallation())
          .thenAnswer((_) async {});
      when(() => mockPushRegistration.disable()).thenAnswer((_) async {});

      await tokenStorage.clearDeviceInstallationRegistration(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      await mockInstallationIdentity.revokeLocalInstallation();
      await mockPushRegistration.disable();

      expect(
        await tokenStorage.getDeviceInstallationRegistration(
          tenantId: testSession.tenantId,
          userId: testSession.userId,
        ),
        isNull,
      );
      verify(() => mockInstallationIdentity.revokeLocalInstallation())
          .called(1);

      // 3. New attendance attempt invokes AttendanceEvidenceService
      final evidenceService = AttendanceEvidenceService(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        installationIdentity: mockInstallationIdentity,
        deviceAttestation: mockDeviceAttestation,
        packageInfo: () async => PackageInfo(
          appName: 'Attend',
          packageName: 'com.zbooma.elabqrihr',
          version: '1.0.15',
          buildNumber: '18',
        ),
      );

      when(() => mockInstallationIdentity.ensureInstallation()).thenAnswer(
        (_) async => const ProtectedInstallation(
          id: freshInstallationId,
          publicKey: 'new-public-key',
          publicKeyThumbprint: 'new-thumbprint',
          keyVersion: 1,
        ),
      );

      when(() => mockApiClient.createInstallationChallenge(
            platform: 'android',
            appIdentifier: 'com.zbooma.elabqrihr',
          )).thenAnswer(
        (_) async => IntegrityChallengeDto(
          challengeId: 'new-challenge-id',
          nonce: 'new-nonce',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );

      when(() => mockDeviceAttestation.signCanonicalEnvelope(
            canonicalEnvelope: any(named: 'canonicalEnvelope'),
            challenge: 'new-nonce',
          )).thenAnswer(
        (_) async => const IntegrityEvidence(
          installationId: freshInstallationId,
          signature: 'new-signature',
          platformAssertion: 'new-integrity-token',
          keyVersion: 1,
        ),
      );

      when(() => mockApiClient.registerDeviceInstallation(any())).thenAnswer(
        (_) async => InstallationRegistrationDto(
          installationId: freshInstallationId,
          platform: 'android',
          status: 'active',
          registeredAt: DateTime.now().toUtc(),
          revision: 1,
        ),
      );

      final registeredId = await evidenceService.ensureRegisteredInstallation();

      expect(registeredId, equals(freshInstallationId));
      expect(registeredId, isNot(equals(revokedInstallationId)));

      final storedId = await tokenStorage.getDeviceInstallationRegistration(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(storedId, equals(freshInstallationId));

      verify(() => mockInstallationIdentity.ensureInstallation()).called(1);
      verify(() => mockApiClient.registerDeviceInstallation(any())).called(1);
    });

    test(
        '10. registration concurrency: calls registration twice concurrently before first resolves, shares single-flight future with exactly 1 challenge, token, and registration request',
        () async {
      final mockInstallationIdentity = MockInstallationIdentityPort();
      final mockDeviceAttestation = MockDeviceAttestationPort();
      final completer = Completer<IntegrityChallengeDto>();

      final evidenceService = AttendanceEvidenceService(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        installationIdentity: mockInstallationIdentity,
        deviceAttestation: mockDeviceAttestation,
        packageInfo: () async => PackageInfo(
          appName: 'Attend',
          packageName: 'com.zbooma.elabqrihr',
          version: '1.0.16',
          buildNumber: '19',
        ),
      );

      when(() => mockInstallationIdentity.ensureInstallation()).thenAnswer(
        (_) async => const ProtectedInstallation(
          id: 'concurrent-inst-1',
          publicKey: 'public-key-concurrent',
          publicKeyThumbprint: 'thumbprint-concurrent',
          keyVersion: 1,
        ),
      );

      when(() => mockApiClient.createInstallationChallenge(
            platform: 'android',
            appIdentifier: 'com.zbooma.elabqrihr',
          )).thenAnswer((_) => completer.future);

      when(() => mockDeviceAttestation.signCanonicalEnvelope(
            canonicalEnvelope: any(named: 'canonicalEnvelope'),
            challenge: 'nonce-concurrent',
          )).thenAnswer(
        (_) async => const IntegrityEvidence(
          installationId: 'concurrent-inst-1',
          signature: 'sig-concurrent',
          platformAssertion: 'token-concurrent',
          keyVersion: 1,
        ),
      );

      when(() => mockApiClient.registerDeviceInstallation(any())).thenAnswer(
        (_) async => InstallationRegistrationDto(
          installationId: 'concurrent-inst-1',
          platform: 'android',
          status: 'active',
          registeredAt: DateTime.now().toUtc(),
          revision: 1,
        ),
      );

      // Invoke twice concurrently while challenge is unresolved
      final call1 = evidenceService.ensureRegisteredInstallation();
      final call2 = evidenceService.ensureRegisteredInstallation();

      // Complete the in-flight challenge
      completer.complete(
        IntegrityChallengeDto(
          challengeId: 'chal-concurrent',
          nonce: 'nonce-concurrent',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );

      final results = await Future.wait([call1, call2]);

      expect(results[0], equals('concurrent-inst-1'));
      expect(results[1], equals('concurrent-inst-1'));

      verify(() => mockApiClient.createInstallationChallenge(
            platform: 'android',
            appIdentifier: 'com.zbooma.elabqrihr',
          )).called(1);
      verify(() => mockDeviceAttestation.signCanonicalEnvelope(
            canonicalEnvelope: any(named: 'canonicalEnvelope'),
            challenge: any(named: 'challenge'),
          )).called(1);
      verify(() => mockApiClient.registerDeviceInstallation(any())).called(1);
    });

    test(
        '11. non-active registration (PLAY_NONCE_MISMATCH / pending_review) is not cached, raises terminal rejection, and enables subsequent clean re-enrolment',
        () async {
      final mockInstallationIdentity = MockInstallationIdentityPort();
      final mockDeviceAttestation = MockDeviceAttestationPort();

      final evidenceService = AttendanceEvidenceService(
        apiClient: mockApiClient,
        tokenStorage: tokenStorage,
        installationIdentity: mockInstallationIdentity,
        deviceAttestation: mockDeviceAttestation,
        packageInfo: () async => PackageInfo(
          appName: 'Attend',
          packageName: 'com.zbooma.elabqrihr',
          version: '1.0.16',
          buildNumber: '19',
        ),
      );

      when(() => mockInstallationIdentity.ensureInstallation()).thenAnswer(
        (_) async => const ProtectedInstallation(
          id: 'inst-test-1',
          publicKey: 'key-1',
          publicKeyThumbprint: 'thumb-1',
          keyVersion: 1,
        ),
      );

      when(() => mockApiClient.createInstallationChallenge(
            platform: 'android',
            appIdentifier: 'com.zbooma.elabqrihr',
          )).thenAnswer(
        (_) async => IntegrityChallengeDto(
          challengeId: 'chal-1',
          nonce: 'nonce-1',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );

      when(() => mockDeviceAttestation.signCanonicalEnvelope(
            canonicalEnvelope: any(named: 'canonicalEnvelope'),
            challenge: any(named: 'challenge'),
          )).thenAnswer(
        (_) async => const IntegrityEvidence(
          installationId: 'inst-test-1',
          signature: 'sig-1',
          platformAssertion: 'token-1',
          keyVersion: 1,
        ),
      );

      // 1. First attempt: server rejects with pending_review and PLAY_NONCE_MISMATCH
      when(() => mockApiClient.registerDeviceInstallation(any())).thenAnswer(
        (_) async => InstallationRegistrationDto(
          installationId: 'inst-test-1',
          platform: 'android',
          status: 'pending_review',
          reasonCode: 'PLAY_NONCE_MISMATCH',
          registeredAt: DateTime.now().toUtc(),
          revision: 1,
        ),
      );

      await expectLater(
        evidenceService.ensureRegisteredInstallation(),
        throwsA(
          isA<AttendanceSubmissionStageException>()
              .having((e) => e.reasonCode, 'reasonCode', 'PLAY_NONCE_MISMATCH')
              .having((e) => e.stage, 'stage',
                  AttendanceSubmissionStage.installationRegistration),
        ),
      );

      // Verify that non-active registration was NEVER saved to storage
      final storedAfterFailure =
          await tokenStorage.getDeviceInstallationRegistration(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(storedAfterFailure, isNull,
          reason: 'Non-active registration responses must never be cached');

      // Verify Arabic guidance mapping
      final arabicMessage =
          AppFailureMapper.attendanceReasonMessage('PLAY_NONCE_MISMATCH');
      expect(
        arabicMessage,
        equals(
          'تعذر التحقق من سلامة الجهاز. لم يُرسل الحضور؛ أعد المحاولة بعد فتح Google Play وتحديثه.',
        ),
      );

      // 2. Second/later clean attempt succeeds with active status
      when(() => mockApiClient.registerDeviceInstallation(any())).thenAnswer(
        (_) async => InstallationRegistrationDto(
          installationId: 'inst-clean-active',
          platform: 'android',
          status: 'active',
          registeredAt: DateTime.now().toUtc(),
          revision: 1,
        ),
      );

      final secondResult = await evidenceService.ensureRegisteredInstallation();
      expect(secondResult, equals('inst-clean-active'));

      final storedAfterSuccess =
          await tokenStorage.getDeviceInstallationRegistration(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(storedAfterSuccess, equals('inst-clean-active'),
          reason: 'Active registration response must be cached');
    });

    test(
        '12. full attendance submission with PLAY_NONCE_MISMATCH: terminal rejection, 0 outbox pending rows, Arabic trust copy',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenThrow(
        AttendanceSubmissionStageException(
          stage: AttendanceSubmissionStage.installationRegistration,
          causalError: StateError('pending_review'),
          reasonCode: 'PLAY_NONCE_MISMATCH',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('PLAY_NONCE_MISMATCH'));

      final arabicMessage =
          AppFailureMapper.attendanceReasonMessage(result.reasonCode);
      expect(
        arabicMessage,
        equals(
          'تعذر التحقق من سلامة الجهاز. لم يُرسل الحضور؛ أعد المحاولة بعد فتح Google Play وتحديثه.',
        ),
      );

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason:
              'PLAY_NONCE_MISMATCH must never be queued into offline outbox');
    });

    test(
        '13. server 503 MOBILE_ACTION_RESTRICTED: terminal rejection, 0 outbox pending rows, Arabic maintenance copy',
        () async {
      when(() => mockEvidenceService.prepare(any())).thenAnswer(
        (_) async => const AttendanceEvidenceDto(
          contentDigest: 'digest-1',
          installationId: 'inst-1',
          challengeId: 'chal-1',
          signature: 'sig-1',
          integrityToken: 'token-1',
        ),
      );

      when(() => mockApiClient.submitAttendanceEvent(
            eventId: any(named: 'eventId'),
            eventType: any(named: 'eventType'),
            shiftInstanceId: any(named: 'shiftInstanceId'),
            location: any(named: 'location'),
            capturedAt: any(named: 'capturedAt'),
            evidence: any(named: 'evidence'),
            expectedTenantId: any(named: 'expectedTenantId'),
            expectedUserId: any(named: 'expectedUserId'),
          )).thenThrow(
        const ApiException(
          statusCode: 503,
          code: 'MOBILE_ACTION_RESTRICTED',
          message: 'Mobile action is temporarily restricted',
        ),
      );

      final result = await repository.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-101',
        location: testLocation,
      );

      expect(result.status, equals(AttendanceValidationStatus.rejected));
      expect(result.reasonCode, equals('MOBILE_ACTION_RESTRICTED'));

      final arabicMessage =
          AppFailureMapper.attendanceReasonMessage(result.reasonCode);
      expect(
        arabicMessage,
        equals('هذه الخدمة متوقفة مؤقتاً للصيانة. حاول مرة أخرى قريباً.'),
      );

      final pending = await outbox.getPendingEvents(
        tenantId: testSession.tenantId,
        userId: testSession.userId,
      );
      expect(pending, isEmpty,
          reason:
              'MOBILE_ACTION_RESTRICTED must never be queued into offline outbox');
    });
  });
}
