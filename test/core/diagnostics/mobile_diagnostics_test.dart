import 'package:attend_mobile/core/diagnostics/mobile_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomSensitiveError implements Exception {
  final String secretToken;
  final String coordinates;
  final String userEmail;

  _CustomSensitiveError(this.secretToken, this.coordinates, this.userEmail);

  @override
  String toString() =>
      '_CustomSensitiveError(token: $secretToken, coords: $coordinates, email: $userEmail)';
}

class _VeryLongNamedExceptionWithMoreThanEightyCharactersExceedingTheAllowlistBoundaryLimitException
    implements Exception {}

void main() {
  setUp(() {
    MobileDiagnostics.resetForTesting();
  });

  tearDown(() {
    MobileDiagnostics.resetForTesting();
  });

  group('MobileDiagnostics Scrubber (T079)', () {
    test('extracts only alphanumeric type name and scrubs all message contents',
        () {
      final category = MobileDiagnostics.safeErrorCategory(
        StateError(
            'token=secret123 coordinates=30.0444,31.2357 email=admin@attend.com'),
      );

      expect(category, 'StateError');
      expect(category, isNot(contains('secret123')));
      expect(category, isNot(contains('30.0444')));
      expect(category, isNot(contains('admin@attend.com')));
    });

    test('handles standard platform exception types safely', () {
      expect(
        MobileDiagnostics.safeErrorCategory(
            const FormatException('malformed input')),
        'FormatException',
      );
      expect(
        MobileDiagnostics.safeErrorCategory(ArgumentError('invalid argument')),
        'ArgumentError',
      );
      expect(
        MobileDiagnostics.safeErrorCategory(RangeError('out of range')),
        'RangeError',
      );
    });

    test('scrubs custom exceptions containing PII and coordinates', () {
      final sensitiveError = _CustomSensitiveError(
        'att_tok_999888777',
        '29.9792,31.1342',
        'employee@company.org',
      );

      final category = MobileDiagnostics.safeErrorCategory(sensitiveError);
      expect(category, '_CustomSensitiveError');
      expect(category, isNot(contains('att_tok')));
      expect(category, isNot(contains('29.9792')));
      expect(category, isNot(contains('employee@company.org')));
    });

    test('falls back to unknown_error when runtimeType exceeds 80 characters',
        () {
      final longError =
          _VeryLongNamedExceptionWithMoreThanEightyCharactersExceedingTheAllowlistBoundaryLimitException();

      final category = MobileDiagnostics.safeErrorCategory(longError);
      expect(category, 'unknown_error');
    });

    test('prohibits special characters or formatting injected into category',
        () {
      // Any class or object that has characters outside A-Za-z0-9_ falls back to unknown_error
      final mapError = <String, dynamic>{'error': 'sql_syntax_error'};
      final category = MobileDiagnostics.safeErrorCategory(mapError);
      // In Dart, runtimeType for Map<String, dynamic> has angle brackets < > and spaces
      expect(category, 'unknown_error');
    });
  });

  group('MobileDiagnostics Consent & Configuration (T079)', () {
    test('defaults to crash reporting disabled (fail-closed)', () {
      // Without --dart-define=ENABLE_CRASHLYTICS=true, reporting remains false
      expect(MobileDiagnostics.isCrashReportingEnabled, isFalse);
    });

    test(
        'initializes safely without unhandled exceptions even when platform services are unconfigured',
        () async {
      // Running initialize() in a local test harness without Google services
      // must never crash or throw unhandled exceptions
      await expectLater(MobileDiagnostics.initialize(), completes);
      expect(MobileDiagnostics.isInitialized, isTrue);

      // Subsequent initialization calls are idempotent
      await expectLater(MobileDiagnostics.initialize(), completes);
      expect(MobileDiagnostics.isInitialized, isTrue);
    });
  });

  group('MobileDiagnostics Handled Error Capture (T079)', () {
    test('records handled errors with fatal: false and non-fatal reason', () {
      String? recordedCategory;
      bool? isFatal;
      String? recordedReason;
      StackTrace? passedStack;

      MobileDiagnostics.onRecordErrorForTesting = ({
        required String errorCategory,
        required bool fatal,
        required String reason,
        StackTrace? stack,
      }) {
        recordedCategory = errorCategory;
        isFatal = fatal;
        recordedReason = reason;
        passedStack = stack;
      };

      final testStack = StackTrace.current;
      MobileDiagnostics.recordHandledError(
        FormatException('Invalid date syntax for employee record'),
        testStack,
      );

      expect(recordedCategory, 'FormatException');
      expect(isFatal, isFalse);
      expect(recordedReason, 'handled_application_error');
      expect(passedStack, testStack);
    });
  });

  group('MobileDiagnostics Fatal Capture (T079)', () {
    test('records fatal errors with fatal: true and unhandled reason', () {
      String? recordedCategory;
      bool? isFatal;
      String? recordedReason;

      MobileDiagnostics.onRecordErrorForTesting = ({
        required String errorCategory,
        required bool fatal,
        required String reason,
        StackTrace? stack,
      }) {
        recordedCategory = errorCategory;
        isFatal = fatal;
        recordedReason = reason;
      };

      MobileDiagnostics.recordFatalError(
        StateError('Critical assertion failure in process'),
      );

      expect(recordedCategory, 'StateError');
      expect(isFatal, isTrue);
      expect(recordedReason, 'unhandled_flutter_error');
    });

    test(
        'scrubs sensitive credentials and location coordinates during fatal error capture',
        () {
      String? recordedCategory;

      MobileDiagnostics.onRecordErrorForTesting = ({
        required String errorCategory,
        required bool fatal,
        required String reason,
        StackTrace? stack,
      }) {
        recordedCategory = errorCategory;
      };

      final confidentialError = _CustomSensitiveError(
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sensitive',
        'lat=30.0444,lon=31.2357',
        'payroll_accountant@enterprise.com',
      );

      MobileDiagnostics.recordFatalError(confidentialError);

      expect(recordedCategory, '_CustomSensitiveError');
      expect(recordedCategory, isNot(contains('eyJhbGciOi')));
      expect(recordedCategory, isNot(contains('30.0444')));
      expect(recordedCategory, isNot(contains('payroll_accountant')));
    });
  });
}
