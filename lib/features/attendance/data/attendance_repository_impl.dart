import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/local_attendance_outbox.dart';
import 'package:attend_mobile/core/location/location_service.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/attendance_sync_service.dart';
import 'package:attend_mobile/features/attendance/data/attendance_failure_classifier.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

class AttendanceRepositoryImpl
    implements AttendanceRepository, HasCurrentLocationCapture {
  final ApiClient _apiClient;
  final LocalAttendanceOutbox _outbox;
  final TokenStorage _tokenStorage;
  final LocationService? _locationService;
  final AttendanceSyncService _syncService;
  final AttendanceEvidenceService? _evidenceService;
  final PushRegistrationPort? _pushRegistrationCoordinator;
  final Uuid _uuid = const Uuid();

  AttendanceRepositoryImpl({
    required ApiClient apiClient,
    required LocalAttendanceOutbox outbox,
    required TokenStorage tokenStorage,
    LocationService? locationService,
    AttendanceEvidenceService? evidenceService,
    PushRegistrationPort? pushRegistrationCoordinator,
  })  : _evidenceService = evidenceService,
        _pushRegistrationCoordinator = pushRegistrationCoordinator,
        _apiClient = apiClient,
        _outbox = outbox,
        _tokenStorage = tokenStorage,
        _locationService = locationService,
        _syncService = AttendanceSyncService(
          repository: _DirectApiAttendanceRepo(apiClient),
        );

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    return _apiClient.getCurrentAttendanceContext();
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      throw Exception(
          'Unauthenticated: Cannot record attendance without active session');
    }

    GeoPoint? effectiveLocation = location;
    if (effectiveLocation == null) {
      effectiveLocation = await _locationService?.getCurrentLocation();
    } else if (effectiveLocation.timestamp == null) {
      effectiveLocation = effectiveLocation.copyWith(
        timestamp: DateTime.now().toUtc(),
      );
    } else if (DateTime.now().toUtc().difference(effectiveLocation.timestamp!).abs() >
        const Duration(seconds: 60)) {
      final fresh = await _locationService?.getCurrentLocation();
      if (fresh != null) {
        effectiveLocation = fresh;
      }
    }
    if (effectiveLocation == null) {
      throw Exception('LocationUnavailable: Unable to capture device location');
    }
    if (effectiveLocation.isMocked) {
      throw const MockLocationDetectedException();
    }

    final eventId = clientEventId ?? _uuid.v4();
    final effectiveCapturedAt =
        (capturedAt ?? DateTime.now()).toUtc();

    final localEvent = AttendanceEventEntity(
      id: eventId,
      eventType: eventType,
      capturedAt: effectiveCapturedAt,
      location: effectiveLocation,
      shiftInstanceId: shiftInstanceId,
      status: AttendanceValidationStatus.pendingSync,
    );

    // 1. Prepare evidence first. Local trust material must be prepared before
    // committing anything to outbox. If trust material fails, it is NEVER
    // persisted to outbox as an event that will later synchronize.
    AttendanceEvidenceDto? evidence;
    if (_evidenceService != null) {
      try {
        evidence = await _evidenceService.prepare(localEvent);
      } catch (error) {
        final classification = AttendanceFailureClassifier.classify(error);
        if (_isRevokedDeviceOutcome(classification.reasonCode)) {
          await _purgeRevokedDeviceState(session);
        }
        return localEvent.copyWith(
          status: classification.terminalStatus,
          reasonCode: classification.reasonCode,
        );
      }
    }

    // 2. Attempt online submission
    try {
      final remoteResult = await _apiClient.submitAttendanceEvent(
        eventId: eventId,
        eventType: eventType,
        shiftInstanceId: shiftInstanceId,
        location: effectiveLocation,
        capturedAt: effectiveCapturedAt,
        evidence: evidence,
      );

      return remoteResult;
    } catch (error) {
      final classification = AttendanceFailureClassifier.classify(error);
      if (classification.isRetryable) {
        // Only genuine transport failures are committed to outbox as pendingSync.
        final nextRetryAt = DateTime.now().toUtc().add(
              classification.retryAfter ?? const Duration(seconds: 30),
            );
        await _outbox.saveEvent(
          tenantId: session.tenantId,
          userId: session.userId,
          event: localEvent.copyWith(reasonCode: classification.reasonCode),
        );
        await _outbox.updateEventStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          eventId: eventId,
          status: AttendanceValidationStatus.pendingSync,
          reasonCode: classification.reasonCode,
          nextRetryAt: nextRetryAt,
        );
        return localEvent.copyWith(reasonCode: classification.reasonCode);
      }

      // If the server revoked device access or the device is no longer active,
      // purge the local protected key, registration cache, and push registration
      // so that subsequent authentication requires fresh device enrolment.
      if (_isRevokedDeviceOutcome(classification.reasonCode)) {
        await _purgeRevokedDeviceState(session);
      }

      // Terminal non-transport rejections, policy failures, and client errors
      // are never kept in the outbox retry queue (0 pending outbox rows).
      return localEvent.copyWith(
        status: classification.terminalStatus,
        reasonCode: classification.reasonCode,
      );
    }
  }

  bool _isRevokedDeviceOutcome(String reasonCode) =>
      reasonCode == 'DEVICE_NOT_ACTIVE' ||
      reasonCode == 'DEVICE_REVOKED' ||
      reasonCode == 'INSTALLATION_REVOKED' ||
      reasonCode == 'DEVICE_REENROLL_REQUIRED';

  Future<void> _purgeRevokedDeviceState(AuthSessionEntity session) async {
    try {
      await _tokenStorage.clearDeviceInstallationRegistration(
        tenantId: session.tenantId,
        userId: session.userId,
      );
    } catch (_) {}
    try {
      await _pushRegistrationCoordinator?.disable();
    } catch (_) {}
    try {
      await _evidenceService?.revokeLocalInstallation();
    } catch (_) {}
  }

  @override
  Future<GeoPoint> captureCurrentLocation() async {
    final location = await _locationService?.getCurrentLocation();
    if (location == null) {
      throw Exception('LocationUnavailable: Unable to capture device location');
    }
    if (location.isMocked) {
      throw const MockLocationDetectedException();
    }
    return location;
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() async* {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      yield [];
      return;
    }
    yield* _outbox.watchPendingEvents(
      tenantId: session.tenantId,
      userId: session.userId,
    );
  }

  @override
  Future<void> synchronizeOutbox() async {
    final session = await _tokenStorage.getSession();
    if (session == null) return;

    final pending = await _outbox.getPendingEvents(
      tenantId: session.tenantId,
      userId: session.userId,
    );

    if (pending.isEmpty) return;

    final results = await _syncService.syncBatch(pending);
    for (final res in results) {
      AttendanceValidationStatus newStatus;
      bool isRetry = false;
      DateTime? nextRetry;

      switch (res.outcome) {
        case SyncOutcome.accepted:
          newStatus = AttendanceValidationStatus.accepted;
          break;
        case SyncOutcome.reviewRequired:
          newStatus = AttendanceValidationStatus.pendingReview;
          break;
        case SyncOutcome.rejected:
          newStatus = AttendanceValidationStatus.rejected;
          break;
        case SyncOutcome.conflictDuplicate:
          // Terminal conflict: mark as conflict, not pendingSync
          newStatus = AttendanceValidationStatus.conflict;
          break;
        case SyncOutcome.networkFailure:
          // Bounded retry failure: increment retry count and schedule next attempt
          newStatus = AttendanceValidationStatus.pendingSync;
          isRetry = true;
          nextRetry = DateTime.now().toUtc().add(
                res.retryAfter ?? const Duration(seconds: 30),
              );
          break;
      }

      await _outbox.updateEventStatus(
        tenantId: session.tenantId,
        userId: session.userId,
        eventId: res.eventId,
        status: newStatus,
        reasonCode: res.message,
        isRetryAttempt: isRetry,
        nextRetryAt: nextRetry,
      );
    }
  }
}

class _DirectApiAttendanceRepo implements AttendanceRepository {
  final ApiClient _apiClient;

  _DirectApiAttendanceRepo(this._apiClient);

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() =>
      _apiClient.getCurrentAttendanceContext();

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) {
    if (location == null) {
      throw ArgumentError('Location is required for direct API submission');
    }
    final effectiveCapturedAt =
        (capturedAt ?? location.timestamp ?? DateTime.now()).toUtc();
    return _apiClient.submitAttendanceEvent(
      eventId: clientEventId ?? const Uuid().v4(),
      eventType: eventType,
      shiftInstanceId: shiftInstanceId,
      location: location,
      capturedAt: effectiveCapturedAt,
    );
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);

  @override
  Future<void> synchronizeOutbox() async {}
}
