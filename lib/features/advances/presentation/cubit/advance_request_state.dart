import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';

abstract class AdvanceRequestState extends Equatable {
  const AdvanceRequestState();

  @override
  List<Object?> get props => [];
}

class AdvanceRequestInitial extends AdvanceRequestState {
  const AdvanceRequestInitial();
}

class AdvanceRequestPreviewing extends AdvanceRequestState {
  const AdvanceRequestPreviewing();
}

class AdvanceRequestPreviewLoaded extends AdvanceRequestState {
  final AdvanceEligibilityPreviewEntity preview;
  final String requestedAmount;
  final int installmentCount;

  const AdvanceRequestPreviewLoaded({
    required this.preview,
    required this.requestedAmount,
    required this.installmentCount,
  });

  @override
  List<Object?> get props => [preview, requestedAmount, installmentCount];
}

class AdvanceRequestSubmitting extends AdvanceRequestState {
  const AdvanceRequestSubmitting();
}

class AdvanceRequestSuccess extends AdvanceRequestState {
  final AdvanceEntity advance;

  const AdvanceRequestSuccess({required this.advance});

  @override
  List<Object?> get props => [advance];
}

class AdvanceRequestError extends AdvanceRequestState {
  final String message;
  final bool isConflict;
  final bool isDenied;

  const AdvanceRequestError({
    required this.message,
    this.isConflict = false,
    this.isDenied = false,
  });

  @override
  List<Object?> get props => [message, isConflict, isDenied];
}
