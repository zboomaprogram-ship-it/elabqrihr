import 'manual_attendance_models.dart';

/// Abstract domain repository for HR Sovereign Controls (Feature 015)
///
/// In accordance with Feature 015 Work Order:
/// "Administrative mutations must never be queued as ordinary employee attendance events."
/// All methods communicate directly with online server endpoints and return
/// authoritative server-calculated decisions.
abstract class ManualAttendanceRepository {
  /// Fetches active employee directory for administrative selection
  Future<List<ManualAttendanceEmployeeOption>> getEmployees({String? search});

  /// Submits an append-only manual emergency attendance action
  Future<ManualAttendanceActionResult> submitManualAttendance(
    ManualAttendanceActionRequest request,
  );

  /// Lists unresolved reconciliation items for attendance exception decisions
  Future<List<DetailedReconciliationItem>> getReconciliationItems({
    String? state,
  });

  /// Lists open payroll cycles eligible for administrative adjustment
  Future<List<OpenPayrollCycle>> getOpenPayrollCycles();

  /// Previews calculated financial impact for exception deduction
  Future<AdministrativeAdjustmentPreview> previewAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  );

  /// Records an idempotent administrative adjustment or attendance waiver
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  );
}
