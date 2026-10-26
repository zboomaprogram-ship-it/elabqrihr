import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';

sealed class FieldMissionDetailState extends Equatable {
  const FieldMissionDetailState();

  @override
  List<Object?> get props => [];
}

final class FieldMissionDetailInitial extends FieldMissionDetailState {
  const FieldMissionDetailInitial();
}

final class FieldMissionDetailLoading extends FieldMissionDetailState {
  const FieldMissionDetailLoading();
}

final class FieldMissionDetailLoaded extends FieldMissionDetailState {
  final HrOperationDetail detail;
  final bool isRevoking;
  final String? actionError;

  const FieldMissionDetailLoaded({
    required this.detail,
    this.isRevoking = false,
    this.actionError,
  });

  FieldMissionDetailLoaded copyWith({
    HrOperationDetail? detail,
    bool? isRevoking,
    String? actionError,
  }) {
    return FieldMissionDetailLoaded(
      detail: detail ?? this.detail,
      isRevoking: isRevoking ?? this.isRevoking,
      actionError: actionError,
    );
  }

  @override
  List<Object?> get props => [detail, isRevoking, actionError];
}

final class FieldMissionDetailRevokedSuccess extends FieldMissionDetailState {
  final HrOperationDetail detail;

  const FieldMissionDetailRevokedSuccess(this.detail);

  @override
  List<Object?> get props => [detail];
}

final class FieldMissionDetailForbidden extends FieldMissionDetailState {
  final String message;

  const FieldMissionDetailForbidden(this.message);

  @override
  List<Object?> get props => [message];
}

final class FieldMissionDetailError extends FieldMissionDetailState {
  final String message;

  const FieldMissionDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class FieldMissionDetailCubit extends Cubit<FieldMissionDetailState> {
  final HrOperationsRepository _repository;

  FieldMissionDetailCubit({
    required HrOperationsRepository repository,
  })  : _repository = repository,
        super(const FieldMissionDetailInitial());

  Future<void> loadDetail(String operationId) async {
    if (isClosed) return;
    emit(const FieldMissionDetailLoading());
    try {
      final detail = await _repository.getOperationDetail(operationId);
      if (isClosed) return;
      emit(FieldMissionDetailLoaded(detail: detail));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is AuthFailure) {
        emit(FieldMissionDetailForbidden(failure.message));
      } else {
        emit(FieldMissionDetailError(failure.message));
      }
    }
  }

  Future<void> revokeMission({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    final currentState = state;
    if (currentState is! FieldMissionDetailLoaded || currentState.isRevoking) {
      return;
    }

    emit(currentState.copyWith(isRevoking: true, actionError: null));

    try {
      final updatedMission = await _repository.revokeFieldMission(
        operationId: operationId,
        commandId: commandId,
        expectedRevision: expectedRevision,
        reason: reason,
      );

      if (isClosed) return;

      final updatedDetail = HrOperationDetail(
        id: currentState.detail.id,
        operationKind: currentState.detail.operationKind,
        employeeId: currentState.detail.employeeId,
        employeeName: currentState.detail.employeeName,
        state: 'revoked',
        revision: currentState.detail.revision + 1,
        submittedAt: currentState.detail.submittedAt,
        nextActionLabelAr: 'تم إلغاء المأمورية',
        fieldMission: updatedMission,
        timeline: [
          ...currentState.detail.timeline,
          TimelineItem(
            id: commandId,
            kind: 'mission_revoked',
            occurredAt: DateTime.now(),
            labelAr: 'تم إلغاء سريان المأمورية',
            actorLabel: 'الإدارة',
          ),
        ],
        permissions: const [],
      );

      emit(FieldMissionDetailRevokedSuccess(updatedDetail));
      emit(FieldMissionDetailLoaded(detail: updatedDetail));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(currentState.copyWith(
        isRevoking: false,
        actionError: failure.message,
      ));
    }
  }
}
