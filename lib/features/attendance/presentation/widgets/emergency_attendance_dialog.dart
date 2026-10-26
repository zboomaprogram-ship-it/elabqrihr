import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/manual_attendance_models.dart';
import '../../domain/manual_attendance_repository.dart';
import '../cubit/hr_manual_attendance_cubit.dart';
import '../cubit/hr_manual_attendance_state.dart';

class EmergencyAttendanceDialog extends StatelessWidget {
  final VoidCallback? onSaved;
  final String? initialBusinessDate;

  const EmergencyAttendanceDialog({
    super.key,
    this.onSaved,
    this.initialBusinessDate,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onSaved,
    String? initialBusinessDate,
  }) {
    ManualAttendanceRepository? repo;
    try {
      repo = context.read<ManualAttendanceRepository>();
    } catch (_) {}
    if (repo == null) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => HrManualAttendanceCubit(
          repository: repo!,
          initialBusinessDate: initialBusinessDate,
        )..loadEmployees(),
        child: EmergencyAttendanceDialog(
          onSaved: onSaved,
          initialBusinessDate: initialBusinessDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: BlocConsumer<HrManualAttendanceCubit, HrManualAttendanceState>(
          listener: (context, state) {
            if (state.outcome == HrSubmissionOutcome.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تسجيل إجراء الحضور الإداري وتوثيقه بنجاح.'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
              Navigator.of(context).pop();
              onSaved?.call();
            }
          },
          builder: (context, state) {
            final cubit = context.read<HrManualAttendanceCubit>();

            return AttendCard(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.emergency_outlined,
                                color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'تسجيل حضور طارئ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          key: const Key('close_emergency_dialog_btn'),
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Error banner if any
                    if (state.errorMessage != null &&
                        state.outcome != HrSubmissionOutcome.idle)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.errorColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Date picker
                    const Text(
                      'تاريخ العمل',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      key: const Key('manual_attendance_date_btn'),
                      onTap: () async {
                        final current =
                            DateTime.tryParse(state.businessDate) ?? DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: current,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          final fmt = DateFormat('yyyy-MM-dd').format(picked);
                          cubit.updateBusinessDate(fmt);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface02,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.businessDate,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.calendar_today,
                                size: 18, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Employee Search and Selection
                    const Text(
                      'الموظف',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('manual_attendance_search_field'),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو الرقم الوظيفي...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        filled: true,
                        fillColor: AppTheme.surface02,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      onChanged: cubit.updateSearch,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 130),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: state.isLoadingEmployees
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : state.filteredEmployees.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: Text(
                                    'لا يوجد موظف مطابق للبحث',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: state.filteredEmployees.length,
                                  itemBuilder: (context, index) {
                                    final emp = state.filteredEmployees[index];
                                    final isSelected =
                                        emp.id == state.selectedEmployeeId;
                                    return InkWell(
                                      key: Key('emp_option_${emp.id}'),
                                      onTap: () => cubit.selectEmployee(emp.id),
                                      child: Container(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                                .withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_off,
                                              size: 18,
                                              color: isSelected
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                emp.displayName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              emp.employeeNumber,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 14),

                    // Action Type Selector
                    const Text(
                      'نوع الإجراء',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ManualAttendanceActionType.values.map((type) {
                        final isSelected = state.actionType == type;
                        return ChoiceChip(
                          key: Key('action_chip_${type.name}'),
                          label: Text(type.arabicLabel),
                          selected: isSelected,
                          onSelected: (_) => cubit.updateActionType(type),
                          selectedColor:
                              AppTheme.primaryColor.withValues(alpha: 0.18),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Timestamp pickers
                    if (state.actionType == ManualAttendanceActionType.checkIn ||
                        state.actionType == ManualAttendanceActionType.checkOut) ...[
                      const Text(
                        'وقت الحركة',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _TimePickerField(
                        key: const Key('occurred_time_picker'),
                        dateTime: state.occurredAt ?? DateTime.now(),
                        onChanged: cubit.updateOccurredAt,
                      ),
                    ] else if (state.actionType ==
                        ManualAttendanceActionType.fullDay) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'وقت الدخول',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _TimePickerField(
                                  key: const Key('check_in_time_picker'),
                                  dateTime: state.checkInAt ??
                                      DateTime.now()
                                          .subtract(const Duration(hours: 8)),
                                  onChanged: (dt) {
                                    cubit.updateFullDayTimes(
                                      dt,
                                      state.checkOutAt ?? DateTime.now(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'وقت الانصراف',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _TimePickerField(
                                  key: const Key('check_out_time_picker'),
                                  dateTime: state.checkOutAt ?? DateTime.now(),
                                  onChanged: (dt) {
                                    cubit.updateFullDayTimes(
                                      state.checkInAt ??
                                          DateTime.now().subtract(
                                              const Duration(hours: 8)),
                                      dt,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Reason Field
                    const Text(
                      'السبب الإداري الموثق (إلزامي)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('manual_attendance_reason_field'),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'مثال: تعطل هاتف الموظف، إذن مأمورية خارجية...',
                        helperText: 'يجب ألا يقل السبب عن 3 أحرف',
                        filled: true,
                        fillColor: AppTheme.surface02,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      onChanged: cubit.updateReason,
                    ),
                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          key: const Key('manual_attendance_submit_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            minimumSize: const Size(120, 44),
                          ),
                          onPressed: state.isValid &&
                                  state.outcome != HrSubmissionOutcome.submitting
                              ? () => cubit.submitManualAttendance()
                              : null,
                          icon: state.outcome == HrSubmissionOutcome.submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            state.outcome == HrSubmissionOutcome.submitting
                                ? 'جارٍ الحفظ…'
                                : 'حفظ الإجراء',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final DateTime dateTime;
  final ValueChanged<DateTime> onChanged;

  const _TimePickerField({
    super.key,
    required this.dateTime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(dateTime);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime:
              TimeOfDay(hour: dateTime.hour, minute: dateTime.minute),
        );
        if (picked != null) {
          final updated = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            picked.hour,
            picked.minute,
          );
          onChanged(updated);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface02,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.access_time, size: 18, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
