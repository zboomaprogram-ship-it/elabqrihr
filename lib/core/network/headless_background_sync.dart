import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/network/background_sync_coordinator.dart';
import 'package:attend_mobile/core/network/background_sync_policy.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/android_attendance_trust_bridge.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';
import 'package:attend_mobile/features/requests/data/request_repository_impl.dart';

const _workerChannel = MethodChannel(
  'com.zbooma.elabqrihr/background_sync/worker',
);
const _qaWorkerReplayHarness = bool.fromEnvironment('ATTEND_QA_WORKER_REPLAY');

void _logBackgroundSync(String message) {
  if (kDebugMode) debugPrint('[ATTEND_BACKGROUND_SYNC] $message');
}

/// Headless Flutter entrypoint launched only by the identity-scoped Android
/// WorkManager task. It replays existing outbox records and never collects GPS.
@pragma('vm:entry-point')
Future<void> attendBackgroundSyncEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logBackgroundSync('headless entrypoint started');
  final command = Completer<Map<Object?, Object?>>();
  var succeeded = false;

  _workerChannel.setMethodCallHandler((call) async {
    if (call.method != 'run' || call.arguments is! Map) return false;
    if (!command.isCompleted) {
      command.complete(Map<Object?, Object?>.from(call.arguments as Map));
    }
    return true;
  });

  try {
    await _workerChannel.invokeMethod<void>('ready');
    final arguments = await command.future.timeout(const Duration(seconds: 15));
    final tenantId = arguments['tenantId'];
    final userId = arguments['userId'];
    if (tenantId is! String ||
        tenantId.isEmpty ||
        userId is! String ||
        userId.isEmpty) {
      throw StateError('Missing scheduled identity');
    }
    _logBackgroundSync('received scheduled identity');

    final skipReplay = shouldSkipBackgroundSyncForQa(
      qaSandbox: ApiClient.qaSandboxBuild,
      workerReplayHarness: _qaWorkerReplayHarness,
      releaseMode: kReleaseMode,
    );
    // Ordinary QA builds use disposable local services and deliberately skip
    // OS-managed replay. The explicit debug QA harness exercises the same
    // composition against its local mock server.
    if (skipReplay) {
      _logBackgroundSync('replay skipped by QA sandbox policy');
      succeeded = true;
    } else {
      succeeded = await _runIdentityScopedReplay(
        tenantId,
        userId,
        useSyntheticProvider: _qaWorkerReplayHarness,
      );
    }
  } catch (error, stackTrace) {
    _logBackgroundSync('replay failed: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    succeeded = false;
  } finally {
    try {
      await _workerChannel.invokeMethod<void>(
        'completed',
        {'success': succeeded},
      );
    } catch (_) {}
    _workerChannel.setMethodCallHandler(null);
  }
}

Future<bool> _runIdentityScopedReplay(
  String tenantId,
  String userId, {
  required bool useSyntheticProvider,
}) async {
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.abqrihr.systems/api/v1',
  );
  final tokenStorage = _ExpectedIdentityTokenStorage(tenantId, userId);
  final session = await tokenStorage.getSession();
  // A revoked or switched account makes this old WorkManager record stale.
  if (session == null) {
    _logBackgroundSync('no matching stored session; stale work ignored');
    return true;
  }
  _logBackgroundSync('matching stored session available');

  final apiClient = ApiClient(baseUrl: apiBaseUrl, tokenStorage: tokenStorage);
  final database = await AppDriftDatabase.open(tokenStorage: tokenStorage);
  try {
    _logBackgroundSync('encrypted outbox opened');
    final trustBridge = AndroidAttendanceTrustBridge();
    final evidenceService = AttendanceEvidenceService(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
      installationIdentity: trustBridge,
      deviceAttestation: useSyntheticProvider
          ? _QaBackgroundReplayAttestation(trustBridge)
          : trustBridge,
    );
    final attendanceRepository = AttendanceRepositoryImpl(
      apiClient: apiClient,
      outbox: database,
      tokenStorage: tokenStorage,
      evidenceService: evidenceService,
    );
    final requestRepository = RequestRepositoryImpl(
      apiClient: apiClient,
      database: database,
      tokenStorage: tokenStorage,
    );
    final dynamicRequestRepository = DynamicRequestRepositoryImpl(
      apiClient: apiClient,
      database: database,
      tokenStorage: tokenStorage,
    );
    final coordinator = BackgroundSyncCoordinator(
      attendanceRepository: attendanceRepository,
      requestRepository: requestRepository,
      dynamicRequestRepository: dynamicRequestRepository,
    );
    try {
      await coordinator.synchronizeAll();
      _logBackgroundSync('all outbox lanes synchronized');
    } on SessionIdentityChangedException {
      _logBackgroundSync('identity changed during replay');
      return true;
    }
    return true;
  } finally {
    apiClient.dio.close(force: true);
    await database.close();
  }
}

class _QaBackgroundReplayAttestation implements DeviceAttestationPort {
  _QaBackgroundReplayAttestation(this._trustBridge);

  final AndroidAttendanceTrustBridge _trustBridge;

  @override
  Future<IntegrityEvidence> signCanonicalEnvelope({
    required String canonicalEnvelope,
    required String challenge,
  }) async {
    final installation = await _trustBridge.ensureInstallation();
    final signature = await _trustBridge.signCaptureDigest(canonicalEnvelope);
    return IntegrityEvidence(
      installationId: installation.id,
      signature: signature,
      platformAssertion: 'synthetic-provider-token',
      keyVersion: installation.keyVersion,
    );
  }
}

/// Makes every repository and API authorization read fail closed if Android
/// starts this work after the account has changed or been revoked.
class _ExpectedIdentityTokenStorage extends TokenStorage {
  _ExpectedIdentityTokenStorage(this._tenantId, this._userId);

  final String _tenantId;
  final String _userId;

  @override
  Future<AuthSessionEntity?> getSession() async {
    final session = await super.getSession();
    if (session == null ||
        session.tenantId != _tenantId ||
        session.userId != _userId) {
      return null;
    }
    return session;
  }
}
