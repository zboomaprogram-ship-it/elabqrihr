import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';

sealed class DisciplinaryCaseDetailState extends Equatable {
  const DisciplinaryCaseDetailState();

  @override
  List<Object?> get props => [];
}

final class DisciplinaryCaseDetailInitial extends DisciplinaryCaseDetailState {
  const DisciplinaryCaseDetailInitial();
}

final class DisciplinaryCaseDetailLoading extends DisciplinaryCaseDetailState {
  const DisciplinaryCaseDetailLoading();
}

final class DisciplinaryCaseDetailLoaded extends DisciplinaryCaseDetailState {
  final HrOperationDetail detail;
  final bool isSubmitting;
  final ConsequencePreview? consequencePreview;
  final String? actionError;
  final String? actionSuccessMessage;

  const DisciplinaryCaseDetailLoaded({
    required this.detail,
    this.isSubmitting = false,
    this.consequencePreview,
    this.actionError,
    this.actionSuccessMessage,
  });

  DisciplinaryCaseDetailLoaded copyWith({
    HrOperationDetail? detail,
    bool? isSubmitting,
    ConsequencePreview? consequencePreview,
    String? actionError,
    String? actionSuccessMessage,
  }) {
    return DisciplinaryCaseDetailLoaded(
      detail: detail ?? this.detail,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      consequencePreview: consequencePreview ?? this.consequencePreview,
      actionError: actionError,
      actionSuccessMessage: actionSuccessMessage,
    );
  }

  @override
  List<Object?> get props => [
        detail,
        isSubmitting,
        consequencePreview,
        actionError,
        actionSuccessMessage,
      ];
}

final class DisciplinaryCaseDetailForbidden extends DisciplinaryCaseDetailState {
  final String message;

  const DisciplinaryCaseDetailForbidden(this.message);

  @override
  List<Object?> get props => [message];
}

final class DisciplinaryCaseDetailError extends DisciplinaryCaseDetailState {
  final String message;

  const DisciplinaryCaseDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class DisciplinaryCaseDetailCubit extends Cubit<DisciplinaryCaseDetailState> {
  final HrOperationsRepository _repository;

  DisciplinaryCaseDetailCubit({
    required HrOperationsRepository repository,
  })  : _repository = repository,
        super(const DisciplinaryCaseDetailInitial());

  Future<void> loadDetail(String operationId) async {
    if (isClosed) return;
    emit(const DisciplinaryCaseDetailLoading());
    try {
      final detail = await _repository.getOperationDetail(operationId);
      if (isClosed) return;
      emit(DisciplinaryCaseDetailLoaded(detail: detail));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is AuthFailure) {
        emit(DisciplinaryCaseDetailForbidden(failure.message));
      } else {
        emit(DisciplinaryCaseDetailError(failure.message));
      }
    }
  }

  Future<void> acknowledgeNotice({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required int noticeRevision,
  }) async {
    final currentState = state;
    if (currentState is! DisciplinaryCaseDetailLoaded ||
        currentState.isSubmitting) {
      return;
    }

    emit(currentState.copyWith(isSubmitting: true, actionError: null));

    try {
      final acknowledgment = await _repository.acknowledgeDisciplinaryNotice(
        operationId: operationId,
        commandId: commandId,
        expectedRevision: expectedRevision,
        noticeRevision: noticeRevision,
      );

      if (isClosed) return;

      final currentDisciplinary = currentState.detail.disciplinary;
      final updatedDisciplinary = currentDisciplinary != null
          ? DisciplinaryDetail(
              policyTitle: currentDisciplinary.policyTitle,
              incidentAt: currentDisciplinary.incidentAt,
              noticeRevision: currentDisciplinary.noticeRevision,
              acknowledgmentState: 'acknowledged',
              grievanceDueAt: currentDisciplinary.grievanceDueAt,
              grievances: currentDisciplinary.grievances,
              consequenceState: currentDisciplinary.consequenceState,
            )
          : null;

      final updatedDetail = HrOperationDetail(
        id: currentState.detail.id,
        operationKind: currentState.detail.operationKind,
        employeeId: currentState.detail.employeeId,
        employeeName: currentState.detail.employeeName,
        state: currentState.detail.state,
        revision: currentState.detail.revision + 1,
        submittedAt: currentState.detail.submittedAt,
        nextActionLabelAr: 'تم الإقرار بالعلم والاستلام فقط',
        fieldMission: currentState.detail.fieldMission,
        disciplinary: updatedDisciplinary,
        timeline: [
          ...currentState.detail.timeline,
          TimelineItem(
            id: acknowledgment.id,
            kind: 'notice_acknowledged',
            occurredAt: acknowledgment.acknowledgedAt,
            labelAr: 'إقرار بالاستلام والعلم (لا يعد اعترافاً بالمسؤولية)',
            actorLabel: currentState.detail.employeeName,
          ),
        ],
        permissions: currentState.detail.permissions
            .where((p) => p != 'acknowledge_notice')
            .toList(),
      );

      emit(currentState.copyWith(
        detail: updatedDetail,
        isSubmitting: false,
        actionSuccessMessage:
            'تم تسجيل استلام الإشعار بالعلم فقط. حقك في التظلم يظل متاحاً.',
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

  Future<void> submitGrievance({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String statement,
    List<String>? attachmentIds,
  }) async {
    final currentState = state;
    if (currentState is! DisciplinaryCaseDetailLoaded ||
        currentState.isSubmitting) {
      return;
    }

    emit(currentState.copyWith(isSubmitting: true, actionError: null));

    try {
      final grievance = await _repository.submitDisciplinaryGrievance(
        operationId: operationId,
        commandId: commandId,
        expectedRevision: expectedRevision,
        statement: statement,
        attachmentIds: attachmentIds,
      );

      if (isClosed) return;

      final currentDisciplinary = currentState.detail.disciplinary;
      final updatedDisciplinary = currentDisciplinary != null
          ? DisciplinaryDetail(
              policyTitle: currentDisciplinary.policyTitle,
              incidentAt: currentDisciplinary.incidentAt,
              noticeRevision: currentDisciplinary.noticeRevision,
              acknowledgmentState: currentDisciplinary.acknowledgmentState,
              grievanceDueAt: currentDisciplinary.grievanceDueAt,
              grievances: [...currentDisciplinary.grievances, grievance],
              consequenceState: currentDisciplinary.consequenceState,
            )
          : null;

      final updatedDetail = HrOperationDetail(
        id: currentState.detail.id,
        operationKind: currentState.detail.operationKind,
        employeeId: currentState.detail.employeeId,
        employeeName: currentState.detail.employeeName,
        state: 'grievance_under_review',
        revision: currentState.detail.revision + 1,
        submittedAt: currentState.detail.submittedAt,
        nextActionLabelAr: 'التظلم قيد مراجعة الإدارة المختصة',
        fieldMission: currentState.detail.fieldMission,
        disciplinary: updatedDisciplinary,
        timeline: [
          ...currentState.detail.timeline,
          TimelineItem(
            id: grievance.id,
            kind: 'grievance_submitted',
            occurredAt: grievance.submittedAt,
            labelAr: 'تم تقديم التماس وتظلم إداري من الموظف',
            actorLabel: currentState.detail.employeeName,
          ),
        ],
        permissions: currentState.detail.permissions
            .where((p) => p != 'submit_grievance')
            .toList(),
      );

      emit(currentState.copyWith(
        detail: updatedDetail,
        isSubmitting: false,
        actionSuccessMessage: 'تم قيد التظلم بنجاح وإحالته للجنة المختصة.',
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

  Future<void> previewConsequence({
    required String operationId,
    required String method,
    num? value,
  }) async {
    final currentState = state;
    if (currentState is! DisciplinaryCaseDetailLoaded) return;

    try {
      final preview = await _repository.previewDisciplinaryConsequence(
        operationId: operationId,
        method: method,
        value: value,
      );
      if (isClosed) return;
      emit(currentState.copyWith(consequencePreview: preview));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(currentState.copyWith(actionError: failure.message));
    }
  }
}
