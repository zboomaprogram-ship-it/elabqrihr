import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import '../test/test_doubles/fake_dynamic_request_repo.dart';
import '../test/test_doubles/stub_profile_dashboard_repos.dart';
import 'package:attend_mobile/main.dart';

class _TestAuthRepo implements AuthRepository {
  final AuthSessionEntity? initialSession;
  _TestAuthRepo([this.initialSession]);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => initialSession;
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'Pilot brand journey displays العبقري HR, navigation tabs, and pilot guidance sheet',
      (WidgetTester tester) async {
    const employeeSession = AuthSessionEntity(
      accessToken: 'pilot-token',
      tenantId: 'tenant-pilot',
      userId: 'user-pilot',
      role: UserRole.employee,
      email: 'pilot@example.com',
      displayName: 'مستخدم تجريبي',
    );

    await tester.pumpWidget(
      AttendApp(
        authRepository: _TestAuthRepo(employeeSession),
        attendanceRepository: _TestAttendanceRepo(),
        requestRepository: _TestRequestRepo(),
        dynamicRequestRepository: FakeDynamicRequestRepo(),
        profileRepository: StubProfileRepository(),
        dashboardRepository: StubDashboardRepository(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify brand displays العبقري HR
    expect(find.text(AppStringsAr.appName), findsWidgets);

    // Verify navigation tabs
    expect(find.text(AppStringsAr.attendanceTab), findsOneWidget);
    expect(find.text(AppStringsAr.requestsTab), findsOneWidget);

    // Tap on pilot guidance action icon
    final infoButton = find.byKey(const Key('pilot_guidance_button'));
    expect(infoButton, findsOneWidget);
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    // Verify guidance sheet displays Arabic pilot guidance
    expect(find.text(AppStringsAr.pilotGuidanceTitle), findsOneWidget);
    expect(find.text(AppStringsAr.pilotLocationNotice), findsOneWidget);
    expect(find.text(AppStringsAr.pilotOfflineNotice), findsOneWidget);
    expect(find.text(AppStringsAr.pilotPrivacyNotice), findsOneWidget);
  });
}
