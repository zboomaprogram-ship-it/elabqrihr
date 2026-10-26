import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_state.dart';

class PayslipDetailScreen extends StatefulWidget {
  final String payslipId;

  const PayslipDetailScreen({super.key, required this.payslipId});

  @override
  State<PayslipDetailScreen> createState() => _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends State<PayslipDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PayslipDetailCubit>().load(widget.payslipId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل كشف الراتب'),
        centerTitle: true,
      ),
      body: BlocBuilder<PayslipDetailCubit, PayslipDetailState>(
        builder: (context, state) => switch (state) {
          PayslipDetailInitial() ||
          PayslipDetailLoading() =>
            const DetailScreenSkeleton(),
          PayslipDetailLoaded(:final payslip) => _buildDetail(context, payslip),
          PayslipDetailDenied() => _buildDenied(context),
          PayslipDetailNotFound() => _buildNotFound(context),
          PayslipDetailError(:final message) => _buildError(context, message),
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, PayslipEntity payslip) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Semantics(
                    label: 'دورة الراتب ${payslip.cycleKey}',
                    child: Text(
                      payslip.cycleKey,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'من ${payslip.periodStart} إلى ${payslip.periodEnd}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _AmountRow(label: 'الإجمالي', money: payslip.gross),
                  _AmountRow(label: 'الخصومات', money: payslip.deductions),
                  const Divider(),
                  _AmountRow(
                    label: 'الصافي',
                    money: payslip.net,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Document download section
          _buildDownloadSection(context, payslip),

          const SizedBox(height: 16),

          // Lines breakdown
          if (payslip.lines.isNotEmpty) ...[
            Text(
              'تفاصيل البنود',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...payslip.lines.map((line) => _PayrollLineTile(line: line)),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadSection(BuildContext context, PayslipEntity payslip) {
    return switch (payslip.documentState) {
      PayslipState.ready when payslip.downloadUrl != null => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.picture_as_pdf, size: 40, color: Colors.green),
                const SizedBox(height: 8),
                const Text('الكشف جاهز للتنزيل'),
                if (payslip.downloadExpiresAt != null)
                  Text(
                    'صالح حتى: ${payslip.downloadExpiresAt!.toLocal().toString().split('.').first}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                // NOTE: downloadUrl is shown but not stored beyond this widget.
                // The actual download must be handled by the OS browser/viewer.
                FilledButton.icon(
                  key: const Key('payslip_download_button'),
                  onPressed: () {
                    // Open URL via platform channel / url_launcher (not stored locally)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('جارٍ فتح الكشف في المتصفح...')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('تنزيل الكشف'),
                ),
              ],
            ),
          ),
        ),
      PayslipState.queued => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'الكشف قيد الإعداد ولم يصبح متاحاً بعد',
                    child: const Text(
                      'يتم إعداد الكشف. سيتوفر قريباً.',
                      key: Key('payslip_queued_message'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      PayslipState.expired => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.timer_off, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'انتهت صلاحية رابط التنزيل',
                    child: const Text(
                      'انتهت صلاحية رابط التنزيل. تواصل مع الموارد البشرية.',
                      key: Key('payslip_expired_message'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      PayslipState.failed => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('تعذّر إنشاء الكشف. تواصل مع الموارد البشرية.'),
                ),
              ],
            ),
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildDenied(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'غير مصرح بالوصول إلى هذا الكشف',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'غير مصرح لك بعرض هذا الكشف',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'كشف الراتب غير موجود',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'كشف الراتب غير موجود',
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
              'تعذّر تحميل تفاصيل الكشف',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'تحقق من الاتصال بالإنترنت وأعد المحاولة.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('payslip_detail_retry_button'),
              onPressed: () =>
                  context.read<PayslipDetailCubit>().retry(widget.payslipId),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final MoneyEntity money;
  final bool isBold;

  const _AmountRow({
    required this.label,
    required this.money,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? Theme.of(context)
            .textTheme
            .bodyLarge!
            .copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: '$label: ${money.display}',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(money.display, style: style),
          ],
        ),
      ),
    );
  }
}

class _PayrollLineTile extends StatelessWidget {
  final PayslipLineEntity line;
  const _PayrollLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (line.kind) {
      PayslipLineKind.earning => (Icons.add_circle_outline, Colors.green),
      PayslipLineKind.deduction || PayslipLineKind.installment => (
          Icons.remove_circle_outline,
          Colors.red
        ),
      PayslipLineKind.adjustment => (Icons.swap_horiz, Colors.blue),
      PayslipLineKind.rounding => (Icons.rounded_corner, Colors.grey),
    };

    return Semantics(
      label: '${line.code}: ${line.amount.display}',
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(line.code),
        trailing: Text(
          line.amount.display,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
