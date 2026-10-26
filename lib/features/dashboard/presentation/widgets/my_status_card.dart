import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

/// "My Status Today" card — shows today's shift summary, check-in time, and
/// worked duration. Mirrors legacy `MyStatusCard` in the Attend Light palette.
class MyStatusCard extends StatelessWidget {
  final ShiftContextEntity? shift;
  final bool isLoading;

  const MyStatusCard({
    super.key,
    this.shift,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const AttendCard(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (shift == null) return const SizedBox.shrink();

    final timeFormat = DateFormat('hh:mm a');
    final checkInEvent = shift!.isCheckedIn ? shift!.lastEvent : null;
    final checkInTime = checkInEvent != null
        ? timeFormat.format(checkInEvent.capturedAt)
        : null;

    // Compute worked duration
    String? workedLabel;
    if (checkInEvent != null) {
      final elapsed = DateTime.now().difference(checkInEvent.capturedAt);
      final h = elapsed.inHours;
      final m = elapsed.inMinutes.remainder(60);
      workedLabel = '$hس ${m}د'; // ignore: unnecessary_brace_in_string_interps
    }

    return AttendCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Status indicator circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: shift!.isCheckedIn
                  ? AppTheme.successColor.withValues(alpha: 0.12)
                  : AppTheme.surface02,
              border: Border.all(
                color: shift!.isCheckedIn
                    ? AppTheme.successColor
                    : AppTheme.surface03,
                width: 1.5,
              ),
            ),
            child: Icon(
              shift!.isCheckedIn
                  ? Icons.how_to_reg_rounded
                  : Icons.radio_button_unchecked,
              color: shift!.isCheckedIn
                  ? AppTheme.successColor
                  : AppTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift!.isCheckedIn ? 'أنت حالياً في الدوام' : 'لم تبدأ يوم العمل بعد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: shift!.isCheckedIn
                        ? AppTheme.successColor
                        : AppTheme.textPrimary,
                  ),
                ),
                if (checkInTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'دخول: $checkInTime',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Worked duration badge
          if (workedLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    workedLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'مدة العمل',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
