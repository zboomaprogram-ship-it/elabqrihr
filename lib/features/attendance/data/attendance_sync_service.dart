import 'dart:async';
import 'package:attend_mobile/features/attendance/data/attendance_failure_classifier.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';

enum SyncOutcome {
  accepted,
  rejected,
  reviewRequired,
  conflictDuplicate,
  networkFailure,
}

class SyncResult {
  final String eventId;
  final SyncOutcome outcome;
  final String? message;
  final Duration? retryAfter;

  const SyncResult({
    required this.eventId,
    required this.outcome,
    this.message,
    this.retryAfter,
  });
}

class AttendanceSyncService {
  final AttendanceRepository _repository;
  final int maxRetries;
  final Duration backoffStep;

  AttendanceSyncService({
    required AttendanceRepository repository,
    this.maxRetries = 3,
    this.backoffStep = const Duration(seconds: 2),
  }) : _repository = repository;

  Future<List<SyncResult>> syncBatch(
      List<AttendanceEventEntity> pendingEvents) async {
    final results = <SyncResult>[];

    for (final event in pendingEvents) {
      var attempt = 0;
      SyncResult? result;

      while (attempt < maxRetries) {
        attempt++;
        try {
          final outcomeEvent = await _repository.submitAttendanceEvent(
            eventType: event.eventType,
            shiftInstanceId: event.shiftInstanceId,
            location: event.location,
            clientEventId: event.id,
            capturedAt: event.capturedAt,
          );

          if (outcomeEvent.status == AttendanceValidationStatus.accepted) {
            result =
                SyncResult(eventId: event.id, outcome: SyncOutcome.accepted);
          } else if (outcomeEvent.status ==
              AttendanceValidationStatus.pendingReview) {
            result = SyncResult(
              eventId: event.id,
              outcome: SyncOutcome.reviewRequired,
              message: outcomeEvent.reasonCode,
            );
          } else {
            result = SyncResult(
              eventId: event.id,
              outcome: SyncOutcome.rejected,
              message: outcomeEvent.reasonCode,
            );
          }
          break; // Terminal outcome reached
        } catch (error) {
          final classification = AttendanceFailureClassifier.classify(error);
          if (classification.disposition ==
              AttendanceFailureDisposition.conflict) {
            result = SyncResult(
              eventId: event.id,
              outcome: SyncOutcome.conflictDuplicate,
              message: classification.reasonCode,
            );
            break; // Do not retry conflicts
          }

          if (!classification.isRetryable) {
            result = SyncResult(
              eventId: event.id,
              outcome: SyncOutcome.rejected,
              message: classification.reasonCode,
            );
            break;
          }

          if (attempt >= maxRetries) {
            result = SyncResult(
              eventId: event.id,
              outcome: SyncOutcome.networkFailure,
              message: classification.reasonCode,
              retryAfter: classification.retryAfter,
            );
          } else {
            // Bounded retry backoff
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
