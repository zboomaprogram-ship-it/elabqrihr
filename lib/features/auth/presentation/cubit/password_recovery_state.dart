import 'package:equatable/equatable.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';

enum PasswordRecoveryStep {
  request,
  confirm,
}

sealed class PasswordRecoveryState extends Equatable {
  final PasswordRecoveryStep step;

  const PasswordRecoveryState({required this.step});

  @override
  List<Object?> get props => [step];
}

class PasswordRecoveryInitial extends PasswordRecoveryState {
  const PasswordRecoveryInitial({
    super.step = PasswordRecoveryStep.request,
  });
}

class PasswordRecoverySubmitting extends PasswordRecoveryState {
  const PasswordRecoverySubmitting({
    required super.step,
  });
}

class PasswordRecoveryRequestSuccess extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryRequestSuccess([
    this.message = AppStringsAr.passwordResetRequestSuccess,
  ]) : super(step: PasswordRecoveryStep.request);

  @override
  List<Object?> get props => [step, message];
}

class PasswordRecoveryConfirmSuccess extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryConfirmSuccess([
    this.message = AppStringsAr.passwordResetSuccess,
  ]) : super(step: PasswordRecoveryStep.confirm);

  @override
  List<Object?> get props => [step, message];
}

class PasswordRecoveryFailure extends PasswordRecoveryState {
  final String message;

  const PasswordRecoveryFailure({
    required super.step,
    required this.message,
  });

  @override
  List<Object?> get props => [step, message];
}
