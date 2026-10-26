import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';
import '../cubit/field_mission_detail_cubit.dart';
import '../widgets/revoke_mission_dialog.dart';

class FieldMissionDetailScreen extends StatelessWidget {
  final String operationId;

  const FieldMissionDetailScreen({
    super.key,
    required this.operationId,
  });

  static Route<void> route({
    required String operationId,
    required HrOperationsRepository repository,
  }) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => FieldMissionDetailCubit(repository: repository)
          ..loadDetail(operationId),
        child: FieldMissionDetailScreen(operationId: operationId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل مأمورية العمل'),
          centerTitle: true,
        ),
        body: BlocConsumer<FieldMissionDetailCubit, FieldMissionDetailState>(
          listener: (context, state) {
            if (state is FieldMissionDetailRevokedSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم إلغاء سريان المأمورية بنجاح.'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            }
          },
          builder: (context, state) {
            return switch (state) {
              FieldMissionDetailInitial() ||
              FieldMissionDetailLoading() =>
                const Center(child: CircularProgressIndicator()),
              FieldMissionDetailForbidden(:final message) => _buildErrorState(
                  context,
                  title: 'غير مصرح لك بالاطلاع',
                  message: message,
                  icon: Icons.lock_outline_rounded,
                ),
              FieldMissionDetailError(:final message) => _buildErrorState(
                  context,
                  title: 'تعذر تحميل التفاصيل',
                  message: message,
                  icon: Icons.error_outline_rounded,
                  onRetry: () => context
                      .read<FieldMissionDetailCubit>()
                      .loadDetail(operationId),
                ),
              FieldMissionDetailLoaded(:final detail, :final actionError) =>
                _buildContent(context, detail, actionError),
              FieldMissionDetailRevokedSuccess(:final detail) =>
                _buildContent(context, detail, null),
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
    final mission = detail.fieldMission;
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

          // Status Header Card
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
                          : 'مأمورية عمل رسمية',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    _buildStatusChip(mission?.authorizationState),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تاريخ التقديم: ${dateFormat.format(detail.submittedAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (detail.nextActionLabelAr != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail.nextActionLabelAr!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mission Scope Card
          if (mission != null) ...[
            AttendCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بيانات الموقع والنطاق المعتمد',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    label: 'الوجهة المعتمدة:',
                    value: mission.destination.label.isNotEmpty
                        ? mission.destination.label
                        : 'موقع خارجي معتمد',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'نصف قطر السماح:',
                    value: '${mission.destination.radiusMeters} متر',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'بداية المأمورية:',
                    value: dateFormat.format(mission.startsAt),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    label: 'نهاية المأمورية:',
                    value: dateFormat.format(mission.endsAt),
                  ),
                  if (mission.purpose != null &&
                      mission.purpose!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      label: 'الغرض من العمل:',
                      value: mission.purpose!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Server Safeguards Notice Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_rounded, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الاستثناء الجغرافي يسري فقط خلال التوقيت المعتمد وضمن نطاق الوجهة المحددة. حماية سلامة الجهاز ومنع تزييف الموقع تظل مفعلة تلقائياً.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timeline Card
          if (detail.timeline.isNotEmpty) ...[
            AttendCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سجل الإجراءات والاعتمادات',
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
            const SizedBox(height: 20),
          ],

          // Revoke Action Button
          if (detail.canRevoke &&
              mission?.authorizationState ==
                  MissionAuthorizationState.active) ...[
            ElevatedButton.icon(
              onPressed: () async {
                final cubit = context.read<FieldMissionDetailCubit>();
                await showDialog<bool>(
                  context: context,
                  builder: (_) => RevokeMissionDialog(
                    operationId: detail.id,
                    expectedRevision: detail.revision,
                    onRevoke: ({
                      required commandId,
                      required expectedRevision,
                      required reason,
                    }) =>
                        cubit.revokeMission(
                      operationId: detail.id,
                      commandId: commandId,
                      expectedRevision: expectedRevision,
                      reason: reason,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('إلغاء المأمورية الإدارية'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(MissionAuthorizationState? state) {
    final (color, label) = switch (state) {
      MissionAuthorizationState.active => (
          AppTheme.successColor,
          'معتمدة وسارية'
        ),
      MissionAuthorizationState.pending => (Colors.orange, 'قيد الاعتماد'),
      MissionAuthorizationState.revoked => (AppTheme.errorColor, 'ملغاة'),
      MissionAuthorizationState.expired => (Colors.grey, 'منتهية'),
      MissionAuthorizationState.rejected => (AppTheme.errorColor, 'مرفوضة'),
      MissionAuthorizationState.cancelled => (Colors.grey, 'ملغاة'),
      null => (Colors.grey, 'غير محددة'),
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

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
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
