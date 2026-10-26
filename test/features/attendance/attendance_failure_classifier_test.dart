import 'dart:io';

import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/attendance_failure_classifier.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceFailureClassifier', () {
    test('marks server decisions terminal and never retryable', () {
      for (final status in [400, 401, 403, 404, 422]) {
        final result = AttendanceFailureClassifier.classify(ApiException(
          statusCode: status,
          message: 'server decision',
        ));
        expect(result.isRetryable, isFalse, reason: 'HTTP $status');
        expect(result.terminalStatus, AttendanceValidationStatus.rejected);
      }
    });

    test('marks duplicate conflicts terminal without replay', () {
      final result = AttendanceFailureClassifier.classify(const ApiException(
        statusCode: 409,
        message: 'duplicate',
        code: 'CONFLICT_DUPLICATE',
      ));
      expect(result.isRetryable, isFalse);
      expect(result.terminalStatus, AttendanceValidationStatus.conflict);
      expect(result.reasonCode, 'CONFLICT_DUPLICATE');
    });

    test('retains only transport and explicitly temporary HTTP failures', () {
      for (final status in [429, 502, 503, 504]) {
        final result = AttendanceFailureClassifier.classify(ApiException(
          statusCode: status,
          message: 'temporary',
          retryAfter: const Duration(hours: 1),
        ));
        expect(result.isRetryable, isTrue, reason: 'HTTP $status');
        expect(result.retryAfter, const Duration(minutes: 15));
      }
      expect(
        AttendanceFailureClassifier.classify(
          const SocketException('offline'),
        ).isRetryable,
        isTrue,
      );
    });

    test('shows unavailable device trust as a terminal integrity outcome', () {
      final result = AttendanceFailureClassifier.classify(
        const AttendanceTrustUnavailableException(),
      );
      expect(result.isRetryable, isFalse);
      expect(result.terminalStatus, AttendanceValidationStatus.rejected);
      expect(result.reasonCode, 'INTEGRITY_UNAVAILABLE');
    });

    test('does not infer retryability from arbitrary exception text', () {
      final result = AttendanceFailureClassifier.classify(
        Exception('network maybe, but not a typed transport failure'),
      );
      expect(result.isRetryable, isFalse);
      expect(result.reasonCode, 'ATTENDANCE_SUBMISSION_FAILED');
    });
  });
}
