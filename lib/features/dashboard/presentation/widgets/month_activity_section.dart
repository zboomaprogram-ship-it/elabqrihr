import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

/// Monthly attendance activity section — shows a calendar-style grid where
/// each day is coloured to indicate attendance status. Mirrors the
/// legacy `MonthActivitySection` anatomy in the Attend Light palette.
///
/// [presentDates]  — dates where a check-in was recorded (accepted)
/// [absentDates]   — dates that are working days with no check-in
class MonthActivitySection extends StatelessWidget {
  final List<DateTime> presentDates;
  final List<DateTime> absentDates;
  final DateTime? month; // defaults to current month

  const MonthActivitySection({
    super.key,
    this.presentDates = const [],
    this.absentDates = const [],
    this.month,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final target = month ?? DateTime(now.year, now.month);
    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(target);
    final daysInMonth = DateUtils.getDaysInMonth(target.year, target.month);

    // First weekday of month (1=Mon…7=Sun in Dart, we want 0-indexed for RTL)
    final firstDay = DateTime(target.year, target.month, 1);
    // offset for Sunday-first grid
    final offset = (firstDay.weekday % 7); // 0=Sun,1=Mon,...,6=Sat

    final presentSet = {
      for (final d in presentDates) '${d.year}-${d.month}-${d.day}'
    };
    final absentSet = {
      for (final d in absentDates) '${d.year}-${d.month}-${d.day}'
    };

    return AttendCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'نشاط الشهر — $monthLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday headers (Sun–Sat in Arabic, displayed RTL)
          Row(
            children: const [
              _DayHeader('أح'),
              _DayHeader('إث'),
              _DayHeader('ثل'),
              _DayHeader('أر'),
              _DayHeader('خم'),
              _DayHeader('جم'),
              _DayHeader('سب'),
            ],
          ),
          const SizedBox(height: 6),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: offset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < offset) return const SizedBox.shrink();
              final dayNum = index - offset + 1;
              final date = DateTime(target.year, target.month, dayNum);
              final key = '${date.year}-${date.month}-${date.day}';
              final isPresent = presentSet.contains(key);
              final isAbsent = absentSet.contains(key);
              final isToday = date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isFuture = date.isAfter(now);

              Color dotColor;
              Color bg;
              if (isFuture) {
                dotColor = Colors.transparent;
                bg = Colors.transparent;
              } else if (isPresent) {
                dotColor = AppTheme.successColor;
                bg = AppTheme.successColor.withValues(alpha: 0.12);
              } else if (isAbsent) {
                dotColor = AppTheme.errorColor;
                bg = AppTheme.errorColor.withValues(alpha: 0.08);
              } else {
                dotColor = Colors.transparent;
                bg = Colors.transparent;
              }

              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday
                                  ? AppTheme.primaryColor
                                  : (isFuture
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary),
                            ),
                          ),
                          if (!isFuture && dotColor != Colors.transparent) ...[
                            const SizedBox(height: 1),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
              _Legend(color: AppTheme.successColor, label: 'حضور'),
              _Legend(color: AppTheme.errorColor, label: 'غياب'),
              _Legend(
                  color: AppTheme.primaryColor,
                  label: 'اليوم',
                  isBorder: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool isBorder;

  const _Legend({
    required this.color,
    required this.label,
    this.isBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBorder ? Colors.transparent : color.withValues(alpha: 0.8),
            border: isBorder ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
