import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

/// Represents the sequential boundaries of an attendance submission pipeline.
enum AttendanceSubmissionStage {
  locationCapture,
  installationRegistration,
  integrityChallenge,
  signature,
  eventSend,
}

/// Presentation-safe typed failure for attendance submission stages.
/// Coordinates, signatures, tokens, and raw exceptions must not cross this boundary.
class AttendanceSubmissionStageException implements Exception {
  final AttendanceSubmissionStage stage;
  final Object causalError;
  final String? reasonCode;

  const AttendanceSubmissionStageException({
    required this.stage,
    required this.causalError,
    this.reasonCode,
  });

  @override
  String toString() =>
      'AttendanceSubmissionStageException(stage: $stage, reasonCode: $reasonCode)';
}

/// Decides whether an attendance command may be retried without changing its
/// original evidence. Server policy decisions are final: keeping them in the
/// outbox would incorrectly tell an employee that their attendance will sync.
enum AttendanceFailureDisposition { retryable, rejected, conflict }

class AttendanceFailureClassification {
  final AttendanceFailureDisposition disposition;
  final String reasonCode;
  final Duration? retryAfter;

  const AttendanceFailureClassification({
    required this.disposition,
    required this.reasonCode,
    this.retryAfter,
  });

  bool get isRetryable => disposition == AttendanceFailureDisposition.retryable;

  AttendanceValidationStatus get terminalStatus =>
      disposition == AttendanceFailureDisposition.conflict
          ? AttendanceValidationStatus.conflict
          : AttendanceValidationStatus.rejected;
}

class AttendanceFailureClassifier {
  static const Duration _defaultRetryAfter = Duration(seconds: 30);
  static const Duration _maximumRetryAfter = Duration(minutes: 15);

  static AttendanceFailureClassification classify(Object error) {
    if (error is AttendanceSubmissionStageException) {
      switch (error.stage) {
        case AttendanceSubmissionStage.installationRegistration:
          return AttendanceFailureClassification(
            disposition: AttendanceFailureDisposition.rejected,
            reasonCode: error.reasonCode ?? 'DEVICE_REGISTRATION_FAILED',
          );
        case AttendanceSubmissionStage.signature:
          return AttendanceFailureClassification(
            disposition: AttendanceFailureDisposition.rejected,
            reasonCode: error.reasonCode ?? 'INTEGRITY_UNAVAILABLE',
          );
        case AttendanceSubmissionStage.locationCapture:
          return AttendanceFailureClassification(
            disposition: AttendanceFailureDisposition.rejected,
            reasonCode: error.reasonCode ?? 'LOCATION_UNAVAILABLE',
          );
        case AttendanceSubmissionStage.integrityChallenge:
        case AttendanceSubmissionStage.eventSend:
          if (error.reasonCode == 'DEVICE_REENROLL_REQUIRED') {
            return const AttendanceFailureClassification(
              disposition: AttendanceFailureDisposition.rejected,
              reasonCode: 'DEVICE_REENROLL_REQUIRED',
            );
          }
          return classify(error.causalError);
      }
    }

    if (error is AttendanceTrustUnavailableException) {
      return const AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.rejected,
        reasonCode: 'INTEGRITY_UNAVAILABLE',
      );
    }

    if (error is ApiException) return _fromApi(error);

    if (error is DioException) {
      if (error.error is ApiException) {
        return _fromApi(error.error! as ApiException);
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return const AttendanceFailureClassification(
          disposition: AttendanceFailureDisposition.retryable,
          reasonCode: 'NETWORK_UNAVAILABLE',
          retryAfter: _defaultRetryAfter,
        );
      }
      if (error.type == DioExceptionType.unknown) {
        final inner = error.error;
        if (inner is SocketException ||
            inner is TimeoutException ||
            inner is HttpException ||
            (inner != null && _isTransportError(inner.toString()))) {
          return const AttendanceFailureClassification(
            disposition: AttendanceFailureDisposition.retryable,
            reasonCode: 'NETWORK_UNAVAILABLE',
            retryAfter: _defaultRetryAfter,
          );
        }
        // Non-transport causal errors are terminal rejections
        return const AttendanceFailureClassification(
          disposition: AttendanceFailureDisposition.rejected,
          reasonCode: 'ATTENDANCE_SUBMISSION_FAILED',
        );
      }
    }

    if (error is SocketException || error is TimeoutException) {
      return const AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.retryable,
        reasonCode: 'NETWORK_UNAVAILABLE',
        retryAfter: _defaultRetryAfter,
      );
    }

    // Unknown local failures must be visible to the employee. They are not
    // safe to replay because we cannot prove that the original command was
    // never received by the server.
    return const AttendanceFailureClassification(
      disposition: AttendanceFailureDisposition.rejected,
      reasonCode: 'ATTENDANCE_SUBMISSION_FAILED',
    );
  }

  static bool _isTransportError(String errorString) {
    final lower = errorString.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('broken pipe') ||
        lower.contains('network is unreachable');
  }

  static AttendanceFailureClassification _fromApi(ApiException error) {
    final status = error.statusCode;
    final code = error.code ?? _fallbackCode(status);
    if (code == 'DEVICE_REENROLL_REQUIRED' ||
        code == 'MOBILE_ACTION_RESTRICTED') {
      return AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.rejected,
        reasonCode: code,
      );
    }
    if (status == 409) {
      return AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.conflict,
        reasonCode: code,
      );
    }

    // These responses prove a server decision. Never retain them in the
    // retry queue, including authorization and missing-assignment responses.
    if (status == 400 ||
        status == 401 ||
        status == 403 ||
        status == 404 ||
        status == 422) {
      return AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.rejected,
        reasonCode: code,
      );
    }

    if (status == 429 ||
        status == 500 ||
        status == 502 ||
        status == 503 ||
        status == 504) {
      return AttendanceFailureClassification(
        disposition: AttendanceFailureDisposition.retryable,
        reasonCode: code,
        retryAfter: _boundedRetryAfter(error.retryAfter),
      );
    }

    return AttendanceFailureClassification(
      disposition: AttendanceFailureDisposition.rejected,
      reasonCode: code,
    );
  }

  static Duration _boundedRetryAfter(Duration? candidate) {
    if (candidate == null || candidate <= Duration.zero) {
      return _defaultRetryAfter;
    }
    if (candidate > _maximumRetryAfter) {
      return _maximumRetryAfter;
    }
    return candidate;
  }

  static String _fallbackCode(int status) => switch (status) {
        400 || 422 => 'VALIDATION_FAILED',
        401 => 'AUTHENTICATION_REQUIRED',
        403 => 'FORBIDDEN',
        404 => 'SHIFT_ASSIGNMENT_NOT_FOUND',
        409 => 'CONFLICT_DUPLICATE',
        429 => 'SERVICE_RATE_LIMITED',
        500 || 502 || 503 || 504 => 'SERVICE_UNAVAILABLE',
        _ => 'ATTENDANCE_SUBMISSION_FAILED',
      };
}
