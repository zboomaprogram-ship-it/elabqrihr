import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_status_chip.dart';

class RequestCard extends StatelessWidget {
  final RequestEntity request;
  final VoidCallback onTap;
  final Widget? footer;

  const RequestCard({
    super.key,
    required this.request,
    required this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final (typeTitle, typeIcon) = request.isDynamic
        ? (request.dynamicTypeNameAr ?? 'طلب ديناميكي', Icons.assignment)
        : _typeMeta(request.type);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkInk,
                          ),
                        ),
                        if (request.employeeName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  request.employeeName!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  RequestStatusChip(state: request.state),
                ],
              ),
              const Divider(height: 24),
              _buildDetailsSnippet(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy/MM/dd – HH:mm')
                          .format(request.submittedAt.toLocal()),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                  if (request.state == RequestState.pendingSync)
                    _pendingSyncBadge(),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.textMuted, size: 20),
                ],
              ),
              if (footer != null) ...[
                const Divider(height: 24),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingSyncBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 14, color: Color(0xFF92400E)),
            SizedBox(width: 4),
            Text(
              'في انتظار المزامنة',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _buildDetailsSnippet() {
    final reason = request.details['reason'] as String? ?? '';
    final detailsList = <Widget>[];

    if (request.isDynamic) {
      detailsList.add(const Text('طلب مخصص وفق سياسة الشركة',
          style: TextStyle(fontSize: 13)));
    } else if (request.type == RequestType.leave) {
      final start = request.details['startDate'] as String? ?? '';
      final end = request.details['endDate'] as String? ?? '';
      detailsList.add(Text('الفترة: $start إلى $end',
          style: const TextStyle(fontSize: 13)));
    } else if (request.type == RequestType.permission) {
      final mins = request.requestedMinutes;
      detailsList.add(
          Text('المدة: $mins دقيقة', style: const TextStyle(fontSize: 13)));
    } else if (request.type == RequestType.attendanceCorrection) {
      final kind = request.details['correctionKind'] as String? ?? '';
      final kindAr =
          kind.contains('check_in') ? 'بصمة الحضور' : 'بصمة الانصراف';
      detailsList.add(
          Text('نوع التصحيح: $kindAr', style: const TextStyle(fontSize: 13)));
    }

    if (reason.isNotEmpty) {
      detailsList.add(const SizedBox(height: 4));
      detailsList.add(Text(
        'السبب: $reason',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detailsList,
    );
  }

  (String, IconData) _typeMeta(RequestType type) {
    switch (type) {
      case RequestType.leave:
        return (AppStringsAr.leaveTypeTitle, Icons.calendar_month);
      case RequestType.permission:
        return (AppStringsAr.permissionTypeTitle, Icons.access_time);
      case RequestType.attendanceCorrection:
        return (AppStringsAr.attendanceCorrectionTitle, Icons.edit_calendar);
      case RequestType.dynamic:
        return ('طلب مخصص', Icons.assignment);
    }
  }
}
