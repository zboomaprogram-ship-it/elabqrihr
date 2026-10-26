import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/data/request_sync_service.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

class RequestRepositoryImpl
    implements
        RequestRepository,
        EmployeeShiftRepository,
        RequestAttachmentRepository {
  final ApiClient _apiClient;
  final AppDriftDatabase _database;
  final TokenStorage _tokenStorage;
  late final RequestSyncService _syncService;
  final Uuid _uuid = const Uuid();

  RequestRepositoryImpl({
    required ApiClient apiClient,
    required AppDriftDatabase database,
    required TokenStorage tokenStorage,
    RequestSyncService? syncService,
  })  : _apiClient = apiClient,
        _database = database,
        _tokenStorage = tokenStorage {
    _syncService = syncService ??
        RequestSyncService(repository: _DirectApiRequestRepo(apiClient));
  }

  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) async {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      throw Exception(
          'Unauthenticated: Cannot submit request without active session');
    }

    final payloadJson = jsonEncode(payload);

    // 1. Commit locally to outbox first (Durable Offline-First)
    await _database.saveRequest(
      tenantId: session.tenantId,
      userId: session.userId,
      id: requestId,
      requestType: type.toApiValue(),
      payloadJson: payloadJson,
      syncStatus: 'pending_sync',
    );

    // 2. Attempt online delivery
    try {
      final cleanPayload = Map<String, dynamic>.from(payload)
        ..remove('requestedMinutes');
      final requestBody = <String, dynamic>{
        'requestId': requestId,
        'type': type.toApiValue(),
        ...cleanPayload,
      };

      final remoteDto = await _apiClient.submitRequest(requestBody);

      await _database.updateRequestStatus(
        tenantId: session.tenantId,
        userId: session.userId,
        requestId: requestId,
        status: remoteDto.state,
      );

      return _mapDtoToEntity(remoteDto);
    } catch (e) {
      if (e is ApiException) {
        if (e.statusCode == 409 && e.code == 'CONFLICT_DUPLICATE') {
          await _database.updateRequestStatus(
            tenantId: session.tenantId,
            userId: session.userId,
            requestId: requestId,
            status: 'conflict',
            reasonCode: 'CONFLICT_DUPLICATE',
          );
          return RequestEntity(
            id: requestId,
            employeeId: session.userId,
            type: type,
            state: RequestState.conflict,
            revision: 1,
            requestedMinutes: payload['requestedMinutes'] as int? ?? 0,
            submittedAt: DateTime.now().toUtc(),
            reasonCode: 'CONFLICT_DUPLICATE',
            details: payload,
            steps: const [],
          );
        }

        if (e.statusCode >= 400 && e.statusCode < 500) {
          // Client or policy rejection (400, 401, 403, 404, 422, etc.): terminal rejection
          await _database.updateRequestStatus(
            tenantId: session.tenantId,
            userId: session.userId,
            requestId: requestId,
            status: 'rejected',
            reasonCode: e.code ?? 'POLICY_REJECTED',
          );
          rethrow;
        }
      }

      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is ConflictFailure) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: requestId,
          status: 'conflict',
          reasonCode: 'CONFLICT_DUPLICATE',
        );
        return RequestEntity(
          id: requestId,
          employeeId: session.userId,
          type: type,
          state: RequestState.conflict,
          revision: 1,
          requestedMinutes: payload['requestedMinutes'] as int? ?? 0,
          submittedAt: DateTime.now().toUtc(),
          reasonCode: 'CONFLICT_DUPLICATE',
          details: payload,
          steps: const [],
        );
      }

      if (failure is ValidationFailure ||
          failure is AuthFailure ||
          failure is NotFoundFailure) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: requestId,
          status: 'rejected',
          reasonCode: failure.code ?? 'POLICY_REJECTED',
        );
        rethrow;
      }

      // Network or transient error: mark as pending_sync with QUEUED_OFFLINE
      await _database.updateRequestStatus(
        tenantId: session.tenantId,
        userId: session.userId,
        requestId: requestId,
        status: 'pending_sync',
        reasonCode: 'QUEUED_OFFLINE',
      );

      return RequestEntity(
        id: requestId,
        employeeId: session.userId,
        type: type,
        state: RequestState.pendingSync,
        revision: 1,
        requestedMinutes: payload['requestedMinutes'] as int? ?? 0,
        submittedAt: DateTime.now().toUtc(),
        reasonCode: 'QUEUED_OFFLINE',
        details: payload,
        steps: const [],
      );
    }
  }

  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async {
    final session = await _tokenStorage.getSession();
    List<LocalRequestRow> localRows = const [];
    if (session != null) {
      try {
        localRows = await _database.getAllRequests(
          tenantId: session.tenantId,
          userId: session.userId,
        );
      } catch (_) {}
    }

    try {
      final page = await _apiClient.getMyRequests(
        cursor: cursor,
        limit: limit,
        type: type?.toApiValue(),
        state: state?.toApiValue(),
      );

      final remoteEntities = page.items.map(_mapDtoToEntity).toList();

      // Incorporate dynamic requests from unified /request-activity
      try {
        final activityPage = await _apiClient.listMyRequestActivity(
          cursor: cursor,
          limit: limit,
        );
        for (final act in activityPage.items) {
          if (act.kind == RequestKind.dynamic) {
            if (state != null && act.state != state.toApiValue()) continue;
            remoteEntities.add(
              RequestEntity(
                id: act.id,
                employeeId: '',
                type: RequestType.attendanceCorrection,
                state: RequestStateX.fromApiValue(act.state),
                revision: act.revision,
                requestedMinutes: 0,
                submittedAt: act.submittedAt,
                decidedAt: null,
                cancelledAt: null,
                reasonCode: act.currentStageLabel,
                details: {'dynamicTypeKey': act.typeKey},
                steps: const [],
                isDynamic: true,
                dynamicTypeNameAr: act.typeNameAr,
              ),
            );
          }
        }
      } catch (_) {}

      final remoteIds = remoteEntities.map((e) => e.id).toSet();

      // Find local entries that are not yet acknowledged by remote (e.g. pending_sync, conflict, or rejected)
      final unacknowledgedLocal = localRows
          .where((row) =>
              !remoteIds.contains(row.id) &&
              (type == null || row.requestType == type.toApiValue()) &&
              (state == null || row.syncStatus == state.toApiValue()))
          .map(_mapRowToEntity)
          .toList();

      return [...unacknowledgedLocal, ...remoteEntities];
    } catch (e) {
      // Offline fallback: if local rows exist, return filtered local rows
      final filteredLocal = localRows
          .where((row) =>
              (type == null || row.requestType == type.toApiValue()) &&
              (state == null || row.syncStatus == state.toApiValue()))
          .map(_mapRowToEntity)
          .toList();

      if (filteredLocal.isNotEmpty) {
        return filteredLocal;
      }
      rethrow;
    }
  }

  @override
  Future<RequestEntity> getRequestDetail(String requestId) async {
    try {
      final dto = await _apiClient.getRequestDetail(requestId);
      return _mapDtoToEntity(dto);
    } catch (e) {
      // Check local database for offline or pending entry
      final session = await _tokenStorage.getSession();
      if (session != null) {
        final localEntry = await _database.getRequestEntry(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: requestId,
        );
        if (localEntry != null) {
          return _mapRowToEntity(localEntry);
        }
      }
      rethrow;
    }
  }

  @override
  Future<RequestEntity> cancelRequest({
    required String requestId,
    required int expectedRevision,
    required String reason,
  }) async {
    final commandId = _uuid.v4();
    final dto = await _apiClient.cancelRequest(
      requestId: requestId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      reason: reason,
    );
    return _mapDtoToEntity(dto);
  }

  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async {
    final dtos = await _apiClient.getMyLeaveBalances();
    return dtos
        .map((d) => LeaveBalanceEntity(
              employeeId: d.employeeId,
              categoryId: d.categoryId,
              categoryName: d.categoryName,
              periodStart: d.periodStart,
              periodEnd: d.periodEnd,
              balanceMinutes: d.balanceMinutes,
            ))
        .toList();
  }

  @override
  Future<List<EmployeeShiftEntity>> listMyShiftInstances({
    required String startDate,
    required String endDate,
    int limit = 50,
  }) async {
    final page = await _apiClient.getMyShiftInstances(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
    return page.items
        .map((shift) => EmployeeShiftEntity(
              shiftInstanceId: shift.shiftInstanceId,
              businessDate: shift.businessDate,
              startsAt: shift.startsAt,
              endsAt: shift.endsAt,
              branchName: shift.branchName,
              state: shift.state,
            ))
        .toList(growable: false);
  }

  @override
  Stream<List<RequestEntity>> watchPendingRequests() async* {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      yield const [];
      return;
    }

    yield* _database
        .watchPendingRequests(
          tenantId: session.tenantId,
          userId: session.userId,
        )
        .map((rows) => rows.map(_mapRowToEntity).toList());
  }

  @override
  Future<void> synchronizeOutbox() async {
    final session = await _tokenStorage.getSession();
    if (session == null) return;

    final pending = await _database.getPendingRequests(
      tenantId: session.tenantId,
      userId: session.userId,
      now: DateTime.now().toUtc(),
    );

    if (pending.isEmpty) return;

    // Dynamic rows use a different command envelope and synchronization owner.
    final entities = pending
        .where((row) => !row.requestType.startsWith('dynamic:'))
        .map(_mapRowToEntity)
        .toList();
    if (entities.isEmpty) return;
    final results = await _syncService.syncBatch(entities);

    for (final res in results) {
      if (res.outcome == RequestSyncOutcome.synchronized &&
          res.entity != null) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: res.requestId,
          status: res.entity!.state.toApiValue(),
        );
      } else if (res.outcome == RequestSyncOutcome.conflict) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: res.requestId,
          status: 'conflict',
          reasonCode: 'CONFLICT_DUPLICATE',
        );
      } else if (res.outcome == RequestSyncOutcome.validationFailure) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: res.requestId,
          status: 'rejected',
          reasonCode: res.message,
        );
      } else if (res.outcome == RequestSyncOutcome.networkFailure) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: res.requestId,
          status: 'pending_sync',
          reasonCode: res.message,
          isRetryAttempt: true,
          nextRetryAt: DateTime.now().toUtc().add(const Duration(seconds: 30)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reviewer Operations (US2: T035-T036) - Online Only
  // ---------------------------------------------------------------------------

  @override
  Future<List<RequestEntity>> listApprovalInbox({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
    String? employeeId,
    String? effectiveFrom,
    String? effectiveTo,
  }) async {
    final page = await _apiClient.getApprovalInbox(
      cursor: cursor,
      limit: limit,
      status: state?.toApiValue(),
      employeeId: employeeId,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
    );
    return page.items.map(_mapDtoToEntity).toList();
  }

  @override
  Future<RequestEntity> decideRequest({
    required String requestId,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async {
    final dto = await _apiClient.decideRequest(
      requestId: requestId,
      decisionId: decisionId,
      expectedRevision: expectedRevision,
      decision: decision,
      comment: comment,
    );
    return _mapDtoToEntity(dto);
  }

  RequestEntity _mapDtoToEntity(RequestDto dto) {
    return RequestEntity(
      id: dto.id,
      employeeId: dto.employeeId,
      employeeName: dto.employeeName,
      type: RequestTypeX.fromApiValue(dto.type),
      state: RequestStateX.fromApiValue(dto.state),
      revision: dto.revision,
      requestedMinutes: dto.requestedMinutes,
      submittedAt: dto.submittedAt,
      decidedAt: dto.decidedAt,
      cancelledAt: dto.cancelledAt,
      reasonCode: dto.reasonCode,
      details: dto.details,
      steps: dto.steps
          .map((s) => ApprovalStepEntity(
                id: s.id,
                position: s.position,
                reviewerRole: s.reviewerRole,
                reviewerName: s.reviewerName,
                state: s.state,
                decidedAt: s.decidedAt,
                comment: s.comment,
              ))
          .toList(),
    );
  }

  @override
  Future<RequestAttachmentEntity> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  }) async {
    final dto = await _apiClient.uploadRequestAttachment(
      bytes: bytes,
      filename: filename,
      mediaType: mediaType,
    );
    return RequestAttachmentEntity(
      id: dto.id,
      displayName: dto.displayName,
      mediaType: dto.mediaType,
      sizeBytes: dto.sizeBytes,
      state: dto.state,
      expiresAt: dto.expiresAt,
    );
  }

  RequestEntity _mapRowToEntity(LocalRequestRow row) {
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    } catch (_) {}

    final isDynamic = row.requestType.startsWith('dynamic:');
    return RequestEntity(
      id: row.id,
      employeeId: row.userId,
      type: isDynamic
          ? RequestType.dynamic
          : RequestTypeX.fromApiValue(row.requestType),
      isDynamic: isDynamic,
      dynamicTypeNameAr:
          isDynamic ? payload['typeNameAr'] as String? ?? 'طلب مخصص' : null,
      state: RequestStateX.fromApiValue(row.syncStatus),
      revision: 1,
      requestedMinutes: payload['requestedMinutes'] as int? ?? 0,
      submittedAt: row.createdAt,
      reasonCode: row.reasonCode,
      details: payload,
      steps: const [],
    );
  }
}

class _DirectApiRequestRepo implements RequestRepository {
  final ApiClient _api;
  _DirectApiRequestRepo(this._api);

  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) async {
    final cleanPayload = Map<String, dynamic>.from(payload)
      ..remove('requestedMinutes');
    final requestBody = <String, dynamic>{
      'requestId': requestId,
      'type': type.toApiValue(),
      ...cleanPayload,
    };
    final dto = await _api.submitRequest(requestBody);
    return RequestEntity(
      id: dto.id,
      employeeId: dto.employeeId,
      employeeName: dto.employeeName,
      type: RequestTypeX.fromApiValue(dto.type),
      state: RequestStateX.fromApiValue(dto.state),
      revision: dto.revision,
      requestedMinutes: dto.requestedMinutes,
      submittedAt: dto.submittedAt,
      decidedAt: dto.decidedAt,
      cancelledAt: dto.cancelledAt,
      reasonCode: dto.reasonCode,
      details: dto.details,
      steps: dto.steps
          .map((s) => ApprovalStepEntity(
                id: s.id,
                position: s.position,
                reviewerRole: s.reviewerRole,
                reviewerName: s.reviewerName,
                state: s.state,
                decidedAt: s.decidedAt,
                comment: s.comment,
              ))
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
