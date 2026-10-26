import 'package:attend_mobile/core/api/api_client.dart';
import '../domain/hr_operations_models.dart';
import '../domain/hr_operations_repository.dart';

class HrOperationsRepositoryImpl implements HrOperationsRepository {
  final ApiClient _apiClient;

  HrOperationsRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<List<HrOperationSummary>> listOperations({
    OperationKind? kind,
    String? state,
    String? cursor,
    int limit = 25,
  }) async {
    final response = await _apiClient.listHrOperations(
      operationKind: kind?.toApiString(),
      state: state,
      cursor: cursor,
      limit: limit,
    );
    final rawList = response['items'] as List<dynamic>? ?? [];
    return rawList
        .map((item) =>
            HrOperationSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<HrOperationDetail> getOperationDetail(String operationId) async {
    final response = await _apiClient.getHrOperation(operationId);
    return HrOperationDetail.fromJson(response);
  }

  @override
  Future<FieldMissionDetail> revokeFieldMission({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    final response = await _apiClient.revokeFieldMission(
      operationId: operationId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      reason: reason,
    );
    return FieldMissionDetail.fromJson(response);
  }

  @override
  Future<Acknowledgment> acknowledgeDisciplinaryNotice({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required int noticeRevision,
  }) async {
    final response = await _apiClient.acknowledgeDisciplinaryNotice(
      operationId: operationId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      noticeRevision: noticeRevision,
    );
    return Acknowledgment.fromJson(response);
  }

  @override
  Future<Grievance> submitDisciplinaryGrievance({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String statement,
    List<String>? attachmentIds,
  }) async {
    final response = await _apiClient.submitDisciplinaryGrievance(
      operationId: operationId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      statement: statement,
      attachmentIds: attachmentIds,
    );
    return Grievance.fromJson(response);
  }

  @override
  Future<ConsequencePreview> previewDisciplinaryConsequence({
    required String operationId,
    required String method,
    num? value,
  }) async {
    final response = await _apiClient.previewDisciplinaryConsequence(
      operationId: operationId,
      method: method,
      value: value,
    );
    return ConsequencePreview.fromJson(response);
  }

  @override
  Future<ConsequenceDecision> decideDisciplinaryConsequence({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String decision,
    required String reason,
    String? payrollCycleId,
    required String method,
    num? value,
  }) async {
    final response = await _apiClient.decideDisciplinaryConsequence(
      operationId: operationId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      decision: decision,
      reason: reason,
      payrollCycleId: payrollCycleId,
      method: method,
      value: value,
    );
    return ConsequenceDecision.fromJson(response);
  }

  @override
  Future<ClearanceItem> decideClearanceItem({
    required String caseId,
    required String itemId,
    required String commandId,
    required int expectedRevision,
    required String action,
    required String reason,
    String? assignedMembershipId,
    String? evidenceAttachmentId,
  }) async {
    final response = await _apiClient.decideClearanceItem(
      caseId: caseId,
      itemId: itemId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      action: action,
      reason: reason,
      assignedMembershipId: assignedMembershipId,
      evidenceAttachmentId: evidenceAttachmentId,
    );
    return ClearanceItem.fromJson(response);
  }

  @override
  Future<ClearanceCase> finalizeClearance({
    required String caseId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    final response = await _apiClient.finalizeClearance(
      caseId: caseId,
      commandId: commandId,
      expectedRevision: expectedRevision,
      reason: reason,
    );
    return ClearanceCase.fromJson(response);
  }
}


