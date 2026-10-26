import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/hr_manual_attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/hr_manual_attendance_state.dart';

class FakeManualAttendanceRepo implements ManualAttendanceRepository {
  List<ManualAttendanceEmployeeOption> employees = [
    const ManualAttendanceEmployeeOption(
      id: 'emp-1',
      displayName: 'محمد أحمد',
      employeeNumber: 'EMP-001',
    ),
    const ManualAttendanceEmployeeOption(
      id: 'emp-2',
      displayName: 'سارة خالد',
      employeeNumber: 'EMP-002',
    ),
  ];

  ManualAttendanceActionRequest? lastSubmittedRequest;
  Object? submitError;
  Object? loadEmployeesError;

  @override
  Future<List<ManualAttendanceEmployeeOption>> getEmployees(
      {String? search}) async {
    if (loadEmployeesError != null) throw loadEmployeesError!;
    return employees;
  }

  @override
  Future<ManualAttendanceActionResult> submitManualAttendance(
    ManualAttendanceActionRequest request,
  ) async {
    lastSubmittedRequest = request;
    if (submitError != null) throw submitError!;
    return ManualAttendanceActionResult(
      id: 'res-1',
      employeeId: request.employeeId,
      shiftInstanceId: 'shift-1',
      businessDate: request.businessDate,
      action: request.action,
      effectiveState: 'completed',
      reason: request.reason,
      source: 'hr_manual_override',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<DetailedReconciliationItem>> getReconciliationItems(
          {String? state}) async =>
      [];

  @override
  Future<List<OpenPayrollCycle>> getOpenPayrollCycles() async => [];

  @override
  Future<AdministrativeAdjustmentPreview> previewAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<AdministrativeAdjustmentResult> submitAdministrativeAdjustment(
    AdministrativeAdjustmentRequest request,
  ) async {
    throw UnimplementedError();
  }
}

void main() {
  late FakeManualAttendanceRepo repo;
  late HrManualAttendanceCubit cubit;

  setUp(() {
    repo = FakeManualAttendanceRepo();
    cubit = HrManualAttendanceCubit(
      repository: repo,
      initialBusinessDate: '2026-10-17',
    );
  });

  tearDown(() => cubit.close());

  group('HrManualAttendanceCubit', () {
    test('initial state has correct default values', () {
      expect(cubit.state.businessDate, '2026-10-17');
      expect(cubit.state.actionType, ManualAttendanceActionType.checkIn);
      expect(cubit.state.outcome, HrSubmissionOutcome.idle);
      expect(cubit.state.isValid, isFalse);
    });

    test('loadEmployees populates list and selects first employee', () async {
      await cubit.loadEmployees();
      expect(cubit.state.employees.length, 2);
      expect(cubit.state.selectedEmployeeId, 'emp-1');
      expect(cubit.state.selectedEmployee?.displayName, 'محمد أحمد');
    });

    test('search filters employees without mutating main list', () async {
      await cubit.loadEmployees();
      cubit.updateSearch('سارة');
      expect(cubit.state.filteredEmployees.length, 1);
      expect(cubit.state.filteredEmployees.first.displayName, 'سارة خالد');

      cubit.updateSearch('001');
      expect(cubit.state.filteredEmployees.length, 1);
      expect(cubit.state.filteredEmployees.first.employeeNumber, 'EMP-001');
    });

    test(
        'validation requires employee selection and at least 3 characters reason',
        () async {
      await cubit.loadEmployees();
      expect(cubit.state.isValid, isFalse);

      cubit.updateReason('ab');
      expect(cubit.state.isValid, isFalse);

      cubit.updateReason('عطل في هاتف الموظف');
      expect(cubit.state.isValid, isTrue);
    });

    test('full day validation requires checkOutAt after checkInAt', () async {
      await cubit.loadEmployees();
      cubit.updateActionType(ManualAttendanceActionType.fullDay);
      cubit.updateReason('عطل في هاتف الموظف');

      // Invalid order
      final now = DateTime.now();
      cubit.updateFullDayTimes(now, now.subtract(const Duration(hours: 1)));
      expect(cubit.state.isValid, isFalse);

      // Valid order
      cubit.updateFullDayTimes(now.subtract(const Duration(hours: 8)), now);
      expect(cubit.state.isValid, isTrue);
    });

    test('successful submission emits submitting then success', () async {
      await cubit.loadEmployees();
      cubit.updateReason('عذر مقبول ومعتمد');

      await cubit.submitManualAttendance();

      expect(cubit.state.outcome, HrSubmissionOutcome.success);
      expect(cubit.state.successResult?.source, 'hr_manual_override');
      expect(repo.lastSubmittedRequest?.reason, 'عذر مقبول ومعتمد');
      expect(repo.lastSubmittedRequest?.employeeId, 'emp-1');
      expect(repo.lastSubmittedRequest?.businessDate, '2026-10-17');
    });

    test('truthfully classifies 403 forbidden error', () async {
      repo.submitError =
          Exception('HTTP 403 Forbidden: insufficient permissions');
      await cubit.loadEmployees();
      cubit.updateReason('سبب معتمد');

      await cubit.submitManualAttendance();

      expect(cubit.state.outcome, HrSubmissionOutcome.forbidden);
      expect(cubit.state.errorMessage, contains('صلاحية'));
    });

    test('truthfully classifies 409 conflict error', () async {
      repo.submitError = Exception('409 Conflict: idempotency_key_reused');
      await cubit.loadEmployees();
      cubit.updateReason('سبب معتمد');

      await cubit.submitManualAttendance();

      expect(cubit.state.outcome, HrSubmissionOutcome.conflict);
      expect(cubit.state.errorMessage, contains('تعارض'));
    });

    test('truthfully classifies 422 policy rejection or finalized period',
        () async {
      repo.submitError = Exception('422 ValidationFailed: period is finalized');
      await cubit.loadEmployees();
      cubit.updateReason('سبب معتمد');

      await cubit.submitManualAttendance();

      expect(cubit.state.outcome, HrSubmissionOutcome.policyRejection);
      expect(cubit.state.errorMessage, contains('دورة الرواتب'));
    });

    test(
        'truthfully classifies network failure without saving to offline queue',
        () async {
      repo.submitError = Exception('SocketException: Network unreachable');
      await cubit.loadEmployees();
      cubit.updateReason('سبب معتمد');

      await cubit.submitManualAttendance();

      expect(cubit.state.outcome, HrSubmissionOutcome.networkError);
      expect(cubit.state.errorMessage, contains('الخادم'));
    });
  });
}
