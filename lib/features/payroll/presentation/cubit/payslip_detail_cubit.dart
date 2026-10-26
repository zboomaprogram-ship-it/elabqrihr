import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'payslip_detail_state.dart';

/// Cubit for the employee self-service payslip detail view.
/// Single responsibility: load and hold one payslip by ID.
/// The downloadUrl is never cached beyond the widget lifecycle.
class PayslipDetailCubit extends Cubit<PayslipDetailState> {
  final PayslipRepository _repository;

  PayslipDetailCubit({required PayslipRepository repository})
      : _repository = repository,
        super(const PayslipDetailInitial());

  Future<void> load(String payslipId) async {
    if (isClosed) return;
    emit(const PayslipDetailLoading());
    try {
      final payslip = await _repository.getPayslip(payslipId);
      if (isClosed) return;
      emit(PayslipDetailLoaded(payslip));
    } on PayslipAccessDeniedException {
      if (!isClosed) emit(const PayslipDetailDenied());
    } on PayslipNotFoundException {
      if (!isClosed) emit(const PayslipDetailNotFound());
    } catch (e) {
      if (!isClosed) {
        emit(PayslipDetailError(AppFailureMapper.fromGeneric(e).message));
      }
    }
  }

  Future<void> retry(String payslipId) => load(payslipId);
}
