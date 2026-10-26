import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_request_state.dart';

class AdvanceRequestScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AdvanceRequestScreen({super.key, this.onSuccess});

  @override
  State<AdvanceRequestScreen> createState() => _AdvanceRequestScreenState();
}

class _AdvanceRequestScreenState extends State<AdvanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  int _installmentCount = 3;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onPreviewPressed() {
    if (!_formKey.currentState!.validate()) return;
    final text = _amountController.text.trim();
    final formatted = text.contains('.') ? text : '$text.00';
    context.read<AdvanceRequestCubit>().previewEligibility(
          amount: formatted,
          installmentCount: _installmentCount,
        );
  }

  void _onSubmitPressed() {
    if (_reasonController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ذكر سبب السلفة (3 أحرف على الأقل)')),
      );
      return;
    }
    context
        .read<AdvanceRequestCubit>()
        .submitAdvance(reason: _reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلب سلفة راتب جديدة'),
          centerTitle: true,
        ),
        body: BlocConsumer<AdvanceRequestCubit, AdvanceRequestState>(
          listener: (context, state) {
            if (state is AdvanceRequestSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'تم تقديم طلب السلفة بنجاح وهو الآن قيد المراجعة والاعتماد.'),
                  backgroundColor: Colors.green,
                ),
              );
              widget.onSuccess?.call();
              Navigator.of(context).pop(true);
            } else if (state is AdvanceRequestError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: state.isConflict
                      ? Colors.orange.shade800
                      : theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            final isSubmitting = state is AdvanceRequestSubmitting;
            final isPreviewing = state is AdvanceRequestPreviewing;
            final previewLoaded =
                state is AdvanceRequestPreviewLoaded ? state : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'بيانات السلفة المطلوبة',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('advance-amount-field'),
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المطلوب (SDG)',
                        hintText: 'مثال: 50000.00',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'يرجى إدخال مبلغ السلفة';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'يرجى إدخال مبلغ صحيح أكبر من الصفر';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: const Key('advance-installments-dropdown'),
                      initialValue: _installmentCount,
                      decoration: const InputDecoration(
                        labelText: 'عدد الأقساط الشهرية',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1} شهر'),
                        ),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _installmentCount = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      key: const Key('advance-preview-button'),
                      onPressed: isPreviewing || isSubmitting
                          ? null
                          : _onPreviewPressed,
                      icon: isPreviewing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: const Text('معاينة الأهلية والجدول المؤقت'),
                    ),
                    const SizedBox(height: 20),
                    if (previewLoaded != null) ...[
                      _buildPreviewCard(previewLoaded, theme),
                      const SizedBox(height: 20),
                    ],
                    if (previewLoaded?.preview.eligible == true) ...[
                      TextFormField(
                        key: const Key('advance-reason-field'),
                        controller: _reasonController,
                        maxLines: 3,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'سبب طلب السلفة (إلزامي)',
                          hintText: 'اذكر سبب طلب السلفة بالتفصيل...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('advance-submit-button'),
                        onPressed: isSubmitting ? null : _onSubmitPressed,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('تأكيد وتقديم طلب السلفة'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
      AdvanceRequestPreviewLoaded loaded, ThemeData theme) {
    final preview = loaded.preview;
    final isEligible = preview.eligible;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEligible ? Colors.green.shade600 : Colors.orange.shade800,
        ),
      ),
      color:
          isEligible ? Colors.green.withAlpha(20) : Colors.orange.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEligible ? Icons.check_circle : Icons.warning_amber,
                  color: isEligible
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview.localizedReasonText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isEligible
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (isEligible && preview.provisionalSchedule.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'الجدول المالي المؤقت للأقساط (تقديري)',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...preview.provisionalSchedule.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'القسط #${item.sequence} (استحقاق: ${item.dueDate})',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        item.amount.display,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تنبيه: يبدأ استقطاع الأقساط فقط بعد اكتمال الصرف الفعلي من المالية.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
