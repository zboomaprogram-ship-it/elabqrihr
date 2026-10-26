import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';
import '../cubit/clearance_case_detail_cubit.dart';

class ResignationClearanceDetailScreen extends StatelessWidget {
  final String operationId;

  const ResignationClearanceDetailScreen({
    super.key,
    required this.operationId,
  });

  static Route<void> route({
    required String operationId,
    required HrOperationsRepository repository,
  }) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => ClearanceCaseDetailCubit(repository: repository)
          ..loadDetail(operationId),
        child: ResignationClearanceDetailScreen(operationId: operationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إخلاء الطرف وإنهاء الخدمة'),
          centerTitle: true,
        ),
        body: BlocConsumer<ClearanceCaseDetailCubit, ClearanceCaseDetailState>(
          listener: (context, state) {
            if (state is ClearanceCaseDetailLoaded &&
                state.actionSuccessMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionSuccessMessage!),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }
          },
          builder: (context, state) {
            return switch (state) {
              ClearanceCaseDetailInitial() ||
              ClearanceCaseDetailLoading() =>
                const Center(child: CircularProgressIndicator()),
              ClearanceCaseDetailForbidden(:final message) =>
                _buildMessageState(
                  icon: Icons.lock_outline_rounded,
                  title: 'غير مصرح لك بالاطلاع',
                  message: message,
                ),
              ClearanceCaseDetailError(:final message) => _buildMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'تعذر تحميل بيانات إخلاء الطرف',
                  message: message,
                  onRetry: () => context
                      .read<ClearanceCaseDetailCubit>()
                      .loadDetail(operationId),
                ),
              ClearanceCaseDetailLoaded(:final detail, :final actionError) =>
                _buildContent(context, detail, actionError),
            };
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    HrOperationDetail detail,
    String? actionError,
  ) {
    final resignation = detail.resignation;
    final clearance = detail.clearance;
    final dateFormat = DateFormat('yyyy/MM/dd');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (actionError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.errorColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actionError,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Resignation Context Card
          AttendCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      detail.employeeName != null
                          ? 'الموظف: ${detail.employeeName}'
                          : 'طلب استقالة وإخلاء طرف',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    _buildStateBadge(detail.state),
                  ],
                ),
                const SizedBox(height: 8),
                if (resignation != null) ...[
                  Text(
                    'آخر يوم عمل مطلوب: ${dateFormat.format(resignation.requestedLastWorkingDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'فترة الإشعار النظامية: ${resignation.noticeDays} يوماً',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const Divider(height: 16),
                const Text(
                  'تظل حالة التوظيف والصلاحيات نشطة حتى إتمام كافة بنود إخلاء الطرف واعتماد المخالصة النهائية من الإدارة.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clearance Progress Card
          if (clearance != null) ...[
            AttendCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'تقدم تسليم العهد وتبرئة الذمة',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${clearance.completedCount} من ${clearance.items.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: clearance.items.isEmpty
                          ? 0
                          : clearance.completedCount / clearance.items.length,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (clearance.mandatoryOutstandingCount > 0)
                    Text(
                      'متبقي ${clearance.mandatoryOutstandingCount} بند إلزامي معلق لا يمكن إنهاء الخدمة بدونه.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Text(
                      'تم استيفاء جميع البنود الإلزامية بنجاح.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Items List
            AttendCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'قائمة بنود تسليم العهد (حسب الأقسام)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Divider(height: 20),
                  ...clearance.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: item.isCompleted
                                  ? AppTheme.successColor.withValues(alpha: 0.3)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: item.isCompleted
                                        ? AppTheme.successColor
                                        : AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.titleAr,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: item.isCompleted
                                                ? AppTheme.textSecondary
                                                : AppTheme.textPrimary,
                                            decoration: item.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        if (item.assigneeLabel != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'المسؤول: ${item.assigneeLabel}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  _buildItemStateChip(item.state),
                                ],
                              ),
                              if (detail.canDecideClearance &&
                                  !item.isCompleted) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final cubit = context
                                          .read<ClearanceCaseDetailCubit>();
                                      cubit.decideItem(
                                        caseId: clearance.id,
                                        itemId: item.id,
                                        commandId: const Uuid().v4(),
                                        expectedRevision: item.revision,
                                        action: 'complete',
                                        reason: 'تم استلام العهدة والتأكد من سلامتها',
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                    ),
                                    child: const Text('تأكيد الاستلام'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Finalize Button
            if (detail.canFinalizeClearance &&
                clearance.mandatoryOutstandingCount == 0 &&
                !clearance.isReadyOrCompleted) ...[
              ElevatedButton.icon(
                onPressed: () {
                  final cubit = context.read<ClearanceCaseDetailCubit>();
                  cubit.finalizeClearance(
                    caseId: clearance.id,
                    commandId: const Uuid().v4(),
                    expectedRevision: clearance.revision,
                    reason: 'اكتمال جميع بنود إخلاء الطرف المعتمدة',
                  );
                },
                icon: const Icon(Icons.verified_rounded),
                label: const Text('اعتماد إخلاء الطرف النهائي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStateBadge(String state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state == 'clearance_completed' ? 'تمت المخالصة' : 'قيد المتابعة',
        style: const TextStyle(
          color: AppTheme.primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildItemStateChip(String state) {
    final (color, label) = switch (state) {
      'completed' => (AppTheme.successColor, 'مكتمل'),
      'waived' => (Colors.blueGrey, 'معفى'),
      'blocked' => (AppTheme.errorColor, 'معطل'),
      'in_progress' => (Colors.orange, 'جاري'),
      _ => (Colors.grey, 'معلق'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
