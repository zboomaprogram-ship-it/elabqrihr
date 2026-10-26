import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/dynamic_request_repository.dart';
import 'dynamic_request_state.dart';

class DynamicRequestCubit extends Cubit<DynamicRequestState> {
  final DynamicRequestRepository _repository;

  DynamicRequestCubit({required DynamicRequestRepository repository})
      : _repository = repository,
        super(const DynamicRequestInitial());

  Future<void> loadCatalog() async {
    if (isClosed) return;
    emit(const DynamicRequestLoading());
    try {
      final categories = await _repository.getRequestCategories();
      if (isClosed) return;
      emit(DynamicRequestCatalogLoaded(categories));
    } catch (e) {
      if (isClosed) return;
      emit(DynamicRequestError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> syncOutbox() async {
    try {
      await _repository.synchronizeOutbox();
    } catch (_) {}
  }

  Future<void> submitRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    required bool offlineEligible,
    String? typeNameAr,
  }) async {
    if (isClosed || state is DynamicRequestSubmitting) return;
    emit(const DynamicRequestSubmitting());
    try {
      final request = await _repository.submitDynamicRequest(
        typeKey: typeKey,
        definitionVersionId: definitionVersionId,
        values: values,
        offlineEligible: offlineEligible,
        typeNameAr: typeNameAr,
      );
      if (isClosed) return;
      emit(DynamicRequestSubmitted(request));
    } catch (e) {
      if (isClosed) return;
      emit(DynamicRequestError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> loadHistory({String? typeKey, String? state}) async {
    if (isClosed) return;
    emit(const DynamicRequestLoading());
    try {
      final requests = await _repository.getMyDynamicRequests(
        typeKey: typeKey,
        state: state,
      );
      if (isClosed) return;
      emit(DynamicRequestHistoryLoaded(requests));
    } catch (e) {
      if (isClosed) return;
      emit(DynamicRequestError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> cancelRequest({
    required String id,
    required int expectedRevision,
    required String reason,
  }) async {
    try {
      await _repository.cancelDynamicRequest(
        id: id,
        expectedRevision: expectedRevision,
        reason: reason,
      );
      if (isClosed) return;
      await loadHistory();
    } catch (e) {
      if (isClosed) return;
      emit(DynamicRequestError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> decideRequest({
    required String id,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async {
    try {
      await _repository.decideDynamicRequest(
        id: id,
        decisionId: decisionId,
        expectedRevision: expectedRevision,
        decision: decision,
        comment: comment,
      );
      if (isClosed) return;
      await loadHistory();
    } catch (e) {
      if (isClosed) return;
      emit(DynamicRequestError(AppFailureMapper.fromGeneric(e).message));
    }
  }
}
