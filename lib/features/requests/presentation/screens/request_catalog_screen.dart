import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/motion_feedback_sheets.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_models.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/dynamic_request_state.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/dynamic_form_builder.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/forms/attendance_correction_form.dart';
import 'package:attend_mobile/features/requests/presentation/forms/leave_request_form.dart';
import 'package:attend_mobile/features/requests/presentation/forms/permission_request_form.dart';

class RequestCatalogScreen extends StatelessWidget {
  final ValueChanged<RequestTypeCategory>? onCategorySelected;

  /// Called after a request was accepted by the server (or safely queued for
  /// offline sync). The owning workspace uses this to return the employee to
  /// their request history and refresh its status list.
  final VoidCallback? onRequestSubmitted;
  final DynamicRequestCubit? cubit;

  const RequestCatalogScreen({
    super.key,
    this.onCategorySelected,
    this.onRequestSubmitted,
    this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final activeCubit = cubit ?? context.read<DynamicRequestCubit>();
    return BlocBuilder<DynamicRequestCubit, DynamicRequestState>(
      bloc: activeCubit,
      buildWhen: (_, state) =>
          state is! DynamicRequestSubmitting &&
          state is! DynamicRequestSubmitted,
      builder: (context, state) {
        if (state is DynamicRequestLoading) {
          return const RequestListSkeleton();
        }

        if (state is DynamicRequestError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: AppTheme.coral),
                  const SizedBox(height: 12),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    key: const Key('catalog_retry_button'),
                    onPressed: () => activeCubit.loadCatalog(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is DynamicRequestCatalogLoaded) {
          return _buildCatalogList(context, state.categories);
        }

        // If in initial state, trigger load and display loading spinner
        activeCubit.loadCatalog();
        return const RequestListSkeleton();
      },
    );
  }

  Widget _buildCatalogList(
    BuildContext context,
    List<RequestTypeCategory> categories,
  ) {
    if (categories.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد تصنيفات طلبات متاحة حالياً',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: AttendCard(
            padding: EdgeInsets.zero,
            child: InkWell(
              key: Key('catalog_category_${category.key}'),
              onTap: () {
                if (onCategorySelected != null) {
                  onCategorySelected!(category);
                } else {
                  _openCategoryForm(context, category);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.surface03),
                    ),
                    child: Icon(_categoryIcon(category.iconKey),
                        color: AppTheme.primaryColor, size: 24),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.nameAr,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (category.descriptionAr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              category.descriptionAr,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 12),
                    child: Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static IconData _categoryIcon(String iconKey) {
    return switch (iconKey) {
      'leave' || 'beach_access' => Icons.calendar_month_outlined,
      'permission' || 'timer' => Icons.access_time_outlined,
      'attendance_correction' || 'fingerprint' => Icons.edit_calendar_outlined,
      _ => Icons.assignment_outlined,
    };
  }

  void _openCategoryForm(BuildContext context, RequestTypeCategory category) {
    // 1. Built-in leave request journey
    if (category.key == 'leave') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text(AppStringsAr.leaveTypeTitle),
              centerTitle: true,
            ),
            body: BlocProvider(
              create: (c) => RequestFormCubit(
                repository: c.read<RequestRepository>(),
              ),
              child: LeaveRequestForm(
                onSuccess: () => _completeSubmission(ctx),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 2. Built-in permission request journey
    if (category.key == 'permission') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text(AppStringsAr.permissionTypeTitle),
              centerTitle: true,
            ),
            body: BlocProvider(
              create: (c) {
                final repo = c.read<RequestRepository>();
                return RequestFormCubit(
                  repository: repo,
                  shiftRepository: repo is EmployeeShiftRepository
                      ? repo as EmployeeShiftRepository
                      : null,
                );
              },
              child: PermissionRequestForm(
                onSuccess: () => _completeSubmission(ctx),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 3. Built-in attendance correction journey
    if (category.key == 'attendance_correction') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text(AppStringsAr.attendanceCorrectionTitle),
              centerTitle: true,
            ),
            body: BlocProvider(
              create: (c) {
                final repo = c.read<RequestRepository>();
                return RequestFormCubit(
                  repository: repo,
                  shiftRepository: repo is EmployeeShiftRepository
                      ? repo as EmployeeShiftRepository
                      : null,
                );
              },
              child: AttendanceCorrectionForm(
                onSuccess: () => _completeSubmission(ctx),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 4. Server-published dynamic request journey
    final activeCubit = cubit ?? context.read<DynamicRequestCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              title: Text(
                category.nameAr,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              centerTitle: true,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: BlocBuilder<DynamicRequestCubit, DynamicRequestState>(
                bloc: activeCubit,
                builder: (context, submissionState) => DynamicFormBuilder(
                  isSubmitting: submissionState is DynamicRequestSubmitting,
                  fields: category.fields,
                  definitionVersionId: category.id,
                  onSubmit: (values) async {
                    await activeCubit.submitRequest(
                      typeKey: category.key,
                      definitionVersionId: category.id,
                      values: values,
                      offlineEligible: category.offlineEligible,
                      typeNameAr: category.nameAr,
                    );
                    if (!ctx.mounted) return;
                    if (activeCubit.state is DynamicRequestSubmitted) {
                      final request =
                          (activeCubit.state as DynamicRequestSubmitted)
                              .request;
                      if (request.state == 'pending_sync') {
                        await MotionFeedbackSheets.showOfflineQueued(
                          ctx,
                          title: 'تم حفظ طلبك على الجهاز',
                          subtitle:
                              'بانتظار المزامنة عند عودة الاتصال. لم يصل الطلب إلى الشركة بعد.',
                        );
                      } else if (request.state == 'conflict' ||
                          request.state == 'rejected' ||
                          request.state == 'processing_failed') {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content:
                              Text('تعذر إرسال الطلب. راجع حالته في طلباتي.'),
                          backgroundColor: AppTheme.coral,
                        ));
                        return;
                      } else {
                        await MotionFeedbackSheets.showRequestSubmitted(
                          ctx,
                          title: 'تم إرسال ${category.nameAr} بنجاح',
                          subtitle: 'تم توثيق طلبك بنجاح في النظام',
                        );
                      }
                      if (ctx.mounted) _completeSubmission(ctx);
                    } else if (activeCubit.state is DynamicRequestError) {
                      final err =
                          (activeCubit.state as DynamicRequestError).message;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: AppTheme.coral,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _completeSubmission(BuildContext routeContext) {
    Navigator.of(routeContext).pop();
    onRequestSubmitted?.call();
  }
}
