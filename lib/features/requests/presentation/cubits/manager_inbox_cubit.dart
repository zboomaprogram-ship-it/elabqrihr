import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

abstract class ManagerInboxState extends Equatable {
  const ManagerInboxState();

  @override
  List<Object?> get props => [];
}

class ManagerInboxInitial extends ManagerInboxState {
  const ManagerInboxInitial();
}

class ManagerInboxLoading extends ManagerInboxState {
  const ManagerInboxLoading();
}

class ManagerInboxLoaded extends ManagerInboxState {
  final List<RequestEntity> requests;
  final RequestState? filterState;
  final bool isDeciding;
  final String? decidedRequestId;
  final String? errorMessage;
  final String? conflictMessage;

  const ManagerInboxLoaded({
    required this.requests,
    this.filterState,
    this.isDeciding = false,
    this.decidedRequestId,
    this.errorMessage,
    this.conflictMessage,
  });

  ManagerInboxLoaded copyWith({
    List<RequestEntity>? requests,
    RequestState? filterState,
    bool? isDeciding,
    String? decidedRequestId,
    String? errorMessage,
    String? conflictMessage,
    bool clearFilterState = false,
    bool clearConflict = false,
    bool clearError = false,
  }) {
    return ManagerInboxLoaded(
      requests: requests ?? this.requests,
      filterState: clearFilterState ? null : (filterState ?? this.filterState),
      isDeciding: isDeciding ?? this.isDeciding,
      decidedRequestId: decidedRequestId ?? this.decidedRequestId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      conflictMessage:
          clearConflict ? null : (conflictMessage ?? this.conflictMessage),
    );
  }

  @override
  List<Object?> get props => [
        requests,
        filterState,
        isDeciding,
        decidedRequestId,
        errorMessage,
        conflictMessage,
      ];
}

class ManagerInboxError extends ManagerInboxState {
  final String message;
  const ManagerInboxError(this.message);

  @override
  List<Object?> get props => [message];
}

class ManagerInboxCubit extends Cubit<ManagerInboxState> {
  final RequestRepository _repository;
  final DynamicRequestRepository? _dynamicRepository;
  final Uuid _uuid = const Uuid();

  ManagerInboxCubit({
    required RequestRepository repository,
    DynamicRequestRepository? dynamicRepository,
  })  : _repository = repository,
        _dynamicRepository = dynamicRepository,
        super(const ManagerInboxInitial());

  Future<void> loadInbox({
    RequestState? stateFilter,
    bool refresh = false,
  }) async {
    if (!refresh && state is ManagerInboxLoaded && stateFilter == null) return;

    if (isClosed) return;
    emit(const ManagerInboxLoading());
    try {
      final items = await _repository.listApprovalInbox(
        state: stateFilter,
      );

      final combined = List<RequestEntity>.from(items);

      if (_dynamicRepository != null) {
        try {
          final approvalActivities =
              await _dynamicRepository.getApprovalActivity();
          for (final act in approvalActivities) {
            if (act.kind == RequestKind.dynamic) {
              if (stateFilter != null &&
                  _approvalActivityState(act.state) != stateFilter) {
                continue;
              }
              combined.add(
                RequestEntity(
                  id: act.requestId,
                  employeeId: '',
                  employeeName: act.requesterDisplayName,
                  type: RequestType.dynamic,
                  state: _approvalActivityState(act.state),
                  revision: act.expectedRevision,
                  requestedMinutes: 0,
                  submittedAt: act.submittedAt,
                  decidedAt: null,
                  cancelledAt: null,
                  reasonCode: act.stageLabel,
                  details: const {'dynamicActivity': true},
                  steps: const [],
                  isDynamic: true,
                  dynamicTypeNameAr: act.typeNameAr,
                ),
              );
            }
          }
        } catch (_) {}
      }

      combined.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      if (isClosed) return;
      emit(ManagerInboxLoaded(
        requests: combined,
        filterState: stateFilter,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(ManagerInboxError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> decideRequest({
    required String requestId,
    required int expectedRevision,
    required String decision, // "approve" or "reject"
    String? comment,
    bool isDynamic = false,
  }) async {
    if (state is! ManagerInboxLoaded) return;
    final current = state as ManagerInboxLoaded;

    if (isClosed) return;
    emit(current.copyWith(
      isDeciding: true,
      decidedRequestId: requestId,
      clearConflict: true,
      clearError: true,
    ));

    final decisionId = _uuid.v4();

    try {
      RequestEntity updated;
      if (isDynamic && _dynamicRepository != null) {
        // Fetch dynamic detail before decisions and preserve the returned revision
        final detail = await _dynamicRepository.getDynamicRequest(requestId);
        final dyn = await _dynamicRepository.decideDynamicRequest(
          id: requestId,
          decisionId: decisionId,
          expectedRevision: detail.revision,
          decision: decision,
          comment: comment,
        );
        updated = RequestEntity(
          id: dyn.id,
          employeeId: '',
          type: RequestType.dynamic,
          state: RequestStateX.fromApiValue(dyn.state),
          revision: dyn.revision,
          requestedMinutes: 0,
          submittedAt: dyn.submittedAt,
          decidedAt: dyn.decidedAt,
          cancelledAt: dyn.cancelledAt,
          reasonCode: dyn.reasonCode,
          details: dyn.values,
          steps: dyn.timeline
              .map((s) => ApprovalStepEntity(
                    id: s.id,
                    position: s.position,
                    reviewerRole: s.assignedRole,
                    reviewerName: s.assignedDisplayName,
                    state: s.state,
                    decidedAt: s.decidedAt,
                    comment: s.comment,
                  ))
              .toList(),
          isDynamic: true,
          dynamicTypeNameAr: dyn.typeNameAr,
        );
      } else {
        updated = await _repository.decideRequest(
          requestId: requestId,
          decisionId: decisionId,
          expectedRevision: expectedRevision,
          decision: decision,
          comment: comment,
        );
      }

      // A next-stage assignment is a server decision. Reload the actor-scoped
      // inbox rather than retaining a button for a stage owned by someone else.
      if (current.filterState == RequestState.pendingApproval &&
          updated.state == RequestState.pendingApproval) {
        await loadInbox(stateFilter: current.filterState, refresh: true);
        return;
      }

      // Successfully decided: update list or remove if filtering pending
      final updatedList =
          current.requests.map((r) => r.id == requestId ? updated : r).toList();
      if (isClosed) return;
      emit(current.copyWith(
        requests: updatedList,
        isDeciding: false,
        decidedRequestId: null,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      final isNotFound = failure is NotFoundFailure;

      if (isConflict) {
        // Refresh inbox immediately: reload both legacy and dynamic requests to prevent dropping dynamic rows
        List<RequestEntity> refreshedItems = [];
        try {
          final items = await _repository.listApprovalInbox(
            state: current.filterState,
          );
          refreshedItems = List<RequestEntity>.from(items);
        } catch (_) {
          refreshedItems = current.requests.where((r) => !r.isDynamic).toList();
        }

        if (_dynamicRepository != null) {
          try {
            final approvalActivities =
                await _dynamicRepository.getApprovalActivity();
            for (final act in approvalActivities) {
              if (act.kind == RequestKind.dynamic) {
                if (current.filterState != null &&
                    _approvalActivityState(act.state) != current.filterState) {
                  continue;
                }
                refreshedItems.add(
                  RequestEntity(
                    id: act.requestId,
                    employeeId: '',
                    employeeName: act.requesterDisplayName,
                    type: RequestType.dynamic,
                    state: _approvalActivityState(act.state),
                    revision: act.expectedRevision,
                    requestedMinutes: 0,
                    submittedAt: act.submittedAt,
                    decidedAt: null,
                    cancelledAt: null,
                    reasonCode: act.stageLabel,
                    details: const {'dynamicActivity': true},
                    steps: const [],
                    isDynamic: true,
                    dynamicTypeNameAr: act.typeNameAr,
                  ),
                );
              }
            }
          } catch (_) {}

          // Also reload specific dynamic detail to ensure latest server revision is present
          if (isDynamic) {
            try {
              final freshDetail =
                  await _dynamicRepository.getDynamicRequest(requestId);
              final idx = refreshedItems.indexWhere((r) => r.id == requestId);
              final freshEntity = RequestEntity(
                id: freshDetail.id,
                employeeId: '',
                type: RequestType.dynamic,
                state: RequestStateX.fromApiValue(freshDetail.state),
                revision: freshDetail.revision,
                requestedMinutes: 0,
                submittedAt: freshDetail.submittedAt,
                decidedAt: freshDetail.decidedAt,
                cancelledAt: freshDetail.cancelledAt,
                reasonCode: freshDetail.reasonCode,
                details: freshDetail.values,
                steps: freshDetail.timeline
                    .map((s) => ApprovalStepEntity(
                          id: s.id,
                          position: s.position,
                          reviewerRole: s.assignedRole,
                          reviewerName: s.assignedDisplayName,
                          state: s.state,
                          decidedAt: s.decidedAt,
                          comment: s.comment,
                        ))
                    .toList(),
                isDynamic: true,
                dynamicTypeNameAr: freshDetail.typeNameAr,
              );
              if (idx != -1) {
                refreshedItems[idx] = freshEntity;
              } else {
                refreshedItems.add(freshEntity);
              }
            } catch (_) {}
          }
        }

        refreshedItems.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

        if (isClosed) return;
        emit(ManagerInboxLoaded(
          requests: refreshedItems,
          filterState: current.filterState,
          isDeciding: false,
          decidedRequestId: null,
          conflictMessage:
              'تم اتخاذ قرار بشأن هذا الطلب أو تم تحديثه مسبقاً من قِبل مراجع آخر.',
        ));
      } else if (isNotFound) {
        if (isClosed) return;
        emit(current.copyWith(
          isDeciding: false,
          decidedRequestId: null,
          errorMessage: 'الطلب غير موجود أو تمت معالجته بالفعل',
        ));
      } else {
        if (isClosed) return;
        emit(current.copyWith(
          isDeciding: false,
          decidedRequestId: null,
          errorMessage: AppFailureMapper.fromGeneric(e).message,
        ));
      }
    }
  }
}

// Approval activity exposes stage state; request lists expose request state.
RequestState _approvalActivityState(String state) => state == 'pending'
    ? RequestState.pendingApproval
    : RequestStateX.fromApiValue(state);
