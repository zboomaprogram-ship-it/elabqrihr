import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/main.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/widgets/notification_badge_icon.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import '../test_doubles/fake_dynamic_request_repo.dart';
import '../test_doubles/stub_profile_dashboard_repos.dart';

class _TestAuthRepo implements AuthRepository {
  final AuthSessionEntity? session;
  _TestAuthRepo([this.session]);

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

class _TestAttendanceRepo implements AttendanceRepository {
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

class _TestRequestRepo implements RequestRepository {
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

void main() {
  group('Production Composition Root', () {
    testWidgets(
        'AttendApp resolves NotificationRepository and ReportRepository without fallbacks',
        (tester) async {
      const authenticatedSession = AuthSessionEntity(
        accessToken: 'valid-token',
        tenantId: 'tenant-prod',
        userId: 'user-prod',
        role: UserRole.employee,
        email: 'employee@attend.app',
        displayName: 'الموظف التجريبي',
      );

      await tester.pumpWidget(
        AttendApp(
          authRepository: _TestAuthRepo(authenticatedSession),
          attendanceRepository: _TestAttendanceRepo(),
          requestRepository: _TestRequestRepo(),
          dynamicRequestRepository: FakeDynamicRequestRepo(),
          profileRepository: StubProfileRepository(),
          dashboardRepository: StubDashboardRepository(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));

      // Verifies production repository providers exist in tree
      final notifRepo = context.read<NotificationRepository>();
      final reportRepo = context.read<ReportRepository>();
      final notifCubit = context.read<NotificationCubit>();

      expect(notifRepo, isNotNull);
      expect(reportRepo, isNotNull);
      expect(notifCubit, isNotNull);

      // Verifies notification badge is present and wired to Cubit
      expect(find.byType(NotificationBadgeIcon), findsOneWidget);
    });

    testWidgets(
        'NotificationBadgeIcon throws ProviderNotFoundException when Cubit is absent',
        (tester) async {
      // Verifies that silent error-swallowing has been removed
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NotificationBadgeIcon(),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error, isA<ProviderNotFoundException>());
    });
  });
}
