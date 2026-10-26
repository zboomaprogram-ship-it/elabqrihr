import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'advance_list_state.dart';

/// Cubit for the employee self-service advances list.
/// Single responsibility: paginated status list of the authenticated employee's advances.
/// Scoped to the current auth identity; cleared on logout via BlocProvider disposal.
class AdvanceListCubit extends Cubit<AdvanceListState> {
  final AdvanceRepository _repository;

  AdvanceListCubit({required AdvanceRepository repository})
      : _repository = repository,
        super(const AdvanceListInitial());

  Future<void> load({String? stateFilter}) async {
    if (isClosed) return;
    emit(const AdvanceListLoading());
    try {
      final page = await _repository.listMyAdvances(state: stateFilter);
      if (isClosed) return;
      if (page.items.isEmpty) {
        emit(const AdvanceListEmpty());
      } else {
        emit(AdvanceListLoaded(
          items: page.items,
          nextCursor: page.nextCursor,
        ));
      }
    } on AdvanceAccessDeniedException {
      if (!isClosed) emit(const AdvanceListDenied());
    } catch (e) {
      if (!isClosed) {
        emit(AdvanceListError(AppFailureMapper.fromGeneric(e).message));
      }
    }
  }

  Future<void> loadMore({String? stateFilter}) async {
    final current = state;
    if (current is! AdvanceListLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    if (isClosed) return;
    emit(current.copyWith(isLoadingMore: true));
    try {
      final page = await _repository.listMyAdvances(
        cursor: current.nextCursor,
        state: stateFilter,
      );
      if (isClosed) return;
      emit(current.copyWith(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } on AdvanceAccessDeniedException {
      if (!isClosed) emit(const AdvanceListDenied());
    } catch (e) {
      if (!isClosed) {
        emit(current.copyWith(isLoadingMore: false));
      }
    }
  }

  Future<void> retry({String? stateFilter}) => load(stateFilter: stateFilter);
}
