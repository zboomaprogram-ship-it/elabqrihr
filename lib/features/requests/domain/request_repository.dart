import 'dart:async';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

abstract class RequestRepository {
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  });

  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  });

  Future<RequestEntity> getRequestDetail(String requestId);

  Future<RequestEntity> cancelRequest({
    required String requestId,
    required int expectedRevision,
    required String reason,
  });

  Future<List<LeaveBalanceEntity>> getMyLeaveBalances();

  Stream<List<RequestEntity>> watchPendingRequests();

  Future<void> synchronizeOutbox();

  // Reviewer Operations (US2 / T035-T036)
  Future<List<RequestEntity>> listApprovalInbox({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
    String? employeeId,
    String? effectiveFrom,
    String? effectiveTo,
  });

  Future<RequestEntity> decideRequest({
    required String requestId,
    required String decisionId,
    required int expectedRevision,
    required String decision, // approve | reject
    String? comment,
  });
}

/// Capability for uploading private request attachments.
abstract class RequestAttachmentRepository {
  Future<RequestAttachmentEntity> uploadAttachment({
    required List<int> bytes,
    required String filename,
    String? mediaType,
  });
}

/// Read-only capability for selecting server-authorized shift instances.
abstract class EmployeeShiftRepository {
  Future<List<EmployeeShiftEntity>> listMyShiftInstances({
    required String startDate,
    required String endDate,
    int limit = 50,
  });
}
