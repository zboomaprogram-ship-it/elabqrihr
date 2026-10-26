import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

/// Priority strip — shows a quick badge when the employee has pending requests.
/// Tapping it navigates to the requests tab. Mirrors the legacy
/// `EmployeePriorityStrip` anatomy without copying its dark/cyan palette.
class EmployeePriorityStrip extends StatelessWidget {
  final int pendingRequestsCount;
  final VoidCallback? onRequestsTap;
  final VoidCallback? onManagerInboxTap;
  final bool isReviewer;
  final int pendingInboxCount;

  const EmployeePriorityStrip({
    super.key,
    required this.pendingRequestsCount,
    this.onRequestsTap,
    this.onManagerInboxTap,
    this.isReviewer = false,
    this.pendingInboxCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasMyPending = pendingRequestsCount > 0;
    final hasInboxPending = isReviewer && pendingInboxCount > 0;

    if (!hasMyPending && !hasInboxPending) return const SizedBox.shrink();

    return Column(
      children: [
        if (hasMyPending) ...[
          _PriorityChip(
            icon: Icons.pending_actions_rounded,
            label: 'لديك $pendingRequestsCount طلب بانتظار المراجعة',
            color: AppTheme.warningColor,
            onTap: onRequestsTap,
          ),
          if (hasInboxPending) const SizedBox(height: 8),
        ],
        if (hasInboxPending)
          _PriorityChip(
            icon: Icons.approval_rounded,
            label: 'صندوقك: $pendingInboxCount طلب يحتاج قرارك',
            color: AppTheme.primaryColor,
            onTap: onManagerInboxTap,
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PriorityChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
