import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'payslip_list_state.dart';

/// Cubit for the employee self-service payslip list.
/// Single responsibility: paginated list of the authenticated employee's payslips.
/// Scoped to the current auth identity; cleared on logout via BlocProvider disposal.
class PayslipListCubit extends Cubit<PayslipListState> {
  final PayslipRepository _repository;

  PayslipListCubit({required PayslipRepository repository})
      : _repository = repository,
        super(const PayslipListInitial());

  Future<void> load() async {
    if (isClosed) return;
    emit(const PayslipListLoading());
    try {
      final page = await _repository.listMyPayslips();
      if (isClosed) return;
      if (page.items.isEmpty) {
        emit(const PayslipListEmpty());
      } else {
        emit(PayslipListLoaded(
          items: page.items,
          nextCursor: page.nextCursor,
        ));
      }
    } on PayslipAccessDeniedException {
      if (!isClosed) emit(const PayslipListDenied());
    } catch (e) {
      if (!isClosed) {
        emit(PayslipListError(AppFailureMapper.fromGeneric(e).message));
      }
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! PayslipListLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    if (isClosed) return;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.listMyPayslips(cursor: current.nextCursor);
      if (isClosed) return;
      emit(current.copyWith(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on PayslipAccessDeniedException {
      if (!isClosed) emit(const PayslipListDenied());
    } catch (e) {
      if (!isClosed) {
        emit(current.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> retry() => load();
}
