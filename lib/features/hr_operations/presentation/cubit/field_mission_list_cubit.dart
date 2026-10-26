import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';

sealed class FieldMissionListState extends Equatable {
  const FieldMissionListState();

  @override
  List<Object?> get props => [];
}

final class FieldMissionListInitial extends FieldMissionListState {
  const FieldMissionListInitial();
}

final class FieldMissionListLoading extends FieldMissionListState {
  const FieldMissionListLoading();
}

final class FieldMissionListLoaded extends FieldMissionListState {
  final List<HrOperationSummary> items;
  final String? activeFilter;

  const FieldMissionListLoaded({
    required this.items,
    this.activeFilter,
  });

  @override
  List<Object?> get props => [items, activeFilter];
}

final class FieldMissionListEmpty extends FieldMissionListState {
  final String? activeFilter;

  const FieldMissionListEmpty({this.activeFilter});

  @override
  List<Object?> get props => [activeFilter];
}

final class FieldMissionListForbidden extends FieldMissionListState {
  final String message;

  const FieldMissionListForbidden(this.message);

  @override
  List<Object?> get props => [message];
}

final class FieldMissionListError extends FieldMissionListState {
  final String message;

  const FieldMissionListError(this.message);

  @override
  List<Object?> get props => [message];
}

class FieldMissionListCubit extends Cubit<FieldMissionListState> {
  final HrOperationsRepository _repository;

  FieldMissionListCubit({
    required HrOperationsRepository repository,
  })  : _repository = repository,
        super(const FieldMissionListInitial());

  Future<void> loadMissions({String? stateFilter}) async {
    if (isClosed) return;
    emit(const FieldMissionListLoading());
    try {
      final items = await _repository.listOperations(
        kind: OperationKind.fieldMission,
        state: stateFilter,
      );
      if (isClosed) return;
      if (items.isEmpty) {
        emit(FieldMissionListEmpty(activeFilter: stateFilter));
      } else {
        emit(FieldMissionListLoaded(items: items, activeFilter: stateFilter));
      }
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is AuthFailure) {
        emit(FieldMissionListForbidden(failure.message));
      } else {
        emit(FieldMissionListError(failure.message));
      }
    }
  }
}
