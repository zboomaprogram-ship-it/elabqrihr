import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/generated/contract_types.dart';
import '../../../../core/auth/token_storage.dart';
import '../../../../core/database/drift_attendance_database.dart';
import '../../../../core/errors/app_failure.dart';
import '../domain/dynamic_request_models.dart';
import '../domain/dynamic_request_repository.dart';

class DynamicRequestRepositoryImpl implements DynamicRequestRepository {
  static const _syncBatchLimit = 25;
  final ApiClient _apiClient;
  final AppDriftDatabase _database;
  final TokenStorage _tokenStorage;
  final Uuid _uuid;

  DynamicRequestRepositoryImpl({
    required ApiClient apiClient,
    required AppDriftDatabase database,
    required TokenStorage tokenStorage,
    Uuid uuid = const Uuid(),
  })  : _apiClient = apiClient,
        _database = database,
        _tokenStorage = tokenStorage,
        _uuid = uuid;

  static List<RequestTypeCategory> get builtInCategories =>
      RequestTypeCategory.builtInCategories;

  static RequestFieldDefinition _mapField(RequestFieldDefinitionInput input) {
    final kind = switch (input.kind) {
      RequestFieldKind.short_text => FieldKind.shortText,
      RequestFieldKind.long_text => FieldKind.longText,
      RequestFieldKind.integer => FieldKind.integer,
      RequestFieldKind.decimal => FieldKind.decimal,
      RequestFieldKind.date => FieldKind.date,
      RequestFieldKind.time => FieldKind.time,
      RequestFieldKind.date_time => FieldKind.dateTime,
      RequestFieldKind.single_choice => FieldKind.singleChoice,
      RequestFieldKind.multiple_choice => FieldKind.multipleChoice,
      RequestFieldKind.boolean => FieldKind.boolean,
      RequestFieldKind.attachment => FieldKind.attachment,
      RequestFieldKind.employee_reference => FieldKind.employeeReference,
    };

    final choiceOptions = (input.choices ?? [])
        .map((c) => ChoiceOption(code: c.code, labelAr: c.labelAr))
        .toList();

    final validation = input.validation != null
        ? FieldValidationRule(
            min: input.validation!.min ?? input.minimum,
            max: input.validation!.max ?? input.maximum,
            minLength: input.validation!.minLength ?? input.minLength,
            maxLength: input.validation!.maxLength ?? input.maxLength,
            pattern: input.validation!.pattern,
          )
        : (input.minimum != null ||
                input.maximum != null ||
                input.minLength != null ||
                input.maxLength != null)
            ? FieldValidationRule(
                min: input.minimum,
                max: input.maximum,
                minLength: input.minLength,
                maxLength: input.maxLength,
              )
            : null;

    final dataSource = input.dataSource != null
        ? RequestFieldDataSource(
            source: input.dataSource!.source.toServerString(),
            searchEnabled: input.dataSource!.searchEnabled,
          )
        : null;

    final conditionalVisibility = input.conditionalVisibility != null
        ? ConditionalVisibilityRule(
            dependsOnFieldKey: input.conditionalVisibility!.dependsOnFieldKey,
            operator: input.conditionalVisibility!.operator,
            value: input.conditionalVisibility!.value,
            values: input.conditionalVisibility!.values,
          )
        : null;

    return RequestFieldDefinition(
      key: input.key,
      position: input.position,
      kind: kind,
      labelAr: input.labelAr,
      helpTextAr: input.helpText,
      required: input.required,
      choiceOptions: choiceOptions,
      dataSource: dataSource,
      validation: validation,
      conditionalVisibility: conditionalVisibility,
    );
  }

  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async {
    final page = await _apiClient.listRequestCatalog();
    // The server catalog is the tenant policy. The app deliberately does not
    // add its own categories or policies when a company has not published one.
    return page.items
        .map(
          (item) => RequestTypeCategory(
            id: item.definitionVersionId ?? item.typeKey,
            key: item.typeKey,
            nameAr: item.nameAr,
            descriptionAr: item.description ?? '',
            iconKey: item.iconKey ?? 'assignment',
            fields: item.fields.map(_mapField).toList(),
            offlineEligible: item.offlineEligible,
          ),
        )
        .toList();
  }

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async {
    final page = await _apiClient.listRequestCatalog();
    final categories = <RequestTypeCategory>[];
    for (final item in page.items) {
      if (item.kind == RequestKind.dynamic && item.categoryKey == 'financial') {
        final mappedFields = item.fields.map(_mapField).toList();
        categories.add(
          RequestTypeCategory(
            id: item.definitionVersionId ?? item.typeKey,
            key: item.typeKey,
            nameAr: item.nameAr,
            descriptionAr: item.description ?? '',
            iconKey: item.iconKey ?? 'account_balance_wallet',
            fields: mappedFields,
            offlineEligible: item.offlineEligible,
          ),
        );
      }
    }
    return categories;
  }

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = true,
    String? typeNameAr,
  }) async {
    final session = await _tokenStorage.getSession();
    if (session == null) {
      throw const AuthFailure('الجلسة غير متوفرة');
    }

    // Server policy is authoritative. A client must not infer financial or
    // online-only handling from translated names or keys.
    final isOnlineOnly = !offlineEligible;

    final requestId = _uuid.v4();
    final commandId = _uuid.v4();
    final capturedAt = DateTime.now().toUtc();

    final createDto = CreateDynamicRequest(
      requestId: requestId,
      commandId: commandId,
      definitionVersionId: definitionVersionId,
      capturedAt: capturedAt,
      values: values,
    );

    if (isOnlineOnly) {
      // Online-only commands are never persisted in the offline outbox.
      // They must NEVER be stored in the offline outbox or local database.
      try {
        final res = await _apiClient.createDynamicRequest(createDto.toJson());
        return DynamicRequestEntity.fromJson(res);
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          throw const ConflictFailure(
              'تم إرسال هذا الطلب مسبقاً أو يوجد تعارض');
        }
        if (e.statusCode == 400 || e.statusCode == 422) {
          throw ValidationFailure(e.message);
        }
        if (e.statusCode == 401 || e.statusCode == 403) {
          throw AuthFailure(e.message);
        }
        throw NetworkFailure(e.message);
      } catch (e) {
        throw AppFailureMapper.fromGeneric(e);
      }
    }

    final storedPayload = {
      if (typeNameAr != null) 'typeNameAr': typeNameAr,
      'requestId': requestId,
      'commandId': commandId,
      'definitionVersionId': definitionVersionId,
      'typeKey': typeKey,
      'capturedAt': capturedAt.toIso8601String(),
      'values': values,
    };

    final payloadJson = jsonEncode(storedPayload);

    // 1. Commit locally to outbox first with composite PK
    await _database.saveRequest(
      tenantId: session.tenantId,
      userId: session.userId,
      id: requestId,
      requestType: 'dynamic:$typeKey',
      payloadJson: payloadJson,
      syncStatus: 'pending_sync',
    );

    // 2. Prepare OpenAPI 0.6.1 CreateDynamicRequest (STRICTLY NO typeKey)
    // 3. Attempt online submission
    try {
      final res = await _apiClient.createDynamicRequest(createDto.toJson());
      final entity = DynamicRequestEntity.fromJson(res);

      await _database.updateRequestStatus(
        tenantId: session.tenantId,
        userId: session.userId,
        requestId: requestId,
        status: entity.state,
      );

      return entity;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: requestId,
          status: 'conflict',
          reasonCode: 'CONFLICT_DUPLICATE',
        );
        return DynamicRequestEntity(
          id: requestId,
          typeKey: typeKey,
          typeNameAr: typeNameAr ?? 'طلب مخصص',
          definitionVersionId: definitionVersionId,
          state: 'conflict',
          revision: 1,
          values: values,
          timeline: const [],
          submittedAt: capturedAt,
          reasonCode: 'CONFLICT_DUPLICATE',
        );
      }
      if (e.statusCode >= 400 && e.statusCode < 500) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: requestId,
          status: 'rejected',
          reasonCode: e.code ?? 'POLICY_REJECTED',
        );
        throw AppFailureMapper.fromGeneric(e);
      }
      return DynamicRequestEntity(
        id: requestId,
        typeKey: typeKey,
        typeNameAr: typeNameAr ?? 'طلب مخصص',
        definitionVersionId: definitionVersionId,
        state: 'pending_sync',
        revision: 1,
        values: values,
        timeline: const [],
        submittedAt: capturedAt,
        reasonCode: 'QUEUED_OFFLINE',
      );
    } catch (e) {
      final failure = AppFailureMapper.fromGeneric(e);
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
      return DynamicRequestEntity(
        id: requestId,
        typeKey: typeKey,
        typeNameAr: typeNameAr ?? 'طلب مخصص',
        definitionVersionId: definitionVersionId,
        state: 'pending_sync',
        revision: 1,
        values: values,
        timeline: const [],
        submittedAt: capturedAt,
        reasonCode: 'QUEUED_OFFLINE',
      );
    }
  }

  @override
  Future<void> synchronizeOutbox() async {
    final session = await _tokenStorage.getSession();
    if (session == null) return;

    final pendingRows = await _database.getPendingRequests(
      tenantId: session.tenantId,
      userId: session.userId,
      now: DateTime.now().toUtc(),
      limit: _syncBatchLimit,
      dynamicOnly: true,
    );

    for (final row in pendingRows) {
      if (!row.requestType.startsWith('dynamic:')) continue;

      final currentSession = await _tokenStorage.getSession();
      if (currentSession == null ||
          currentSession.tenantId != session.tenantId ||
          currentSession.userId != session.userId) {
        return;
      }

      if (row.retryCount >= 5) {
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: row.id,
          status: 'rejected',
          reasonCode: 'MAX_RETRIES_EXCEEDED',
        );
        continue;
      }

      try {
        final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
        final requestId = payload['requestId'] as String? ?? row.id;
        final commandId = payload['commandId'] as String;
        final definitionVersionId = payload['definitionVersionId'] as String;
        final capturedAt = DateTime.parse(payload['capturedAt'] as String);
        final values = Map<String, dynamic>.from(payload['values'] as Map);

        final createDto = CreateDynamicRequest(
          requestId: requestId,
          commandId: commandId,
          definitionVersionId: definitionVersionId,
          capturedAt: capturedAt,
          values: values,
        );

        final res = await _apiClient.createDynamicRequest(
          createDto.toJson(),
          expectedTenantId: session.tenantId,
          expectedUserId: session.userId,
        );
        final entity = DynamicRequestEntity.fromJson(res);

        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: row.id,
          status: entity.state,
        );
      } on SessionIdentityChangedException {
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          await _database.updateRequestStatus(
            tenantId: session.tenantId,
            userId: session.userId,
            requestId: row.id,
            status: 'conflict',
            reasonCode: 'CONFLICT_DUPLICATE',
          );
        } else if (e.statusCode >= 400 && e.statusCode < 500) {
          await _database.updateRequestStatus(
            tenantId: session.tenantId,
            userId: session.userId,
            requestId: row.id,
            status: 'rejected',
            reasonCode: e.code ?? 'POLICY_REJECTED',
          );
        } else {
          final backoffSeconds = (5 * (1 << row.retryCount)).clamp(5, 300);
          final nextRetry =
              DateTime.now().toUtc().add(Duration(seconds: backoffSeconds));
          await _database.updateRequestStatus(
            tenantId: session.tenantId,
            userId: session.userId,
            requestId: row.id,
            status: 'pending_sync',
            isRetryAttempt: true,
            nextRetryAt: nextRetry,
          );
        }
      } catch (_) {
        final backoffSeconds = (5 * (1 << row.retryCount)).clamp(5, 300);
        final nextRetry =
            DateTime.now().toUtc().add(Duration(seconds: backoffSeconds));
        await _database.updateRequestStatus(
          tenantId: session.tenantId,
          userId: session.userId,
          requestId: row.id,
          status: 'pending_sync',
          isRetryAttempt: true,
          nextRetryAt: nextRetry,
        );
      }
    }
  }

  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests({
    String? typeKey,
    String? state,
  }) async {
    final session = await _tokenStorage.getSession();
    final localRows = session != null
        ? await _database.getAllRequests(
            tenantId: session.tenantId,
            userId: session.userId,
          )
        : <LocalRequestRow>[];

    try {
      final res = await _apiClient.getMyDynamicRequests(
        typeKey: typeKey,
        state: state,
      );
      final items = res['items'] as List<dynamic>? ?? [];
      final remoteEntities = items
          .map((item) =>
              DynamicRequestEntity.fromJson(item as Map<String, dynamic>))
          .toList();

      final remoteIds = remoteEntities.map((e) => e.id).toSet();

      final localEntities = localRows
          .where((row) =>
              row.requestType.startsWith('dynamic:') &&
              !remoteIds.contains(row.id) &&
              (state == null || row.syncStatus == state))
          .map((row) {
        Map<String, dynamic> values = {};
        String? displayName;
        try {
          final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
          displayName = p['typeNameAr'] as String?;
          values = (p['values'] as Map<String, dynamic>?) ?? {};
        } catch (_) {}

        return DynamicRequestEntity(
          id: row.id,
          typeKey: row.requestType.replaceFirst('dynamic:', ''),
          typeNameAr: displayName ?? 'طلب مخصص',
          definitionVersionId: '',
          state: row.syncStatus,
          revision: 1,
          values: values,
          timeline: const [],
          submittedAt: row.createdAt,
          reasonCode: row.reasonCode,
        );
      }).toList();

      return [...localEntities, ...remoteEntities];
    } catch (e) {
      return localRows
          .where((row) =>
              row.requestType.startsWith('dynamic:') &&
              (state == null || row.syncStatus == state))
          .map((row) {
        Map<String, dynamic> values = {};
        String? displayName;
        try {
          final p = jsonDecode(row.payloadJson) as Map<String, dynamic>;
          displayName = p['typeNameAr'] as String?;
          values = (p['values'] as Map<String, dynamic>?) ?? {};
        } catch (_) {}

        return DynamicRequestEntity(
          id: row.id,
          typeKey: row.requestType.replaceFirst('dynamic:', ''),
          typeNameAr: displayName ?? 'طلب مخصص',
          definitionVersionId: '',
          state: row.syncStatus,
          revision: 1,
          values: values,
          timeline: const [],
          submittedAt: row.createdAt,
          reasonCode: row.reasonCode,
        );
      }).toList();
    }
  }

  @override
  Future<DynamicRequestEntity> getDynamicRequest(String id) async {
    final res = await _apiClient.getDynamicRequest(id);
    return DynamicRequestEntity.fromJson(res);
  }

  @override
  Future<DynamicRequestEntity> cancelDynamicRequest({
    required String id,
    required int expectedRevision,
    required String reason,
  }) async {
    final commandId = _uuid.v4();
    final res = await _apiClient.cancelDynamicRequest(
      dynamicRequestId: id,
      commandId: commandId,
      expectedRevision: expectedRevision,
      reason: reason,
    );
    return DynamicRequestEntity.fromJson(res);
  }

  @override
  Future<DynamicRequestEntity> decideDynamicRequest({
    required String id,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async {
    final res = await _apiClient.decideDynamicRequest(
      dynamicRequestId: id,
      decisionId: decisionId,
      expectedRevision: expectedRevision,
      decision: decision,
      comment: comment,
    );
    return DynamicRequestEntity.fromJson(res);
  }

  @override
  Future<List<ApprovalActivitySummary>> getApprovalActivity({
    String? cursor,
    int? limit,
  }) async {
    final page = await _apiClient.listMyApprovalActivity(
      cursor: cursor,
      limit: limit,
    );
    return page.items;
  }

  @override
  Future<List<RequestActivitySummary>> getRequestActivity({
    String? cursor,
    int? limit,
  }) async {
    final page = await _apiClient.listMyRequestActivity(
      cursor: cursor,
      limit: limit,
    );
    return page.items;
  }

  @override
  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  }) async {
    try {
      final page = await _apiClient.listRequestFieldOptions(
        definitionVersionId: definitionVersionId,
        fieldKey: fieldKey,
        search: search,
      );
      return page.items
          .map((dto) => RequestSelectorOption(
                value: dto.value,
                label: dto.labelAr,
                subtitle: dto.secondaryLabel,
              ))
          .toList();
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }
}
