import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/navigation/main_navigation_shell.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/notification_open_listener.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_cubit.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) {
        // Do not rebuild during background session checks or token refresh
        if (previous is Authenticated && current is AuthLoading) {
          return false;
        }
        // Do not rebuild when already authenticated unless the user or role changed
        if (previous is Authenticated && current is Authenticated) {
          return previous.session.userId != current.session.userId ||
              previous.session.role != current.session.role;
        }
        return true;
      },
      builder: (context, state) {
        // Only the very first application frame uses the full-page loader.
        // During an interactive sign-in, keeping LoginScreen mounted preserves
        // the company's code, email and password and lets its button show the
        // in-place progress indicator and any resulting error message.
        if (state is AuthInitial) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppTheme.logoAsset,
                    width: 100,
                    height: 100,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is Authenticated) {
          // Session is verified; now provide session-scoped cubits and load their initial state
          final attendanceRepo = context.read<AttendanceRepository>();
          final requestRepo = context.read<RequestRepository>();
          final profileRepo = context.read<ProfileRepository>();
          final dashboardRepo = context.read<DashboardRepository>();
          DynamicRequestRepository? dynamicRepo;
          try {
            dynamicRepo = context.read<DynamicRequestRepository>();
          } catch (_) {}
          NotificationRepository? notificationRepo;
          try {
            notificationRepo = context.read<NotificationRepository>();
          } catch (_) {}
          final mobileControlsRepo = context.read<MobileControlsRepository>();

          return MultiBlocProvider(
            key: ValueKey(state.session.userId),
            providers: [
              BlocProvider<AttendanceCubit>(
                create: (_) =>
                    AttendanceCubit(attendanceRepo)..loadShiftContext(),
              ),
              BlocProvider<MobileControlsCubit>(
                create: (_) => MobileControlsCubit(
                  repository: mobileControlsRepo,
                  currentBuildNumber: context.read<int>(),
                )..loadConfiguration(forceRefresh: true),
              ),
              BlocProvider<EmployeeRequestsCubit>(
                create: (_) => EmployeeRequestsCubit(
                  repository: requestRepo,
                  dynamicRepository: dynamicRepo,
                )..loadRequests(),
              ),
              BlocProvider<ManagerInboxCubit>(
                create: (_) => ManagerInboxCubit(
                  repository: requestRepo,
                  dynamicRepository: dynamicRepo,
                ),
              ),
              BlocProvider<ProfileCubit>(
                create: (_) =>
                    ProfileCubit(repository: profileRepo)..loadProfile(),
              ),
              BlocProvider<DashboardCubit>(
                create: (_) =>
                    DashboardCubit(repository: dashboardRepo)..loadDashboard(),
              ),
              if (notificationRepo != null)
                BlocProvider<NotificationCubit>(
                  create: (_) =>
                      NotificationCubit(repository: notificationRepo!)
                        ..loadNotifications()
                        ..refreshUnreadCount(),
                ),
            ],
            child: NotificationOpenListener(
              child: MainNavigationShell(userRole: state.session.role),
            ),
          );
        }

        // Unauthenticated or AuthError -> Present LoginScreen
        return const LoginScreen();
      },
    );
  }
}
