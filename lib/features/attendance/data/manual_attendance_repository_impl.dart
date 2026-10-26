import 'package:attend_mobile/core/api/api_client.dart';
import '../domain/manual_attendance_models.dart';
import '../domain/manual_attendance_repository.dart';

class ManualAttendanceRepositoryImpl implements ManualAttendanceRepository {
  final ApiClient _apiClient;

  ManualAttendanceRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<List<ManualAttendanceEmployeeOption>> getEmployees({
    String? search,
  }) async {
    final response = await _apiClient.getEmployeeDirectory(search: search);
    final rawList = response['items'] as List<dynamic>? ?? [];
    return rawList
        .map((item) =>
            ManualAttendanceEmployeeOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ManualAttendanceActionResult> submitManualAttendance(
    ManualAttendanceActionRequest request,
  ) async {
    // In accordance with Feature 015 Work Order:
    // Administrative mutations must never be queued into the local outbox.
    final response =
        await _apiClient.createManualAttendanceAction(request.toJson());
    return ManualAttendanceActionResult.fromJson(response);
  }

  @override
  Future<List<DetailedReconciliationItem>> getReconciliationItems({
    String? state,
  }) async {
    final response =
        await _apiClient.getDetailedReconciliationItems(state: state);
    final rawList = response['items'] as List<dynamic>? ?? [];
    return rawList
        .map((item) =>
            DetailedReconciliationItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OpenPayrollCycle>> getOpenPayrollCycles() async {
    final response = await _apiClient.getOpenAdjustmentPayrollCycles();
    final rawList = response['items'] as List<dynamic>? ?? [];
    return rawList
        .map((item) => OpenPayrollCycle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AdministrativeAdjustmentPreview> previewAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    final response =
        await _apiClient.previewAdministrativeAdjustment(request.toJson());
    return AdministrativeAdjustmentPreview.fromJson(response);
  }

  @override
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    final response =
        await _apiClient.createAdministrativeAdjustment(request.toJson());
    return AdministrativeAdjustmentResult.fromJson(response);
  }
}
