import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/team_summary_card.dart';
import 'package:attend_mobile/features/navigation/main_navigation_shell.dart';

/// Dedicated Team Roster and attendance monitoring screen for Managers.
class TeamRosterScreen extends StatelessWidget {
  const TeamRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'فريق العمل',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            final summary = state is DashboardLoaded ? state.summary : null;
            final pendingApprovals = summary?.pendingApprovals ?? 0;

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<DashboardCubit>().loadDashboard(refresh: true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TeamSummaryCard(
                    pendingApprovalsCount: pendingApprovals,
                    onReviewInboxTap: () =>
                        MainTabController.switchTab(context, 3),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'حالة أعضاء الفريق اليوم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AttendCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'كشف الحضور اللحظي',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تتم مزامنة حالة الفريق اللحظية تلقائياً من خادم الشركة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
