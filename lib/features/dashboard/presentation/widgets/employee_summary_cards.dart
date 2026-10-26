import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

class EmployeeSummaryCards extends StatelessWidget {
  final int pendingRequestsCount;
  final int availableLeaveDays;
  final String monthlyHoursText;
  final VoidCallback? onRequestsTap;
  final VoidCallback? onLeaveTap;

  const EmployeeSummaryCards({
    super.key,
    this.pendingRequestsCount = 0,
    this.availableLeaveDays = 0,
    this.monthlyHoursText = '-',
    this.onRequestsTap,
    this.onLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12.0, right: 4.0),
          child: Text(
            'نظرة عامة على الشهر',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          children: [
            // Monthly Hours Metric
            Expanded(
              child: _MetricCard(
                title: 'ساعات العمل',
                value: monthlyHoursText,
                icon: Icons.timer_outlined,
                accentColor: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),

            // Leave Balance Metric
            Expanded(
              child: _MetricCard(
                title: 'رصيد الإجازات',
                value: availableLeaveDays > 0 ? '$availableLeaveDays يوم' : '-',
                icon: Icons.event_available_outlined,
                accentColor: AppTheme.successColor,
                onTap: onLeaveTap,
              ),
            ),
            const SizedBox(width: 12),

            // Pending Requests Metric
            Expanded(
              child: _MetricCard(
                title: 'طلبات جارية',
                value: '$pendingRequestsCount',
                icon: Icons.assignment_outlined,
                accentColor: AppTheme.warningColor,
                onTap: onRequestsTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = WolfCard(
      hasBorderGlow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardContent,
      );
    }
    return cardContent;
  }
}
