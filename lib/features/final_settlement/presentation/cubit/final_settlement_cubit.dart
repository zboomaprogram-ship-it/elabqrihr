import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/final_settlement_models.dart';
import '../../domain/final_settlement_repository.dart';

sealed class FinalSettlementState {
  const FinalSettlementState();
}

final class FinalSettlementInitial extends FinalSettlementState {
  const FinalSettlementInitial();
}

final class FinalSettlementLoading extends FinalSettlementState {
  const FinalSettlementLoading();
}

final class FinalSettlementEmpty extends FinalSettlementState {
  const FinalSettlementEmpty();
}

final class FinalSettlementLoaded extends FinalSettlementState {
  final SettlementStatementEntity statement;
  final String? savedPath;
  const FinalSettlementLoaded(this.statement, {this.savedPath});
}

final class FinalSettlementFailure extends FinalSettlementState {
  final String message;
  const FinalSettlementFailure(this.message);
}

class FinalSettlementCubit extends Cubit<FinalSettlementState> {
  final FinalSettlementRepository _repository;
  FinalSettlementCubit({required FinalSettlementRepository repository})
      : _repository = repository,
        super(const FinalSettlementInitial());

  Future<void> load([String? settlementId]) async {
    emit(const FinalSettlementLoading());
    try {
      final statement = settlementId == null
          ? await _repository.getLatestStatement()
          : await _repository.getStatement(settlementId);
      emit(statement == null
          ? const FinalSettlementEmpty()
          : FinalSettlementLoaded(statement));
    } catch (_) {
      emit(const FinalSettlementFailure(
          'تعذر تحميل كشف المخالصة. تحقق من صلاحية الحساب ثم أعد المحاولة.'));
    }
  }

  Future<void> download() async {
    final current = state;
    if (current is! FinalSettlementLoaded) return;
    try {
      final path = await _repository
          .downloadPrivateDocument(current.statement.settlementId);
      emit(FinalSettlementLoaded(current.statement, savedPath: path));
    } catch (_) {
      emit(const FinalSettlementFailure(
          'المستند غير جاهز أو انتهت صلاحية التحميل. اطلب إعادة إنشائه.'));
    }
  }
}
