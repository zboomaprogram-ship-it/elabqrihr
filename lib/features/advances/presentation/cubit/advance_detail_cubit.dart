import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';

sealed class AdvanceDetailState {
  const AdvanceDetailState();
}

class AdvanceDetailInitial extends AdvanceDetailState {
  const AdvanceDetailInitial();
}

class AdvanceDetailLoaded extends AdvanceDetailState {
  final AdvanceEntity advance;

  const AdvanceDetailLoaded(this.advance);
}

class AdvanceDetailCubit extends Cubit<AdvanceDetailState> {
  AdvanceDetailCubit() : super(const AdvanceDetailInitial());

  void show(AdvanceEntity advance) => emit(AdvanceDetailLoaded(advance));
}
