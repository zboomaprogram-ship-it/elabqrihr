import '../../../core/api/generated/contract_types.dart';
import 'dynamic_request_models.dart';

abstract class DynamicRequestRepository {
  Future<List<RequestTypeCategory>> getRequestCategories();

  Future<List<RequestTypeCategory>> getFinancialRequestCategories();

  Future<DynamicRequestEntity> submitDynamicRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = true,
    String? typeNameAr,
  });

  Future<List<DynamicRequestEntity>> getMyDynamicRequests({
    String? typeKey,
    String? state,
  });

  Future<DynamicRequestEntity> getDynamicRequest(String id);

  Future<DynamicRequestEntity> cancelDynamicRequest({
    required String id,
    required int expectedRevision,
    required String reason,
  });

  Future<DynamicRequestEntity> decideDynamicRequest({
    required String id,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  });

  Future<void> synchronizeOutbox();

  Future<List<ApprovalActivitySummary>> getApprovalActivity({
    String? cursor,
    int? limit,
  });

  Future<List<RequestActivitySummary>> getRequestActivity({
    String? cursor,
    int? limit,
  });

  Future<List<RequestSelectorOption>> getFieldOptions({
    required String definitionVersionId,
    required String fieldKey,
    String? search,
  });
}
