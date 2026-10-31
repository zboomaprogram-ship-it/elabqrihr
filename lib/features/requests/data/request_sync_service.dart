import 'dart:async';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

enum RequestSyncOutcome {
  synchronized,
  conflict,
  validationFailure,
  networkFailure,
}

class RequestSyncResult {
  final String requestId;
  final RequestSyncOutcome outcome;
  final RequestEntity? entity;
  final String? message;

  const RequestSyncResult({
    required this.requestId,
    required this.outcome,
    this.entity,
    this.message,
  });
}

class RequestSyncService {
  final RequestRepository _repository;
  final int maxRetries;
  final Duration backoffStep;

  RequestSyncService({
    required RequestRepository repository,
    this.maxRetries = 3,
    this.backoffStep = const Duration(seconds: 1),
  }) : _repository = repository;

  Future<List<RequestSyncResult>> syncBatch(
    List<RequestEntity> pendingRequests, {
    Future<RequestEntity> Function(RequestEntity request)? submitRequest,
  }) async {
    final results = <RequestSyncResult>[];

    for (final req in pendingRequests) {
      var attempt = 0;
      RequestSyncResult? result;

      while (attempt < maxRetries) {
        attempt++;
        try {
          final outcome = submitRequest == null
              ? await _repository.submitRequest(
                  requestId: req.id,
                  type: req.type,
                  payload: req.details,
                )
              : await submitRequest(req);

          result = RequestSyncResult(
            requestId: req.id,
            outcome: RequestSyncOutcome.synchronized,
            entity: outcome,
          );
          break; // Terminal success
        } catch (e) {
          if (e is SessionIdentityChangedException) rethrow;
          final failure = AppFailureMapper.fromGeneric(e);

          if (failure is ConflictFailure) {
            result = RequestSyncResult(
              requestId: req.id,
              outcome: RequestSyncOutcome.conflict,
              message: failure.code ?? 'CONFLICT_DUPLICATE',
            );
            break;
          }

          if (failure is ValidationFailure ||
              failure is AuthFailure ||
              failure is NotFoundFailure) {
            result = RequestSyncResult(
              requestId: req.id,
              outcome: RequestSyncOutcome.validationFailure,
              message: failure.code ?? failure.message,
            );
            break;
          }

          if (attempt >= maxRetries) {
            result = RequestSyncResult(
              requestId: req.id,
              outcome: RequestSyncOutcome.networkFailure,
              message: AppFailureMapper.fromGeneric(e).message,
            );
          } else {
            await Future.delayed(backoffStep * attempt);
          }
        }
      }

      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }
}
