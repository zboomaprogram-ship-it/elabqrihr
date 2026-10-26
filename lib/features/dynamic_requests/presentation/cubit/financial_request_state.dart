import 'package:equatable/equatable.dart';
import '../../domain/dynamic_request_models.dart';

sealed class FinancialRequestState extends Equatable {
  const FinancialRequestState();

  @override
  List<Object?> get props => [];
}

class FinancialRequestInitial extends FinancialRequestState {
  const FinancialRequestInitial();
}

class FinancialRequestLoading extends FinancialRequestState {
  const FinancialRequestLoading();
}

class FinancialRequestCatalogLoaded extends FinancialRequestState {
  final List<RequestTypeCategory> categories;

  const FinancialRequestCatalogLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class FinancialRequestEmpty extends FinancialRequestState {
  const FinancialRequestEmpty();
}

class FinancialRequestDenied extends FinancialRequestState {
  final String message;

  const FinancialRequestDenied(
      [this.message = 'غير مصرح لك بالوصول إلى الطلبات المالية']);

  @override
  List<Object?> get props => [message];
}

class FinancialRequestSubmitting extends FinancialRequestState {
  const FinancialRequestSubmitting();
}

class FinancialRequestSubmitted extends FinancialRequestState {
  final DynamicRequestEntity request;

  const FinancialRequestSubmitted(this.request);

  @override
  List<Object?> get props => [request];
}

class FinancialRequestError extends FinancialRequestState {
  final String message;
  final bool isSubmitting;

  const FinancialRequestError(this.message, {this.isSubmitting = false});

  @override
  List<Object?> get props => [message, isSubmitting];
}
