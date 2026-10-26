import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';
import '../cubit/disciplinary_case_detail_cubit.dart';
import '../widgets/grievance_submission_dialog.dart';

class DisciplinaryCaseDetailScreen extends StatelessWidget {
  final String operationId;

  const DisciplinaryCaseDetailScreen({
    super.key,
    required this.operationId,
  });

  static Route<void> route({
    required String operationId,
    required HrOperationsRepository repository,
  }) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => DisciplinaryCaseDetailCubit(repository: repository)
          ..loadDetail(operationId),
        child: DisciplinaryCaseDetailScreen(operationId: operationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الإجراء الإداري'),
          centerTitle: true,
        ),
        body: BlocConsumer<DisciplinaryCaseDetailCubit,
            DisciplinaryCaseDetailState>(
          listener: (context, state) {
            if (state is DisciplinaryCaseDetailLoaded &&
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
              DisciplinaryCaseDetailInitial() ||
              DisciplinaryCaseDetailLoading() =>
                const Center(child: CircularProgressIndicator()),
              DisciplinaryCaseDetailForbidden(:final message) =>
                _buildMessageState(
                  icon: Icons.lock_outline_rounded,
                  title: 'إشعار خاص ومحمي',
                  message: message,
                ),
              DisciplinaryCaseDetailError(:final message) => _buildMessageState(
                  icon: Icons.error_outline_rounded,
                  title: 'تعذر تحميل الإجراء',
                  message: message,
                  onRetry: () => context
                      .read<DisciplinaryCaseDetailCubit>()
                      .loadDetail(operationId),
                ),
              DisciplinaryCaseDetailLoaded(:final detail, :final actionError) =>
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
    final disciplinary = detail.disciplinary;
    final dateFormat = DateFormat('yyyy/MM/dd · hh:mm a');

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

          // Case Summary Card
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
                      disciplinary?.policyTitle ?? 'إشعار إداري رسمي',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    _buildConsequenceBadge(disciplinary?.consequenceState),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تاريخ القيد: ${dateFormat.format(detail.submittedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (disciplinary?.incidentAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'تاريخ الواقعة المنسوبة: ${dateFormat.format(disciplinary!.incidentAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Acknowledgment Card (Receipt Only Semantics)
          AttendCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined,
                        color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إقرار الاستلام والعلم',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                const Text(
                  'تأكيد الاستلام يُعد إقراراً بالعلم بالواقعة فقط، ولا يعني بالضرورة الإقرار بصحة المنسوب أو التنازل عن حق التظلم القانوني المكفول للموظف.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                if (disciplinary?.isAcknowledged == true) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تم تسجيل الاستلام بالعلم فقط (لا يعد اعترافاً بالمسؤولية).',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (detail.canAcknowledge) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      final cubit = context.read<DisciplinaryCaseDetailCubit>();
                      cubit.acknowledgeNotice(
                        operationId: detail.id,
                        commandId: const Uuid().v4(),
                        expectedRevision: detail.revision,
                        noticeRevision: disciplinary?.noticeRevision ?? 1,
                      );
                    },
                    icon: const Icon(Icons.touch_app_outlined),
                    label: const Text('تأكيد العلم والاستلام (استلام فقط)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grievance / Appeal Card
          AttendCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'التظلمات والالتماسات الإدارية',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (disciplinary?.grievanceDueAt != null) ...[
                  Text(
                    'آخر موعد لتقديم التظلم: ${dateFormat.format(disciplinary!.grievanceDueAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (disciplinary?.grievances.isNotEmpty == true) ...[
                  const Text(
                    'التظلمات المقدمة مسبقاً:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...disciplinary!.grievances.map((g) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.description_outlined,
                                  size: 16, color: AppTheme.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  g.statement ?? 'تظلم رسمي مسجل',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              _buildGrievanceStateChip(g.state),
                            ],
                          ),
                        ),
                      )),
                ] else ...[
                  const Text(
                    'لم يتم تقديم أي تظلم حتى الآن.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (detail.canGrievance) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final cubit = context.read<DisciplinaryCaseDetailCubit>();
                      await showDialog<bool>(
                        context: context,
                        builder: (_) => GrievanceSubmissionDialog(
                          operationId: detail.id,
                          expectedRevision: detail.revision,
                          onSubmit: ({
                            required commandId,
                            required expectedRevision,
                            required statement,
                          }) =>
                              cubit.submitGrievance(
                            operationId: detail.id,
                            commandId: commandId,
                            expectedRevision: expectedRevision,
                            statement: statement,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('تقديم تظلم أو التماس كتابي'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Truthful Consequence Card (Never display proposed as deducted)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الأثر المالي ومسير الرواتب',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _consequenceExplanation(disciplinary?.consequenceState),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Timeline
          if (detail.timeline.isNotEmpty) ...[
            AttendCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المسار الزمني للإجراء',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Divider(height: 20),
                  ...detail.timeline.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.labelAr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${dateFormat.format(item.occurredAt)}${item.actorLabel != null ? ' · ${item.actorLabel}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsequenceBadge(String? state) {
    final (color, label) = switch (state) {
      'proposed' => (
          Colors.orange,
          'مقترح غير مخصوم'
        ),
      'approved' => (AppTheme.errorColor, 'معتمد رسمياً'),
      'waived' => (AppTheme.successColor, 'تم الإعفاء'),
      'superseded' => (Colors.grey, 'مستبدل'),
      _ => (Colors.blueGrey, 'لا يوجد أثر مالي'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGrievanceStateChip(String state) {
    final (color, label) = switch (state) {
      'submitted' || 'under_review' => (Colors.orange, 'قيد الدراسة'),
      'accepted' => (AppTheme.successColor, 'مقبول'),
      'rejected' => (AppTheme.errorColor, 'مرفوض'),
      'withdrawn' => (Colors.grey, 'مسحوب'),
      _ => (Colors.blueGrey, state),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _consequenceExplanation(String? state) {
    return switch (state) {
      'proposed' =>
        'مقترح الخصم لا يزال قيد الدراسة الإدارية، ولم يتم خصم أي مبالغ من راتبك حتى تاريخه. لا يُنفذ أي خصم إلا بقرار مالي معتمد لدورة رواتب مفتوحة.',
      'approved' =>
        'تم اعتماد الأثر المالي بقرار رسمي وتم إدراجه ضمن دورة الرواتب المفتوحة.',
      'waived' => 'تم إعفاء الموظف من أي خصم مالي بناءً على القرار الإداري.',
      _ => 'هذا الإشعار الإداري لا يتضمن أي عقوبة أو خصم مالي.',
    };
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
