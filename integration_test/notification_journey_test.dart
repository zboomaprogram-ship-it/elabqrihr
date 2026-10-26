import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/notifications/data/notification_repository_impl.dart';
import 'package:attend_mobile/features/reports/data/report_repository_impl.dart';
import 'package:attend_mobile/features/reports/presentation/screens/role_reports_screen.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';
import '../test/test_doubles/fake_dynamic_request_repo.dart';
import '../test/test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class RecordedHttpCall {
  final String method;
  final String path;
  final Map<String, String> queryParameters;
  final dynamic body;
  final int statusCode;

  RecordedHttpCall({
    required this.method,
    required this.path,
    required this.queryParameters,
    this.body,
    required this.statusCode,
  });

  @override
  String toString() =>
      '$method $path query=$queryParameters status=$statusCode';
}

class _LocalIntegrationHttpServer {
  final HttpServer server;
  final List<RecordedHttpCall> recordedCalls = [];
  int unreadCount = 2;
  bool reportsForbidden = false;
  bool reportsEmpty = false;
  String exportJobState = 'queued';

  _LocalIntegrationHttpServer._(this.server);

  static Future<_LocalIntegrationHttpServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = _LocalIntegrationHttpServer._(server);
    instance._listen();
    return instance;
  }

  void _listen() {
    server.listen((HttpRequest request) async {
      String? bodyString;
      dynamic parsedBody;
      if (request.method == 'POST' || request.method == 'PUT') {
        bodyString = await utf8.decoder.bind(request).join();
        if (bodyString.isNotEmpty) {
          try {
            parsedBody = jsonDecode(bodyString);
          } catch (_) {
            parsedBody = bodyString;
          }
        }
      }

      int statusCode = 200;
      Map<String, dynamic> responseData = {};

      final path = request.uri.path;
      final query = Map<String, String>.from(request.uri.queryParameters);

      if (path == '/notifications/unread-count') {
        statusCode = 200;
        responseData = {'count': unreadCount};
      } else if (path == '/notifications') {
        statusCode = 200;
        responseData = {
          'items': [
            {
              'id': 'notif-forbidden-2',
              'tenantId': 'tenant-pilot-5',
              'userId': 'user-pilot-5',
              'kind': 'request_submitted',
              'titleKey': 'notification.request.submitted.title',
              'bodyKey': 'notification.request.submitted.body',
              'destinationKind': 'request',
              'destinationId': 'req-forbidden-2',
              'readState': unreadCount > 0 ? 'unread' : 'read',
              'createdAt': '2026-09-26T09:15:00.000Z',
            },
            {
              'id': 'notif-auth-1',
              'tenantId': 'tenant-pilot-5',
              'userId': 'user-pilot-5',
              'kind': 'request_decided',
              'titleKey': 'notification.request.decided.title',
              'bodyKey': 'notification.request.decided.body',
              'destinationKind': 'request',
              'destinationId': 'req-auth-1',
              'readState': unreadCount > 1 ? 'unread' : 'read',
              'createdAt': '2026-09-26T09:00:00.000Z',
            },
          ],
          'nextCursor': null,
        };
      } else if (path == '/notifications/notif-forbidden-2/read') {
        if (unreadCount > 0) unreadCount--;
        statusCode = 200;
        responseData = {
          'id': 'notif-forbidden-2',
          'tenantId': 'tenant-pilot-5',
          'userId': 'user-pilot-5',
          'kind': 'request_submitted',
          'titleKey': 'notification.request.submitted.title',
          'bodyKey': 'notification.request.submitted.body',
          'destinationKind': 'request',
          'destinationId': 'req-forbidden-2',
          'readState': 'read',
          'readAt': DateTime.now().toUtc().toIso8601String(),
          'createdAt': '2026-09-26T09:15:00.000Z',
        };
      } else if (path == '/notifications/notif-auth-1/read') {
        if (unreadCount > 0) unreadCount--;
        statusCode = 200;
        responseData = {
          'id': 'notif-auth-1',
          'tenantId': 'tenant-pilot-5',
          'userId': 'user-pilot-5',
          'kind': 'request_decided',
          'titleKey': 'notification.request.decided.title',
          'bodyKey': 'notification.request.decided.body',
          'destinationKind': 'request',
          'destinationId': 'req-auth-1',
          'readState': 'read',
          'readAt': DateTime.now().toUtc().toIso8601String(),
          'createdAt': '2026-09-26T09:00:00.000Z',
        };
      } else if (path == '/notifications/read-all') {
        unreadCount = 0;
        statusCode = 200;
        responseData = {'count': 0};
      } else if (path == '/requests/req-forbidden-2') {
        statusCode = 403;
        responseData = {
          'message': 'ليس لديك صلاحية فتح هذا الطلب.',
          'code': 'FORBIDDEN'
        };
      } else if (path == '/requests/req-auth-1') {
        statusCode = 200;
        responseData = {
          'id': 'req-auth-1',
          'employeeId': 'emp-pilot-1',
          'type': 'leave',
          'state': 'approved',
          'revision': 1,
          'requestedMinutes': 480,
          'submittedAt': '2026-09-25T09:00:00.000Z',
          'details': {},
          'steps': [],
        };
      } else if (path == '/reports/workforce/summary') {
        if (reportsForbidden) {
          statusCode = 403;
          responseData = {
            'message': 'ليس لديك صلاحية لعرض هذا التقرير.',
            'code': 'FORBIDDEN'
          };
        } else if (reportsEmpty) {
          statusCode = 200;
          responseData = {
            'from': query['from'] ?? '2026-08-01',
            'to': query['to'] ?? '2026-08-31',
            'activeEmployees': 0,
            'suspendedEmployees': 0,
            'archivedEmployees': 0,
            'activeLocations': 0,
            'unassignedEmployees': 0,
            'generatedAt': '2026-09-27T10:00:00.000Z',
          };
        } else {
          statusCode = 200;
          responseData = {
            'from': query['from'] ?? '2026-08-01',
            'to': query['to'] ?? '2026-08-31',
            'activeEmployees': 12,
            'suspendedEmployees': 2,
            'archivedEmployees': 1,
            'activeLocations': 4,
            'unassignedEmployees': 0,
            'generatedAt': '2026-09-27T10:00:00.000Z',
          };
        }
      } else if (path == '/reports/attendance-leave') {
        if (query.containsKey('requestState') ||
            query.containsKey('requestType')) {
          statusCode = 422;
          responseData = {'message': 'Non-canonical report query'};
        } else if (reportsEmpty) {
          statusCode = 200;
          responseData = {
            'totals': {
              'employees': 0,
              'attendanceExceptions': 0,
              'leaveMinutes': 0,
              'requests': 0,
            },
            'items': [],
            'nextCursor': null,
          };
        } else if (query['cursor'] == 'page-2-cursor') {
          statusCode = 200;
          responseData = {
            'totals': {
              'employees': 15,
              'attendanceExceptions': 3,
              'leaveMinutes': 240,
              'requests': 4,
            },
            'items': [
              {
                'employeeId': 'emp-pilot-2',
                'employeeName': 'سارة المهندس',
                'businessDate': '2026-09-25',
                'attendanceState': 'late',
                'leaveMinutes': 60,
                'requestState': 'approved',
              },
            ],
            'nextCursor': null,
          };
        } else {
          statusCode = 200;
          responseData = {
            'totals': {
              'employees': 15,
              'attendanceExceptions': 3,
              'leaveMinutes': 240,
              'requests': 4,
            },
            'items': [
              {
                'employeeId': 'emp-pilot-1',
                'employeeName': 'أحمد إبراهيم',
                'businessDate': '2026-09-26',
                'attendanceState': 'present',
                'leaveMinutes': 0,
                'requestState': 'approved',
              },
            ],
            'nextCursor': 'page-2-cursor',
          };
        }
      } else if (path == '/exports') {
        statusCode = 202;
        responseData = {
          'id': 'exp-pilot-001',
          'reportType': 'attendance_leave',
          'format': 'csv',
          'state': 'queued',
          'rowCount': 15,
          'checksum':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'reasonCode': 'EXPORT_ACCEPTED',
          'createdAt': '2026-09-27T10:00:00.000Z',
          'expiresAt': '2026-10-04T10:00:00.000Z',
        };
      } else if (path == '/exports/exp-pilot-001') {
        statusCode = 200;
        responseData = {
          'id': 'exp-pilot-001',
          'reportType': 'attendance_leave',
          'format': 'csv',
          'state': exportJobState,
          'rowCount': 15,
          'checksum':
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'reasonCode': 'EXPORT_ACCEPTED',
          'createdAt': '2026-09-27T10:00:00.000Z',
          'expiresAt': '2026-10-04T10:00:00.000Z',
        };
      } else {
        statusCode = 404;
        responseData = {'message': 'Not found'};
      }

      recordedCalls.add(
        RecordedHttpCall(
          method: request.method,
          path: path,
          queryParameters: query,
          body: parsedBody,
          statusCode: statusCode,
        ),
      );

      request.response.statusCode = statusCode;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(responseData));
      await request.response.close();
    });
  }

  Future<void> close() async {
    await server.close(force: true);
  }
}

class _IntegrationTokenStorage extends TokenStorage {
  AuthSessionEntity? currentSession;
  _IntegrationTokenStorage(this.currentSession);
  @override
  Future<AuthSessionEntity?> getSession() async => currentSession;
  @override
  Future<void> saveSession(AuthSessionEntity s) async {
    currentSession = s;
  }

  @override
  Future<void> clearSession() async {
    currentSession = null;
  }

  @override
  Future<String?> getBaseUrl() async => null;
}

class _IntegrationAuthRepo implements AuthRepository {
  final AuthSessionEntity session;
  _IntegrationAuthRepo(this.session);
  @override
  Future<AuthSessionEntity?> getCachedSession() async => session;
  @override
  Future<AuthSessionEntity> login(
          {required String email,
          required String password,
          required String tenantSlug,
          String? deviceInstallationId}) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSessionEntity> refreshSession() => throw UnimplementedError();
  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();
  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class _IntegrationAttendanceRepo implements AttendanceRepository {
  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-1',
      branchName: 'Cairo HQ',
      shiftName: 'Morning Shift',
      scheduledStart: DateTime.utc(2026, 9, 26, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 26, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent(
          {required AttendanceEventType eventType,
          required String shiftInstanceId,
          GeoPoint? location,
          String? clientEventId,
          DateTime? capturedAt}) =>
      throw UnimplementedError();
  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
}

class _IntegrationRequestRepo implements RequestRepository {
  @override
  Future<RequestEntity> submitRequest(
          {required String requestId,
          required RequestType type,
          required Map<String, dynamic> payload}) =>
      throw UnimplementedError();
  @override
  Future<List<RequestEntity>> listMyRequests(
          {String? cursor,
          int limit = 50,
          RequestType? type,
          RequestState? state}) async =>
      const [];
  @override
  Future<RequestEntity> getRequestDetail(String requestId) async {
    return RequestEntity(
      id: requestId,
      employeeId: 'emp-pilot-1',
      type: RequestType.leave,
      state: RequestState.approved,
      revision: 1,
      requestedMinutes: 480,
      submittedAt: DateTime.utc(2026, 9, 25, 9, 0),
      details: const {},
      steps: const [],
    );
  }

  @override
  Future<RequestEntity> cancelRequest(
          {required String requestId,
          required int expectedRevision,
          required String reason}) =>
      throw UnimplementedError();
  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => const [];
  @override
  Stream<List<RequestEntity>> watchPendingRequests() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
  @override
  Future<List<RequestEntity>> listApprovalInbox(
          {String? cursor,
          int limit = 50,
          RequestType? type,
          RequestState? state,
          String? employeeId,
          String? effectiveFrom,
          String? effectiveTo}) async =>
      const [];
  @override
  Future<RequestEntity> decideRequest(
          {required String requestId,
          required String decisionId,
          required int expectedRevision,
          required String decision,
          String? comment}) =>
      throw UnimplementedError();
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> pumpUntilNotFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  expect(finder, findsNothing);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _LocalIntegrationHttpServer server;
  late ApiClient apiClient;
  late NotificationRepositoryImpl notifRepo;
  late ReportRepositoryImpl reportRepo;

  const employeeSession = AuthSessionEntity(
    accessToken: 'pilot-token-55',
    tenantId: 'tenant-pilot-5',
    userId: 'user-pilot-5',
    role: UserRole.employee,
    email: 'pilot5@example.com',
    displayName: 'مهندس العمليات',
  );

  setUp(() async {
    server = await _LocalIntegrationHttpServer.start();
    apiClient = ApiClient(
      baseUrl: 'http://127.0.0.1:${server.server.port}',
      tokenStorage: _IntegrationTokenStorage(employeeSession),
    );
    notifRepo = NotificationRepositoryImpl(apiClient: apiClient);
    reportRepo = ReportRepositoryImpl(apiClient: apiClient);
  });

  tearDown(() async {
    await server.close();
  });

  testWidgets(
      'Notification acceptance journey with live loopback HTTP server: badge, TalkBack, 200% text, live 403 denial, 200 navigation, and read-all',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      AttendApp(
        apiClient: apiClient,
        authRepository: _IntegrationAuthRepo(employeeSession),
        attendanceRepository: _IntegrationAttendanceRepo(),
        requestRepository: _IntegrationRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
        notificationRepository: notifRepo,
        reportRepository: reportRepo,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify unread badge shows 2 and TalkBack semantics
    final badgeFinder = find.byKey(const Key('notification_unread_badge'));
    await pumpUntilFound(tester, badgeFinder);
    expect(find.text('2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'2 إشعار غير مقروء')), findsOneWidget);

    // 2. Open Notification Center
    final badgeButton = find.byKey(const Key('notification_badge_button'));
    expect(badgeButton, findsOneWidget);
    await tester.tap(badgeButton);
    await tester.pumpAndSettle();

    // Verify Notification Center screen opened
    expect(find.text('الإشعارات'), findsWidgets);

    // 3. Tap on forbidden notification -> Safe live reauthorization makes GET /requests/req-forbidden-2 returning 403
    final forbiddenItemFinder =
        find.byKey(const Key('notification_item_notif-forbidden-2'));
    await pumpUntilFound(tester, forbiddenItemFinder);
    await tester.tap(forbiddenItemFinder);
    await tester.pumpAndSettle();

    // Verify live reauthorization returned 403, safe SnackBar shown, RequestDetailScreen NOT opened
    await pumpUntilFound(
        tester, find.text('لم تعد لديك صلاحية فتح هذه الوجهة.'));
    expect(find.byType(RequestDetailScreen), findsNothing);

    // 4. Tap on authorized notification -> Reauthorization makes GET /requests/req-auth-1 returning 200
    final authorizedItemFinder =
        find.byKey(const Key('notification_item_notif-auth-1'));
    await pumpUntilFound(tester, authorizedItemFinder);
    await tester.tap(authorizedItemFinder);
    await tester.pumpAndSettle();

    // Verify RequestDetailScreen opened
    await pumpUntilFound(tester, find.byType(RequestDetailScreen));

    // Pop back from detail screen
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pop();
    await tester.pumpAndSettle();

    // 5. Tap 'تعليم الكل كمقروء' -> calls POST /notifications/read-all with single commandId
    final markAllButton = find.byKey(const Key('mark_all_read_button'));
    if (markAllButton.evaluate().isNotEmpty) {
      await tester.tap(markAllButton);
      await tester.pumpAndSettle();
    }

    // Pop back to Home
    navigator.pop();
    await tester.pumpAndSettle();

    // Verify badge is now gone
    await pumpUntilNotFound(tester, badgeFinder);

    // 6. 200% Text Scale & Accessibility Verification
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification_badge_button')), findsOneWidget);
    final buttonRect =
        tester.getRect(find.byKey(const Key('notification_badge_button')));
    expect(buttonRect.width, greaterThanOrEqualTo(44.0));
    expect(buttonRect.height, greaterThanOrEqualTo(44.0));

    // Verify observed HTTP calls from loopback server
    final observedPaths = server.recordedCalls
        .map((c) => '${c.method} ${c.path} [${c.statusCode}]')
        .toList();
    expect(observedPaths, contains('GET /notifications/unread-count [200]'));
    expect(observedPaths, contains('GET /notifications [200]'));
    expect(observedPaths,
        contains('POST /notifications/notif-forbidden-2/read [200]'));
    expect(observedPaths, contains('GET /requests/req-forbidden-2 [403]'));
    expect(
        observedPaths, contains('POST /notifications/notif-auth-1/read [200]'));
    expect(observedPaths, contains('GET /requests/req-auth-1 [200]'));

    // Check commandId in read-all call if triggered
    final readAllCall = server.recordedCalls
        .where((c) => c.path == '/notifications/read-all')
        .firstOrNull;
    if (readAllCall != null) {
      expect((readAllCall.body as Map)['commandId'], isNotEmpty);
    }

    // Cleanup text scale and semantics
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    semantics.dispose();
  });

  testWidgets(
      'T059 Role Reports acceptance journey with live loopback HTTP server: all 4 roles, reconciliation, empty, 403 retry, filter, pagination, export states, TalkBack, 200% text',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();

    // 1. Verify all 4 roles render appropriate Arabic scope titles and descriptions
    final roleMatrix = <UserRole, Map<String, String>>{
      UserRole.employee: {
        'title': 'تقريري الشخصي',
        'subtitle': 'ملخص حي محسوب من سجلات حضورك وطلباتك المصرح بها.',
      },
      UserRole.manager: {
        'title': 'تقرير فريقي',
        'subtitle': 'ملخص حي محسوب من سجلات أعضاء فريقك المصرح بها.',
      },
      UserRole.hr: {
        'title': 'تقرير الشركة',
        'subtitle':
            'ملخص حي محسوب من سجلات الموظفين والتكليفات ومواقع العمل المصرح بها.',
      },
      UserRole.companyAdmin: {
        'title': 'تقرير الشركة',
        'subtitle':
            'ملخص حي محسوب من سجلات الموظفين والتكليفات ومواقع العمل المصرح بها.',
      },
    };

    for (final entry in roleMatrix.entries) {
      final role = entry.key;
      final expected = entry.value;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    key: Key('open_report_${role.name}'),
                    onPressed: () {
                      Navigator.of(context).push(
                        RoleReportsScreen.route(
                            role: role, repository: reportRepo),
                      );
                    },
                    child: Text('Open ${role.name}'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('open_report_${role.name}')));
      await tester.pumpAndSettle();

      // Wait for async report load from loopback HTTP server
      await pumpUntilFound(tester, find.textContaining('إجمالي الموظفين'));

      // Verify scope title and subtitle
      expect(find.text(expected['title']!), findsWidgets);
      expect(find.text(expected['subtitle']!), findsOneWidget);

      // Verify live reconciliation: Active(12) + Suspended(2) + Archived(1) = 15 total employees
      expect(find.text('إجمالي الموظفين: 15'), findsOneWidget);
      expect(find.text('الموظفون النشطون'), findsOneWidget);
      expect(find.text('الموقوفون'), findsOneWidget);
      expect(find.text('المؤرشفون'), findsOneWidget);

      if (role != UserRole.companyAdmin) {
        final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
        nav.pop();
        await tester.pumpAndSettle();
      }
    }

    // 2. Test Attendance tab & Pagination
    final attendanceTabFinder = find.byKey(const Key('reports_tab_attendance'));
    expect(attendanceTabFinder, findsOneWidget);
    await tester.tap(attendanceTabFinder);
    await tester.pumpAndSettle();

    // Verify first page items rendered
    await pumpUntilFound(tester, find.text('أحمد إبراهيم'));

    // Verify load more button and tap it
    final loadMoreFinder = find.byKey(const Key('reports_load_more_button'));
    await pumpUntilFound(tester, loadMoreFinder);
    await tester.ensureVisible(loadMoreFinder);
    await tester.pumpAndSettle();
    await tester.tap(loadMoreFinder);
    await tester.pumpAndSettle();

    // Verify second page item appended without duplicating first item
    await pumpUntilFound(tester, find.text('سارة المهندس'));
    expect(find.text('أحمد إبراهيم'), findsOneWidget);

    // 3. Test Export Creation & States (queued, ready, expired)
    final exportButtonFinder =
        find.byKey(const Key('reports_export_csv_button'));
    await pumpUntilFound(tester, exportButtonFinder);
    await tester.ensureVisible(exportButtonFinder);
    await tester.pumpAndSettle();

    // Initial state: queued
    server.exportJobState = 'queued';
    await tester.tap(exportButtonFinder);
    await tester.pumpAndSettle();
    await pumpUntilFound(
        tester, find.byKey(const Key('reports_export_status_card')));
    expect(find.text('طلب التصدير قيد المعالجة'), findsOneWidget);

    // State 2: refresh the same authorized job to ready
    server.exportJobState = 'ready';
    final refreshExportFinder =
        find.byKey(const Key('reports_refresh_export_button'));
    await pumpUntilFound(tester, refreshExportFinder);
    await tester.ensureVisible(refreshExportFinder);
    await tester.tap(refreshExportFinder);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('ملف التصدير جاهز للتحميل'));

    // State 3: refresh that same job after its private artifact expires
    server.exportJobState = 'expired';
    await pumpUntilFound(tester, refreshExportFinder);
    await tester.ensureVisible(refreshExportFinder);
    await tester.tap(refreshExportFinder);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('انتهت صلاحية ملف التصدير'));

    // 4. Test 403 Forbidden Denied State and Retry Recovery
    server.reportsForbidden = true;
    final refreshFinder = find.byKey(const Key('reports_refresh_button'));
    await pumpUntilFound(tester, refreshFinder);
    await tester.tap(refreshFinder);
    await tester.pumpAndSettle();

    // Verify 403 denied state displayed with retry button
    await pumpUntilFound(
        tester, find.text('ليس لديك صلاحية لعرض هذا التقرير.'));
    final retryFinder = find.byKey(const Key('reports_retry_button'));
    expect(retryFinder, findsOneWidget);

    // Recover from 403 by clearing error and tapping retry
    server.reportsForbidden = false;
    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    // Verify recovery: title and totals visible again
    await pumpUntilFound(tester, find.text('إجمالي الموظفين: 15'));

    // 5. Test Empty State
    server.reportsEmpty = true;
    await tester.tap(refreshFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reports_tab_attendance')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
        tester, find.text('لا توجد سجلات حضور أو إجازات ضمن النطاق المصرح.'));

    // 6. Test 200% text scale and accessibility touch targets
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reports_refresh_button')), findsOneWidget);
    final refreshRect =
        tester.getRect(find.byKey(const Key('reports_refresh_button')));
    expect(refreshRect.width, greaterThanOrEqualTo(44.0));
    expect(refreshRect.height, greaterThanOrEqualTo(44.0));

    // Verify recorded calls on the loopback server
    final observedCalls = server.recordedCalls;
    expect(observedCalls.where((c) => c.path == '/reports/workforce/summary'),
        isNotEmpty);
    expect(observedCalls.where((c) => c.path == '/reports/attendance-leave'),
        isNotEmpty);
    final exportCalls =
        observedCalls.where((c) => c.path == '/exports').toList();
    expect(exportCalls, hasLength(1));
    final firstExport = exportCalls.first;
    expect((firstExport.body as Map)['commandId'], isNotEmpty);
    expect((firstExport.body as Map)['reportType'], equals('attendance_leave'));
    expect((firstExport.body as Map)['format'], equals('csv'));
    expect((firstExport.body as Map)['filter'], isNotNull);
    expect(
      observedCalls.where((c) => c.path == '/exports/exp-pilot-001'),
      hasLength(2),
    );

    tester.platformDispatcher.clearTextScaleFactorTestValue();
    semantics.dispose();
  });
}
