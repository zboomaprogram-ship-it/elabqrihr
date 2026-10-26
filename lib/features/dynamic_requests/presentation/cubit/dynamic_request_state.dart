import 'package:equatable/equatable.dart';
import '../../domain/dynamic_request_models.dart';

abstract class DynamicRequestState extends Equatable {
  const DynamicRequestState();

  @override
  List<Object?> get props => [];
}

class DynamicRequestInitial extends DynamicRequestState {
  const DynamicRequestInitial();
}

class DynamicRequestLoading extends DynamicRequestState {
  const DynamicRequestLoading();
}

class DynamicRequestCatalogLoaded extends DynamicRequestState {
  final List<RequestTypeCategory> categories;

  const DynamicRequestCatalogLoaded(this.categories);

  @override
  List<Object?> get props => [categories];
}

class DynamicRequestSubmitting extends DynamicRequestState {
  const DynamicRequestSubmitting();
}

class DynamicRequestSubmitted extends DynamicRequestState {
  final DynamicRequestEntity request;

  const DynamicRequestSubmitted(this.request);

  @override
  List<Object?> get props => [request];
}

class DynamicRequestHistoryLoaded extends DynamicRequestState {
  final List<DynamicRequestEntity> requests;

  const DynamicRequestHistoryLoaded(this.requests);

  @override
  List<Object?> get props => [requests];
}

class DynamicRequestError extends DynamicRequestState {
  final String message;

  const DynamicRequestError(this.message);

  @override
  List<Object?> get props => [message];
}
