import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

/// Quick action grid — uses the Attend Light palette.
/// Actions: New Request | Leave Balances.
/// No chat, no tasks, no payroll tile per project owner instructions.
class EmployeeQuickActionsGrid extends StatelessWidget {
  final VoidCallback? onNewRequest;
  final VoidCallback? onLeaveBalances;

  const EmployeeQuickActionsGrid({
    super.key,
    this.onNewRequest,
    this.onLeaveBalances,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.post_add_outlined,
                label: 'طلب جديد',
                subtitle: 'تقديم طلب إلكتروني',
                color: AppTheme.primaryColor,
                onTap: onNewRequest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.event_available_outlined,
                label: 'رصيد الإجازات',
                subtitle: 'استعراض الأرصدة',
                color: AppTheme.successColor,
                onTap: onLeaveBalances,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
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
