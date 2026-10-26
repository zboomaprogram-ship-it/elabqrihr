import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/main.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/data/notification_repository_impl.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import '../../test_doubles/fake_dynamic_request_repo.dart';
import '../../test_doubles/stub_profile_dashboard_repos.dart';

class _InMemoryTokenStorage extends TokenStorage {
  AuthSessionEntity? _session;

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

class _RouteTestAuthRepo implements AuthRepository {
  AuthSessionEntity? session;
  _RouteTestAuthRepo([this.session]);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => session;
  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async =>
      session!;
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSessionEntity> refreshSession() async => session!;
  @override
  Future<void> requestPasswordReset({
    required String email,
    required String tenantSlug,
  }) async {}
  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {}
}

class _RouteTestAttendanceRepo implements AttendanceRepository {
  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    return ShiftContextEntity(
      shiftInstanceId: 'shift-1',
      branchName: 'Cairo HQ',
      shiftName: 'Morning Shift',
      scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
      scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
      branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      allowedRadiusMeters: 150.0,
      isCheckedIn: false,
    );
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async =>
      throw UnimplementedError();
  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
}

class _RouteTestRequestRepo implements RequestRepository {
  @override
  Future<RequestEntity> submitRequest({
    required String requestId,
    required RequestType type,
    required Map<String, dynamic> payload,
  }) async =>
      throw UnimplementedError();
  @override
  Future<List<RequestEntity>> listMyRequests({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
  }) async =>
      const [];
  @override
  Future<RequestEntity> getRequestDetail(String requestId) async =>
      throw UnimplementedError();
  @override
  Future<RequestEntity> cancelRequest({
    required String requestId,
    required int expectedRevision,
    required String reason,
  }) async =>
      throw UnimplementedError();
  @override
  Future<List<LeaveBalanceEntity>> getMyLeaveBalances() async => const [];
  @override
  Stream<List<RequestEntity>> watchPendingRequests() => Stream.value([]);
  @override
  Future<void> synchronizeOutbox() async {}
  @override
  Future<List<RequestEntity>> listApprovalInbox({
    String? cursor,
    int limit = 50,
    RequestType? type,
    RequestState? state,
    String? employeeId,
    String? effectiveFrom,
    String? effectiveTo,
  }) async =>
      const [];
  @override
  Future<RequestEntity> decideRequest({
    required String requestId,
    required String decisionId,
    required int expectedRevision,
    required String decision,
    String? comment,
  }) async =>
      throw UnimplementedError();
}

class _RouteTestNotificationRepo implements NotificationRepository {
  List<NotificationEntity> notifications;
  int unreadCount;
  bool shouldThrowTimeout;
  bool shouldThrow401Once = false;

  _RouteTestNotificationRepo({
    this.notifications = const [],
    this.unreadCount = 0,
    this.shouldThrowTimeout = false,
  });

  @override
  Future<NotificationPageEntity> listNotifications({
    String? cursor,
    int limit = 50,
  }) async {
    if (shouldThrowTimeout) {
      throw Exception('Connection timeout');
    }
    if (shouldThrow401Once) {
      shouldThrow401Once = false;
      throw Exception('401 Unauthorized');
    }
    return NotificationPageEntity(
      items: notifications,
      nextCursor: null,
    );
  }

  @override
  Future<NotificationEntity?> getNotification(String notificationId) async {
    return notifications.where((n) => n.id == notificationId).firstOrNull;
  }

  @override
  Future<int> getUnreadCount() async {
    if (shouldThrowTimeout) {
      throw Exception('Connection timeout');
    }
    return unreadCount;
  }

  @override
  Future<NotificationEntity> markAsRead(String notificationId) async {
    final item = notifications.firstWhere((n) => n.id == notificationId);
    final readItem = item.copyWith(
      readState: NotificationReadState.read,
      readAt: DateTime.now(),
    );
    unreadCount = (unreadCount > 0) ? unreadCount - 1 : 0;
    return readItem;
  }

  @override
  Future<int> markAllAsRead({String? commandId, DateTime? before}) async {
    unreadCount = 0;
    return notifications.length;
  }

  @override
  Future<ReauthorizationResult> reauthorizeDestination(
    NotificationDestinationKind kind,
    String destinationId,
  ) async {
    return ReauthorizationResult.authorized;
  }
}

void main() {
  const testSession = AuthSessionEntity(
    accessToken: 'test-token',
    tenantId: 'tenant-demo',
    userId: 'user-demo-1',
    role: UserRole.employee,
    email: 'reviewer.employee@elabqrihr.com',
    displayName: 'موظف تجريبي',
  );

  final sampleNotification = NotificationEntity(
    id: 'notif-101',
    kind: 'company_announcement',
    titleKey: 'notification.company_announcement.title',
    bodyKey: 'notification.company_announcement.body',
    destinationKind: NotificationDestinationKind.announcement,
    destinationId: 'ann-1',
    readState: NotificationReadState.unread,
    createdAt: DateTime.utc(2026, 10, 20, 10, 0),
  );

  Widget createTestApp({
    required NotificationRepository notificationRepo,
    AuthRepository? authRepo,
  }) {
    return AttendApp(
      authRepository: authRepo ?? _RouteTestAuthRepo(testSession),
      attendanceRepository: _RouteTestAttendanceRepo(),
      requestRepository: _RouteTestRequestRepo(),
      dynamicRequestRepository: FakeDynamicRequestRepo(),
      profileRepository: StubProfileRepository(),
      dashboardRepository: StubDashboardRepository(),
      notificationRepository: notificationRepo,
    );
  }

  group('Notification Center Route Composition Tests', () {
    testWidgets(
      'tapping notification_badge_button opens NotificationCenterScreen and remains visible after settled frames',
      (tester) async {
        final notifRepo = _RouteTestNotificationRepo(
          notifications: [sampleNotification],
          unreadCount: 1,
        );

        await tester.pumpWidget(createTestApp(notificationRepo: notifRepo));
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Verify Home screen is visible with the notification badge
        final badgeButton = find.byKey(const Key('notification_badge_button'));
        expect(badgeButton, findsOneWidget);

        // 2. Tap notification bell
        await tester.tap(badgeButton);
        await tester.pump();
        await tester.pumpAndSettle();

        // 3. Assert NotificationCenterScreen title is visible and remains visible
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('إعلان إداري رسمي'), findsOneWidget);

        // Extra frame settlement must not pop or replace the route
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationCenterScreen route remains visible when unread count refreshes or AuthCubit re-emits',
      (tester) async {
        final notifRepo = _RouteTestNotificationRepo(
          notifications: [sampleNotification],
          unreadCount: 1,
        );

        await tester.pumpWidget(createTestApp(notificationRepo: notifRepo));
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap notification bell to open screen
        await tester.tap(find.byKey(const Key('notification_badge_button')));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterScreen), findsOneWidget);

        // Trigger unread count refresh
        final context = tester.element(find.byType(NotificationCenterScreen));
        final notifCubit = context.read<NotificationCubit>();
        await notifCubit.refreshUnreadCount();
        await tester.pumpAndSettle();

        // Screen MUST remain visible, not pop to prior tab
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);

        // Simulate unrelated Authenticated emission on AuthCubit (e.g. token refresh)
        final authCubit = context.read<AuthCubit>();
        authCubit.emit(const Authenticated(AuthSessionEntity(
          accessToken: 'new-token',
          tenantId: 'tenant-demo',
          userId: 'user-demo-1',
          role: UserRole.employee,
          email: 'reviewer.employee@elabqrihr.com',
          displayName: 'موظف تجريبي',
        )));
        await tester.pumpAndSettle();

        // Screen MUST still remain visible after AuthState emission
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationCenterScreen route remains visible during full Authenticated -> AuthLoading -> Authenticated refresh lifecycle',
      (tester) async {
        final notifRepo = _RouteTestNotificationRepo(
          notifications: [sampleNotification],
          unreadCount: 1,
        );

        await tester.pumpWidget(createTestApp(notificationRepo: notifRepo));
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Open NotificationCenterScreen from shell
        await tester.tap(find.byKey(const Key('notification_badge_button')));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);

        // 2. Transition to AuthLoading (simulating token refresh or background session check)
        final context = tester.element(find.byType(NotificationCenterScreen));
        final authCubit = context.read<AuthCubit>();
        authCubit.emit(const AuthLoading());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Screen MUST remain visible throughout, not flash blank or show LoginScreen or pop
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);

        // 3. Transition back to Authenticated with refreshed access token
        authCubit.emit(const Authenticated(AuthSessionEntity(
          accessToken: 'refreshed-token',
          tenantId: 'tenant-demo',
          userId: 'user-demo-1',
          role: UserRole.employee,
          email: 'reviewer.employee@elabqrihr.com',
          displayName: 'موظف تجريبي',
        )));
        await tester.pumpAndSettle();

        // Screen MUST still remain visible after returning to Authenticated
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('إعلان إداري رسمي'), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationCenterScreen shows truthful error and retry button on timeout response rather than blank flash',
      (tester) async {
        final notifRepo = _RouteTestNotificationRepo(
          shouldThrowTimeout: true,
          unreadCount: 5,
        );

        await tester.pumpWidget(createTestApp(notificationRepo: notifRepo));
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap notification bell
        await tester.tap(find.byKey(const Key('notification_badge_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        // Screen remains visible with truthful error message and retry button
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('تعذر تحميل الإشعارات. حاول مرة أخرى.'), findsOneWidget);
        expect(find.byKey(const Key('notification_retry_button')), findsOneWidget);

        // Verify route is stable and not blank or popped
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationCenterScreen route transparently recovers through real ApiClient 401 token refresh interceptor',
      (tester) async {
        const initialSession = AuthSessionEntity(
          accessToken: 'stale-token',
          refreshToken: 'valid-refresh-token',
          tenantId: 'tenant-demo',
          userId: 'user-demo-1',
          role: UserRole.employee,
          email: 'reviewer.employee@elabqrihr.com',
          displayName: 'موظف تجريبي',
        );

        var notificationRequestCount = 0;
        var refreshRequestCount = 0;

        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.httpClientAdapter = _MockHttpAdapter((options) async {
          if (options.path.endsWith('/notifications/unread-count')) {
            return ResponseBody.fromString(
              jsonEncode({'count': 1}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          if (options.path.endsWith('/notifications')) {
            notificationRequestCount++;
            final authHeader = options.headers['Authorization'] as String?;
            if (authHeader == 'Bearer stale-token') {
              return ResponseBody.fromString(
                jsonEncode({'code': 'UNAUTHORIZED', 'message': 'Token expired'}),
                401,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
            if (authHeader == 'Bearer refreshed-token') {
              return ResponseBody.fromString(
                jsonEncode({
                  'items': [
                    {
                      'id': 'notif-101',
                      'kind': 'company_announcement',
                      'titleKey': 'notification.company_announcement.title',
                      'bodyKey': 'notification.company_announcement.body',
                      'destinationKind': 'announcement',
                      'destinationId': 'ann-1',
                      'readState': 'unread',
                      'createdAt': '2026-10-20T10:00:00.000Z',
                    }
                  ],
                  'nextCursor': null,
                }),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }
          }

          if (options.path.endsWith('/auth/refresh')) {
            refreshRequestCount++;
            return ResponseBody.fromString(
              jsonEncode({
                'accessToken': 'refreshed-token',
                'refreshToken': 'new-refresh-token',
                'user': {
                  'id': 'user-demo-1',
                  'email': 'reviewer.employee@elabqrihr.com',
                  'displayName': 'موظف تجريبي',
                },
                'membership': {
                  'tenantId': 'tenant-demo',
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

        final tokenStorage = _InMemoryTokenStorage(initialSession: initialSession);
        final apiClient = ApiClient(
          baseUrl: 'http://test',
          tokenStorage: tokenStorage,
          dio: dio,
        );
        final notifRepo = NotificationRepositoryImpl(apiClient: apiClient);

        await tester.pumpWidget(createTestApp(
          notificationRepo: notifRepo,
          authRepo: _RouteTestAuthRepo(initialSession),
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Open NotificationCenterScreen by tapping the badge button
        await tester.tap(find.byKey(const Key('notification_badge_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        // 2. ApiClient automatically handled 401 via refresh and retried
        expect(notificationRequestCount, equals(2));
        expect(refreshRequestCount, equals(1));

        // 3. NotificationCenterScreen is open, stable, and displays data without blank screen or error
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.text('إعلان إداري رسمي'), findsOneWidget);

        final updatedSession = await tokenStorage.getSession();
        expect(updatedSession?.accessToken, equals('refreshed-token'));
      },
    );

    testWidgets(
      'NotificationCenterScreen displays truthful retryable error when repository throws unauthorized/error and recovers on user retry',
      (tester) async {
        final notifRepo = _RouteTestNotificationRepo(
          notifications: [sampleNotification],
          unreadCount: 1,
        );

        await tester.pumpWidget(createTestApp(notificationRepo: notifRepo));
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Open NotificationCenterScreen
        await tester.tap(find.byKey(const Key('notification_badge_button')));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(NotificationCenterScreen), findsOneWidget);

        // 2. Trigger an unrecoverable 401 error on reload (e.g. refresh token revoked)
        notifRepo.shouldThrow401Once = true;
        final context = tester.element(find.byType(NotificationCenterScreen));
        await context.read<NotificationCubit>().loadNotifications();
        await tester.pumpAndSettle();

        // Screen remains visible with error and retry button rather than blank or popping
        expect(find.byType(NotificationCenterScreen), findsOneWidget);
        expect(find.text('الإشعارات'), findsOneWidget);
        expect(find.byKey(const Key('notification_retry_button')), findsOneWidget);

        // 3. Tap retry button after error resolved
        await tester.tap(find.byKey(const Key('notification_retry_button')));
        await tester.pump();
        await tester.pumpAndSettle();

        // Items now display successfully
        expect(find.text('إعلان إداري رسمي'), findsOneWidget);
      },
    );
  });
}
