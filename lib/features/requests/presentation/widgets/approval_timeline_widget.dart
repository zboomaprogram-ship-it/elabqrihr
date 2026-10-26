import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';

class ApprovalTimelineWidget extends StatelessWidget {
  final List<ApprovalStepEntity> steps;

  const ApprovalTimelineWidget({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'لا توجد مراحل اعتماد مسجلة',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStringsAr.approvalTimeline,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkInk,
          ),
        ),
        const SizedBox(height: 12),
        ...steps
            .map((step) => _buildStepItem(step, isLast: step == steps.last)),
      ],
    );
  }

  Widget _buildStepItem(ApprovalStepEntity step, {required bool isLast}) {
    Color iconColor;
    IconData icon;
    String statusText;

    switch (step.state.toLowerCase()) {
      case 'approved':
        iconColor = AppTheme.mint;
        icon = Icons.check_circle;
        statusText = AppStringsAr.stateApproved;
        break;
      case 'rejected':
        iconColor = AppTheme.coral;
        icon = Icons.cancel;
        statusText = AppStringsAr.stateRejected;
        break;
      case 'pending':
        iconColor = AppTheme.primaryColor;
        icon = Icons.hourglass_top;
        statusText = 'قيد المراجعة';
        break;
      case 'waiting':
      default:
        iconColor = Colors.grey;
        icon = Icons.radio_button_unchecked;
        statusText = 'في انتظار المرحلة السابقة';
        break;
    }

    final roleLabel = step.reviewerRole == 'manager'
        ? AppStringsAr.managerRole
        : (step.reviewerRole == 'hr' ? AppStringsAr.hrRole : 'إدارة الشركة');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المرحلة ${step.position}: $roleLabel',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.darkInk,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (step.reviewerName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'المراجع: ${step.reviewerName}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                  if (step.decidedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm')
                          .format(step.decidedAt!.toLocal()),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  if (step.comment != null && step.comment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ملاحظة: ${step.comment}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.darkInk),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
