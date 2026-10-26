import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder feed always sends a bounded default window', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    late Map<String, dynamic> query;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          query = Map<String, dynamic>.from(options.queryParameters);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: const {
                'timezone': 'Africa/Cairo',
                'feedRevision':
                    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'items': <Object>[],
              },
            ),
          );
        },
      ),
    );
    final client = ApiClient(
      baseUrl: 'http://test',
      tokenStorage: _EmptyTokenStorage(),
      dio: dio,
    );

    await client.getAttendanceReminderFeed();

    final from = DateTime.parse(query['from'] as String);
    final until = DateTime.parse(query['until'] as String);
    expect(until.isAfter(from), isTrue);
    expect(until.difference(from), lessThanOrEqualTo(const Duration(days: 31)));
  });
}

class _EmptyTokenStorage extends TokenStorage {
  @override
  Future<AuthSessionEntity?> getSession() async => null;
}
