import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase only when the Android/iOS configuration is present.
///
/// Crash reporting is deliberately opt-in. Release builds must pass
/// `--dart-define=ENABLE_CRASHLYTICS=true` after the product owner has accepted
/// Firebase's processing terms and the store privacy declarations are updated.
/// Error payloads are reduced to stable category names; user input, access
/// tokens, tenant data, coordinates, and server response bodies are never sent.
final class MobileDiagnostics {
  static const _crashReportingEnabled = bool.fromEnvironment(
    'ENABLE_CRASHLYTICS',
    defaultValue: false,
  );

  static bool _initialized = false;

  static bool get isCrashReportingEnabled => _crashReportingEnabled;
  static bool get isInitialized => _initialized;

  @visibleForTesting
  static void Function({
    required String errorCategory,
    required bool fatal,
    required String reason,
    StackTrace? stack,
  })? onRecordErrorForTesting;

  static Future<void> initialize({
    bool? enableCrashReporting,
  }) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    final shouldEnable = enableCrashReporting ?? _crashReportingEnabled;

    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(shouldEnable);
      // Token creation and FCM analytics stay disabled until the user has made
      // a clear notification choice in the notification settings screen.
      await FirebaseMessaging.instance.setAutoInitEnabled(false);

      if (!shouldEnable) return;

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _record(details.exception, details.stack, fatal: true);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        _record(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      // Diagnostics must never prevent a user from opening the HR application.
      // Firebase configuration errors are deliberately not emitted to a remote
      // service, because they can contain environment-specific details.
    }
  }

  static void recordHandledError(Object error, [StackTrace? stack]) {
    _record(error, stack, fatal: false);
  }

  static void recordFatalError(Object error, [StackTrace? stack]) {
    _record(error, stack, fatal: true);
  }

  static void _record(Object error, StackTrace? stack, {required bool fatal}) {
    final category = safeErrorCategory(error);

    if (onRecordErrorForTesting != null) {
      onRecordErrorForTesting!(
        errorCategory: category,
        fatal: fatal,
        reason: fatal ? 'unhandled_flutter_error' : 'handled_application_error',
        stack: stack,
      );
    }

    if (!_crashReportingEnabled) return;

    try {
      FirebaseCrashlytics.instance.setCustomKey(
        'error_category',
        category,
      );
      FirebaseCrashlytics.instance.recordError(
        StateError('Unhandled mobile application error'),
        stack,
        fatal: fatal,
        reason: fatal ? 'unhandled_flutter_error' : 'handled_application_error',
      );
    } catch (_) {
      // Ignore transport errors in diagnostic reporting
    }
  }

  @visibleForTesting
  static String safeErrorCategory(Object error) {
    final type = error.runtimeType.toString();
    return RegExp(r'^[A-Za-z0-9_]{1,80}$').hasMatch(type)
        ? type
        : 'unknown_error';
  }

  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    onRecordErrorForTesting = null;
  }
}
