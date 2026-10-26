import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

abstract class RequestDetailState extends Equatable {
  const RequestDetailState();

  @override
  List<Object?> get props => [];
}

class RequestDetailLoading extends RequestDetailState {
  const RequestDetailLoading();
}

class RequestDetailLoaded extends RequestDetailState {
  final RequestEntity request;
  final bool isCancelling;
  final String? errorMessage;

  const RequestDetailLoaded({
    required this.request,
    this.isCancelling = false,
    this.errorMessage,
  });

  RequestDetailLoaded copyWith({
    RequestEntity? request,
    bool? isCancelling,
    String? errorMessage,
  }) {
    return RequestDetailLoaded(
      request: request ?? this.request,
      isCancelling: isCancelling ?? this.isCancelling,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [request, isCancelling, errorMessage];
}

class RequestDetailCancelled extends RequestDetailState {
  final RequestEntity request;
  const RequestDetailCancelled(this.request);

  @override
  List<Object?> get props => [request];
}

class RequestDetailError extends RequestDetailState {
  final String message;
  const RequestDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class RequestDetailCubit extends Cubit<RequestDetailState> {
  final RequestRepository _repository;

  RequestDetailCubit({required RequestRepository repository})
      : _repository = repository,
        super(const RequestDetailLoading());

  Future<void> loadDetail(String requestId) async {
    if (isClosed) return;
    emit(const RequestDetailLoading());
    try {
      final detail = await _repository.getRequestDetail(requestId);
      if (isClosed) return;
      emit(RequestDetailLoaded(request: detail));
    } catch (e) {
      if (isClosed) return;
      emit(RequestDetailError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> cancelRequest({required String reason}) async {
    if (state is! RequestDetailLoaded) return;
    final current = (state as RequestDetailLoaded).request;

    if (isClosed) return;
    emit(RequestDetailLoaded(request: current, isCancelling: true));

    try {
      final updated = await _repository.cancelRequest(
        requestId: current.id,
        expectedRevision: current.revision,
        reason: reason,
      );
      if (isClosed) return;
      emit(RequestDetailCancelled(updated));
    } catch (e) {
      if (isClosed) return;
      emit(RequestDetailLoaded(
        request: current,
        isCancelling: false,
        errorMessage: AppFailureMapper.fromGeneric(e).message,
      ));
    }
  }
}
