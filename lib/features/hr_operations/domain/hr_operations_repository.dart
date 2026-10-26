import 'hr_operations_models.dart';

abstract class HrOperationsRepository {
  Future<List<HrOperationSummary>> listOperations({
    OperationKind? kind,
    String? state,
    String? cursor,
    int limit = 25,
  });

  Future<HrOperationDetail> getOperationDetail(String operationId);

  Future<FieldMissionDetail> revokeFieldMission({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  });

  Future<Acknowledgment> acknowledgeDisciplinaryNotice({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required int noticeRevision,
  });

  Future<Grievance> submitDisciplinaryGrievance({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String statement,
    List<String>? attachmentIds,
  });

  Future<ConsequencePreview> previewDisciplinaryConsequence({
    required String operationId,
    required String method,
    num? value,
  });

  Future<ConsequenceDecision> decideDisciplinaryConsequence({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String decision,
    required String reason,
    String? payrollCycleId,
    required String method,
    num? value,
  });

  Future<ClearanceItem> decideClearanceItem({
    required String caseId,
    required String itemId,
    required String commandId,
    required int expectedRevision,
    required String action,
    required String reason,
    String? assignedMembershipId,
    String? evidenceAttachmentId,
  });

  Future<ClearanceCase> finalizeClearance({
    required String caseId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  });
}


