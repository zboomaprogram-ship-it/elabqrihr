import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

/// Self-service payslip repository. Scoped to the authenticated employee.
/// May only call GET /finance/payslips and GET /finance/payslips/{id}.
/// Never returns salary amounts from a local cache or calculates financial values.
abstract class PayslipRepository {
  /// Returns a cursor-paginated page of the authenticated employee's payslips.
  Future<PayslipPageEntity> listMyPayslips({
    String? cursor,
    int limit = 25,
  });

  /// Returns the full detail of a single payslip the employee is authorized to read.
  /// Throws [PayslipAccessDeniedException] on 403.
  /// Throws [PayslipNotFoundException] on 404.
  Future<PayslipEntity> getPayslip(String payslipId);
}

class PayslipAccessDeniedException implements Exception {
  const PayslipAccessDeniedException();
  @override
  String toString() => 'PayslipAccessDeniedException';
}

class PayslipNotFoundException implements Exception {
  final String payslipId;
  const PayslipNotFoundException(this.payslipId);
  @override
  String toString() => 'PayslipNotFoundException($payslipId)';
}
