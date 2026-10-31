import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/widgets/checkin_radar_button.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_screen.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_cubit.dart';

class MockAttendanceRepository implements AttendanceRepository {
  ShiftContextEntity stubbedContext;
  final List<AttendanceEventEntity> stubbedPendingEvents;
  final Future<AttendanceEventEntity> Function(AttendanceEventType eventType)?
      onSubmit;

  MockAttendanceRepository({
    required this.stubbedContext,
    this.stubbedPendingEvents = const [],
    this.onSubmit,
  });

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async => stubbedContext;

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    if (onSubmit != null) {
      return onSubmit!(eventType);
    }
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
      Stream.value(stubbedPendingEvents);

  @override
  Future<void> synchronizeOutbox() async {}
}

/// Stub RequestRepository that returns empty lists — satisfies the
/// EmployeeRequestsCubit that AttendanceScreen now creates.
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

class _StubMobileControlsRepo implements MobileControlsRepository {
  final MobileOperationalConfiguration configuration;

  _StubMobileControlsRepo([MobileOperationalConfiguration? configuration])
      : configuration = configuration ??
            MobileOperationalConfiguration.defaultRestrictive();

  @override
  MobileOperationalConfiguration get currentConfiguration => configuration;

  @override
  Future<MobileOperationalConfiguration> getConfiguration({
    bool forceRefresh = false,
  }) async =>
      configuration;

  @override
  Future<MobileControlEntry?> getControl(MobileControlKey key) async =>
      configuration.getControl(key);

  @override
  Future<bool> isActionAllowed(MobileControlKey key) async =>
      configuration.isActionAllowed(key);
}

Widget createTestApp(
  AttendanceCubit cubit, {
  MobileOperationalConfiguration? controlsConfiguration,
}) {
  final controlsCubit = MobileControlsCubit(
    repository: _StubMobileControlsRepo(controlsConfiguration),
  )..loadConfiguration();
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
          BlocProvider<MobileControlsCubit>.value(value: controlsCubit),
          BlocProvider<NotificationCubit>(
            create: (_) =>
                NotificationCubit(repository: _StubNotificationRepo()),
          ),
        ],
        child: const AttendanceScreen(),
      ),
    ),
  );
}

void main() {
  final baseShift = ShiftContextEntity(
    shiftInstanceId: 'shift-100',
    branchName: 'فرع القاهرة الرئيسي',
    shiftName: 'الوردية الصباحية',
    scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
    scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
    branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
    allowedRadiusMeters: 150.0,
    isCheckedIn: false,
  );

  group('AttendanceScreen UI States (T031, T035)', () {
    testWidgets('server completed state disables attendance action',
        (tester) async {
      final repo = MockAttendanceRepository(
          stubbedContext: baseShift.copyWith(isCompleted: true));
      final cubit = AttendanceCubit(repo);
      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();
      expect(find.text('اكتملت الوردية'), findsOneWidget);
      expect(find.text(AppStringsAr.checkIn), findsNothing);
      expect(
          tester
              .widget<CheckInRadarButton>(find.byType(CheckInRadarButton))
              .disabled,
          isTrue);
    });

    testWidgets(
        'current server shift stays actionable after another shift checkout',
        (tester) async {
      final checkout = AttendanceEventEntity(
        id: 'previous-event',
        eventType: AttendanceEventType.checkOut,
        capturedAt: DateTime.utc(2026, 9, 20),
        location: const GeoPoint(latitude: 30, longitude: 31),
        shiftInstanceId: 'previous-shift',
        status: AttendanceValidationStatus.accepted,
      );
      final repo = MockAttendanceRepository(
          stubbedContext: baseShift.copyWith(lastEvent: checkout));
      final cubit = AttendanceCubit(repo);
      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();
      expect(find.text(AppStringsAr.checkIn), findsOneWidget);
      expect(find.text('اكتملت الوردية'), findsNothing);
    });

    testWidgets('accepted event reason does not render a rejection banner',
        (tester) async {
      final acceptedCheckIn = AttendanceEventEntity(
        id: 'accepted-event',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.accepted,
        reasonCode: 'ACCEPTED',
      );
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift.copyWith(
          isCheckedIn: true,
          lastEvent: acceptedCheckIn,
        ),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.statusPresent), findsOneWidget);
      expect(
        find.text(AppFailureMapper.attendanceReasonMessage('ACCEPTED')),
        findsNothing,
      );
    });

    testWidgets('Renders Arabic RTL current shift card and check-in action',
        (tester) async {
      final repo = MockAttendanceRepository(stubbedContext: baseShift);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text('الوردية الصباحية'), findsOneWidget);
      expect(find.text('فرع القاهرة الرئيسي'), findsOneWidget);
      expect(find.text(AppStringsAr.checkIn), findsOneWidget);
      expect(find.text(AppStringsAr.statusNotStarted), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets(
        'Action click invokes submission flow and handles permission denied',
        (tester) async {
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift,
        onSubmit: (_) => throw Exception(
            'PermissionDeniedException: Location permission denied'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      // Tap Check-in
      await tester.tap(find.text(AppStringsAr.checkIn));
      await tester.pumpAndSettle();

      // Banner renders Arabic permission required message
      expect(
          find.text(AppStringsAr.locationPermissionRequired), findsOneWidget);
    });

    testWidgets('restricted attendance action never submits an event',
        (tester) async {
      var submissions = 0;
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift,
        onSubmit: (_) async {
          submissions++;
          throw StateError('must not submit while restricted');
        },
      );
      final cubit = AttendanceCubit(repo);
      final restrictedConfiguration = MobileOperationalConfiguration(
        version: 'test',
        issuedAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        controls: const {
          MobileControlKey.attendanceSubmit: MobileControlEntry(
            controlKey: MobileControlKey.attendanceSubmit,
            state: MobileControlState.restricted,
            outcomeCode: 'MOBILE_ACTION_RESTRICTED',
            messageAr: 'تم إيقاف الحضور للاختبار',
          ),
        },
        buildPolicy: const MobileBuildPolicy(
          minimumBuild: 1,
          recommendedBuild: 1,
        ),
        messages: const [],
        destinations: MobileAllowedDestination.values.toSet(),
      );

      await tester.pumpWidget(createTestApp(
        cubit,
        controlsConfiguration: restrictedConfiguration,
      ));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.checkIn));
      await tester.pumpAndSettle();

      expect(submissions, isZero);
      expect(find.text('الإجراء متوقف مؤقتاً'), findsOneWidget);
      expect(find.text('تم إيقاف الحضور للاختبار'), findsOneWidget);
    });

    testWidgets(
        'Handles permanently denied location permission with dedicated Arabic instruction',
        (tester) async {
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift,
        onSubmit: (_) => throw Exception(
            'PermissionDeniedForever: permission permanently denied'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.checkIn));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.locationPermissionPermanentlyDenied),
          findsOneWidget);
    });

    testWidgets(
        'Handles disabled GPS location service with Arabic instruction to enable',
        (tester) async {
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift,
        onSubmit: (_) => throw Exception(
            'LocationServiceDisabledException: GPS is disabled'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.checkIn));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.locationServiceDisabled), findsOneWidget);
    });

    testWidgets('Handles location timeout with Arabic retry message',
        (tester) async {
      final repo = MockAttendanceRepository(
        stubbedContext: baseShift,
        onSubmit: (_) =>
            throw Exception('TimeoutException after 10000ms: location timeout'),
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsAr.checkIn));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.locationTimeout), findsOneWidget);
    });

    testWidgets('Renders pending sync badge and offline outbox count',
        (tester) async {
      final pendingEvt = AttendanceEventEntity(
        id: 'offline-evt-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.pendingSync,
      );

      final shiftWithPending = baseShift.copyWith(lastEvent: pendingEvt);
      final repo = MockAttendanceRepository(
        stubbedContext: shiftWithPending,
        stubbedPendingEvents: [pendingEvt],
      );
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.statusPendingSync), findsOneWidget);
      expect(find.textContaining('${AppStringsAr.statusPendingSync} (1)'),
          findsOneWidget);
    });

    testWidgets('Renders pending review status badge', (tester) async {
      final reviewEvt = AttendanceEventEntity(
        id: 'review-evt-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.pendingReview,
      );

      final shiftWithReview = baseShift.copyWith(lastEvent: reviewEvt);
      final repo = MockAttendanceRepository(stubbedContext: shiftWithReview);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.statusPendingReview), findsOneWidget);
    });

    testWidgets(
        'Renders rejection status badge and reason banner (out of radius)',
        (tester) async {
      final rejectedEvt = AttendanceEventEntity(
        id: 'rejected-evt-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.rejected,
        reasonCode: 'LOCATION_OUT_OF_RADIUS',
      );

      final shiftWithRejection = baseShift.copyWith(lastEvent: rejectedEvt);
      final repo = MockAttendanceRepository(stubbedContext: shiftWithRejection);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.statusRejected), findsOneWidget);
      expect(find.text(AppStringsAr.reasonOutOfRadius), findsOneWidget);
    });

    testWidgets('Renders conflict status badge and duplicate banner',
        (tester) async {
      final conflictEvt = AttendanceEventEntity(
        id: 'conflict-evt-1',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 9, 20, 8, 0),
        location: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
        shiftInstanceId: 'shift-100',
        status: AttendanceValidationStatus.conflict,
        reasonCode: 'CONFLICT_DUPLICATE',
      );

      final shiftWithConflict = baseShift.copyWith(lastEvent: conflictEvt);
      final repo = MockAttendanceRepository(stubbedContext: shiftWithConflict);
      final cubit = AttendanceCubit(repo);

      await tester.pumpWidget(createTestApp(cubit));
      await cubit.loadShiftContext();
      await tester.pumpAndSettle();

      // Conflict badge and banner
      expect(find.text(AppStringsAr.statusConflict), findsWidgets);
    });
  });
}
