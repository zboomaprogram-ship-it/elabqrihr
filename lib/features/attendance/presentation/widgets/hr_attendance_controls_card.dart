import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'emergency_attendance_dialog.dart';
import 'reconciliation_queue_sheet.dart';

class HrAttendanceControlsCard extends StatelessWidget {
  final VoidCallback? onEmergencySaved;

  const HrAttendanceControlsCard({
    super.key,
    this.onEmergencySaved,
  });

  @override
  Widget build(BuildContext context) {
    return AttendCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security_outlined,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التحكم الإداري السيادي',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'تسجيل حضور طارئ وتسوية استثناءات الورديات',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                key: const Key('hr_emergency_attendance_action_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(140, 44),
                ),
                onPressed: () {
                  EmergencyAttendanceDialog.show(
                    context,
                    onSaved: onEmergencySaved,
                  );
                },
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('تسجيل حضور طارئ'),
              ),
              OutlinedButton.icon(
                key: const Key('hr_reconciliation_queue_action_btn'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(140, 44),
                ),
                onPressed: () {
                  ReconciliationQueueSheet.show(context);
                },
                icon: const Icon(Icons.rule_folder_outlined, size: 18),
                label: const Text('تسوية الاستثناءات'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
