import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';

void main() {
  group('AppFailureMapper Tests', () {
    test('Maps connectionTimeout to TimeoutFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionTimeout,
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<TimeoutFailure>());
      expect(failure.message, contains('استغرق الخادم وقتاً أطول'));
    });

    test('Maps connectionError to NetworkFailure with Arabic network guidance',
        () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.connectionError,
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<NetworkFailure>());
      expect(failure.message, contains('تعذر الاتصال بخادم النظام'));
      expect(failure.message, isNot(contains('DioException')));
    });

    test('Maps 401/403 status to AuthFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
          data: {'message': 'جلسة العمل منتهية', 'code': 'UNAUTHORIZED'},
        ),
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<AuthFailure>());
      expect(failure.message, equals('جلسة العمل منتهية'));
      expect(failure.code, equals('UNAUTHORIZED'));
    });

    test('replaces a machine credential code with Arabic recovery copy', () {
      final failure = AppFailureMapper.fromGeneric(const _ApiError(
        statusCode: 401,
        code: 'INVALID_CREDENTIALS',
        message: 'INVALID_CREDENTIALS',
      ));
      expect(failure, isA<AuthFailure>());
      expect(failure.message,
          equals('البريد الإلكتروني أو كلمة المرور غير صحيحة.'));
      expect(failure.message, isNot(contains('INVALID_CREDENTIALS')));
    });

    test('Maps 400/422 status to ValidationFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 422,
          data: {'message': 'البيانات غير مكتملة', 'code': 'VALIDATION_FAILED'},
        ),
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, equals('البيانات غير مكتملة'));
    });

    test('Maps 409 status to ConflictFailure', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 409,
          data: {'message': 'تعارض في تسجيل الحضور'},
        ),
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<ConflictFailure>());
      expect(failure.message, equals('تعارض في تسجيل الحضور'));
    });

    test('Maps 500 status to ServerFailure with safe Arabic message', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/test'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 500,
        ),
      );
      final failure = AppFailureMapper.fromDio(dioException);
      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('حدث خطأ في خدمة النظام'));
      expect(failure.message, isNot(contains('DioException')));
    });

    test('fromGeneric handles unexpected exceptions safely', () {
      final failure =
          AppFailureMapper.fromGeneric(Exception('Raw socket error'));
      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('حدث خطأ غير متوقع'));
      expect(failure.message, isNot(contains('Raw socket error')));
    });
  });
}

class _ApiError {
  const _ApiError({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;
  dynamic get details => null;
}
