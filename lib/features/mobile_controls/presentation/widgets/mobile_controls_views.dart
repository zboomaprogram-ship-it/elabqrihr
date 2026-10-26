import 'package:flutter/material.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_state.dart';

/// Full-screen accessible Arabic view displayed when a required build update is active.
class MobileUpdateRequiredScreen extends StatelessWidget {
  final int minimumBuild;
  final int currentBuild;
  final VoidCallback? onRetry;

  const MobileUpdateRequiredScreen({
    super.key,
    required this.minimumBuild,
    required this.currentBuild,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 44,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'تحديث مطلوب للمتابعة',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'يتطلب التطبيق تحديثاً لضمان أمان البيانات واستقرار الخدمة. يرجى تثبيت أحدث إصدار متوفر على Google Play.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (onRetry != null)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة التحقق من التحديث'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accessible inline Arabic banner displayed when a feature or screen is in maintenance or restricted.
class MobileControlRestrictedBanner extends StatelessWidget {
  final String messageAr;
  final bool isMaintenance;
  final VoidCallback? onDismiss;

  const MobileControlRestrictedBanner({
    super.key,
    required this.messageAr,
    this.isMaintenance = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isMaintenance ? Colors.orange.shade50 : Colors.red.shade50;
    final borderColor =
        isMaintenance ? Colors.orange.shade300 : Colors.red.shade300;
    final iconColor =
        isMaintenance ? Colors.orange.shade800 : Colors.red.shade800;
    final textColor =
        isMaintenance ? Colors.orange.shade900 : Colors.red.shade900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isMaintenance
                  ? Icons.build_circle_outlined
                  : Icons.warning_amber_rounded,
              color: iconColor,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                messageAr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

/// Accessible Arabic alert dialog or bottom sheet for restricted action attempts.
class MobileActionGuardDialog {
  static Future<void> show(
    BuildContext context, {
    required MobileActionGuardDecision decision,
  }) async {
    if (decision.isPermitted) return;

    final String title;
    final String body;
    final IconData icon;
    final Color color;

    switch (decision) {
      case ActionMaintenance(messageAr: final msg):
        title = 'الخدمة قيد الصيانة';
        body = msg;
        icon = Icons.construction_rounded;
        color = Colors.orange.shade700;
      case ActionRestricted(messageAr: final msg):
        title = 'الإجراء متوقف مؤقتاً';
        body = msg;
        icon = Icons.block_rounded;
        color = Colors.red.shade700;
      case UpdateRequired(messageAr: final msg):
        title = 'تحديث مطلوب';
        body = msg;
        icon = Icons.system_update_rounded;
        color = Colors.amber.shade800;
      case ActionAllowed():
        return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: Icon(icon, color: color, size: 36),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            body,
            style: const TextStyle(height: 1.5),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      ),
    );
  }
}
