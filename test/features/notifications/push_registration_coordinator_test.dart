import 'dart:async';

import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/notifications/data/push_registration_coordinator.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });
  test('does not request permission before the explicit preference action',
      () async {
    final push = _Push(permission: PushPermissionState.unknown);
    final coordinator = _coordinator(push: push);
    expect(push.requests, 0);
    await coordinator.dispose();
  });

  test('registers only after a granted explicit permission action', () async {
    final push = _Push(permission: PushPermissionState.unknown);
    final requests = <RequestOptions>[];
    final coordinator = _coordinator(push: push, requests: requests);

    final result = await coordinator.enable(locale: 'ar');

    expect(result, PushRegistrationOutcome.enabled);
    expect(push.requests, 1);
    expect(requests.single.path, '/notification-devices');
    expect(requests.single.data, {
      'installationId': '00000000-0000-4000-8000-000000000001',
      'platform': 'android',
      'provider': 'fcm',
      'token': 'synthetic-token-value-at-least-32-characters',
      'locale': 'ar',
    });
    await coordinator.dispose();
  });

  test('declined permission does not obtain or register a token', () async {
    final push = _Push(
      permission: PushPermissionState.denied,
      permissionAfterRequest: PushPermissionState.denied,
    );
    final requests = <RequestOptions>[];
    final coordinator = _coordinator(push: push, requests: requests);

    final outcome = await coordinator.enable(locale: 'ar');
    expect(outcome, PushRegistrationOutcome.permissionUnavailable);
    expect(push.requests, 1);
    expect(push.tokenRequests, 0);
    expect(requests, isEmpty);
    await coordinator.dispose();
  });

  test('keeps push disabled when protected registration is unavailable',
      () async {
    final push = _Push(permission: PushPermissionState.granted);
    final coordinator = PushRegistrationCoordinator(
      apiClient: ApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        tokenStorage: TokenStorage(),
        dio: Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1')),
      ),
      tokenStorage: TokenStorage(),
      pushNotifications: push,
      installationEvidence: _UnavailableInstallation(),
    );

    final outcome = await coordinator.enable(locale: 'ar');

    expect(outcome, PushRegistrationOutcome.registrationUnavailable);
    await coordinator.dispose();
  });

  test('revokes the remote destination before deleting a local token',
      () async {
    final push = _Push(permission: PushPermissionState.granted);
    final requests = <RequestOptions>[];
    final storage = _MemoryTokenStorage();
    await storage.saveSession(const AuthSessionEntity(
      accessToken: 'access',
      refreshToken: 'refresh',
      tenantId: '00000000-0000-4000-8000-000000000101',
      userId: '00000000-0000-4000-8000-000000000102',
      role: UserRole.employee,
      email: 'synthetic@example.test',
      displayName: 'Synthetic',
    ));
    await storage.saveDeviceInstallationRegistration(
      tenantId: '00000000-0000-4000-8000-000000000101',
      userId: '00000000-0000-4000-8000-000000000102',
      installationId: '00000000-0000-4000-8000-000000000001',
    );
    final coordinator = _coordinator(
      push: push,
      requests: requests,
      storage: storage,
    );

    await coordinator.disable();

    expect(requests.single.path,
        '/notification-devices/00000000-0000-4000-8000-000000000001');
    expect(requests.single.method, 'DELETE');
    expect(push.disabled, 1);
    await coordinator.dispose();
  });
}

PushRegistrationCoordinator _coordinator({
  required _Push push,
  List<RequestOptions>? requests,
  TokenStorage? storage,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'));
  dio.httpClientAdapter = _Adapter(requests ?? <RequestOptions>[]);
  return PushRegistrationCoordinator(
    apiClient: ApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      tokenStorage: storage ?? TokenStorage(),
      dio: dio,
    ),
    tokenStorage: storage ?? TokenStorage(),
    pushNotifications: push,
    installationEvidence: _Installation(),
  );
}

final class _Installation implements RegisteredInstallationPort {
  @override
  Future<String> ensureRegisteredInstallation() async =>
      '00000000-0000-4000-8000-000000000001';
}

final class _MemoryTokenStorage extends TokenStorage {
  AuthSessionEntity? session;
  String? installationId;

  @override
  Future<void> saveSession(AuthSessionEntity value) async {
    session = value;
  }

  @override
  Future<AuthSessionEntity?> getSession() async => session;

  @override
  Future<void> saveDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
    required String installationId,
  }) async {
    this.installationId = installationId;
  }

  @override
  Future<String?> getDeviceInstallationRegistration({
    required String tenantId,
    required String userId,
  }) async =>
      installationId;
}

final class _Push implements PushNotificationPort {
  _Push({
    required this.permission,
    this.permissionAfterRequest = PushPermissionState.granted,
  });
  PushPermissionState permission;
  final PushPermissionState permissionAfterRequest;
  int requests = 0;
  int tokenRequests = 0;
  int disabled = 0;
  final _refreshes = StreamController<String>.broadcast();

  @override
  Future<PushPermissionState> currentPermission() async => permission;
  @override
  Future<void> disable() async {
    disabled++;
  }

  @override
  Future<String?> enableAndGetToken() async {
    tokenRequests++;
    return 'synthetic-token-value-at-least-32-characters';
  }

  @override
  Future<PushPermissionState> requestPermission() async {
    requests++;
    permission = permissionAfterRequest;
    return permission;
  }

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<String> get foregroundMessageIds => const Stream.empty();

  @override
  Stream<String> get openedMessageIds => const Stream.empty();

  @override
  Future<String?> initialMessageId() async => null;
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.requests);
  final List<RequestOptions> requests;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"id":"00000000-0000-4000-8000-000000000002","installationId":"00000000-0000-4000-8000-000000000001","provider":"fcm","state":"active","lastSeenAt":"2026-10-06T00:00:00.000Z"}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }
}

final class _UnavailableInstallation implements RegisteredInstallationPort {
  @override
  Future<String> ensureRegisteredInstallation() =>
      Future<String>.error(const AttendanceTrustUnavailableException());
}
