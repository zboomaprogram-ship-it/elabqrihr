import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/leave_quota_repository.dart';
import 'leave_quota_state.dart';

class LeaveQuotaCubit extends Cubit<LeaveQuotaState> {
  final LeaveQuotaRepository _repository;

  LeaveQuotaCubit({
    required LeaveQuotaRepository repository,
  })  : _repository = repository,
        super(const LeaveQuotaInitial());

  Future<void> loadBalances() async {
    emit(const LeaveQuotaLoading());
    try {
      final balances = await _repository.getMyBalances();
      emit(LeaveQuotaLoaded(balances));
    } catch (e) {
      final failure = AppFailureMapper.fromGeneric(e);
      emit(LeaveQuotaError(failure.message));
    }
  }

  Future<void> refresh() async {
    try {
      final balances = await _repository.getMyBalances();
      emit(LeaveQuotaLoaded(balances));
    } catch (e) {
      final failure = AppFailureMapper.fromGeneric(e);
      emit(LeaveQuotaError(failure.message));
    }
  }
}
