import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/app_theme.dart';
import '../../../../core/design_system/widgets/skeleton_loaders.dart';
import '../../domain/dynamic_request_repository.dart';
import '../cubit/dynamic_request_detail_cubit.dart';

class DynamicRequestDetailScreen extends StatelessWidget {
  const DynamicRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DynamicRequestDetailCubit(
        repository: context.read<DynamicRequestRepository>(),
      )..load(requestId),
      child: const _DynamicRequestDetailView(),
    );
  }
}

class _DynamicRequestDetailView extends StatelessWidget {
  const _DynamicRequestDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: BlocConsumer<DynamicRequestDetailCubit, DynamicRequestDetailState>(
        listener: (context, state) {
          if (state is DynamicRequestDetailCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('تم إلغاء الطلب بنجاح'),
              backgroundColor: AppTheme.mint,
            ));
          }
        },
        builder: (context, state) {
          if (state is DynamicRequestDetailLoading) {
            return const DetailScreenSkeleton();
          }
          if (state is DynamicRequestDetailError) {
            return _ErrorState(message: state.message);
          }
          final request = switch (state) {
            DynamicRequestDetailLoaded(:final request) => request,
            DynamicRequestDetailCancelled(:final request) => request,
            _ => null,
          };
          if (request == null) return const SizedBox.shrink();
          final cancelling =
              state is DynamicRequestDetailLoaded && state.isCancelling;
          final canCancel = request.state == 'submitted' ||
              request.state == 'pending_approval';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.typeNameAr,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _StateLabel(state: request.state),
                    const SizedBox(height: 8),
                    Text(
                        'قُدّم في ${DateFormat('yyyy/MM/dd – HH:mm').format(request.submittedAt.toLocal())}',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                    if (request.reasonCode != null) ...[
                      const SizedBox(height: 8),
                      Text(_reasonLabel(request.reasonCode!),
                          style: const TextStyle(color: AppTheme.coral)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'بيانات الطلب',
                child: Column(
                  children: request.values.entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Text(_label(entry.key),
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary))),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Text(_value(entry.value),
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'مسار الموافقة',
                child: Column(
                  children: request.timeline
                      .map((step) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_timelineIcon(step.state),
                                color: _timelineColor(step.state)),
                            title: Text(
                                step.assignedDisplayName ?? step.assignedRole),
                            subtitle: Text(
                                step.comment ?? _timelineLabel(step.state)),
                            trailing: Text('المرحلة ${step.position}'),
                          ))
                      .toList(),
                ),
              ),
              if (state is DynamicRequestDetailLoaded &&
                  state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(state.errorMessage!,
                    style: const TextStyle(color: AppTheme.coral)),
              ],
              if (canCancel) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: cancelling ? null : () => _askToCancel(context),
                  icon: cancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cancel_outlined),
                  label: const Text('إلغاء الطلب'),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: AppTheme.coral),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _askToCancel(BuildContext context) async {
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('رجوع')),
            ElevatedButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) return;
                Navigator.pop(dialogContext);
                context.read<DynamicRequestDetailCubit>().cancel(reason);
              },
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _label(String value) => value.replaceAll('_', ' ');
  String _value(Object? value) => switch (value) {
        List() => value.join('، '),
        null => '—',
        _ => value.toString()
      };
  String _timelineLabel(String state) => switch (state) {
        'approved' => 'تمت الموافقة',
        'rejected' => 'تم الرفض',
        'pending' => 'بانتظار القرار',
        _ => 'بانتظار المرحلة'
      };
  String _reasonLabel(String code) => switch (code) {
        'VALIDATION_FAILED' => 'تعذر قبول البيانات المدخلة.',
        'CONFLICT_DUPLICATE' => 'تمت معالجة الطلب مسبقاً.',
        'MAX_RETRIES_EXCEEDED' => 'تعذر إرسال الطلب بعد عدة محاولات.',
        'QUEUED_OFFLINE' => 'الطلب محفوظ محلياً وبانتظار الاتصال.',
        _ => 'توجد ملاحظة على هذا الطلب. راجع مسار الموافقة.'
      };
  IconData _timelineIcon(String state) => state == 'approved'
      ? Icons.check_circle_outline
      : state == 'rejected'
          ? Icons.cancel_outlined
          : Icons.schedule_outlined;
  Color _timelineColor(String state) => state == 'approved'
      ? AppTheme.mint
      : state == 'rejected'
          ? AppTheme.coral
          : AppTheme.primary;
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title});
  final String? title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8)
            ],
            child,
          ]),
        ),
      );
}

class _StateLabel extends StatelessWidget {
  const _StateLabel({required this.state});
  final String state;
  @override
  Widget build(BuildContext context) => Text(
        switch (state) {
          'approved' => 'مقبول',
          'rejected' => 'مرفوض',
          'cancelled' => 'ملغى',
          'pending_approval' => 'بانتظار الموافقة',
          'pending_sync' => 'بانتظار المزامنة',
          _ => 'تم الإرسال'
        },
        style: const TextStyle(
            color: AppTheme.primary, fontWeight: FontWeight.w700),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center)));
}
