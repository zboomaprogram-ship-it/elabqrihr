import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'password_recovery_state.dart';

class PasswordRecoveryCubit extends Cubit<PasswordRecoveryState> {
  final AuthRepository _authRepository;

  PasswordRecoveryCubit({
    required AuthRepository authRepository,
    PasswordRecoveryStep initialStep = PasswordRecoveryStep.request,
  })  : _authRepository = authRepository,
        super(PasswordRecoveryInitial(step: initialStep));

  void setStep(PasswordRecoveryStep step) {
    emit(PasswordRecoveryInitial(step: step));
  }

  void reset() {
    emit(const PasswordRecoveryInitial(step: PasswordRecoveryStep.request));
  }

  Future<void> requestReset({
    required String email,
    required String tenantSlug,
  }) async {
    emit(const PasswordRecoverySubmitting(step: PasswordRecoveryStep.request));

    try {
      await _authRepository.requestPasswordReset(
        email: email.trim(),
        tenantSlug: tenantSlug.trim(),
      );

      // FR-015: Indistinguishable response for known and unknown accounts.
      emit(const PasswordRecoveryRequestSuccess(
        AppStringsAr.passwordResetRequestSuccess,
      ));
    } catch (e) {
      final failure = AppFailureMapper.fromGeneric(e);
      emit(PasswordRecoveryFailure(
        step: PasswordRecoveryStep.request,
        message: failure.message,
      ));
    }
  }

  Future<void> confirmReset({
    required String resetToken,
    required String newPassword,
  }) async {
    emit(const PasswordRecoverySubmitting(step: PasswordRecoveryStep.confirm));

    try {
      await _authRepository.confirmPasswordReset(
        resetToken: resetToken.trim(),
        newPassword: newPassword,
      );

      emit(const PasswordRecoveryConfirmSuccess(
        AppStringsAr.passwordResetSuccess,
      ));
    } catch (e) {
      final failure = AppFailureMapper.fromGeneric(e);
      emit(PasswordRecoveryFailure(
        step: PasswordRecoveryStep.confirm,
        message: failure.message,
      ));
    }
  }
}
