import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/app_failure.dart';
import '../../domain/dynamic_request_repository.dart';
import 'financial_request_state.dart';

class FinancialRequestCubit extends Cubit<FinancialRequestState> {
  final DynamicRequestRepository _repository;

  FinancialRequestCubit({required DynamicRequestRepository repository})
      : _repository = repository,
        super(const FinancialRequestInitial());

  Future<void> loadCatalog() async {
    if (isClosed) return;
    emit(const FinancialRequestLoading());
    try {
      final categories = await _repository.getFinancialRequestCategories();
      if (isClosed) return;
      if (categories.isEmpty) {
        emit(const FinancialRequestEmpty());
      } else {
        emit(FinancialRequestCatalogLoaded(categories));
      }
    } on AuthFailure catch (e) {
      if (isClosed) return;
      emit(FinancialRequestDenied(e.message));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      if (failure is AuthFailure) {
        emit(FinancialRequestDenied(failure.message));
      } else {
        emit(FinancialRequestError(failure.message));
      }
    }
  }

  Future<void> submitRequest({
    required String typeKey,
    required String definitionVersionId,
    required Map<String, dynamic> values,
    bool offlineEligible = false,
  }) async {
    if (isClosed) return;
    emit(const FinancialRequestSubmitting());
    try {
      final request = await _repository.submitDynamicRequest(
        typeKey: typeKey,
        definitionVersionId: definitionVersionId,
        values: values,
        offlineEligible: offlineEligible,
      );
      if (isClosed) return;
      emit(FinancialRequestSubmitted(request));
    } on AuthFailure catch (e) {
      if (isClosed) return;
      emit(FinancialRequestDenied(e.message));
    } catch (e) {
      if (isClosed) return;
      emit(FinancialRequestError(
        AppFailureMapper.fromGeneric(e).message,
        isSubmitting: true,
      ));
    }
  }
}
