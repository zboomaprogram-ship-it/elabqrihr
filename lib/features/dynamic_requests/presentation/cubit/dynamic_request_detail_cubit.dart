import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/dynamic_request_models.dart';
import '../../domain/dynamic_request_repository.dart';

sealed class DynamicRequestDetailState extends Equatable {
  const DynamicRequestDetailState();

  @override
  List<Object?> get props => const [];
}

class DynamicRequestDetailLoading extends DynamicRequestDetailState {
  const DynamicRequestDetailLoading();
}

class DynamicRequestDetailLoaded extends DynamicRequestDetailState {
  final DynamicRequestEntity request;
  final bool isCancelling;
  final String? errorMessage;

  const DynamicRequestDetailLoaded({
    required this.request,
    this.isCancelling = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [request, isCancelling, errorMessage];
}

class DynamicRequestDetailCancelled extends DynamicRequestDetailState {
  final DynamicRequestEntity request;
  const DynamicRequestDetailCancelled(this.request);

  @override
  List<Object?> get props => [request];
}

class DynamicRequestDetailError extends DynamicRequestDetailState {
  final String message;
  const DynamicRequestDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class DynamicRequestDetailCubit extends Cubit<DynamicRequestDetailState> {
  DynamicRequestDetailCubit({required DynamicRequestRepository repository})
      : _repository = repository,
        super(const DynamicRequestDetailLoading());

  final DynamicRequestRepository _repository;

  Future<void> load(String requestId) async {
    if (isClosed) return;
    emit(const DynamicRequestDetailLoading());
    try {
      final request = await _repository.getDynamicRequest(requestId);
      if (!isClosed) emit(DynamicRequestDetailLoaded(request: request));
    } catch (error) {
      if (!isClosed) {
        emit(DynamicRequestDetailError(
            AppFailureMapper.fromGeneric(error).message));
      }
    }
  }

  Future<void> cancel(String reason) async {
    final current = state;
    if (current is! DynamicRequestDetailLoaded || current.isCancelling) return;
    emit(DynamicRequestDetailLoaded(
        request: current.request, isCancelling: true));
    try {
      final request = await _repository.cancelDynamicRequest(
        id: current.request.id,
        expectedRevision: current.request.revision,
        reason: reason,
      );
      if (!isClosed) emit(DynamicRequestDetailCancelled(request));
    } catch (error) {
      if (!isClosed) {
        emit(DynamicRequestDetailLoaded(
          request: current.request,
          errorMessage: AppFailureMapper.fromGeneric(error).message,
        ));
      }
    }
  }
}
