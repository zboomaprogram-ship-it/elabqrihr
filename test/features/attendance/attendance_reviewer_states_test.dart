import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_screen.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';

class _MockAttendanceRepository implements AttendanceRepository {
  final Future<ShiftContextEntity> Function()? onGetContext;
  final ShiftContextEntity? stubbedContext;

  _MockAttendanceRepository({this.stubbedContext, this.onGetContext});

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async {
    if (onGetContext != null) {
      return onGetContext!();
    }
    if (stubbedContext != null) {
      return stubbedContext!;
    }
    throw Exception('SHIFT_NOT_FOUND');
  }

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    return AttendanceEventEntity(
      id: 'mock-evt-1',
      eventType: eventType,
      capturedAt: capturedAt ?? DateTime.utc(2026, 9, 20, 8, 0),
      location:
          location ?? const GeoPoint(latitude: 30.0444, longitude: 31.2357),
      shiftInstanceId: shiftInstanceId,
      status: AttendanceValidationStatus.accepted,
    );
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() =>
      Stream.value(const []);

  @override
  Future<void> synchronizeOutbox() async {}
}

class _StubRequestRepo implements RequestRepository {
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
  Future<RequestEntity> getRequestDetail(String requestId) =>
      throw UnimplementedError();
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

class _StubNotificationRepo implements NotificationRepository {
  @override
  Future<NotificationEntity?> getNotification(String notificationId) async =>
      null;

  @override
  Future<NotificationPageEntity> listNotifications(
          {String? cursor, int limit = 50}) async =>
      const NotificationPageEntity(items: [], nextCursor: null);
  @override
  Future<int> getUnreadCount() async => 0;
  @override
  Future<NotificationEntity> markAsRead(String notificationId) =>
      throw UnimplementedError();
  @override
  Future<int> markAllAsRead({String? commandId, DateTime? before}) async => 0;
  @override
  Future<ReauthorizationResult> reauthorizeDestination(
    NotificationDestinationKind kind,
    String destinationId,
  ) async =>
      ReauthorizationResult.authorized;
}

Widget _buildTestHarness({
  required AttendanceCubit cubit,
  UserRole? userRole,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RequestRepository>.value(value: _StubRequestRepo()),
        RepositoryProvider<NotificationRepository>.value(
            value: _StubNotificationRepo()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AttendanceCubit>.value(value: cubit),
          BlocProvider<NotificationCubit>(
            create: (_) =>
                NotificationCubit(repository: _StubNotificationRepo()),
          ),
        ],
        child: AttendanceScreen(userRole: userRole),
      ),
    ),
  );
}

void main() {
  final baseShift = ShiftContextEntity(
    shiftInstanceId: 'shift-100',
    branchName: 'فرع الرياض الرئيسي',
    shiftName: 'وردية المراجعة',
    scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
    scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
    branchLocation: const GeoPoint(latitude: 24.7136, longitude: 46.6753),
    allowedRadiusMeters: 100.0,
    isCheckedIn: false,
  );

  group('Truthful Reviewer States & Clean Attendance Rendering (T023)', () {
    testWidgets(
        'Missing Shift Handling: renders polite empty-state card with calendar icon and no raw errors',
        (tester) async {
      final repo = _MockAttendanceRepository(
        onGetContext: () =>
            throw Exception('SHIFT_NOT_FOUND: No shift scheduled'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      // Renders polite Arabic empty state
      expect(find.text('لا توجد وردية عمل حالياً'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byKey(const Key('attendance_refresh_shift_btn')),
          findsOneWidget);

      // Ensures zero raw exception strings or red error icons leak
      expect(find.textContaining('SHIFT_NOT_FOUND'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
        'Missing Shift Handling: handles 404 / NO_ACTIVE_SHIFT gracefully',
        (tester) async {
      final repo = _MockAttendanceRepository(
        onGetContext: () => throw Exception('404 Not Found: NO_ACTIVE_SHIFT'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text('لا توجد وردية عمل حالياً'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.textContaining('NO_ACTIVE_SHIFT'), findsNothing);
      expect(find.textContaining('404'), findsNothing);
    });

    testWidgets(
        'Outside Geofence Handling: renders clean explanation without raw coordinates or server error dumps',
        (tester) async {
      final geofenceRejectedEvt = AttendanceEventEntity(
        id: 'evt-geofence-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 30),
        location: const GeoPoint(latitude: 25.0000, longitude: 47.0000),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'OUTSIDE_GEOFENCE',
      );

      final shiftWithGeofenceRejection =
          baseShift.copyWith(lastEvent: geofenceRejectedEvt);
      final repo =
          _MockAttendanceRepository(stubbedContext: shiftWithGeofenceRejection);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      // Displays polite, explicit Arabic explanation requiring physical presence
      expect(
        find.textContaining(
            'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);

      // Verifies zero technical coordinates or raw codes leak into the UI
      expect(find.textContaining('OUTSIDE_GEOFENCE'), findsNothing);
      expect(find.textContaining('25.0000'), findsNothing);
      expect(find.textContaining('47.0000'), findsNothing);
    });

    testWidgets(
        'Outside Geofence Handling: handles GEOFENCE_REJECTED code properly',
        (tester) async {
      final geofenceRejectedEvt = AttendanceEventEntity(
        id: 'evt-geofence-2',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 30),
        location: const GeoPoint(latitude: 25.0000, longitude: 47.0000),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'GEOFENCE_REJECTED',
      );

      final shiftWithGeofenceRejection =
          baseShift.copyWith(lastEvent: geofenceRejectedEvt);
      final repo =
          _MockAttendanceRepository(stubbedContext: shiftWithGeofenceRejection);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.'),
        findsOneWidget,
      );
      expect(find.textContaining('GEOFENCE_REJECTED'), findsNothing);
    });

    testWidgets(
        'Role-Forbidden Notice: renders respectful administrative card for company admin persona',
        (tester) async {
      final repo = _MockAttendanceRepository(stubbedContext: baseShift);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(
        cubit: cubit,
        userRole: UserRole.companyAdmin,
      ));
      await tester.pumpAndSettle();

      // Shows respectful role card
      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
      expect(
        find.textContaining('تسجيل الحضور الذاتي مخصص للموظفين التشغيليين'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);
      expect(
          find.textContaining(
              'أدوات الإشراف والاعتماد متاحة في التبويبات الأخرى'),
          findsOneWidget);

      // Ensures zero error icons or 403 Forbidden leaks
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('Forbidden'), findsNothing);
    });

    testWidgets(
        'Role-Forbidden Notice: handles 403 / FORBIDDEN failure gracefully',
        (tester) async {
      final repo = _MockAttendanceRepository(
        onGetContext: () => throw Exception('403 Forbidden: ROLE_FORBIDDEN'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text('حساب إدارة المنشأة'), findsOneWidget);
      expect(
        find.textContaining('تسجيل الحضور الذاتي مخصص للموظفين التشغيليين'),
        findsOneWidget,
      );
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('ROLE_FORBIDDEN'), findsNothing);
    });

    testWidgets(
        'Sanitized Fallback: unexpected raw errors map cleanly through AppFailureMapper without leakage',
        (tester) async {
      final repo = _MockAttendanceRepository(
        onGetContext: () => throw Exception(
            'DioException [bad response]: status code 500 at package:dio/src/dio.dart:123'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(_buildTestHarness(cubit: cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      // Expect polite Arabic server message
      expect(find.textContaining('حدث خطأ'), findsOneWidget);

      // Absolutely no raw DioException or stack trace strings in the UI
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('bad response'), findsNothing);
      expect(find.textContaining('package:dio'), findsNothing);
    });

    test(
        'Sanitized Fallback: resolveErrorText maps all raw exception categories to polite Arabic',
        () {
      expect(
        AttendanceScreen.resolveErrorText(
            'DioException [bad response]: status code 500 at foo.dart'),
        'حدث خطأ في خدمة الخادم. يرجى المحاولة لاحقاً.',
      );
      expect(
        AttendanceScreen.resolveErrorText(
            'SocketException: OS Error: Connection refused, errno = 111'),
        'تعذر الاتصال بالخادم. يرجى التأكد من تشغيل الخادم وإعدادات الاتصال.',
      );
      expect(
        AttendanceScreen.resolveErrorText('403 Forbidden: role restricted'),
        'تسجيل الحضور الذاتي مخصص للموظفين التشغيليين.',
      );
      expect(
        AttendanceScreen.resolveErrorText(
            'OUTSIDE_GEOFENCE: employee at 24.7, 46.7 outside 100m radius'),
        'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.',
      );
      expect(
        AttendanceScreen.resolveErrorText(
            'SHIFT_NOT_FOUND: no scheduled shifts active'),
        'لا توجد وردية عمل حالياً مسندة إليك.',
      );
      expect(
        AttendanceScreen.resolveErrorText(
            'UnknownTechnicalException: internal stack at line 99'),
        'حدث خطأ غير متوقع في الخادم. يرجى المحاولة لاحقاً أو إبلاغ الدعم الفني.',
      );
    });
  });
}
