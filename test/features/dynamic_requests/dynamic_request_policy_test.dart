import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _SessionStorage extends TokenStorage {
  _SessionStorage(this._session);
  final AuthSessionEntity _session;

  @override
  Future<AuthSessionEntity?> getSession() async => _session;
}

class _RecordingRepository implements DynamicRequestRepository {
  bool? receivedOfflineEligible;

  @override
  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = true,
    String? typeNameAr,
  }) async {
    receivedOfflineEligible = offlineEligible;
    return DynamicRequestEntity(
      id: 'request-1',
      typeKey: typeKey,
      typeNameAr: 'طلب مالي',
      definitionVersionId: definitionVersionId,
      state: 'pending_approval',
      revision: 1,
      values: values,
      timeline: const [],
      submittedAt: DateTime.utc(2026),
    );
  }

  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async => const [];

  @override
  Future<List<RequestTypeCategory>> getFinancialRequestCategories() async =>
      const [];
  @override
  Future<void> synchronizeOutbox() async {}
  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests(
          {String? typeKey, String? state}) async =>
      const [];
  @override
  Future<DynamicRequestEntity> getDynamicRequest(String id) =>
      throw UnimplementedError();
  @override
  Future<DynamicRequestEntity> cancelDynamicRequest(
          {required String id,
          required int expectedRevision,
          required String reason}) =>
      throw UnimplementedError();
  @override
  Future<DynamicRequestEntity> decideDynamicRequest(
          {required String id,
          required String decisionId,
          required int expectedRevision,
          required String decision,
          String? comment}) =>
      throw UnimplementedError();
  @override
  Future<List<ApprovalActivitySummary>> getApprovalActivity(
          {String? cursor, int? limit}) async =>
      const [];
  @override
  Future<List<RequestActivitySummary>> getRequestActivity(
          {String? cursor, int? limit}) async =>
      const [];
  @override
  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  }) async =>
      const [];
}

void main() {
  test(
      'server online-only policy is preserved when submitting a catalogue request',
      () async {
    final repository = _RecordingRepository();
    final cubit = DynamicRequestCubit(repository: repository);

    await cubit.submitRequest(
      typeKey: 'salary_advance',
      definitionVersionId: 'advance-v2',
      values: const {'amount': 100},
      offlineEligible: false,
    );

    expect(repository.receivedOfflineEligible, isFalse);
  });

  test('an online-only request is never committed to the local outbox',
      () async {
    const session = AuthSessionEntity(
      accessToken: 'access-token',
      tenantId: 'tenant-policy-test',
      userId: 'employee-policy-test',
      role: UserRole.employee,
      email: 'employee@example.test',
      displayName: 'موظف الاختبار',
    );
    final storage = _SessionStorage(session);
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      )),
    ));
    final database = AppDriftDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DynamicRequestRepositoryImpl(
      apiClient:
          ApiClient(baseUrl: 'http://test', dio: dio, tokenStorage: storage),
      database: database,
      tokenStorage: storage,
    );

    await expectLater(
      repository.submitDynamicRequest(
        typeKey: 'expense_claim',
        definitionVersionId: 'published-expense-v1',
        values: const {'amount': 100},
        offlineEligible: false,
      ),
      throwsA(isA<NetworkFailure>()),
    );

    expect(
      await database.getAllRequests(
        tenantId: session.tenantId,
        userId: session.userId,
      ),
      isEmpty,
    );
  });
}
