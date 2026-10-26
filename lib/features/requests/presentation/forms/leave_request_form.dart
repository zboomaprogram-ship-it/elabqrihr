import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/motion_feedback_sheets.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';

class LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSuccess;

  const LeaveRequestForm({super.key, required this.onSuccess});

  @override
  State<LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  String? _categoryId;
  List<LeaveBalanceEntity> _balances = const [];

  @override
  void initState() {
    super.initState();
    context.read<RequestFormCubit>().loadBalances();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestFormCubit, RequestFormState>(
      listener: (context, state) async {
        if (state is RequestFormSuccess) {
          if (!state.isQueuedOffline) {
            await MotionFeedbackSheets.showRequestSubmitted(
              context,
              title: AppStringsAr.requestSubmittedSuccess,
              subtitle:
                  'تم استلام طلب الإجازة بنجاح وسيتم إشعاره للمراجع المختص',
            );
          } else {
            await MotionFeedbackSheets.showOfflineQueued(
              context,
              title: 'حُفظ الطلب للمزامنة لاحقاً',
              subtitle: AppStringsAr.offlineRequestSavedNotice,
            );
          }
          if (mounted) widget.onSuccess();
        } else if (state is RequestFormError) {
          final message = state.isConflict
              ? AppStringsAr.duplicateRequestConflictNotice
              : state.message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.coral),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is RequestFormSubmitting;
        if (state is RequestFormInitial) {
          _balances = state.balances;
        }
        if (_categoryId == null && _balances.isNotEmpty) {
          _categoryId = _balances.first.categoryId;
        }
        final hasCategories = _balances.isNotEmpty;

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildBalanceBanner(state),
              if (state is RequestFormInitial && state.balancesLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (state is RequestFormInitial &&
                  !state.balancesLoading &&
                  state.balances.isEmpty)
                _buildMissingBalances(state.balanceError),
              const SizedBox(height: 16),
              const Text(
                AppStringsAr.leaveTypeTitle,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkInk),
              ),
              const SizedBox(height: 16),
              // Category Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                dropdownColor: AppTheme.surface01,
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'نوع الإجازة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                items: _balances
                    .map((b) => DropdownMenuItem(
                          value: b.categoryId,
                          child: Text(
                            b.categoryName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: hasCategories
                    ? (val) {
                        if (val != null) setState(() => _categoryId = val);
                      }
                    : null,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'يرجى اختيار نوع الإجازة';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Date range pickers
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      label: AppStringsAr.startDate,
                      selectedDate: _startDate,
                      onPicked: (d) => setState(() {
                        _startDate = d;
                        if (_endDate.isBefore(_startDate)) {
                          _endDate = _startDate;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDatePicker(
                      label: AppStringsAr.endDate,
                      selectedDate: _endDate,
                      onPicked: (d) => setState(() => _endDate = d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Reason field
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: AppStringsAr.reasonFieldLabel,
                  hintText: 'اكتب سبب طلب الإجازة بالتفصيل...',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return AppStringsAr.reasonRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Submit button (minimum 48 height satisfies >=44px)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading || !hasCategories ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(AppStringsAr.submitRequest,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceBanner(RequestFormState state) {
    if (_balances.isNotEmpty) {
      final bal = _balances.first;
      final days = (bal.balanceMinutes / 480).toStringAsFixed(1);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.secondary),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              '${AppStringsAr.leaveBalance}: $days يوم (${bal.balanceMinutes} دقيقة)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.darkInk),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMissingBalances(String? error) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              error ?? 'لا توجد أنواع إجازات متاحة لهذا الحساب حالياً.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.read<RequestFormCubit>().loadBalances(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تحميل الأرصدة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime selectedDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          DateFormat('yyyy-MM-dd').format(selectedDate),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

      context.read<RequestFormCubit>().submitLeaveRequest(
            categoryId: _categoryId ?? '',
            startDate: startStr,
            endDate: endStr,
            reason: _reasonController.text.trim(),
          );
    }
  }
}
