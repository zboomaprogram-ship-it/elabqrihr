import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/manual_attendance_models.dart';
import '../../domain/manual_attendance_repository.dart';
import '../cubit/reconciliation_quick_actions_cubit.dart';
import '../cubit/reconciliation_quick_actions_state.dart';
import 'reconciliation_decision_dialog.dart';

class ReconciliationQueueSheet extends StatelessWidget {
  const ReconciliationQueueSheet({super.key});

  static Future<void> show(BuildContext context) {
    ManualAttendanceRepository? repo;
    try {
      repo = context.read<ManualAttendanceRepository>();
    } catch (_) {}
    if (repo == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => ReconciliationQuickActionsCubit(repository: repo!)
          ..loadItems()
          ..loadOpenCycles(),
        child: const ReconciliationQueueSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: BlocBuilder<ReconciliationQuickActionsCubit,
            ReconciliationQuickActionsState>(
          builder: (context, state) {
            final cubit = context.read<ReconciliationQuickActionsCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top notch
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.steel.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rule_folder_outlined,
                            color: AppTheme.primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'تسوية استثناءات الحضور',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: const Key('refresh_reconciliation_btn'),
                          icon: const Icon(Icons.refresh),
                          onPressed: () => cubit.loadItems(),
                          tooltip: 'تحديث',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'راجع الاستثناءات وقرر الإعفاء أو الخصم بدقة دون تعديل بصمات الحضور الأصلية.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),

                // Error alert
                if (state.errorMessage != null &&
                    state.outcome != ReconciliationActionOutcome.idle)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(
                          color: AppTheme.errorColor, fontSize: 13),
                    ),
                  ),

                // Items list
                Expanded(
                  child: state.outcome ==
                          ReconciliationActionOutcome.loadingItems
                      ? const Center(child: CircularProgressIndicator())
                      : state.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      size: 48,
                                      color: AppTheme.steel
                                          .withValues(alpha: 0.5)),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'لا توجد مهام تسوية عالقة حالياً',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: state.items.length,
                              itemBuilder: (context, index) {
                                final item = state.items[index];
                                return _ReconciliationItemCard(item: item);
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReconciliationItemCard extends StatelessWidget {
  final DetailedReconciliationItem item;

  const _ReconciliationItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AttendCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.employeeName.isNotEmpty
                      ? item.employeeName
                      : 'موظف (${item.employeeId.substring(0, 8)})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _stateBadge(item.state),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.friendlyReasonDescription,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          if (item.isLateArrivalProposal) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'التأخير بعد السماح: ${item.lateMinutes ?? 0} دقيقة · لم يُخصم شيء بعد.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ),
                  if (item.suggestedDeduction != null)
                    Text(
                      'مقترح: ${item.suggestedDeduction!.units} س',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'التاريخ: ${item.businessDate} · المحاولات: ${item.attempts}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                ),
              ),
              const SizedBox(width: 8),
              if (item.state != 'resolved')
                ElevatedButton(
                  key: Key('reconcile_item_btn_${item.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: const Size(90, 36),
                  ),
                  onPressed: () {
                    ReconciliationDecisionDialog.show(
                      context,
                      item: item,
                      onSaved: () {
                        context
                            .read<ReconciliationQuickActionsCubit>()
                            .loadItems();
                      },
                    );
                  },
                  child: Text(
                    item.isLateArrivalProposal
                        ? 'معالجة المقترح'
                        : 'معالجة الاستثناء',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stateBadge(String state) {
    final (label, color) = switch (state) {
      'queued' => ('في الانتظار', Colors.amber),
      'running' => ('قيد المعالجة', Colors.blue),
      'resolved' => ('تمت المعالجة', AppTheme.successColor),
      'conflicted' => ('تعارض يحتاج مراجعة', Colors.orange),
      'failed' => ('فشلت المحاولة', AppTheme.errorColor),
      'exhausted' => ('استنفدت المحاولات', AppTheme.errorColor),
      _ => (state, AppTheme.steel),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
