import 'package:dio/dio.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';

sealed class AppFailure {
  final String message;
  final String? code;

  const AppFailure(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message =
        'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت أو إعدادات الشبكة.',
    String? code,
  ]) : super(code: code ?? 'NETWORK_ERROR');
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure([
    super.message =
        'استغرق الخادم وقتاً أطول من المتوقع للاستجابة. يرجى المحاولة مرة أخرى.',
    String? code,
  ]) : super(code: code ?? 'TIMEOUT_ERROR');
}

class AuthFailure extends AppFailure {
  const AuthFailure([
    super.message = 'بيانات الاعتماد غير صحيحة أو انتهت صلاحية الجلسة.',
    String? code,
  ]) : super(code: code ?? 'AUTH_ERROR');
}

class ValidationFailure extends AppFailure {
  final Map<String, dynamic>? details;

  const ValidationFailure(
    super.message, {
    String? code,
    this.details,
  }) : super(code: code ?? 'VALIDATION_ERROR');
}

class ConflictFailure extends AppFailure {
  const ConflictFailure([
    super.message =
        'تعارض في البيانات؛ تمت معالجة هذا الطلب أو تم تعديله مسبقاً.',
    String? code,
  ]) : super(code: code ?? 'CONFLICT');
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([
    super.message = 'العنصر المطلوب غير موجود أو تم حذفه.',
    String? code,
  ]) : super(code: code ?? 'NOT_FOUND');
}

class ServerFailure extends AppFailure {
  const ServerFailure([
    super.message =
        'حدث خطأ غير متوقع في الخادم. يرجى المحاولة لاحقاً أو إبلاغ الدعم الفني.',
    String? code,
  ]) : super(code: code ?? 'SERVER_ERROR');
}

class OperationCancelledFailure extends AppFailure {
  const OperationCancelledFailure([
    super.message = 'تم إلغاء العملية.',
    String? code,
  ]) : super(code: code ?? 'CANCELLED');
}

class AppFailureMapper {
  /// Safe, concise messages for attendance outcome codes. These codes are
  /// stable API contracts; raw server messages must never reach the UI.
  static String attendanceReasonMessage(String? code) => switch (code) {
        'LOCATION_OUT_OF_RADIUS' ||
        'GEOFENCE_REJECTED' ||
        'OUTSIDE_GEOFENCE' ||
        'OUTSIDE_ALLOWED_RADIUS' =>
          AppStringsAr.reasonOutOfRadius,
        'LOCATION_STALE' ||
        'STALE_LOCATION' =>
          'تعذر اعتماد الموقع لأنه قديم. حدّث موقعك ثم حاول مرة أخرى.',
        'FUTURE_TIMESTAMP' =>
          'وقت الجهاز غير متوافق. فعّل الوقت التلقائي ثم حاول مرة أخرى.',
        'SHIFT_ASSIGNMENT_NOT_FOUND' ||
        'SHIFT_NOT_FOUND' ||
        'NO_ACTIVE_SHIFT' =>
          'لا توجد وردية عمل حالياً.',
        'AUTHENTICATION_REQUIRED' => 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
        'FORBIDDEN' || 'ROLE_FORBIDDEN' => 'ليس لديك صلاحية لتسجيل هذه الحركة.',
        'CONFLICT_DUPLICATE' ||
        'DUPLICATE_EVENT' ||
        'ALREADY_CHECKED_IN' =>
          'تم تسجيل هذه الحركة مسبقاً.',
        'SERVICE_UNAVAILABLE' ||
        'SERVICE_RATE_LIMITED' =>
          'الخدمة مشغولة حالياً. ستتم إعادة المحاولة تلقائياً.',
        'NETWORK_UNAVAILABLE' =>
          'لا يوجد اتصال مستقر. حُفظت الحركة للمزامنة لاحقاً.',
        'INTEGRITY_UNAVAILABLE' ||
        'PLAY_NONCE_MISMATCH' ||
        'PLAY_INTEGRITY_FAILED' ||
        'PLAY_INTEGRITY_REVIEW_REQUIRED' ||
        'DEVICE_REGISTRATION_PENDING_REVIEW' =>
          'تعذر التحقق من سلامة الجهاز. لم يُرسل الحضور؛ أعد المحاولة بعد فتح Google Play وتحديثه.',
        'DEVICE_REGISTRATION_FAILED' =>
          'تعذر تسجيل الجهاز لدى النظام. لم يُرسل الحضور؛ تحقق من الاتصال وحاول مجدداً.',
        'DEVICE_NOT_ACTIVE' ||
        'DEVICE_REVOKED' ||
        'INSTALLATION_REVOKED' ||
        'DEVICE_REENROLL_REQUIRED' =>
          'تم إلغاء تسجيل هذا الجهاز من قِبل إدارة الموارد البشرية. يرجى تسجيل الدخول مجدداً لتفعيل الجهاز.',
        'LOCATION_UNAVAILABLE' =>
          'تعذر التقاط موقع الجهاز بدقة. فعّل GPS وحاول مجدداً.',
        'MOBILE_ACTION_RESTRICTED' =>
          'هذه الخدمة متوقفة مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
        'VALIDATION_FAILED' ||
        'ATTENDANCE_SUBMISSION_FAILED' =>
          'تعذر اعتماد حركة الحضور. راجع البيانات ثم حاول مرة أخرى.',
        _ => 'تعذر اعتماد حركة الحضور. حاول مرة أخرى.',
      };

  /// Error codes are useful to operators, but must not become user-facing copy.
  static String _safeMessage(String? code, String fallback) {
    final localized = switch (code) {
      'INVALID_CREDENTIALS' => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      'MOBILE_ACTION_RESTRICTED' =>
        'هذه الخدمة متوقفة مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
      'INTEGRITY_UNAVAILABLE' ||
      'PLAY_NONCE_MISMATCH' ||
      'PLAY_INTEGRITY_FAILED' ||
      'PLAY_INTEGRITY_REVIEW_REQUIRED' ||
      'DEVICE_REGISTRATION_PENDING_REVIEW' =>
        'تعذر التحقق من سلامة الجهاز. لم يُرسل الحضور؛ أعد المحاولة بعد فتح Google Play وتحديثه.',
      'DEVICE_NOT_ACTIVE' ||
      'DEVICE_REVOKED' ||
      'INSTALLATION_REVOKED' ||
      'DEVICE_REENROLL_REQUIRED' =>
        'تم إلغاء تسجيل هذا الجهاز من قِبل إدارة الموارد البشرية. يرجى تسجيل الدخول مجدداً لتفعيل الجهاز.',
      'REQUEST_FAILED' => 'تعذر إكمال الطلب. حاول مرة أخرى.',
      'VALIDATION_FAILED' ||
      'INVALID_FIELD_VALUE' ||
      'REQUIRED_FIELD_MISSING' =>
        'تحقق من الحقول المطلوبة ثم أعد المحاولة.',
      'AUTHENTICATION_REQUIRED' ||
      'UNAUTHORIZED' =>
        'انتهت الجلسة. سجّل الدخول مرة أخرى.',
      'FORBIDDEN' || 'ROLE_FORBIDDEN' => 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
      'RESOURCE_NOT_FOUND' ||
      'NOT_FOUND' ||
      'SHIFT_NOT_FOUND' =>
        'العنصر المطلوب غير موجود أو لم يعد متاحاً.',
      'DEFINITION_VERSION_CONFLICT' ||
      'POLICY_VERSION_CONFLICT' ||
      'CONFLICT' =>
        'تم تعديل البيانات مسبقاً أو بواسطة مستخدم آخر. حدّث الصفحة ثم حاول مرة أخرى.',
      'RESET_TOKEN_INVALID' =>
        'رمز إعادة تعيين كلمة المرور غير صالح أو منتهي الصلاحية. يرجى طلب رمز جديد.',
      'PASSWORD_RESET_RATE_LIMITED' ||
      'RATE_LIMITED' =>
        'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.',
      'NETWORK_ERROR' ||
      'CONNECTION_ERROR' =>
        'تعذر الاتصال بالخادم. يرجى التحقق من اتصال الإنترنت.',
      'NO_SCHEDULED_WORK' =>
        'لا توجد وردية عمل مجدولة في التواريخ المحددة لاحتساب الإجازة عليها.',
      'INVALID_PERMISSION_INTERVAL' =>
        'فترة الإذن يجب أن تكون داخل ساعات الوردية المجدولة.',
      'INVALID_CORRECTION_TIME' =>
        'وقت البصمة المقترح خارج نافذة الوردية المسموح بها.',
      _ => null,
    };
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(fallback);
    if (hasArabic && fallback.trim() != code) return fallback;
    if (localized != null) return localized;
    return 'حدث خطأ أثناء معالجة الطلب. يرجى المحاولة مرة أخرى.';
  }

  static AppFailure fromDio(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();

      case DioExceptionType.connectionError:
        return const NetworkFailure(
          'تعذر الاتصال بخادم النظام. تأكد من تشغيل الخادم وتطابق عنوان الخادم (IP) مع شبكتك.',
        );

      case DioExceptionType.badResponse:
        final status = exception.response?.statusCode;
        final data = exception.response?.data;
        String? message;
        String? code;

        if (data is Map<String, dynamic>) {
          message = data['message'] as String? ?? data['error'] as String?;
          code = data['code'] as String?;
        }

        if (status == 401 || status == 403) {
          return AuthFailure(
            _safeMessage(
              code,
              message ?? 'جلسة العمل غير صالحة أو غير مصرح لك بهذا الإجراء.',
            ),
            code,
          );
        } else if (status == 404) {
          return NotFoundFailure(
              message ?? 'العنصر المطلوب غير موجود أو تم حذفه.', code);
        } else if (status == 400 || status == 422) {
          return ValidationFailure(
            _safeMessage(
              code,
              message ?? 'البيانات المدخلة غير صحيحة أو غير مكتملة.',
            ),
            code: code,
            details: data is Map<String, dynamic> ? data : null,
          );
        } else if (status == 409) {
          return ConflictFailure(
              message ?? 'تعارض في بيانات السجل أو تم تحديثه مسبقاً.', code);
        } else if (status != null && status >= 500) {
          return ServerFailure(
              'حدث خطأ في خدمة النظام ($status). يرجى المحاولة لاحقاً.', code);
        }
        return ServerFailure(message ?? 'حدث خطأ أثناء معالجة الطلب.', code);

      case DioExceptionType.cancel:
        return const OperationCancelledFailure();

      default:
        return const NetworkFailure();
    }
  }

  static AppFailure fromGeneric(dynamic error) {
    if (error is AppFailure) return error;
    if (error is DioException) return fromDio(error);

    // Typed inspection for ApiException or any exception carrying statusCode
    try {
      final dyn = error as dynamic;
      final int? statusCode = dyn.statusCode as int?;
      final String? code = dyn.code as String?;
      final String? message = dyn.message as String?;
      final dynamic details = dyn.details;

      if (statusCode != null) {
        if (statusCode == 401 || statusCode == 403) {
          return AuthFailure(
            _safeMessage(
              code,
              message ?? 'جلسة العمل غير صالحة أو غير مصرح لك بهذا الإجراء.',
            ),
            code,
          );
        } else if (statusCode == 404) {
          return NotFoundFailure(
              message ?? 'العنصر المطلوب غير موجود أو تم حذفه.', code);
        } else if (statusCode == 409) {
          return ConflictFailure(
              message ?? 'تعارض في بيانات السجل أو تم تحديثه مسبقاً.', code);
        } else if (statusCode == 400 || statusCode == 422) {
          return ValidationFailure(
            _safeMessage(
              code,
              message ?? 'البيانات المدخلة غير صحيحة أو غير مكتملة.',
            ),
            code: code,
            details: details is Map<String, dynamic> ? details : null,
          );
        } else if (statusCode >= 500) {
          return ServerFailure(
              message ?? 'حدث خطأ في خدمة النظام ($statusCode).', code);
        }
      }
    } catch (_) {}

    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socketexception') ||
        errStr.contains('httpexception') ||
        errStr.contains('network') ||
        errStr.contains('failed host lookup')) {
      return const NetworkFailure();
    }
    if (errStr.contains('403') || errStr.contains('forbidden')) {
      return const AuthFailure(
          'ليس لديك صلاحية لتنفيذ هذا الإجراء.', 'FORBIDDEN');
    }
    if (errStr.contains('409') || errStr.contains('conflict')) {
      return const ConflictFailure(
          'تعارض في البيانات؛ تمت معالجة هذا الطلب أو تم تعديله مسبقاً.');
    }
    if (errStr.contains('404') ||
        errStr.contains('not found') ||
        errStr.contains('shift_not_found') ||
        errStr.contains('no_active_shift')) {
      return const NotFoundFailure('العنصر المطلوب غير موجود أو تم حذفه.');
    }

    return const ServerFailure();
  }
}
