import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_state.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_detail_screen.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

class PayslipListScreen extends StatefulWidget {
  const PayslipListScreen({super.key});

  @override
  State<PayslipListScreen> createState() => _PayslipListScreenState();
}

class _PayslipListScreenState extends State<PayslipListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<PayslipListCubit>().load();
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
      context.read<PayslipListCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشوف الرواتب'),
        centerTitle: true,
      ),
      body: BlocBuilder<PayslipListCubit, PayslipListState>(
        builder: (context, state) {
          return switch (state) {
            PayslipListInitial() ||
            PayslipListLoading() =>
              const RequestListSkeleton(),
            PayslipListEmpty() => _buildEmpty(context),
            PayslipListDenied() => _buildDenied(context),
            PayslipListError(:final message) => _buildError(context, message),
            PayslipListLoaded(
              :final items,
              :final isLoadingMore,
              :final hasMore,
            ) =>
              _buildList(context, items, isLoadingMore, hasMore),
          };
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<PayslipSummaryEntity> items,
    bool isLoadingMore,
    bool hasMore,
  ) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                semanticsLabel: 'جارٍ تحميل المزيد',
              ),
            ),
          );
        }
        final item = items[i];
        return _PayslipListTile(
          key: ValueKey('payslip_item_${item.id}'),
          payslip: item,
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'لا توجد كشوف رواتب',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'لا توجد كشوف رواتب بعد',
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
        label: 'غير مصرح بالوصول',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'غير مصرح لك بعرض كشوف الرواتب',
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
            const Icon(Icons.error_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'تعذّر تحميل كشوف الرواتب',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'خطأ في الاتصال. تحقق من الإنترنت وأعد المحاولة.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('payslip_list_retry_button'),
              onPressed: () => context.read<PayslipListCubit>().retry(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayslipListTile extends StatelessWidget {
  final PayslipSummaryEntity payslip;

  const _PayslipListTile({super.key, required this.payslip});

  @override
  Widget build(BuildContext context) {
    final stateLabel = switch (payslip.documentState) {
      PayslipState.ready => 'متاح',
      PayslipState.queued => 'قيد الإعداد',
      PayslipState.failed => 'فشل إعداد الملف',
      PayslipState.expired => 'منتهي الصلاحية',
    };

    return Semantics(
      label:
          'كشف راتب ${payslip.cycleKey}، صافي ${payslip.net.display}، الحالة: $stateLabel',
      button: true,
      child: ListTile(
        key: Key('payslip_tile_${payslip.id}'),
        leading: const Icon(Icons.receipt_long),
        title: Text(
          payslip.cycleKey,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإجمالي: ${payslip.gross.display}'),
            Text('الخصومات: ${payslip.deductions.display}'),
            Text('الصافي: ${payslip.net.display}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: _DocumentStateChip(state: payslip.documentState),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider(
              create: (ctx) => PayslipDetailCubit(
                repository: ctx.read<PayslipRepository>(),
              ),
              child: PayslipDetailScreen(payslipId: payslip.id),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentStateChip extends StatelessWidget {
  final PayslipState state;
  const _DocumentStateChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      PayslipState.ready => ('متاح', Colors.green),
      PayslipState.queued => ('قيد الإعداد', Colors.orange),
      PayslipState.failed => ('فشل', Colors.red),
      PayslipState.expired => ('منتهي', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}
