import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import '../../domain/final_settlement_models.dart';
import '../cubit/final_settlement_cubit.dart';

class FinalSettlementStatementScreen extends StatefulWidget {
  final String? settlementId;
  const FinalSettlementStatementScreen({super.key, this.settlementId});
  @override
  State<FinalSettlementStatementScreen> createState() =>
      _FinalSettlementStatementScreenState();
}

class _FinalSettlementStatementScreenState
    extends State<FinalSettlementStatementScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FinalSettlementCubit>().load(widget.settlementId);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(title: const Text('كشف المخالصة النهائية')),
          body: BlocBuilder<FinalSettlementCubit, FinalSettlementState>(
            builder: (context, state) {
              if (state is FinalSettlementInitial ||
                  state is FinalSettlementLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is FinalSettlementEmpty) {
                return const _Message(
                    icon: Icons.receipt_long_outlined,
                    text: 'لا يوجد كشف مخالصة منشور لحسابك حتى الآن.');
              }
              if (state is FinalSettlementFailure) {
                return _Message(
                  icon: Icons.error_outline,
                  text: state.message,
                  action: () => context
                      .read<FinalSettlementCubit>()
                      .load(widget.settlementId),
                );
              }
              final loaded = state as FinalSettlementLoaded;
              final statement = loaded.statement;
              return RefreshIndicator(
                onRefresh: () => context
                    .read<FinalSettlementCubit>()
                    .load(widget.settlementId),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statement.statementNumber,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                                'تاريخ النشر: ${_date(statement.publishedAt)}'),
                            Text(
                                'حالة المستند: ${statement.documentState.arabicLabel}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Total('الاستحقاقات', statement.earningsMinor,
                            statement.currency),
                        _Total('الاستقطاعات', statement.deductionsMinor,
                            statement.currency),
                        _Total('الصافي', statement.netMinor, statement.currency,
                            emphasized: true),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('تفاصيل الحساب',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...statement.lines.map((line) => Card(
                          child: ListTile(
                            title: Text(line.description),
                            subtitle: Text(
                                '${line.type.arabicLabel}${line.ruleReference == null ? '' : ' · ${line.ruleReference}'}'),
                            trailing: Text(
                              '${_money(line.amountMinor)} ${line.currency}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                    const SizedBox(height: 16),
                    Text('مسار الاعتماد',
                        style: Theme.of(context).textTheme.titleMedium),
                    ...statement.decisions.map((decision) => ListTile(
                          leading: const Icon(Icons.verified_outlined,
                              color: AppTheme.successColor),
                          title: Text('المرحلة ${decision.stage}'),
                          subtitle: Text(
                              '${decision.actorDisplayName} · ${_date(decision.decidedAt)}'),
                        )),
                    if (statement.linkedAdjustmentId != null)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.history),
                          title: Text('توجد تسوية مالية لاحقة'),
                          subtitle: Text(
                              'بقي الكشف الأصلي ثابتاً وأضيفت التسوية كسجل مستقل.'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: statement.documentState ==
                              SettlementDocumentState.ready
                          ? context.read<FinalSettlementCubit>().download
                          : null,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('تحميل المستند الخاص'),
                    ),
                    if (loaded.savedPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('تم حفظ نسخة آمنة داخل ملفات التطبيق.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.successColor)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class _Total extends StatelessWidget {
  final String label;
  final int value;
  final String currency;
  final bool emphasized;
  const _Total(this.label, this.value, this.currency,
      {this.emphasized = false});
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 145),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: emphasized ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: emphasized ? Colors.white70 : AppTheme.textSecondary)),
          Text('${_money(value)} $currency',
              style: TextStyle(
                  color: emphasized ? Colors.white : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? action;
  const _Message({required this.icon, required this.text, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppTheme.steel),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: action, child: const Text('إعادة المحاولة')),
            ],
          ]),
        ),
      );
}

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
String _money(int minor) => (minor / 100).toStringAsFixed(2);
