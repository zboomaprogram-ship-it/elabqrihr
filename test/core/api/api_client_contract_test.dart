import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/notifications/data/push_registration_coordinator.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';

class FakeTokenStorage extends TokenStorage {
  @override
  Future<void> saveSession(AuthSessionEntity session) async {}

  @override
  Future<AuthSessionEntity?> getSession() async => null;

  @override
  Future<void> clearSession() async {}
}

void main() {
  group('ApiClient Contract Serialization Tests (OpenAPI 0.2.0)', () {
    late Dio dio;
    late ApiClient apiClient;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path == '/attendance/current') {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'shiftInstanceId': '8c52084c-cb14-41d9-813a-773cefb180a0',
                    'businessDate': '2026-09-20',
                    'startsAt': '2026-09-20T22:00:00.000Z',
                    'endsAt': '2026-09-21T06:00:00.000Z',
                    'branch': {
                      'id': '9c52084c-cb14-41d9-813a-773cefb180a1',
                      'name': 'Cairo HQ',
                      'timezone': 'Africa/Cairo',
                      'latitude': 30.0444,
                      'longitude': 31.2357,
                      'radiusMeters': 150,
                    },
                    'state': 'not_started',
                  },
                ),
              );
            }

            if (options.path == '/attendance/events') {
              final body = options.data as Map<String, dynamic>;
              expect(body.containsKey('eventId'), isTrue);
              expect(body.containsKey('shiftInstanceId'), isTrue);
              expect(body.containsKey('type'), isTrue);
              expect(body.containsKey('occurredAt'), isTrue);
              expect(body.containsKey('location'), isTrue);

              final loc = body['location'] as Map<String, dynamic>;
              expect(loc.containsKey('capturedAt'), isTrue);
              expect(loc.containsKey('accuracyMeters'), isTrue);
              expect(loc['capturedAt'], '2026-09-20T21:59:40.000Z');

              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'eventId': body['eventId'],
                    'result': 'accepted',
                    'reasonCode': 'ACCEPTED',
                    'receivedAt': DateTime.now().toUtc().toIso8601String(),
                    'session': {
                      'shiftInstanceId': body['shiftInstanceId'],
                      'state': 'checked_in',
                    },
                  },
                ),
              );
            }

            if (options.path == '/attendance/shifts') {
              expect(options.queryParameters, {
                'startDate': '2026-09-01',
                'endDate': '2026-09-21',
                'limit': 25,
              });
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'items': [
                    {
                      'shiftInstanceId': '8c52084c-cb14-41d9-813a-773cefb180a0',
                      'businessDate': '2026-09-20',
                      'startsAt': '2026-09-20T06:00:00.000Z',
                      'endsAt': '2026-09-20T14:00:00.000Z',
                      'branchName': 'Cairo HQ',
                      'state': 'completed',
                    }
                  ],
                },
              ));
            }

            if (options.path == '/device-installations/challenges') {
              expect(options.data, {
                'platform': 'android',
                'appIdentifier': 'com.zbooma.elabqrihr',
                'purpose': 'installation_registration',
              });
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'challengeId': '8c52084c-cb14-41d9-813a-773cefb180a0',
                    'nonce': 'synthetic-installation-nonce',
                    'expiresAt': '2026-10-12T00:00:00.000Z',
                  },
                ),
              );
            }

            if (options.path == '/notifications') {
              expect(options.queryParameters['cursor'], equals('cur-1'));
              expect(options.queryParameters['limit'], equals(10));
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'items': [
                    {
                      'id': 'notif-1',
                      'tenantId': 'tenant-1',
                      'userId': 'user-1',
                      'kind': 'request_submitted',
                      'titleKey': 'notification.request.submitted.title',
                      'bodyKey': 'notification.request.submitted.body',
                      'destinationKind': 'request',
                      'destinationId': 'req-1',
                      'readState': 'unread',
                      'createdAt': '2026-09-27T08:00:00.000Z',
                    },
                  ],
                  'nextCursor': 'cur-2',
                },
              ));
            }

            if (options.path == '/notifications/notif-1') {
              expect(options.method, equals('GET'));
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'notif-1',
                  'tenantId': 'tenant-1',
                  'userId': 'user-1',
                  'kind': 'request_submitted',
                  'titleKey': 'notification.request.submitted.title',
                  'bodyKey': 'notification.request.submitted.body',
                  'destinationKind': 'request',
                  'destinationId': 'req-1',
                  'readState': 'unread',
                  'createdAt': '2026-09-27T08:00:00.000Z',
                },
              ));
            }

            if (options.path == '/notifications/unread-count') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'count': 3},
              ));
            }

            if (options.path == '/notifications/notif-1/read') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'notif-1',
                  'tenantId': 'tenant-1',
                  'userId': 'user-1',
                  'kind': 'request_submitted',
                  'titleKey': 'notification.request.submitted.title',
                  'bodyKey': 'notification.request.submitted.body',
                  'destinationKind': 'request',
                  'destinationId': 'req-1',
                  'readState': 'read',
                  'readAt': '2026-09-27T08:05:00.000Z',
                  'createdAt': '2026-09-27T08:00:00.000Z',
                },
              ));
            }

            if (options.path == '/notifications/read-all') {
              final body = options.data as Map<String, dynamic>;
              expect(body['commandId'], isNotEmpty);
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {'count': 0},
              ));
            }

            if (options.path == '/reports/workforce/summary') {
              expect(options.queryParameters['from'], equals('2026-08-01'));
              expect(options.queryParameters['to'], equals('2026-08-31'));
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'from': '2026-08-01',
                  'to': '2026-08-31',
                  'activeEmployees': 12,
                  'suspendedEmployees': 1,
                  'archivedEmployees': 2,
                  'activeLocations': 3,
                  'unassignedEmployees': 0,
                  'generatedAt': '2026-08-31T23:59:59.000Z',
                },
              ));
            }

            if (options.path == '/reports/attendance-leave') {
              expect(
                  options.queryParameters['startDate'], equals('2026-08-01'));
              expect(options.queryParameters['endDate'], equals('2026-08-31'));
              expect(options.queryParameters['cursor'], equals('cur-rep-1'));
              expect(options.queryParameters['limit'], equals(20));
              expect(options.queryParameters['state'], equals('approved'));
              expect(options.queryParameters['type'], equals('leave'));
              expect(
                  options.queryParameters.containsKey('requestState'), isFalse);
              expect(
                  options.queryParameters.containsKey('requestType'), isFalse);
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'totals': {
                    'employees': 15,
                    'attendanceExceptions': 4,
                    'leaveMinutes': 360,
                    'requests': 6,
                  },
                  'items': [
                    {
                      'employeeId': 'emp-10',
                      'employeeName': 'فاطمة أحمد',
                      'businessDate': '2026-08-15',
                      'attendanceState': 'present',
                      'leaveMinutes': 0,
                      'requestState': 'approved',
                    }
                  ],
                  'nextCursor': 'cur-rep-2',
                },
              ));
            }

            if (options.path == '/exports') {
              final body = options.data as Map<String, dynamic>;
              expect(body['commandId'], isNotEmpty);
              expect(body['reportType'], equals('attendance_leave'));
              expect(body['format'], equals('csv'));
              expect(body['filter'], isA<Map<String, dynamic>>());
              final filter = body['filter'] as Map<String, dynamic>;
              expect(filter['startDate'], equals('2026-08-01'));
              expect(filter['endDate'], equals('2026-08-31'));
              expect(filter['requestState'], equals('approved'));

              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 202,
                data: {
                  'id': 'exp-job-1',
                  'reportType': 'attendance_leave',
                  'format': 'csv',
                  'state': 'queued',
                  'rowCount': 15,
                  'checksum': 'a' * 64,
                  'reasonCode': 'EXPORT_QUEUED',
                  'createdAt': '2026-08-31T12:00:00.000Z',
                  'expiresAt': '2026-09-07T12:00:00.000Z',
                },
              ));
            }

            if (options.path == '/exports/exp-job-1') {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'id': 'exp-job-1',
                  'reportType': 'attendance_leave',
                  'format': 'csv',
                  'state': 'ready',
                  'rowCount': 15,
                  'createdAt': '2026-08-31T12:00:00.000Z',
                  'expiresAt': '2026-09-07T12:00:00.000Z',
                },
              ));
            }

            return handler.next(options);
          },
        ),
      );

      apiClient = ApiClient(
        baseUrl: 'http://test',
        tokenStorage: FakeTokenStorage(),
        dio: dio,
      );
    });

    test('getCurrentAttendanceContext maps OpenAPI 0.2.0 payload correctly',
        () async {
      final context = await apiClient.getCurrentAttendanceContext();
      expect(context.shiftInstanceId,
          equals('8c52084c-cb14-41d9-813a-773cefb180a0'));
      expect(context.branchName, equals('Cairo HQ'));
      expect(context.isCheckedIn, isFalse);
      expect(context.branchLocation.latitude, equals(30.0444));
      expect(context.allowedRadiusMeters, equals(150.0));
    });

    test(
        'submitAttendanceEvent serializes eventId and location to contract schema',
        () async {
      final event = await apiClient.submitAttendanceEvent(
        eventId: '8c52084c-cb14-41d9-813a-773cefb180a2',
        eventType: AttendanceEventType.checkIn,
        shiftInstanceId: '8c52084c-cb14-41d9-813a-773cefb180a0',
        location: GeoPoint(
            latitude: 30.0444,
            longitude: 31.2357,
            accuracyMeters: 10.0,
            timestamp: DateTime.utc(2026, 9, 20, 21, 59, 40)),
        capturedAt: DateTime.utc(2026, 9, 20, 22, 0, 0),
      );

      expect(event.id, equals('8c52084c-cb14-41d9-813a-773cefb180a2'));
      expect(event.status, equals(AttendanceValidationStatus.accepted));
      expect(event.reasonCode, equals('ACCEPTED'));
    });

    test('installation challenge includes its required purpose', () async {
      final challenge = await apiClient.createInstallationChallenge(
        platform: 'android',
        appIdentifier: 'com.zbooma.elabqrihr',
      );

      expect(challenge.challengeId,
          equals('8c52084c-cb14-41d9-813a-773cefb180a0'));
    });

    test('getMyShiftInstances uses the OpenAPI 0.4.1 query and response',
        () async {
      final page = await apiClient.getMyShiftInstances(
        startDate: '2026-09-01',
        endDate: '2026-09-21',
        limit: 25,
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.branchName, 'Cairo HQ');
      expect(page.items.single.shiftInstanceId,
          '8c52084c-cb14-41d9-813a-773cefb180a0');
    });

    test(
        'listNotifications uses cursor and limit query parameters and maps items',
        () async {
      final page =
          await apiClient.listNotifications(cursor: 'cur-1', limit: 10);
      expect(page.items, hasLength(1));
      expect(page.items.first.id, equals('notif-1'));
      expect(page.items.first.titleKey,
          equals('notification.request.submitted.title'));
      expect(page.nextCursor, equals('cur-2'));
    });

    test('getNotification resolves an opaque notification ID', () async {
      final notification = await apiClient.getNotification('notif-1');
      expect(notification.id, equals('notif-1'));
      expect(notification.destinationId, equals('req-1'));
      expect(notification.destinationKind,
          equals(NotificationDestinationKindDto.request));
    });

    test('getUnreadNotificationCount returns count dto', () async {
      final res = await apiClient.getUnreadNotificationCount();
      expect(res.count, equals(3));
    });

    test('markNotificationRead posts to /notifications/:id/read', () async {
      final res = await apiClient.markNotificationRead('notif-1');
      expect(res.id, equals('notif-1'));
      expect(res.readState, equals(NotificationReadStateDto.read));
    });

    test('markAllNotificationsRead posts commandId to /notifications/read-all',
        () async {
      final res = await apiClient.markAllNotificationsRead(
        commandId: 'cmd-read-all-1',
      );
      expect(res.count, equals(0));
    });

    test('getWorkforceSummary sends required from and to date queries',
        () async {
      final summary = await apiClient.getWorkforceSummary(
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 31),
      );
      expect(summary.from, equals('2026-08-01'));
      expect(summary.to, equals('2026-08-31'));
      expect(summary.activeEmployees, equals(12));
      expect(summary.suspendedEmployees, equals(1));
      expect(summary.archivedEmployees, equals(2));
      expect(summary.totalEmployees, equals(15));
    });

    test(
        'getAttendanceLeaveReport sends bounded date queries and maps totals and items',
        () async {
      final report = await apiClient.getAttendanceLeaveReport(
        from: DateTime.utc(2026, 8, 1),
        to: DateTime.utc(2026, 8, 31),
        cursor: 'cur-rep-1',
        limit: 20,
        requestType: 'leave',
        requestState: 'approved',
      );
      expect(report.totals.employees, equals(15));
      expect(report.totals.attendanceExceptions, equals(4));
      expect(report.totals.leaveMinutes, equals(360));
      expect(report.totals.requests, equals(6));
      expect(report.items, hasLength(1));
      expect(report.items.first.employeeName, equals('فاطمة أحمد'));
      expect(report.items.first.requestState, equals('approved'));
      expect(report.nextCursor, equals('cur-rep-2'));
    });

    test('createExport posts commandId and singular filter to /exports',
        () async {
      final request = CreateExportRequestDto(
        commandId: 'cmd-export-1',
        reportType: 'attendance_leave',
        format: 'csv',
        filter: const ReportFilterDto(
          startDate: '2026-08-01',
          endDate: '2026-08-31',
          requestState: 'approved',
        ),
      );
      final job = await apiClient.createExport(request: request);
      expect(job.id, equals('exp-job-1'));
      expect(job.reportType, equals('attendance_leave'));
      expect(job.format, equals('csv'));
      expect(job.state, equals('queued'));
      expect(job.rowCount, equals(15));
      expect(job.checksum, equals('a' * 64));
    });

    test('getExport reads the authorized export status endpoint', () async {
      final job = await apiClient.getExport('exp-job-1');
      expect(job.id, 'exp-job-1');
      expect(job.state, 'ready');
      expect(job.rowCount, 15);
    });
  });

  group('ApiClient Token Refresh & Session Management Tests', () {
    test('does not retry an old request with a different user session',
        () async {
      const first = AuthSessionEntity(
        accessToken: 'first-token',
        refreshToken: 'first-refresh',
        tenantId: 'tenant',
        userId: 'first',
        role: UserRole.employee,
        email: 'first@example.invalid',
        displayName: 'First',
      );
      const second = AuthSessionEntity(
        accessToken: 'second-token',
        refreshToken: 'second-refresh',
        tenantId: 'tenant',
        userId: 'second',
        role: UserRole.employee,
        email: 'second@example.invalid',
        displayName: 'Second',
      );
      final storage = _InMemoryTokenStorage(initialSession: first);
      final transport = Dio(BaseOptions(baseUrl: 'http://test'));
      var calls = 0;
      transport.httpClientAdapter = _MockHttpAdapter((options) async {
        calls++;
        if (calls == 1) {
          await storage.saveSession(second);
          return ResponseBody.fromString('{}', 401, headers: {
            Headers.contentTypeHeader: ['application/json']
          });
        }
        return ResponseBody.fromString('{}', 200, headers: {
          Headers.contentTypeHeader: ['application/json']
        });
      });
      final client = ApiClient(
          baseUrl: 'http://test', tokenStorage: storage, dio: transport);
      await expectLater(
        client.createDynamicRequest(<String, dynamic>{}),
        throwsA(isA<SessionIdentityChangedException>()),
      );
      expect(calls, 1);
      expect((await storage.getSession())?.userId, 'second');
    });
    test('401 automatically refreshes token and retries request', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      var requestCount = 0;
      var refreshCount = 0;

      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path.endsWith('/protected-data')) {
          requestCount++;
          if (options.headers['Authorization'] == 'Bearer stale-token') {
            return ResponseBody.fromString(
              '{"code":"UNAUTHORIZED","message":"Token expired"}',
              401,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          if (options.headers['Authorization'] == 'Bearer refreshed-token') {
            return ResponseBody.fromString(
              '{"success":true}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
        }

        if (options.path.endsWith('/auth/refresh')) {
          refreshCount++;
          expect(options.headers.containsKey('Authorization'), isFalse);
          return ResponseBody.fromString(
            jsonEncode({
              'accessToken': 'refreshed-token',
              'refreshToken': 'new-refresh-token',
              'user': {
                'id': 'user-1',
                'email': 'user@test.com',
                'displayName': 'Test User',
              },
              'membership': {
                'tenantId': 'tenant-1',
                'role': 'employee',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        throw DioException(
          requestOptions: options,
          message: 'Unhandled mock path: ${options.path}',
        );
      });

      final currentSession = const AuthSessionEntity(
        accessToken: 'stale-token',
        refreshToken: 'valid-refresh-token',
        tenantId: 'tenant-1',
        userId: 'user-1',
        role: UserRole.employee,
        email: 'user@test.com',
        displayName: 'Test User',
      );

      final tokenStorage =
          _InMemoryTokenStorage(initialSession: currentSession);
      ApiClient(
        baseUrl: 'http://test',
        tokenStorage: tokenStorage,
        dio: dio,
      );

      final response = await dio.get('/protected-data');
      expect(response.statusCode, equals(200));
      expect(response.data, equals({'success': true}));
      expect(requestCount, equals(2));
      expect(refreshCount, equals(1));

      final updatedSession = await tokenStorage.getSession();
      expect(updatedSession?.accessToken, equals('refreshed-token'));
      expect(updatedSession?.refreshToken, equals('new-refresh-token'));
    });

    test('network failure during refresh does not wipe session', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      var sessionExpiredCalled = false;

      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path.endsWith('/protected-data')) {
          return ResponseBody.fromString(
            '{"code":"UNAUTHORIZED","message":"Token expired"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path.endsWith('/auth/refresh')) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'Connection timed out',
          );
        }

        throw DioException(
          requestOptions: options,
          message: 'Unhandled mock path: ${options.path}',
        );
      });

      final currentSession = const AuthSessionEntity(
        accessToken: 'stale-token',
        refreshToken: 'valid-refresh-token',
        tenantId: 'tenant-1',
        userId: 'user-1',
        role: UserRole.employee,
        email: 'user@test.com',
        displayName: 'Test User',
      );

      final tokenStorage =
          _InMemoryTokenStorage(initialSession: currentSession);
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenStorage: tokenStorage,
        dio: dio,
      );
      client.onSessionExpired = () {
        sessionExpiredCalled = true;
      };

      try {
        await dio.get('/protected-data');
        fail('Should have thrown DioException');
      } catch (e) {
        expect(e, isA<DioException>());
      }

      // Session must NOT be cleared on transient network errors!
      expect(sessionExpiredCalled, isFalse);
      final sessionStillThere = await tokenStorage.getSession();
      expect(sessionStillThere, isNotNull);
      expect(sessionStillThere?.refreshToken, equals('valid-refresh-token'));
    });

    test('401 on refresh explicitly wipes invalid session', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      var sessionExpiredCalled = false;

      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        if (options.path.endsWith('/protected-data')) {
          return ResponseBody.fromString(
            '{"code":"UNAUTHORIZED"}',
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        if (options.path.endsWith('/auth/refresh')) {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 'INVALID_REFRESH_TOKEN',
              'message': 'Refresh token is invalid or revoked',
            }),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        throw DioException(
          requestOptions: options,
          message: 'Unhandled mock path: ${options.path}',
        );
      });

      final currentSession = const AuthSessionEntity(
        accessToken: 'stale-token',
        refreshToken: 'revoked-refresh-token',
        tenantId: 'tenant-1',
        userId: 'user-1',
        role: UserRole.employee,
        email: 'user@test.com',
        displayName: 'Test User',
      );

      final tokenStorage =
          _InMemoryTokenStorage(initialSession: currentSession);
      final client = ApiClient(
        baseUrl: 'http://test',
        tokenStorage: tokenStorage,
        dio: dio,
      );
      client.onSessionExpired = () {
        sessionExpiredCalled = true;
      };

      try {
        await dio.get('/protected-data');
      } catch (_) {}

      // Session MUST be cleared because server rejected the refresh token with 401
      expect(sessionExpiredCalled, isTrue);
      final sessionAfter = await tokenStorage.getSession();
      expect(sessionAfter, isNull);
    });
    test(
        'logout removes revoked credentials before scoped push cleanup and never refreshes them',
        () async {
      const session = AuthSessionEntity(
          accessToken: 'logout-access',
          refreshToken: 'logout-refresh',
          tenantId: 'tenant-logout',
          userId: 'user-logout',
          role: UserRole.employee,
          email: 'employee@example.test',
          displayName: 'Synthetic employee');
      final storage = _InMemoryTokenStorage(initialSession: session)
        ..installationId = '00000000-0000-4000-8000-000000000001';
      final requests = <RequestOptions>[];
      var revoked = false;
      final transport = Dio(BaseOptions(baseUrl: 'http://test'));
      transport.httpClientAdapter = _MockHttpAdapter((options) async {
        requests.add(options);
        if (options.path == '/auth/logout') {
          revoked = true;
          return ResponseBody.fromString('', 204);
        }
        if (options.path.startsWith('/notification-devices/') && !revoked) {
          return ResponseBody.fromString('', 204);
        }
        return ResponseBody.fromString('{"code":"SESSION_INACTIVE"}', 401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            });
      });
      final client = ApiClient(
          baseUrl: 'http://test', tokenStorage: storage, dio: transport);
      final push = _LogoutPushPort();
      final coordinator = PushRegistrationCoordinator(
          apiClient: client,
          tokenStorage: storage,
          pushNotifications: push,
          installationEvidence: _LogoutInstallation());
      var invalidations = 0, expired = 0;
      client.onBeforeLogout = (_) => coordinator.disable();
      client.onSessionInvalidated = (previous) async {
        invalidations++;
        expect(previous.userId, session.userId);
        expect(await storage.getSession(), isNull,
            reason:
                'Revoked credentials must not be available to authenticated push cleanup');
        await coordinator.disable();
      };
      client.onSessionExpired = () {
        expired++;
      };
      await client.logout();
      expect(await storage.getSession(), isNull);
      expect(invalidations, 1);
      expect(expired, 1);
      expect(push.disabled, 2);
      expect(requests.map((r) => r.path).toList(), [
        '/notification-devices/00000000-0000-4000-8000-000000000001',
        '/auth/logout'
      ]);
      expect(requests.where((r) => r.path == '/auth/refresh'), isEmpty);
      await coordinator.dispose();
    });
    test(
        'cleanup failure still clears credentials and announces the expired session',
        () async {
      const session = AuthSessionEntity(
          accessToken: 'logout-access',
          refreshToken: 'logout-refresh',
          tenantId: 'tenant-logout',
          userId: 'user-logout',
          role: UserRole.employee,
          email: 'employee@example.test',
          displayName: 'Synthetic employee');
      final storage = _InMemoryTokenStorage(initialSession: session);
      final transport = Dio(BaseOptions(baseUrl: 'http://test'));
      transport.httpClientAdapter =
          _MockHttpAdapter((options) async => ResponseBody.fromString('', 204));
      final client = ApiClient(
          baseUrl: 'http://test', tokenStorage: storage, dio: transport);
      var expired = 0;
      client.onSessionInvalidated = (_) async {
        throw StateError('Synthetic cleanup storage failure');
      };
      client.onSessionExpired = () {
        expired++;
      };
      await expectLater(client.logout(), throwsStateError);
      expect(await storage.getSession(), isNull);
      expect(expired, 1);
    });
  });
}

class _InMemoryTokenStorage extends TokenStorage {
  AuthSessionEntity? _session;
  String? installationId;

  _InMemoryTokenStorage({AuthSessionEntity? initialSession})
      : _session = initialSession;

  @override
  Future<void> saveSession(AuthSessionEntity session) async {
    _session = session;
  }

  @override
  Future<AuthSessionEntity?> getSession() async => _session;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<String?> getDeviceInstallationRegistration(
          {required String tenantId, required String userId}) async =>
      installationId;
}

final class _MockHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockHttpAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

final class _LogoutInstallation implements RegisteredInstallationPort {
  @override
  Future<String> ensureRegisteredInstallation() async =>
      '00000000-0000-4000-8000-000000000001';
}

final class _LogoutPushPort implements PushNotificationPort {
  int disabled = 0;
  @override
  Future<void> disable() async {
    disabled++;
  }

  @override
  Future<PushPermissionState> currentPermission() async =>
      PushPermissionState.granted;
  @override
  Future<PushPermissionState> requestPermission() async =>
      PushPermissionState.granted;
  @override
  Future<String?> enableAndGetToken() async => null;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<String> get foregroundMessageIds => const Stream.empty();
  @override
  Stream<String> get openedMessageIds => const Stream.empty();
  @override
  Future<String?> initialMessageId() async => null;
}
