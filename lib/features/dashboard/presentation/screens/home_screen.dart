import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/rtl_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/attendance_status_teaser_card.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_priority_strip.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_quick_actions_grid.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_summary_cards.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/recent_requests_preview.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/team_summary_card.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/features/navigation/main_navigation_shell.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/employee_requests_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:attend_mobile/features/notifications/presentation/widgets/notification_badge_icon.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/reports/domain/report_models.dart';
import 'package:attend_mobile/features/reports/presentation/screens/role_reports_screen.dart';

/// Distinct Home Dashboard Screen backed by [DashboardCubit] (`GET /me/dashboard`)
/// and OpenAPI contracts. Distinct from [AttendanceScreen].
///
/// Home owns:
/// - Branded greeting and identity context
/// - Authoritative priority strip and server counts
/// - At most one compact read-only attendance status teaser navigating to Attendance
/// - Role quick actions and overview summaries
/// - Recent request preview
///
/// Home strictly excludes:
/// - Check-in/out controls
/// - Detailed shift data & MyStatusCard
/// - Location refresh & geofence chips
/// - MonthActivitySection & attendance calendar
/// - Invented attendance values & DateTime.now() fabrication
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<EmployeeRequestsCubit>();
      return const _HomeScreenBody();
    } catch (_) {
      return BlocProvider<EmployeeRequestsCubit>(
        create: (ctx) => EmployeeRequestsCubit(
          repository: ctx.read<RequestRepository>(),
        )..loadRequests(),
        child: const _HomeScreenBody(),
      );
    }
  }
}

class _HomeScreenBody extends StatelessWidget {
  const _HomeScreenBody();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Semantics(
            label: AppStringsAr.appNameSpoken,
            excludeSemantics: true,
            child: const Text(
              AppStringsAr.appName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          actions: [
            const NotificationBadgeIcon(),
          ],
        ),
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, dashState) {
            if (dashState is DashboardLoading) {
              return const DashboardSkeleton();
            }

            final authState = context.watch<AuthCubit>().state;
            final session =
                authState is Authenticated ? authState.session : null;

            if (dashState is DashboardError && session == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(
                        dashState.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context
                            .read<DashboardCubit>()
                            .loadDashboard(refresh: true),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final summary =
                dashState is DashboardLoaded ? dashState.summary : null;
            final profile = summary?.profile;

            final displayName = (profile != null &&
                    profile.userId != 'fallback-user' &&
                    profile.displayName.isNotEmpty)
                ? profile.displayName
                : (session?.displayName ?? profile?.displayName ?? 'الموظف');
            final role = profile?.role ?? session?.role ?? UserRole.employee;
            final policy = RoleNavigationPolicy(role);
            final isReviewer = policy.canAccessReviewerInbox;
            final reviewerTabIndex = role == UserRole.manager
                ? 3
                : (role == UserRole.companyAdmin ? 1 : 2);

            // Authoritative attendance status from AttendanceCubit without fabricating values
            final attendState = context.watch<AttendanceCubit>().state;
            final isCheckedIn = attendState is AttendanceReady &&
                attendState.shiftContext.isCheckedIn;

            return BlocBuilder<EmployeeRequestsCubit, EmployeeRequestsState>(
              builder: (context, reqState) {
                final recentRequests = reqState is EmployeeRequestsLoaded
                    ? reqState.requests
                    : <RequestEntity>[];
                final pendingList = recentRequests
                    .where((r) =>
                        r.state == RequestState.submitted ||
                        r.state == RequestState.pendingApproval ||
                        r.state == RequestState.pendingSync)
                    .toList();
                final pendingRequestsCount =
                    summary?.pendingRequests ?? pendingList.length;
                final pendingApprovalsCount = summary?.pendingApprovals ?? 0;

                return RefreshIndicator(
                  onRefresh: () async {
                    await context
                        .read<DashboardCubit>()
                        .loadDashboard(refresh: true);
                    if (context.mounted) {
                      await context
                          .read<EmployeeRequestsCubit>()
                          .loadRequests();
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Compact branded header — greeting and live date (no fake geofence/location)
                        DashboardHeader(
                          userName: displayName,
                        ),
                        if (dashState is DashboardError) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 18, color: AppTheme.errorColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dashState.message,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textPrimary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context
                                      .read<DashboardCubit>()
                                      .loadDashboard(refresh: true),
                                  child: const Text('إعادة المحاولة',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Small Authoritative Attendance Status Teaser (navigates to Attendance)
                        if (policy.canRecordSelfAttendance) ...[
                          AttendanceStatusTeaserCard(
                            isCheckedIn: isCheckedIn,
                            onTap: () =>
                                MainTabController.switchTab(context, 1),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Priority Strip
                        EmployeePriorityStrip(
                          pendingRequestsCount: pendingRequestsCount,
                          isReviewer: isReviewer,
                          pendingInboxCount: pendingApprovalsCount,
                          onRequestsTap: () {
                            if (pendingList.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RequestDetailScreen(
                                    requestId: pendingList.first.id,
                                    isDynamic: pendingList.first.isDynamic,
                                  ),
                                ),
                              );
                            } else {
                              MainTabController.switchTab(context, 2);
                            }
                          },
                          onManagerInboxTap: () {
                            MainTabController.switchTab(
                                context, reviewerTabIndex);
                          },
                        ),
                        if (pendingRequestsCount > 0 ||
                            (isReviewer && pendingApprovalsCount > 0))
                          const SizedBox(height: 8),

                        // Role-scoped Quick Actions (No Payroll tile, No Chat, No Tasks)
                        const _SectionLabel('الإجراءات السريعة'),
                        const SizedBox(height: 10),
                        if (role == UserRole.employee)
                          EmployeeQuickActionsGrid(
                            onNewRequest: () =>
                                MainTabController.switchTab(context, 2),
                            onLeaveBalances: () =>
                                MainTabController.switchTab(context, 2),
                          )
                        else if (role == UserRole.manager)
                          Row(
                            children: [
                              Expanded(
                                child: _ManagerQuickActionCard(
                                  icon: Icons.checklist_rtl_rounded,
                                  label: 'طلبات فريقي',
                                  subtitle: 'المراجعة والاعتماد',
                                  color: AppTheme.primaryColor,
                                  onTap: () =>
                                      MainTabController.switchTab(context, 3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ManagerQuickActionCard(
                                  icon: Icons.groups_outlined,
                                  label: 'كشف الفريق',
                                  subtitle: 'حضور اليوم',
                                  color: AppTheme.secondaryColor,
                                  onTap: () =>
                                      MainTabController.switchTab(context, 2),
                                ),
                              ),
                            ],
                          )
                        else if (role == UserRole.hr ||
                            role == UserRole.companyAdmin)
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _ManagerQuickActionCard(
                                      icon: Icons.how_to_reg_outlined,
                                      label: 'تسجيل الحضور',
                                      subtitle: 'إثبات الحضور والانصراف',
                                      color: AppTheme.primaryColor,
                                      onTap: () => MainTabController.switchTab(
                                          context, 1),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ManagerQuickActionCard(
                                      icon: Icons.fact_check_outlined,
                                      label: 'صندوق الاعتماد',
                                      subtitle: 'مراجعة واعتماد الطلبات',
                                      color: AppTheme.warningColor,
                                      onTap: () => MainTabController.switchTab(
                                          context, 2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ManagerQuickActionCard(
                                      icon: Icons.post_add_outlined,
                                      label: 'تقديم طلب',
                                      subtitle: 'إجازة أو مهمة أو سلفة',
                                      color: AppTheme.secondaryColor,
                                      onTap: () => MainTabController.switchTab(
                                          context, 2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ManagerQuickActionCard(
                                      icon: Icons.analytics_outlined,
                                      label: 'تحليلات الشركة',
                                      subtitle: 'مؤشرات وتقارير الحضور',
                                      color: AppTheme.successColor,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          RoleReportsScreen.route(role: role),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        // Role Overview Summary Cards
                        if (role != UserRole.employee) ...[
                          const _SectionLabel('نظرة عامة'),
                          const SizedBox(height: 10),
                        ],
                        if (role == UserRole.employee)
                          EmployeeSummaryCards(
                            pendingRequestsCount: pendingRequestsCount,
                            onRequestsTap: () {
                              if (pendingList.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RequestDetailScreen(
                                      requestId: pendingList.first.id,
                                      isDynamic: pendingList.first.isDynamic,
                                    ),
                                  ),
                                );
                              } else {
                                MainTabController.switchTab(context, 2);
                              }
                            },
                            onLeaveTap: () =>
                                MainTabController.switchTab(context, 2),
                          )
                        else
                          TeamSummaryCard(
                            pendingApprovalsCount: pendingApprovalsCount,
                            onReviewInboxTap: () => MainTabController.switchTab(
                                context, reviewerTabIndex),
                          ),
                        const SizedBox(height: 24),

                        // Authorized Role Reports (T059)
                        const _SectionLabel('التقارير المعتمدة'),
                        const SizedBox(height: 10),
                        _RoleReportCard(
                          role: role,
                          onTap: () {
                            Navigator.of(context).push(
                              RoleReportsScreen.route(role: role),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Recent Requests Preview
                        if (recentRequests.isNotEmpty) ...[
                          RecentRequestsPreview(
                            requests: recentRequests,
                            onViewAll: () =>
                                MainTabController.switchTab(context, 2),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ManagerQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ManagerQuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surface03),
            boxShadow: const [AppTheme.cardShadow],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _RoleReportCard extends StatelessWidget {
  final UserRole role;
  final VoidCallback onTap;

  const _RoleReportCard({
    required this.role,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = ReportScopeHelper.titleForRole(role);
    final subtitle = ReportScopeHelper.subtitleForRole(role);

    return Semantics(
      label: '$title. $subtitle. زر لفتح التقرير المعتمد',
      button: true,
      child: WolfCard(
        child: InkWell(
          key: const Key('role_report_card_button'),
          borderRadius: BorderRadius.circular(16.0),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    RtlNavigation.forwardIcon(context),
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
