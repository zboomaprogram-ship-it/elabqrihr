import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import '../../domain/leave_quota_models.dart';

class RequestQuotaPresubmitBanner extends StatelessWidget {
  final QuotaBalanceEntity? balance;
  final int requestedUnits;
  final bool isLoading;

  const RequestQuotaPresubmitBanner({
    super.key,
    required this.balance,
    this.requestedUnits = 0,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface03,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'جارٍ التحقق من رصيد الإجازات المتاح...',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    final currentBalance = balance;
    if (currentBalance == null) {
      return const SizedBox.shrink();
    }

    final isExceeded = requestedUnits > 0 && requestedUnits > currentBalance.remaining;
    final isZero = currentBalance.remaining <= 0;

    final bgColor = (isExceeded || isZero)
        ? AppTheme.errorColor.withValues(alpha: 0.1)
        : AppTheme.primaryColor.withValues(alpha: 0.08);

    final borderColor = (isExceeded || isZero)
        ? AppTheme.errorColor.withValues(alpha: 0.3)
        : AppTheme.primaryColor.withValues(alpha: 0.2);

    final iconColor = (isExceeded || isZero)
        ? AppTheme.errorColor
        : AppTheme.primaryColor;

    return Container(
      key: const Key('quota_presubmit_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isExceeded || isZero
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentBalance.quotaKey.displayNameAr}: المتبقي ${currentBalance.formattedRemaining}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isExceeded
                      ? 'تنبيه: الكمية المطلوبة ($requestedUnits ${currentBalance.unit.labelAr}) تتجاوز رصيدك الحالي المتاح (${currentBalance.remaining} ${currentBalance.unit.labelAr}).'
                      : isZero
                          ? 'تنبيه: رصيدك المتاح حالياً 0. قد يتطلب الطلب موافقة إدارية استثنائية.'
                          : 'طلبك ضمن حدود الرصيد المتاح لفترة (${currentBalance.resetCycle.labelAr}).',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
