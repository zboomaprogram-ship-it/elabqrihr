import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

class TeamSummaryCard extends StatelessWidget {
  final int totalMembers;
  final int presentCount;
  final int onLeaveCount;
  final int pendingApprovalsCount;
  final VoidCallback? onReviewInboxTap;

  const TeamSummaryCard({
    super.key,
    this.totalMembers = 0,
    this.presentCount = 0,
    this.onLeaveCount = 0,
    this.pendingApprovalsCount = 0,
    this.onReviewInboxTap,
  });

  @override
  Widget build(BuildContext context) {
    return AttendCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.groups_outlined, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'ملخص أداء الفريق اليوم',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (pendingApprovalsCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$pendingApprovalsCount بانتظار الموافقة',
                    style: const TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, color: AppTheme.surface03),
          Row(
            children: [
              Expanded(
                child: _TeamMetric(
                  label: 'الحاضرون',
                  value: '$presentCount',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle_outline,
                ),
              ),
              Expanded(
                child: _TeamMetric(
                  label: 'في إجازة/إذن',
                  value: '$onLeaveCount',
                  color: AppTheme.warningColor,
                  icon: Icons.pause_circle_outline,
                ),
              ),
              Expanded(
                child: _TeamMetric(
                  label: 'إجمالي الفريق',
                  value: '$totalMembers',
                  color: AppTheme.textSecondary,
                  icon: Icons.people_outline,
                ),
              ),
            ],
          ),
          if (pendingApprovalsCount > 0 && onReviewInboxTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReviewInboxTap,
                icon: const Icon(Icons.playlist_add_check, size: 18),
                label: const Text('مراجعة الطلبات المعلقة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.25),
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TeamMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
