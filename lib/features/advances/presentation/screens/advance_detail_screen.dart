import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_detail_cubit.dart';

class AdvanceDetailScreen extends StatelessWidget {
  final AdvanceEntity advance;

  const AdvanceDetailScreen({super.key, required this.advance});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdvanceDetailCubit()..show(advance),
      child: const _AdvanceDetailView(),
    );
  }
}

class _AdvanceDetailView extends StatelessWidget {
  const _AdvanceDetailView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل السلفة')),
        body: BlocBuilder<AdvanceDetailCubit, AdvanceDetailState>(
          builder: (context, state) => switch (state) {
            AdvanceDetailInitial() =>
              const Center(child: CircularProgressIndicator()),
            AdvanceDetailLoaded(:final advance) =>
              _AdvanceDetailContent(advance: advance),
          },
        ),
      ),
    );
  }
}

class _AdvanceDetailContent extends StatelessWidget {
  final AdvanceEntity advance;

  const _AdvanceDetailContent({required this.advance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectionStarted =
        advance.state == AdvanceLifecycleState.disbursed ||
            advance.state == AdvanceLifecycleState.collecting ||
            advance.state == AdvanceLifecycleState.settled;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(advance.state.arabicLabel,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                _AmountLine(
                    label: 'المبلغ الأصلي', value: advance.principal.display),
                _AmountLine(
                    label: 'المبلغ المسدد',
                    value: advance.postedAmount.display),
                _AmountLine(
                  label: 'الرصيد المتبقي',
                  value: advance.remainingBalance.display,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('مسار الاعتماد', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ...advance.approvalRoute.map((stage) {
                  final complete = stage.role == 'hr'
                      ? advance.hrReviewed
                      : stage.role == 'finance'
                          ? advance.financeReviewed
                          : false;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      complete ? Icons.check_circle : Icons.schedule,
                      color: complete ? Colors.green : Colors.orange,
                    ),
                    title: Text(stage.arabicLabel),
                    subtitle: Text(complete ? 'اكتملت' : 'بانتظار المراجعة'),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('جدول الأقساط', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (!collectionStarted)
                  const Text(
                    'لن يبدأ أي استقطاع قبل تسجيل الصرف الفعلي واعتماده.',
                    key: Key('advance-no-collection-before-disbursement'),
                  )
                else if (advance.installmentSchedule.isEmpty)
                  const Text('لا يوجد جدول أقساط متاح حالياً.')
                else
                  ...advance.installmentSchedule.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('القسط ${item.sequence}'),
                      subtitle: Text('تاريخ الاستحقاق: ${item.dueDate}'),
                      trailing: Text(item.amount.display),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AmountLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: emphasized ? FontWeight.bold : null),
          ),
        ],
      ),
    );
  }
}
