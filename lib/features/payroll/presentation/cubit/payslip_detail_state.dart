import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

sealed class PayslipDetailState {
  const PayslipDetailState();
}

final class PayslipDetailInitial extends PayslipDetailState {
  const PayslipDetailInitial();
}

final class PayslipDetailLoading extends PayslipDetailState {
  const PayslipDetailLoading();
}

final class PayslipDetailLoaded extends PayslipDetailState {
  final PayslipEntity payslip;
  const PayslipDetailLoaded(this.payslip);
}

final class PayslipDetailDenied extends PayslipDetailState {
  const PayslipDetailDenied();
}

final class PayslipDetailNotFound extends PayslipDetailState {
  const PayslipDetailNotFound();
}

final class PayslipDetailError extends PayslipDetailState {
  final String message;
  const PayslipDetailError(this.message);
}
