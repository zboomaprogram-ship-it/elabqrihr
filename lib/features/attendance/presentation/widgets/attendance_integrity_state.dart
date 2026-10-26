import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

/// Safe explanation for an integrity review. It intentionally does not expose
/// device-detection signals or instructions that could help bypass controls.
class AttendanceIntegrityState extends StatelessWidget {
  const AttendanceIntegrityState({
    super.key,
    required this.reasonCode,
    required this.onRefresh,
  });

  final String? reasonCode;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final revoked = reasonCode == 'DEVICE_REVOKED' ||
        reasonCode == 'DEVICE_INSTALLATION_NOT_FOUND';
    final unavailable = reasonCode == 'INTEGRITY_PROVIDER_UNAVAILABLE' ||
        reasonCode == 'INTEGRITY_PROVIDER_DISABLED';
    final text = revoked
        ? 'لم يعد هذا الجهاز معتمداً لتسجيل الحضور. سجّل الدخول مرة أخرى، ثم تواصل مع مسؤول الموارد البشرية إذا استمرت المشكلة.'
        : unavailable
            ? 'تحتاج حركة الحضور إلى مراجعة قبل اعتمادها. لن تُحتسب الحركة أو تدخل في الرواتب حتى تكتمل المراجعة.'
            : 'تم إرسال حركة الحضور للمراجعة الأمنية. لن تُحتسب الحركة أو تدخل في الرواتب حتى تكتمل المراجعة.';

    return Semantics(
      container: true,
      label: 'حالة مراجعة أمان الحضور',
      child: Container(
        key: const Key('attendance_integrity_review_state'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.warningColor.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.warningColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الحركة قيد المراجعة',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
            if (revoked || unavailable) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('attendance_integrity_refresh_button'),
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث حالة الجهاز'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
