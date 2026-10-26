import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/manual_attendance_models.dart';
import '../cubit/reconciliation_quick_actions_cubit.dart';
import '../cubit/reconciliation_quick_actions_state.dart';

class ReconciliationDecisionDialog extends StatelessWidget {
  final DetailedReconciliationItem item;
  final VoidCallback? onSaved;

  const ReconciliationDecisionDialog({
    super.key,
    required this.item,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required DetailedReconciliationItem item,
    VoidCallback? onSaved,
  }) {
    final cubit = context.read<ReconciliationQuickActionsCubit>();
    cubit.selectItem(item);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ReconciliationDecisionDialog(item: item, onSaved: onSaved),
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
        child: BlocConsumer<ReconciliationQuickActionsCubit,
            ReconciliationQuickActionsState>(
          listener: (context, state) {
            if (state.outcome == ReconciliationActionOutcome.decisionSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم اعتماد قرار تسوية الاستثناء بنجاح.'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
              Navigator.of(context).pop();
              onSaved?.call();
            }
          },
          builder: (context, state) {
            final cubit = context.read<ReconciliationQuickActionsCubit>();

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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معالجة استثناء ${item.employeeName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'تاريخ: ${item.businessDate}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: const Key('close_decision_dialog_btn'),
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            cubit.clearSelection();
                            Navigator.of(context).pop();
                          },
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Error banner
                    if (state.errorMessage != null &&
                        state.outcome != ReconciliationActionOutcome.idle)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
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

                    // Late Arrival Proposal Banner
                    if (item.isLateArrivalProposal)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'اقتراح تأخير آلي (${item.lateMinutes ?? 0} دقيقة)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الساعات المقترحة: ${item.suggestedDeduction?.units ?? "0"} س · لم يُخصم شيء بعد حتى الاعتماد الصريح.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Open Cycles Dropdown
                    const Text(
                      'دورة الرواتب المفتوحة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface02,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('decision_cycle_dropdown'),
                          value: state.selectedCycleId,
                          isExpanded: true,
                          hint: const Text('اختر دورة الرواتب'),
                          items: state.openCycles.map((cycle) {
                            return DropdownMenuItem<String>(
                              value: cycle.id,
                              child: Text(
                                'دورة ${cycle.cycleKey} (${cycle.state})',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) cubit.selectCycle(val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Decision Mode
                    const Text(
                      'قرار المعالجة',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface02,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<AdministrativeAdjustmentMode>(
                          key: const Key('decision_mode_dropdown'),
                          value: state.mode,
                          isExpanded: true,
                          items: AdministrativeAdjustmentMode.values.map((m) {
                            return DropdownMenuItem<
                                AdministrativeAdjustmentMode>(
                              value: m,
                              child: Text(m.arabicLabel),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) cubit.setMode(val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mode Details
                    if (state.mode ==
                        AdministrativeAdjustmentMode.dayFraction) ...[
                      const Text(
                        'جزء اليوم',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          _fractionChip(cubit, state, '0.25', 'ربع يوم'),
                          _fractionChip(cubit, state, '0.5', 'نصف يوم'),
                          _fractionChip(cubit, state, '1', 'يوم كامل'),
                          _fractionChip(cubit, state, '2', 'يومان'),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else if (state.mode ==
                        AdministrativeAdjustmentMode.customHours) ...[
                      const Text(
                        'عدد الساعات',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('decision_hours_field'),
                        keyboardType:
                            const TextInputAnimationType(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'مثال: 1.5',
                          filled: true,
                          fillColor: AppTheme.surface02,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                        onChanged: cubit.setUnits,
                      ),
                      const SizedBox(height: 12),
                    ] else if (state.mode ==
                        AdministrativeAdjustmentMode.fixed) ...[
                      const Text(
                        'المبلغ المحدد (جنيه سوداني)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('decision_fixed_amount_field'),
                        keyboardType:
                            const TextInputAnimationType(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'مثال: 100.00',
                          suffixText: 'SDG',
                          filled: true,
                          fillColor: AppTheme.surface02,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                        onChanged: cubit.setFixedAmount,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Reason Field
                    const Text(
                      'سبب القرار (إلزامي)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('decision_reason_field'),
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'اكتب سبب القرار الإداري الموثق...',
                        helperText: 'يجب ألا يقل عن 3 أحرف',
                        filled: true,
                        fillColor: AppTheme.surface02,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      onChanged: cubit.setReason,
                    ),
                    const SizedBox(height: 12),

                    // Preview Result if available
                    if (state.preview != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'القيمة المحسوبة:',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${state.preview!.amount.amount} ${state.preview!.amount.currency}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Action buttons
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            cubit.clearSelection();
                            Navigator.of(context).pop();
                          },
                          child: const Text('إلغاء'),
                        ),
                        if (state.mode != AdministrativeAdjustmentMode.waived) ...[
                          OutlinedButton(
                            key: const Key('decision_preview_btn'),
                            onPressed: state.isDecisionValid &&
                                    state.outcome !=
                                        ReconciliationActionOutcome.previewing
                                ? () => cubit.previewAdjustment()
                                : null,
                            child: state.outcome ==
                                    ReconciliationActionOutcome.previewing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('معاينة الحساب'),
                          ),
                        ],
                        ElevatedButton.icon(
                          key: const Key('decision_submit_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            minimumSize: const Size(110, 44),
                          ),
                          onPressed: state.isDecisionValid &&
                                  (state.mode ==
                                          AdministrativeAdjustmentMode.waived ||
                                      state.preview != null) &&
                                  state.outcome !=
                                      ReconciliationActionOutcome.saving
                              ? () => cubit.submitDecision()
                              : null,
                          icon: state.outcome ==
                                  ReconciliationActionOutcome.saving
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
                            state.outcome == ReconciliationActionOutcome.saving
                                ? 'جارٍ الحفظ…'
                                : item.isLateArrivalProposal
                                    ? (state.mode ==
                                            AdministrativeAdjustmentMode.waived
                                        ? 'إعفاء التأخير'
                                        : 'اعتماد الخصم')
                                    : (state.mode ==
                                            AdministrativeAdjustmentMode.waived
                                        ? 'إعفاء المخالفة'
                                        : 'حفظ القرار'),
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

  Widget _fractionChip(
    ReconciliationQuickActionsCubit cubit,
    ReconciliationQuickActionsState state,
    String value,
    String label,
  ) {
    final isSelected = state.units == value;
    return ChoiceChip(
      key: Key('fraction_chip_$value'),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => cubit.setUnits(value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class TextInputAnimationType extends TextInputType {
  const TextInputAnimationType({super.signed, super.decimal}) : super.numberWithOptions();
}
