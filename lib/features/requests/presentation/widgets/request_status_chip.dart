import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

class RequestStatusChip extends StatelessWidget {
  final RequestState state;

  const RequestStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (state) {
      case RequestState.pendingSync:
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        label = AppStringsAr.statePendingSync;
        break;
      case RequestState.pendingApproval:
      case RequestState.submitted:
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.10);
        textColor = AppTheme.primaryColor;
        label = AppStringsAr.statePendingApproval;
        break;
      case RequestState.approved:
        bgColor = AppTheme.mint.withValues(alpha: 0.15);
        textColor = AppTheme.mint;
        label = AppStringsAr.stateApproved;
        break;
      case RequestState.rejected:
        bgColor = AppTheme.coral.withValues(alpha: 0.15);
        textColor = AppTheme.coral;
        label = AppStringsAr.stateRejected;
        break;
      case RequestState.cancelled:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = AppStringsAr.stateCancelled;
        break;
      case RequestState.conflict:
        bgColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFFC2410C);
        label = AppStringsAr.stateConflict;
        break;
      case RequestState.processingFailed:
        bgColor = AppTheme.coral.withValues(alpha: 0.15);
        textColor = AppTheme.coral;
        label = AppStringsAr.statusError;
        break;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
