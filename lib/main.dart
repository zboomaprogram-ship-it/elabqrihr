import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/diagnostics/mobile_diagnostics.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/localization/language_cubit.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/location/location_service.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/data/attendance_repository_impl.dart';
import 'package:attend_mobile/features/attendance/data/attendance_sync_coordinator.dart';
import 'package:attend_mobile/features/attendance/data/attendance_evidence_service.dart';
import 'package:attend_mobile/features/attendance/data/android_attendance_trust_bridge.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_repository.dart';
import 'package:attend_mobile/features/attendance/data/manual_attendance_repository_impl.dart';
import 'package:attend_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/screens/password_recovery_screen.dart';
import 'package:attend_mobile/features/auth/presentation/widgets/auth_gate.dart';
import 'package:attend_mobile/features/requests/data/request_repository_impl.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/profile/data/profile_repository_impl.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_repository_impl.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_sync_coordinator.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/notifications/data/notification_repository_impl.dart';
import 'package:attend_mobile/features/notifications/data/push_notification_service.dart';
import 'package:attend_mobile/features/notifications/data/push_registration_coordinator.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/reports/data/report_repository_impl.dart';
import 'package:attend_mobile/features/reports/domain/report_repository.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/data/payslip_repository_impl.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/data/advance_repository_impl.dart';
import 'package:attend_mobile/features/leave_quotas/domain/leave_quota_repository.dart';
import 'package:attend_mobile/features/leave_quotas/data/leave_quota_repository_impl.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_repository.dart';
import 'package:attend_mobile/features/final_settlement/data/final_settlement_repository_impl.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_repository.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_scheduler.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_coordinator.dart';
import 'package:attend_mobile/features/attendance_reminders/data/attendance_reminder_repository_impl.dart';
import 'package:attend_mobile/features/attendance_reminders/data/local_attendance_reminder_scheduler.dart';
import 'package:attend_mobile/features/attendance_reminders/data/attendance_reminder_coordinator.dart';
import 'package:attend_mobile/features/mobile_controls/data/mobile_controls_cache_impl.dart';
import 'package:attend_mobile/features/mobile_controls/data/mobile_controls_repository_impl.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attend_mobile/features/notifications/data/qa_push_notification_service.dart';

String resolveDefaultApiBaseUrl() {
  const envUrl = String.fromEnvironment('API_BASE_URL');
  if (envUrl.isNotEmpty) return envUrl;
  if (kReleaseMode) {
    return 'https://api.abqrihr.systems/api/v1';
  }
  final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
  return 'http://$host:3000/api/v1';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!ApiClient.qaSandboxBuild) await MobileDiagnostics.initialize();
  tz.initializeTimeZones();
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  final tokenStorage = TokenStorage();
  final packageInfo = await PackageInfo.fromPlatform();
  final installedBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
  final outbox = await AppDriftDatabase.open(tokenStorage: tokenStorage);
  final locationService = GeolocatorLocationService();

  // In release mode, the app is strictly locked to the production HTTPS domain.
  // Stored custom URLs from local debug environments are ignored.
  final String initialBaseUrl;
  if (kReleaseMode) {
    initialBaseUrl = resolveDefaultApiBaseUrl();
  } else {
    final savedBaseUrl = await tokenStorage.getBaseUrl();
    initialBaseUrl = (savedBaseUrl != null && savedBaseUrl.isNotEmpty)
        ? savedBaseUrl
        : resolveDefaultApiBaseUrl();
  }

  final apiClient = ApiClient(
    baseUrl: initialBaseUrl,
    tokenStorage: tokenStorage,
  );
  final mobileControlsRepository = MobileControlsRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    cache: const MobileControlsCacheImpl(),
  );
  final attendanceTrustBridge = AndroidAttendanceTrustBridge();

  final reminderScheduler = LocalAttendanceReminderScheduler();
  final reminderRepository = AttendanceReminderRepositoryImpl(
    apiClient: apiClient,
    secureStorage: const FlutterSecureStorage(),
  );
  final reminderCoordinator = AttendanceReminderCoordinator(
    repository: reminderRepository,
    scheduler: reminderScheduler,
  );

  final authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    onLogout: () async {
      await reminderCoordinator.onSignOutOrTenantSwitch();
    },
  );

  final attendanceEvidenceService = AttendanceEvidenceService(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    installationIdentity: attendanceTrustBridge,
    deviceAttestation: attendanceTrustBridge,
  );

  final PushNotificationPort pushNotificationService = ApiClient.qaSandboxBuild
      ? const QaPushNotificationService()
      : FirebasePushNotificationService();
  final pushRegistrationCoordinator = PushRegistrationCoordinator(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    pushNotifications: pushNotificationService,
    installationEvidence: attendanceEvidenceService,
  );

  final attendanceRepository = AttendanceRepositoryImpl(
    apiClient: apiClient,
    outbox: outbox,
    tokenStorage: tokenStorage,
    locationService: locationService,
    evidenceService: attendanceEvidenceService,
    pushRegistrationCoordinator: pushRegistrationCoordinator,
  );
  final attendanceSyncCoordinator = AttendanceSyncCoordinator(
    repository: attendanceRepository,
  );

  final requestRepository = RequestRepositoryImpl(
    apiClient: apiClient,
    database: outbox,
    tokenStorage: tokenStorage,
  );

  final profileRepository = ProfileRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    database: outbox,
  );

  final dashboardRepository = DashboardRepositoryImpl(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
  );

  final dynamicRequestRepository = DynamicRequestRepositoryImpl(
    apiClient: apiClient,
    database: outbox,
    tokenStorage: tokenStorage,
  );

  final dynamicSyncCoordinator = DynamicRequestSyncCoordinator(
    repository: dynamicRequestRepository,
  );

  final notificationRepository = NotificationRepositoryImpl(
    apiClient: apiClient,
  );
  apiClient.onBeforeLogout = (_) async {
    // Best effort only: a logout must still complete if the device is offline.
    // The local FCM token is removed after a successful server revocation.
    try {
      await pushRegistrationCoordinator.disable();
    } catch (_) {}
  };
  apiClient.onSessionInvalidated = (session) async {
    await outbox.clearIdentity(
      tenantId: session.tenantId,
      userId: session.userId,
    );
    try {
      await pushRegistrationCoordinator.disable();
    } catch (_) {}
    try {
      await tokenStorage.clearDeviceInstallationRegistration(
        tenantId: session.tenantId,
        userId: session.userId,
      );
    } catch (_) {}
    try {
      await attendanceTrustBridge.revokeLocalInstallation();
    } catch (_) {}
  };

  final reportRepository = ReportRepositoryImpl(
    apiClient: apiClient,
  );

  final payslipRepository = PayslipRepositoryImpl(
    api: apiClient,
  );

  final advanceRepository = AdvanceRepositoryImpl(
    api: apiClient,
  );

  final leaveQuotaRepository = LeaveQuotaRepositoryImpl(
    apiClient: apiClient,
  );
  final finalSettlementRepository =
      FinalSettlementRepositoryImpl(api: apiClient);

  runApp(AttendApp(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    authRepository: authRepository,
    attendanceRepository: attendanceRepository,
    attendanceSyncCoordinator: attendanceSyncCoordinator,
    installationIdentity: attendanceTrustBridge,
    requestRepository: requestRepository,
    profileRepository: profileRepository,
    dashboardRepository: dashboardRepository,
    dynamicRequestRepository: dynamicRequestRepository,
    dynamicSyncCoordinator: dynamicSyncCoordinator,
    notificationRepository: notificationRepository,
    pushNotificationPort: pushNotificationService,
    pushRegistrationCoordinator: pushRegistrationCoordinator,
    reportRepository: reportRepository,
    payslipRepository: payslipRepository,
    advanceRepository: advanceRepository,
    leaveQuotaRepository: leaveQuotaRepository,
    finalSettlementRepository: finalSettlementRepository,
    reminderRepository: reminderRepository,
    reminderScheduler: reminderScheduler,
    reminderCoordinator: reminderCoordinator,
    mobileControlsRepository: mobileControlsRepository,
    mobileBuildNumber: installedBuildNumber,
  ));
}

class AttendApp extends StatelessWidget {
  final ApiClient? apiClient;
  final TokenStorage? tokenStorage;
  final AuthRepository? authRepository;
  final AttendanceRepository? attendanceRepository;
  final AttendanceSyncCoordinator? attendanceSyncCoordinator;
  final InstallationIdentityPort? installationIdentity;
  final RequestRepository? requestRepository;
  final ProfileRepository profileRepository;
  final DashboardRepository dashboardRepository;
  final DynamicRequestRepository dynamicRequestRepository;
  final DynamicRequestSyncCoordinator? dynamicSyncCoordinator;
  final NotificationRepository? notificationRepository;
  final PushNotificationPort? pushNotificationPort;
  final PushRegistrationPort? pushRegistrationCoordinator;
  final ReportRepository? reportRepository;
  final PayslipRepository? payslipRepository;
  final AdvanceRepository? advanceRepository;
  final LeaveQuotaRepository? leaveQuotaRepository;
  final FinalSettlementRepository? finalSettlementRepository;
  final ManualAttendanceRepository? manualAttendanceRepository;
  final ReminderRepository? reminderRepository;
  final ReminderScheduler? reminderScheduler;
  final ReminderCoordinator? reminderCoordinator;
  final LanguageCubit? languageCubit;
  final MobileControlsRepository? mobileControlsRepository;
  final int mobileBuildNumber;

  const AttendApp({
    super.key,
    this.apiClient,
    this.tokenStorage,
    this.authRepository,
    this.attendanceRepository,
    this.attendanceSyncCoordinator,
    this.installationIdentity,
    this.requestRepository,
    required this.profileRepository,
    required this.dashboardRepository,
    required this.dynamicRequestRepository,
    this.dynamicSyncCoordinator,
    this.notificationRepository,
    this.pushNotificationPort,
    this.pushRegistrationCoordinator,
    this.reportRepository,
    this.payslipRepository,
    this.advanceRepository,
    this.leaveQuotaRepository,
    this.finalSettlementRepository,
    this.manualAttendanceRepository,
    this.reminderRepository,
    this.reminderScheduler,
    this.reminderCoordinator,
    this.languageCubit,
    this.mobileControlsRepository,
    this.mobileBuildNumber = 19,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAuth = authRepository ?? _FallbackAuthRepo();
    final effectiveAttendance =
        attendanceRepository ?? _FallbackAttendanceRepo();
    final effectiveRequest = requestRepository ?? _FallbackRequestRepo();
    final effectiveProfile = profileRepository;
    final effectiveDashboard = dashboardRepository;
    final effectiveTokenStorage = tokenStorage ?? TokenStorage();
    final effectiveApiClient = apiClient ??
        ApiClient(
          baseUrl: resolveDefaultApiBaseUrl(),
          tokenStorage: effectiveTokenStorage,
        );
    final effectiveNotification = notificationRepository ??
        NotificationRepositoryImpl(apiClient: effectiveApiClient);
    final effectiveReport =
        reportRepository ?? ReportRepositoryImpl(apiClient: effectiveApiClient);
    final effectivePayslip =
        payslipRepository ?? PayslipRepositoryImpl(api: effectiveApiClient);
    final effectiveAdvance =
        advanceRepository ?? AdvanceRepositoryImpl(api: effectiveApiClient);
    final effectiveLeaveQuota = leaveQuotaRepository ??
        LeaveQuotaRepositoryImpl(apiClient: effectiveApiClient);
    final effectiveFinalSettlement = finalSettlementRepository ??
        FinalSettlementRepositoryImpl(api: effectiveApiClient);
    final effectiveManualAttendance = manualAttendanceRepository ??
        ManualAttendanceRepositoryImpl(apiClient: effectiveApiClient);
    final effectiveReminderRepository = reminderRepository ??
        AttendanceReminderRepositoryImpl(
          apiClient: effectiveApiClient,
          secureStorage: const FlutterSecureStorage(),
        );
    final effectiveReminderScheduler =
        reminderScheduler ?? LocalAttendanceReminderScheduler();
    final effectiveReminderCoordinator = reminderCoordinator ??
        AttendanceReminderCoordinator(
          repository: effectiveReminderRepository,
          scheduler: effectiveReminderScheduler,
        );
    final effectiveDynamicRequest = dynamicRequestRepository;
    final effectiveMobileControls = mobileControlsRepository ??
        MobileControlsRepositoryImpl(
          apiClient: effectiveApiClient,
          tokenStorage: effectiveTokenStorage,
          cache: const MobileControlsCacheImpl(),
        );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ApiClient>.value(value: effectiveApiClient),
        RepositoryProvider<TokenStorage>.value(value: effectiveTokenStorage),
        RepositoryProvider<AuthRepository>.value(value: effectiveAuth),
        RepositoryProvider<AttendanceRepository>.value(
            value: effectiveAttendance),
        RepositoryProvider<RequestRepository>.value(value: effectiveRequest),
        if (effectiveRequest is RequestAttachmentRepository)
          RepositoryProvider<RequestAttachmentRepository>.value(
              value: effectiveRequest as RequestAttachmentRepository),
        RepositoryProvider<ProfileRepository>.value(value: effectiveProfile),
        RepositoryProvider<DashboardRepository>.value(
            value: effectiveDashboard),
        RepositoryProvider<DynamicRequestRepository>.value(
            value: effectiveDynamicRequest),
        RepositoryProvider<NotificationRepository>.value(
            value: effectiveNotification),
        if (pushNotificationPort != null)
          RepositoryProvider<PushNotificationPort>.value(
              value: pushNotificationPort!),
        if (pushRegistrationCoordinator != null)
          RepositoryProvider<PushRegistrationPort>.value(
              value: pushRegistrationCoordinator!),
        RepositoryProvider<ReportRepository>.value(value: effectiveReport),
        RepositoryProvider<PayslipRepository>.value(value: effectivePayslip),
        RepositoryProvider<AdvanceRepository>.value(value: effectiveAdvance),
        if (effectiveAdvance is AdvanceEligibilityRepository)
          RepositoryProvider<AdvanceEligibilityRepository>.value(
              value: effectiveAdvance as AdvanceEligibilityRepository),
        RepositoryProvider<LeaveQuotaRepository>.value(
            value: effectiveLeaveQuota),
        RepositoryProvider<FinalSettlementRepository>.value(
            value: effectiveFinalSettlement),
        RepositoryProvider<ManualAttendanceRepository>.value(
            value: effectiveManualAttendance),
        RepositoryProvider<ReminderRepository>.value(
            value: effectiveReminderRepository),
        RepositoryProvider<ReminderScheduler>.value(
            value: effectiveReminderScheduler),
        RepositoryProvider<ReminderCoordinator>.value(
            value: effectiveReminderCoordinator),
        RepositoryProvider<MobileControlsRepository>.value(
          value: effectiveMobileControls,
        ),
        RepositoryProvider<int>.value(value: mobileBuildNumber),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<LanguageCubit>(
            create: (_) =>
                languageCubit ??
                (LanguageCubit(tokenStorage: effectiveTokenStorage)
                  ..loadLanguage()),
          ),
          BlocProvider<AuthCubit>(
            create: (_) {
              final cubit = AuthCubit(
                effectiveAuth,
                installationIdentity: installationIdentity,
              );
              effectiveApiClient.onSessionExpired = () => cubit.expireSession();
              return cubit..checkSession();
            },
          ),
          BlocProvider<ProfileCubit>(
            create: (_) => ProfileCubit(repository: effectiveProfile),
          ),
          BlocProvider<DashboardCubit>(
            create: (_) => DashboardCubit(repository: effectiveDashboard),
          ),
          BlocProvider<DynamicRequestCubit>(
            create: (_) =>
                DynamicRequestCubit(repository: effectiveDynamicRequest)
                  ..syncOutbox(),
          ),
          BlocProvider<NotificationCubit>(
            create: (_) => NotificationCubit(repository: effectiveNotification),
          ),
        ],
        child: BlocBuilder<LanguageCubit, LanguageState>(
          builder: (context, langState) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: AppStringsAr.appName,
              theme: AppTheme.lightTheme,
              themeMode: ThemeMode.light,
              locale: langState.locale,
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AuthGate(),
              routes: {
                '/password-recovery': (context) =>
                    const PasswordRecoveryScreen(),
              },
            );
          },
        ),
      ),
    );
  }
}

class _FallbackAuthRepo implements AuthRepository {
  @override
  Future<AuthSessionEntity?> getCachedSession() async => null;
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
          {required String email, required String tenantSlug}) =>
      throw UnimplementedError();
  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) =>
      throw UnimplementedError();
}

class _FallbackAttendanceRepo implements AttendanceRepository {
  @override
  Future<ShiftContextEntity> getCurrentShiftContext() =>
      throw UnimplementedError();
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

class _FallbackRequestRepo implements RequestRepository {
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
