import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

/// Compact read-only attendance status teaser card for [HomeScreen].
///
/// Provides a concise indicator of whether today's attendance has been
/// recorded and navigates exclusively to the operational [AttendanceScreen]
/// on tap. Contains zero check-in controls, zero location refresh, and
/// zero fabricated attendance timestamps.
class AttendanceStatusTeaserCard extends StatelessWidget {
  final bool isCheckedIn;
  final VoidCallback onTap;

  const AttendanceStatusTeaserCard({
    super.key,
    required this.isCheckedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AttendCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCheckedIn
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCheckedIn ? Icons.check_circle_rounded : Icons.schedule_outlined,
                  color: isCheckedIn ? AppTheme.successColor : AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حالة الحضور اليوم',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCheckedIn
                          ? 'تم تسجيل الحضور — انقر للعرض'
                          : 'لم يتم تسجيل الحضور — انقر للتسجيل',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCheckedIn ? AppTheme.successColor : AppTheme.textSecondary,
                        fontWeight: isCheckedIn ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.steel,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
