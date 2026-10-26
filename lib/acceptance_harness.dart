// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/location/location_service.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/data/request_repository_impl.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';

class _FixedUuid extends Uuid {
  final List<String> _ids;
  int _idx = 0;
  _FixedUuid(this._ids);
  @override
  String v4({dynamic config, Map<String, dynamic>? options}) {
    if (_idx < _ids.length) {
      return _ids[_idx++];
    }
    return 'fixed-id';
  }
}

class _OfflineDynamicRequestApiClient extends ApiClient {
  _OfflineDynamicRequestApiClient(
      {required super.baseUrl, required super.tokenStorage});

  @override
  Future<Map<String, dynamic>> createDynamicRequest(dynamic payload) async {
    throw const SocketException(
        'Network unreachable for offline dynamic request acceptance Phase 1');
  }
}

class _FixedLocationService implements LocationService {
  const _FixedLocationService();

  @override
  Future<GeoPoint> getCurrentLocation() async {
    return const GeoPoint(
        latitude: 30.0444, longitude: 31.2357, accuracyMeters: 5.0);
  }
}

class _OfflineRequestApiClient extends ApiClient {
  _OfflineRequestApiClient(
      {required super.baseUrl, required super.tokenStorage});

  @override
  Future<RequestDto> submitRequest(Map<String, dynamic> requestPayload) async {
    throw const SocketException(
        'Network unreachable for offline request acceptance Phase 1');
  }
}

class _OfflineApiClient extends ApiClient {
  _OfflineApiClient({required super.baseUrl, required super.tokenStorage});

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required String eventId,
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    required GeoPoint location,
    required DateTime capturedAt,
    AttendanceEvidenceDto? evidence,
  }) async {
    throw const SocketException(
        'Network unreachable for offline acceptance Phase 1');
  }

  @override
  Future<ShiftContextEntity> getCurrentAttendanceContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-restart-001',
      branchName: 'Cairo HQ',
      shiftName: 'Morning Shift',
      scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
    );
  }
}

Future<void> _writeMarker(
    Directory markerDir, String filename, String content) async {
  try {
    final f1 = File('${markerDir.path}/$filename');
    await f1.writeAsString(content);
  } catch (_) {}
  try {
    final parent = markerDir.parent;
    final filesDir = Directory('${parent.path}/files');
    if (!filesDir.existsSync()) {
      filesDir.createSync(recursive: true);
    }
    final f2 = File('${filesDir.path}/$filename');
    await f2.writeAsString(content);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final markerDir = await getApplicationDocumentsDirectory();
  await markerDir.create(recursive: true);

  String phase = const String.fromEnvironment('PHASE', defaultValue: '');
  if (phase.isEmpty) {
    final phaseFile1 = File('${markerDir.path}/current_phase.txt');
    if (phaseFile1.existsSync()) {
      phase = phaseFile1.readAsStringSync().trim();
    }
  }
  if (phase.isEmpty) {
    try {
      final phaseFile2 =
          File('${markerDir.parent.path}/files/current_phase.txt');
      if (phaseFile2.existsSync()) {
        phase = phaseFile2.readAsStringSync().trim();
      }
    } catch (_) {}
  }
  if (phase.isEmpty) {
    phase = '1';
  }

  String host = '10.0.2.2';
  final hostFile1 = File('${markerDir.path}/host_ip.txt');
  if (hostFile1.existsSync()) {
    host = hostFile1.readAsStringSync().trim();
  } else {
    try {
      final hostFile2 = File('${markerDir.parent.path}/files/host_ip.txt');
      if (hostFile2.existsSync()) {
        host = hostFile2.readAsStringSync().trim();
      }
    } catch (_) {}
  }

  const serverPort = '8088';

  try {
    if (phase == '1') {
      print('[ACCEPTANCE_HARNESS] Starting Phase 1 in PID $pid...');

      final tokenStorage = TokenStorage();
      await tokenStorage.saveSession(const AuthSessionEntity(
        accessToken: 'test-access-token',
        refreshToken: 'test-refresh-token',
        tenantId: 'tenant-restart-acceptance',
        userId: 'user-restart-001',
        role: UserRole.employee,
        email: 'restart-001@example.com',
        displayName: 'Restart User 001',
      ));

      final outbox = await AppDriftDatabase.open();
      final offlineClient = _OfflineApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      final repo = AttendanceRepositoryImpl(
        apiClient: offlineClient,
        outbox: outbox,
        tokenStorage: tokenStorage,
        locationService: const _FixedLocationService(),
      );

      const eventId = 'journey-restart-evt-001';
      final result = await repo.submitAttendanceEvent(
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: 'shift-restart-001',
        clientEventId: eventId,
      );

      if (result.status != AttendanceValidationStatus.pendingSync) {
        throw StateError('Phase 1 failed: Expected pendingSync status');
      }

      final pending = await outbox
          .watchPendingEvents(
            tenantId: 'tenant-restart-acceptance',
            userId: 'user-restart-001',
          )
          .first;
      if (!pending.any((e) => e.id == eventId)) {
        throw StateError('Phase 1 failed: Event $eventId missing from outbox');
      }

      await _writeMarker(markerDir, 'phase1_result.txt',
          'PHASE_1_SUCCESS:PID=$pid:EVENT=$eventId\n');
      print('[ACCEPTANCE_HARNESS] Phase 1 completed successfully in PID $pid');

      await outbox.close();
    } else if (phase == '2') {
      print('[ACCEPTANCE_HARNESS] Starting Phase 2 in fresh PID $pid...');

      final tokenStorage = TokenStorage();
      final session = await tokenStorage.getSession();
      if (session == null || session.tenantId != 'tenant-restart-acceptance') {
        throw StateError('Phase 2 failed: Session identity not restored');
      }

      final outbox = await AppDriftDatabase.open();
      const eventId = 'journey-restart-evt-001';

      final pendingBeforeSync = await outbox
          .watchPendingEvents(
            tenantId: 'tenant-restart-acceptance',
            userId: 'user-restart-001',
          )
          .first;
      if (!pendingBeforeSync.any((e) => e.id == eventId)) {
        throw StateError(
            'Phase 2 failed: Event did not survive process restart in Drift DB');
      }

      final liveClient = ApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      final repo = AttendanceRepositoryImpl(
        apiClient: liveClient,
        outbox: outbox,
        tokenStorage: tokenStorage,
        locationService: const _FixedLocationService(),
      );

      final pendingEntry = await outbox.getEntry(
          tenantId: 'tenant-restart-acceptance',
          userId: 'user-restart-001',
          eventId: eventId);
      final retryAt = pendingEntry?.nextRetryAt;
      if (retryAt != null) {
        final remaining = retryAt.toUtc().difference(DateTime.now().toUtc());
        if (remaining > Duration.zero) {
          await Future<void>.delayed(
              remaining + const Duration(milliseconds: 100));
        }
      }
      await repo.synchronizeOutbox();
      await repo.synchronizeOutbox();

      final pendingAfterSync = await outbox.getPendingEvents(
        tenantId: 'tenant-restart-acceptance',
        userId: 'user-restart-001',
      );
      if (pendingAfterSync.isNotEmpty) {
        throw StateError('Phase 2 failed: Pending events remaining after sync');
      }

      final entry = await outbox.getEntry(
        tenantId: 'tenant-restart-acceptance',
        userId: 'user-restart-001',
        eventId: eventId,
      );
      if (entry == null || entry.syncStatus != 'accepted') {
        throw StateError(
            'Phase 2 failed: Entry not terminal accepted (syncStatus=${entry?.syncStatus})');
      }

      await _writeMarker(markerDir, 'phase2_result.txt',
          'PHASE_2_SUCCESS:PID=$pid:EVENT=$eventId:STATUS=${entry.syncStatus}\n');
      print('[ACCEPTANCE_HARNESS] Phase 2 completed successfully in PID $pid');

      await outbox.close();
    } else if (phase == 'request_1') {
      print('[ACCEPTANCE_HARNESS] Starting Request Phase 1 in PID $pid...');

      final tokenStorage = TokenStorage();
      await tokenStorage.saveSession(const AuthSessionEntity(
        accessToken: 'test-req-token',
        refreshToken: 'test-req-refresh',
        tenantId: 'tenant-restart-req',
        userId: 'user-restart-001',
        role: UserRole.employee,
        email: 'restart-req@example.com',
        displayName: 'Restart Req User',
      ));

      final outbox = await AppDriftDatabase.open();
      final offlineClient = _OfflineRequestApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      final repo = RequestRepositoryImpl(
        apiClient: offlineClient,
        database: outbox,
        tokenStorage: tokenStorage,
      );

      const requestId = 'journey-restart-req-001';
      // Strict OpenAPI 0.4.0 payload: NO requestedMinutes!
      final result = await repo.submitRequest(
        requestId: requestId,
        type: RequestType.leave,
        payload: {
          'categoryId': '00000000-0000-0000-0000-000000000001',
          'startDate': '2026-09-25',
          'endDate': '2026-09-26',
          'reason': 'طلب إجازة في وضع عدم الاتصال',
        },
      );

      if (result.state != RequestState.pendingSync) {
        throw StateError('Request Phase 1 failed: Expected pendingSync status');
      }

      final pending = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-req',
        userId: 'user-restart-001',
      );
      if (!pending.any((r) => r.id == requestId)) {
        throw StateError(
            'Request Phase 1 failed: Request $requestId missing from Drift request outbox');
      }

      await _writeMarker(markerDir, 'phase1_result.txt',
          'PHASE_1_SUCCESS:PID=$pid:REQUEST=$requestId\n');
      print(
          '[ACCEPTANCE_HARNESS] Request Phase 1 completed successfully in PID $pid');

      await outbox.close();
    } else if (phase == 'request_2') {
      print(
          '[ACCEPTANCE_HARNESS] Starting Request Phase 2 in fresh PID $pid...');

      final tokenStorage = TokenStorage();
      final session = await tokenStorage.getSession();
      if (session == null || session.tenantId != 'tenant-restart-req') {
        throw StateError(
            'Request Phase 2 failed: Session identity not restored from secure storage');
      }

      final outbox = await AppDriftDatabase.open();
      const requestId = 'journey-restart-req-001';

      final pendingBeforeSync = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-req',
        userId: 'user-restart-001',
      );
      if (!pendingBeforeSync.any((r) => r.id == requestId)) {
        throw StateError(
            'Request Phase 2 failed: Request did not survive process restart in Drift DB');
      }

      final liveClient = ApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      final repo = RequestRepositoryImpl(
        apiClient: liveClient,
        database: outbox,
        tokenStorage: tokenStorage,
      );

      // Synchronize outbox to host mock server
      await repo.synchronizeOutbox();

      final pendingAfterSync = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-req',
        userId: 'user-restart-001',
      );
      if (pendingAfterSync.isNotEmpty) {
        throw StateError(
            'Request Phase 2 failed: Pending requests remaining after sync');
      }

      final entry = await outbox.getRequestEntry(
        tenantId: 'tenant-restart-req',
        userId: 'user-restart-001',
        requestId: requestId,
      );
      if (entry == null || entry.syncStatus != 'pending_approval') {
        throw StateError(
            'Request Phase 2 failed: Entry not terminal pending_approval '
            '(status=${entry?.syncStatus}, reason=${entry?.reasonCode}, retries=${entry?.retryCount})');
      }

      await _writeMarker(markerDir, 'phase2_result.txt',
          'PHASE_2_SUCCESS:PID=$pid:REQUEST=$requestId:STATUS=${entry.syncStatus}\n');
      print(
          '[ACCEPTANCE_HARNESS] Request Phase 2 completed successfully in PID $pid');

      await outbox.close();
    } else if (phase == 'dynamic_1') {
      print(
          '[ACCEPTANCE_HARNESS] Starting Dynamic Request Phase 1 in PID $pid...');

      final tokenStorage = TokenStorage();
      await tokenStorage.saveSession(const AuthSessionEntity(
        accessToken: 'test-dyn-token',
        refreshToken: 'test-dyn-refresh',
        tenantId: 'tenant-restart-dyn',
        userId: 'user-restart-001',
        role: UserRole.employee,
        email: 'restart-dyn@example.com',
        displayName: 'Restart Dyn User',
      ));

      final outbox = await AppDriftDatabase.open();
      final offlineClient = _OfflineDynamicRequestApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      const requestId = 'journey-restart-dyn-001';
      const commandId = 'journey-cmd-dyn-001';

      final repo = DynamicRequestRepositoryImpl(
        apiClient: offlineClient,
        database: outbox,
        tokenStorage: tokenStorage,
        uuid: _FixedUuid([requestId, commandId]),
      );

      final result = await repo.submitDynamicRequest(
        typeKey: 'general_inquiry',
        definitionVersionId: '00000000-0000-0000-0000-000000000001',
        values: {
          'title': 'طلب عهدة مؤقتة',
          'description': 'طلب عهدة شراء أدوات مكتبية',
        },
      );

      if (result.state != 'pending_sync') {
        throw StateError(
            'Dynamic Request Phase 1 failed: Expected pending_sync status, got ${result.state}');
      }

      final pending = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-dyn',
        userId: 'user-restart-001',
      );
      if (!pending.any((r) => r.id == requestId)) {
        throw StateError(
            'Dynamic Request Phase 1 failed: Request $requestId missing from Drift request outbox');
      }

      await _writeMarker(markerDir, 'phase1_result.txt',
          'PHASE_1_SUCCESS:PID=$pid:REQUEST=$requestId:COMMAND=$commandId\n');
      print(
          '[ACCEPTANCE_HARNESS] Dynamic Request Phase 1 completed successfully in PID $pid');

      await outbox.close();
    } else if (phase == 'dynamic_2') {
      print(
          '[ACCEPTANCE_HARNESS] Starting Dynamic Request Phase 2 in fresh PID $pid...');

      final tokenStorage = TokenStorage();
      final session = await tokenStorage.getSession();
      if (session == null || session.tenantId != 'tenant-restart-dyn') {
        throw StateError(
            'Dynamic Request Phase 2 failed: Session identity not restored from secure storage');
      }

      final outbox = await AppDriftDatabase.open();
      const requestId = 'journey-restart-dyn-001';
      const commandId = 'journey-cmd-dyn-001';

      final pendingBeforeSync = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-dyn',
        userId: 'user-restart-001',
      );
      if (!pendingBeforeSync.any((r) => r.id == requestId)) {
        throw StateError(
            'Dynamic Request Phase 2 failed: Request did not survive process restart in Drift DB');
      }

      final liveClient = ApiClient(
        baseUrl: 'http://$host:$serverPort/api/v1',
        tokenStorage: tokenStorage,
      );

      final repo = DynamicRequestRepositoryImpl(
        apiClient: liveClient,
        database: outbox,
        tokenStorage: tokenStorage,
      );

      // Synchronize outbox to host mock server
      await repo.synchronizeOutbox();

      final pendingAfterSync = await outbox.getPendingRequests(
        tenantId: 'tenant-restart-dyn',
        userId: 'user-restart-001',
      );
      if (pendingAfterSync.isNotEmpty) {
        throw StateError(
            'Dynamic Request Phase 2 failed: Pending requests remaining after sync');
      }

      final entry = await outbox.getRequestEntry(
        tenantId: 'tenant-restart-dyn',
        userId: 'user-restart-001',
        requestId: requestId,
      );
      if (entry == null || entry.syncStatus != 'submitted') {
        throw StateError(
            'Dynamic Request Phase 2 failed: Entry not terminal submitted '
            '(status=${entry?.syncStatus}, reason=${entry?.reasonCode}, retries=${entry?.retryCount})');
      }

      await _writeMarker(markerDir, 'phase2_result.txt',
          'PHASE_2_SUCCESS:PID=$pid:REQUEST=$requestId:COMMAND=$commandId:STATUS=${entry.syncStatus}\n');
      print(
          '[ACCEPTANCE_HARNESS] Dynamic Request Phase 2 completed successfully in PID $pid');

      await outbox.close();
    }
  } catch (e, stack) {
    print('[ACCEPTANCE_HARNESS] FATAL ERROR in phase $phase: $e\n$stack');
    await _writeMarker(markerDir, 'phase_error.txt',
        'PHASE_ERROR:PID=$pid:PHASE=$phase:ERROR=$e\n$stack\n');
  }

  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('ACCEPTANCE RUNNER DONE', textDirection: TextDirection.ltr),
      ),
    ),
  ));
}
