import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/rtl_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/design_system/app_theme.dart';
import '../../../../core/design_system/widgets/wolf_card.dart';
import '../../../../core/design_system/widgets/skeleton_loaders.dart';
import '../../domain/dynamic_request_models.dart';
import '../attachment_picker_service.dart';
import '../cubit/financial_request_cubit.dart';
import '../cubit/financial_request_state.dart';
import '../dynamic_form_builder.dart';

class FinancialRequestScreen extends StatefulWidget {
  final FinancialRequestCubit? cubit;
  final AttachmentPickerService? attachmentPicker;
  final RequestTypeCategory? initialCategory;

  const FinancialRequestScreen({
    super.key,
    this.cubit,
    this.attachmentPicker,
    this.initialCategory,
  });

  @override
  State<FinancialRequestScreen> createState() => _FinancialRequestScreenState();
}

class _FinancialRequestScreenState extends State<FinancialRequestScreen> {
  RequestTypeCategory? _selectedCategory;
  Map<String, dynamic>? _lastSubmittedValues;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    final activeCubit = widget.cubit ?? context.read<FinancialRequestCubit>();
    activeCubit.loadCatalog();
  }

  void _submitForm(Map<String, dynamic> values, FinancialRequestCubit cubit) {
    if (_selectedCategory == null) return;
    _lastSubmittedValues = values;
    cubit.submitRequest(
      typeKey: _selectedCategory!.key,
      definitionVersionId: _selectedCategory!.id,
      values: values,
      offlineEligible: _selectedCategory!.offlineEligible,
    );
  }

  void _retryLastSubmission(FinancialRequestCubit cubit) {
    if (_selectedCategory != null && _lastSubmittedValues != null) {
      cubit.submitRequest(
        typeKey: _selectedCategory!.key,
        definitionVersionId: _selectedCategory!.id,
        values: _lastSubmittedValues!,
        offlineEligible: _selectedCategory!.offlineEligible,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCubit = widget.cubit ?? context.read<FinancialRequestCubit>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          title: Text(
            _selectedCategory == null
                ? 'الطلبات المالية'
                : _selectedCategory!.nameAr,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          centerTitle: true,
          leading: _selectedCategory != null && widget.initialCategory == null
              ? IconButton(
                  key: const Key('financial_form_back_button'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _lastSubmittedValues = null;
                    });
                    activeCubit.loadCatalog();
                  },
                )
              : null,
        ),
        body: BlocBuilder<FinancialRequestCubit, FinancialRequestState>(
          bloc: activeCubit,
          builder: (context, state) {
            if (_selectedCategory != null) {
              return _buildFormView(context, state, activeCubit);
            }

            return switch (state) {
              FinancialRequestInitial() ||
              FinancialRequestLoading() =>
                const RequestListSkeleton(),
              FinancialRequestEmpty() => _buildEmpty(context),
              FinancialRequestDenied(:final message) =>
                _buildDenied(context, message),
              FinancialRequestError(:final message) =>
                _buildError(context, message, activeCubit),
              FinancialRequestCatalogLoaded(:final categories) =>
                _buildCatalogList(context, categories),
              _ => const RequestListSkeleton(),
            };
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AttendCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 56, color: AppTheme.textMuted),
              SizedBox(height: 16),
              Text(
                'لا توجد طلبات مالية معتمدة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'لم تقم الشركة بنشر نماذج طلبات مالية متاحة لك حالياً.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDenied(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AttendCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: AppTheme.coral),
              const SizedBox(height: 16),
              const Text(
                'غير مصرح بالوصول',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message.isNotEmpty
                    ? message
                    : 'غير مصرح لك بعرض أو تقديم الطلبات المالية.',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(
      BuildContext context, String message, FinancialRequestCubit cubit) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AttendCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: AppTheme.coral),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل الطلبات المالية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                key: const Key('financial_request_retry_button'),
                onPressed: () => cubit.loadCatalog(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogList(
      BuildContext context, List<RequestTypeCategory> categories) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AttendCard(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              key: Key('financial_category_${category.key}'),
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                  _lastSubmittedValues = null;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surface03),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.nameAr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (category.descriptionAr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            category.descriptionAr,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(RtlNavigation.forwardIcon(context),
                      size: 16, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormView(
    BuildContext context,
    FinancialRequestState state,
    FinancialRequestCubit cubit,
  ) {
    if (state is FinancialRequestDenied) {
      return _buildDenied(context, state.message);
    }

    if (state is FinancialRequestSubmitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AttendCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 64, color: AppTheme.successColor),
                const SizedBox(height: 16),
                const Text(
                  'تم إرسال الطلب المالي بنجاح',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'الطلب رقم: ${state.request.id}',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تم توثيق طلبك في سجلات الشركة وسيتم مراجعته وتدقيقه من قبل الإدارة المالية وفق سياسات الرواتب المعتمدة.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('financial_success_back_button'),
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _lastSubmittedValues = null;
                    });
                    cubit.loadCatalog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('العودة إلى قائمة الطلبات'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isSubmitting = state is FinancialRequestSubmitting;
    final errorMessage = state is FinancialRequestError && state.isSubmitting
        ? state.message
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AttendCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                Icon(Icons.info_outline,
                    color: AppTheme.primaryColor, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الطلبات المالية تخضع للتدقيق والاعتماد المالي المباشر عبر الخادم، ولا يتم تطبيق أو احتساب أي تسويات للراتب محلياً.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (errorMessage != null) ...[
            AttendCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.coral, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.coral),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('financial_form_retry_button'),
                      onPressed: () => _retryLastSubmission(cubit),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('إعادة المحاولة'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.coral,
                        side: const BorderSide(color: AppTheme.coral),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          DynamicFormBuilder(
            fields: _selectedCategory!.fields,
            definitionVersionId: _selectedCategory!.id,
            isSubmitting: isSubmitting,
            attachmentPicker: widget.attachmentPicker,
            onSubmit: (values) => _submitForm(values, cubit),
          ),
        ],
      ),
    );
  }
}
