import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

void main() {
  const owner = AuthSessionEntity(
    accessToken: 'owner-token',
    refreshToken: 'owner-refresh',
    tenantId: 'tenant-a',
    userId: 'owner-a',
    role: UserRole.employee,
    email: 'owner@example.invalid',
    displayName: 'Owner',
  );
  const other = AuthSessionEntity(
    accessToken: 'other-token',
    refreshToken: 'other-refresh',
    tenantId: 'tenant-b',
    userId: 'other-b',
    role: UserRole.employee,
    email: 'other@example.invalid',
    displayName: 'Other',
  );

  for (final kind in ['attendance', 'built-in request']) {
    test('$kind replay refuses a different identity before authorization',
        () async {
      final storage = _MemoryStorage(other);
      var sends = 0;
      final client = _client(storage, (options) async {
        sends++;
        return _response(options, 200, '{}');
      });

      await expectLater(
        _submit(client, kind),
        throwsA(isA<SessionIdentityChangedException>()),
      );

      expect(sends, 0);
    });

    test('$kind replay does not retry a 401 as another identity', () async {
      final storage = _MemoryStorage(owner);
      var sends = 0;
      final client = _client(storage, (options) async {
        sends++;
        expect(options.headers['Authorization'], 'Bearer owner-token');
        await storage.saveSession(other);
        return _response(
            options,
            401,
            jsonEncode({
              'code': 'UNAUTHORIZED',
              'message': 'Expired',
            }));
      });

      await expectLater(
        _submit(client, kind),
        throwsA(isA<SessionIdentityChangedException>()),
      );

      expect(sends, 1);
      expect((await storage.getSession())?.userId, other.userId);
    });
  }
}

Future<void> _submit(ApiClient client, String kind) {
  if (kind == 'attendance') {
    return client
        .submitAttendanceEvent(
          eventId: 'event-owner-a',
          eventType: AttendanceEventType.checkIn,
          shiftInstanceId: 'shift-a',
          location: const GeoPoint(
            latitude: 30.0,
            longitude: 31.0,
            accuracyMeters: 8,
          ),
          capturedAt: DateTime.utc(2026, 10, 29),
          expectedTenantId: 'tenant-a',
          expectedUserId: 'owner-a',
        )
        .then((_) {});
  }
  return client.submitRequest(
    {'requestId': 'request-owner-a', 'type': 'leave'},
    expectedTenantId: 'tenant-a',
    expectedUserId: 'owner-a',
  ).then((_) {});
}

ApiClient _client(
  _MemoryStorage storage,
  Future<ResponseBody> Function(RequestOptions) respond,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.invalid'));
  dio.httpClientAdapter = _Adapter(respond);
  return ApiClient(
      baseUrl: 'https://api.example.invalid', tokenStorage: storage, dio: dio);
}

ResponseBody _response(RequestOptions options, int status, String body) =>
    ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

final class _MemoryStorage extends TokenStorage {
  AuthSessionEntity? session;

  _MemoryStorage(this.session);

  @override
  Future<void> saveSession(AuthSessionEntity value) async => session = value;

  @override
  Future<AuthSessionEntity?> getSession() async => session;

  @override
  Future<void> clearSession() async => session = null;
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      respond(options);

  @override
  void close({bool force = false}) {}
}
