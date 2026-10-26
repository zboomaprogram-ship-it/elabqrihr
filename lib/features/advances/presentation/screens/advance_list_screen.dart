import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_state.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_request_screen.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_detail_screen.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

class AdvanceListScreen extends StatefulWidget {
  const AdvanceListScreen({super.key});

  @override
  State<AdvanceListScreen> createState() => _AdvanceListScreenState();
}

class _AdvanceListScreenState extends State<AdvanceListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<AdvanceListCubit>().load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<AdvanceListCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السلف المالية'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('request-advance-fab'),
        onPressed: () async {
          final repo = context.read<AdvanceEligibilityRepository>();
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => AdvanceRequestCubit(repository: repo),
                child: const AdvanceRequestScreen(),
              ),
            ),
          );
          if (result == true && context.mounted) {
            context.read<AdvanceListCubit>().load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('طلب سلفة جديدة'),
      ),
      body: BlocBuilder<AdvanceListCubit, AdvanceListState>(
        builder: (context, state) {
          return switch (state) {
            AdvanceListInitial() ||
            AdvanceListLoading() =>
              const RequestListSkeleton(),
            AdvanceListEmpty() => _buildEmpty(context),
            AdvanceListDenied() => _buildDenied(context),
            AdvanceListError(:final message) => _buildError(context, message),
            AdvanceListLoaded(
              :final items,
              :final isLoadingMore,
            ) =>
              _buildList(context, items, isLoadingMore),
          };
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<AdvanceEntity> items,
    bool isLoadingMore,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                semanticsLabel: 'جارٍ تحميل المزيد من السلف',
              ),
            ),
          );
        }
        return _AdvanceCard(
          advance: items[i],
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AdvanceDetailScreen(advance: items[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'لا توجد سلف مالية مسجلة',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'لا توجد سلف مالية مسجلة',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenied(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'غير مصرح بالوصول إلى بيانات السلف',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'غير مصرح لك بعرض بيانات السلف',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'تعذّر تحميل بيانات السلف',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'خطأ في الاتصال بالإنترنت. يرجى إعادة المحاولة.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('advance_list_retry_button'),
              onPressed: () => context.read<AdvanceListCubit>().retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvanceCard extends StatelessWidget {
  final AdvanceEntity advance;
  final VoidCallback onTap;

  const _AdvanceCard({required this.advance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (chipColor, chipBg) = switch (advance.state) {
      AdvanceLifecycleState.settled => (
          Colors.green,
          Colors.green.withValues(alpha: 0.15)
        ),
      AdvanceLifecycleState.collecting || AdvanceLifecycleState.disbursed => (
          Colors.blue,
          Colors.blue.withValues(alpha: 0.15)
        ),
      AdvanceLifecycleState.approved ||
      AdvanceLifecycleState.pendingApproval ||
      AdvanceLifecycleState.submitted =>
        (Colors.orange, Colors.orange.withValues(alpha: 0.15)),
      AdvanceLifecycleState.rejected ||
      AdvanceLifecycleState.cancelled ||
      AdvanceLifecycleState.reversed =>
        (Colors.red, Colors.red.withValues(alpha: 0.15)),
    };

    final semanticsText = 'سلفة مالية، الحالة: ${advance.state.arabicLabel}، '
        'المبلغ الأصلي: ${advance.principal.display}، '
        'المبلغ المسدد: ${advance.postedAmount.display}، '
        'الرصيد المتبقي: ${advance.remainingBalance.display}';

    return Semantics(
      label: semanticsText,
      child: Card(
        key: Key('advance_card_${advance.id}'),
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row: State chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'سلفة مالية',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        advance.state.arabicLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: chipColor,
                        ),
                      ),
                      backgroundColor: chipBg,
                      side: BorderSide(color: chipColor),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Principal row
                _AmountRow(
                  label: 'المبلغ الأصلي',
                  amount: advance.principal.display,
                ),

                // Posted / Repaid amount row
                _AmountRow(
                  label: 'المبلغ المسدد',
                  amount: advance.postedAmount.display,
                ),

                const SizedBox(height: 4),

                // Remaining balance row (server authoritative amount)
                _AmountRow(
                  label: 'الرصيد المتبقي',
                  amount: advance.remainingBalance.display,
                  isBold: true,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isBold;
  final Color? color;

  const _AmountRow({
    required this.label,
    required this.amount,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: color,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(amount, style: style),
        ],
      ),
    );
  }
}
