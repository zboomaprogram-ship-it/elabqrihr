import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';

class FakeDynamicRequestRepo extends Fake implements DynamicRequestRepository {
  List<RequestTypeCategory> categories;
  List<DynamicRequestEntity> dynamicRequests;

  FakeDynamicRequestRepo({
    this.categories = const [],
    this.dynamicRequests = const [],
  });

  @override
  Future<List<RequestTypeCategory>> getRequestCategories() async => categories;

  @override
  Future<void> synchronizeOutbox() async {}

  @override
  Future<List<DynamicRequestEntity>> getMyDynamicRequests(
          {String? typeKey, String? state}) async =>
      dynamicRequests;

  @override
  Future<List<RequestActivitySummary>> getRequestActivity(
          {String? cursor, int? limit}) async =>
      const [];

  @override
  Future<List<ApprovalActivitySummary>> getApprovalActivity(
          {String? cursor, int? limit}) async =>
      const [];
}
