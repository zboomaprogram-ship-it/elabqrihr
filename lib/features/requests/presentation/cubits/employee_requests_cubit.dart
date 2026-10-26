import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

abstract class EmployeeRequestsState extends Equatable {
  const EmployeeRequestsState();

  @override
  List<Object?> get props => [];
}

class EmployeeRequestsInitial extends EmployeeRequestsState {
  const EmployeeRequestsInitial();
}

class EmployeeRequestsLoading extends EmployeeRequestsState {
  const EmployeeRequestsLoading();
}

class EmployeeRequestsLoaded extends EmployeeRequestsState {
  final List<RequestEntity> requests;
  final List<LeaveBalanceEntity> balances;
  final RequestType? filterType;
  final RequestState? filterState;
  final int pendingOutboxCount;

  const EmployeeRequestsLoaded({
    required this.requests,
    required this.balances,
    this.filterType,
    this.filterState,
    this.pendingOutboxCount = 0,
  });

  EmployeeRequestsLoaded copyWith({
    List<RequestEntity>? requests,
    List<LeaveBalanceEntity>? balances,
    RequestType? filterType,
    RequestState? filterState,
    int? pendingOutboxCount,
    bool clearFilterType = false,
    bool clearFilterState = false,
  }) {
    return EmployeeRequestsLoaded(
      requests: requests ?? this.requests,
      balances: balances ?? this.balances,
      filterType: clearFilterType ? null : (filterType ?? this.filterType),
      filterState: clearFilterState ? null : (filterState ?? this.filterState),
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
    );
  }

  @override
  List<Object?> get props =>
      [requests, balances, filterType, filterState, pendingOutboxCount];
}

class EmployeeRequestsError extends EmployeeRequestsState {
  final String message;
  const EmployeeRequestsError(this.message);

  @override
  List<Object?> get props => [message];
}

class EmployeeRequestsCubit extends Cubit<EmployeeRequestsState> {
  final RequestRepository _repository;
  final DynamicRequestRepository? _dynamicRepository;
  StreamSubscription<List<RequestEntity>>? _outboxSubscription;
  int _pendingOutboxCount = 0;

  EmployeeRequestsCubit({
    required RequestRepository repository,
    DynamicRequestRepository? dynamicRepository,
  })  : _repository = repository,
        _dynamicRepository = dynamicRepository,
        super(const EmployeeRequestsInitial()) {
    _listenToOutbox();
  }

  void _listenToOutbox() {
    _outboxSubscription = _repository.watchPendingRequests().listen((pending) {
      if (isClosed) return;
      _pendingOutboxCount = pending.length;
      if (state is EmployeeRequestsLoaded) {
        final current = state as EmployeeRequestsLoaded;
        emit(current.copyWith(pendingOutboxCount: pending.length));
      }
    });
  }

  Future<List<RequestEntity>> _fetchMergedRequests({
    RequestType? type,
    RequestState? state,
  }) async {
    List<RequestEntity> legacy = [];
    if (type != RequestType.dynamic) {
      legacy = await _repository.listMyRequests(
        type: type,
        state: state,
      );
    }

    final combined = List<RequestEntity>.from(legacy);

    if (_dynamicRepository != null &&
        (type == null || type == RequestType.dynamic)) {
      try {
        final dynamicActivities = await _dynamicRepository.getRequestActivity();
        for (final act in dynamicActivities) {
          if (act.kind == RequestKind.dynamic) {
            if (state != null && act.state != state.toApiValue()) {
              continue;
            }
            combined.add(
              RequestEntity(
                id: act.id,
                employeeId: '',
                type: RequestType.dynamic,
                state: RequestStateX.fromApiValue(act.state),
                revision: act.revision,
                requestedMinutes: 0,
                submittedAt: act.submittedAt,
                decidedAt: null,
                cancelledAt: null,
                reasonCode: act.currentStageLabel,
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

    final unique = {
      for (final request in combined)
        '${request.isDynamic ? 'dynamic' : 'built_in'}:${request.id}': request,
    }.values.toList();
    unique.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return unique;
  }

  Future<void> loadRequests({bool refresh = false}) async {
    if (!refresh && state is! EmployeeRequestsInitial) return;

    if (isClosed) return;
    emit(const EmployeeRequestsLoading());
    try {
      final requests = await _fetchMergedRequests();
      List<LeaveBalanceEntity> balances = const [];
      try {
        balances = await _repository.getMyLeaveBalances();
      } catch (_) {
        // Balances may be offline or empty
      }

      if (isClosed) return;
      emit(EmployeeRequestsLoaded(
        requests: requests,
        balances: balances,
        pendingOutboxCount: _pendingOutboxCount,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(EmployeeRequestsError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> filterByType(RequestType? type) async {
    if (state is! EmployeeRequestsLoaded) return;
    final current = state as EmployeeRequestsLoaded;

    try {
      final requests = await _fetchMergedRequests(
        type: type,
        state: current.filterState,
      );
      if (isClosed) return;
      emit(current.copyWith(
        requests: requests,
        filterType: type,
        clearFilterType: type == null,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(EmployeeRequestsError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> filterByState(RequestState? requestState) async {
    if (state is! EmployeeRequestsLoaded) return;
    final current = state as EmployeeRequestsLoaded;

    try {
      final requests = await _fetchMergedRequests(
        type: current.filterType,
        state: requestState,
      );
      if (isClosed) return;
      emit(current.copyWith(
        requests: requests,
        filterState: requestState,
        clearFilterState: requestState == null,
      ));
    } catch (e) {
      if (isClosed) return;
      emit(EmployeeRequestsError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> syncOutbox() async {
    try {
      await _repository.synchronizeOutbox();
      if (_dynamicRepository != null) {
        await _dynamicRepository.synchronizeOutbox();
      }
      if (isClosed) return;
      await loadRequests(refresh: true);
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _outboxSubscription?.cancel();
    return super.close();
  }
}
