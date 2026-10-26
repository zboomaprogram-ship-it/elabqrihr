import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';

sealed class ClearanceCaseDetailState extends Equatable {
  const ClearanceCaseDetailState();

  @override
  List<Object?> get props => [];
}

final class ClearanceCaseDetailInitial extends ClearanceCaseDetailState {
  const ClearanceCaseDetailInitial();
}

final class ClearanceCaseDetailLoading extends ClearanceCaseDetailState {
  const ClearanceCaseDetailLoading();
}

final class ClearanceCaseDetailLoaded extends ClearanceCaseDetailState {
  final HrOperationDetail detail;
  final bool isSubmitting;
  final String? actionError;
  final String? actionSuccessMessage;

  const ClearanceCaseDetailLoaded({
    required this.detail,
    this.isSubmitting = false,
    this.actionError,
    this.actionSuccessMessage,
  });

  ClearanceCaseDetailLoaded copyWith({
    HrOperationDetail? detail,
    bool? isSubmitting,
    String? actionError,
    String? actionSuccessMessage,
  }) {
    return ClearanceCaseDetailLoaded(
      detail: detail ?? this.detail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionError: actionError,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        detail,
        isSubmitting,
        actionError,
        actionSuccessMessage,
      ];
}

final class ClearanceCaseDetailForbidden extends ClearanceCaseDetailState {
  final String message;

  const ClearanceCaseDetailForbidden(this.message);

  @override
  List<Object?> get props => [message];
}

final class ClearanceCaseDetailError extends ClearanceCaseDetailState {
  final String message;

  const ClearanceCaseDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class ClearanceCaseDetailCubit extends Cubit<ClearanceCaseDetailState> {
  final HrOperationsRepository _repository;

  ClearanceCaseDetailCubit({
    required HrOperationsRepository repository,
  })  : _repository = repository,
        super(const ClearanceCaseDetailInitial());

  Future<void> loadDetail(String operationId) async {
    if (isClosed) return;
    emit(const ClearanceCaseDetailLoading());
    try {
      final detail = await _repository.getOperationDetail(operationId);
      if (isClosed) return;
      emit(ClearanceCaseDetailLoaded(detail: detail));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is AuthFailure) {
        emit(ClearanceCaseDetailForbidden(failure.message));
      } else {
        emit(ClearanceCaseDetailError(failure.message));
      }
    }
  }

  Future<void> decideItem({
    required String caseId,
    required String itemId,
    required String commandId,
    required int expectedRevision,
    required String action,
    required String reason,
    String? assignedMembershipId,
    String? evidenceAttachmentId,
  }) async {
    final currentState = state;
    if (currentState is! ClearanceCaseDetailLoaded ||
        currentState.isSubmitting) {
      return;
    }

    emit(currentState.copyWith(isSubmitting: true, actionError: null));

    try {
      final updatedItem = await _repository.decideClearanceItem(
        caseId: caseId,
        itemId: itemId,
        commandId: commandId,
        expectedRevision: expectedRevision,
        action: action,
        reason: reason,
        assignedMembershipId: assignedMembershipId,
        evidenceAttachmentId: evidenceAttachmentId,
      );

      if (isClosed) return;

      final currentClearance = currentState.detail.clearance;
      if (currentClearance == null) return;

      final updatedItems = currentClearance.items.map((i) {
        return i.id == itemId ? updatedItem : i;
      }).toList();

      final allMandatoryDone = updatedItems
          .where((i) => i.mandatory)
          .every((i) => i.isCompleted);

      final updatedClearance = ClearanceCase(
        id: currentClearance.id,
        employeeId: currentClearance.employeeId,
        state: allMandatoryDone ? 'ready' : 'in_progress',
        revision: currentClearance.revision + 1,
        targetLastWorkingDate: currentClearance.targetLastWorkingDate,
        items: updatedItems,
        handoffs: currentClearance.handoffs,
      );

      final updatedDetail = HrOperationDetail(
        id: currentState.detail.id,
        operationKind: currentState.detail.operationKind,
        employeeId: currentState.detail.employeeId,
        employeeName: currentState.detail.employeeName,
        state: allMandatoryDone ? 'clearance_ready' : 'clearance_in_progress',
        revision: currentState.detail.revision + 1,
        submittedAt: currentState.detail.submittedAt,
        nextActionLabelAr: allMandatoryDone
            ? 'اكتملت بنود إخلاء الطرف وجاهزة للاعتماد النهائي'
            : 'متابعة استيفاء بنود العهد المتبقية',
        fieldMission: currentState.detail.fieldMission,
        disciplinary: currentState.detail.disciplinary,
        resignation: currentState.detail.resignation,
        clearance: updatedClearance,
        timeline: [
          ...currentState.detail.timeline,
          TimelineItem(
            id: commandId,
            kind: 'clearance_item_$action',
            occurredAt: DateTime.now(),
            labelAr: 'تحديث بند إخلاء الطرف: ${updatedItem.titleAr}',
            actorLabel: 'المسؤول المختص',
          ),
        ],
        permissions: currentState.detail.permissions,
      );

      emit(currentState.copyWith(
        detail: updatedDetail,
        isSubmitting: false,
        actionSuccessMessage: 'تم تحديث حالة بند إخلاء الطرف بنجاح.',
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(currentState.copyWith(
        isSubmitting: false,
        actionError: failure.message,
      ));
    }
  }

  Future<void> finalizeClearance({
    required String caseId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    final currentState = state;
    if (currentState is! ClearanceCaseDetailLoaded ||
        currentState.isSubmitting) {
      return;
    }

    emit(currentState.copyWith(isSubmitting: true, actionError: null));

    try {
      final finalizedCase = await _repository.finalizeClearance(
        caseId: caseId,
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
        state: 'clearance_completed',
        revision: currentState.detail.revision + 1,
        submittedAt: currentState.detail.submittedAt,
        nextActionLabelAr: 'تم إخلاء الطرف والمخالصة النهائية بنجاح',
        fieldMission: currentState.detail.fieldMission,
        disciplinary: currentState.detail.disciplinary,
        resignation: currentState.detail.resignation,
        clearance: finalizedCase,
        timeline: [
          ...currentState.detail.timeline,
          TimelineItem(
            id: commandId,
            kind: 'clearance_finalized',
            occurredAt: DateTime.now(),
            labelAr: 'اعتماد المخالصة النهائية وإخلاء الطرف رسمياً',
            actorLabel: 'إدارة الموارد البشرية',
          ),
        ],
        permissions: const [],
      );

      emit(currentState.copyWith(
        detail: updatedDetail,
        isSubmitting: false,
        actionSuccessMessage: 'تم إنهاء واعتماد إخلاء الطرف بنجاح.',
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(currentState.copyWith(
        isSubmitting: false,
        actionError: failure.message,
      ));
    }
  }
}
