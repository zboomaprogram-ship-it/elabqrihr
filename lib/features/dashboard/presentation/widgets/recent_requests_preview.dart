import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';

/// Shows the 3 most recent employee requests in a compact list.
/// Mirrors `EmployeeRequestHistorySection` from legacy but renders live data
/// from the Attend SaaS backend via [requests] list.
class RecentRequestsPreview extends StatelessWidget {
  final List<RequestEntity> requests;
  final VoidCallback? onViewAll;

  const RecentRequestsPreview({
    super.key,
    required this.requests,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const SizedBox.shrink();

    final visible = requests.take(3).toList();

    return AttendCard(
      padding: const EdgeInsets.all(16),
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
                'آخر الطلبات',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 16, color: AppTheme.surface03),
          ...visible.map((req) => _RequestRow(request: req)),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final RequestEntity request;

  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabel(request.type);
    final (stateLabel, stateColor) = _stateInfo(request.state);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(requestId: request.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _typeIcon(request.type),
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _formatDate(request.submittedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _typeLabel(RequestType type) {
    switch (type) {
      case RequestType.leave:
        return 'طلب إجازة';
      case RequestType.permission:
        return 'طلب إذن';
      case RequestType.attendanceCorrection:
        return 'تصحيح بصمة';
      case RequestType.dynamic:
        return 'طلب مخصص';
    }
  }

  static IconData _typeIcon(RequestType type) {
    switch (type) {
      case RequestType.leave:
        return Icons.calendar_month_outlined;
      case RequestType.permission:
        return Icons.access_time_outlined;
      case RequestType.attendanceCorrection:
        return Icons.edit_calendar_outlined;
      case RequestType.dynamic:
        return Icons.assignment_outlined;
    }
  }

  static (String, Color) _stateInfo(RequestState state) {
    switch (state) {
      case RequestState.submitted:
      case RequestState.pendingApproval:
        return ('بانتظار الموافقة', AppTheme.warningColor);
      case RequestState.approved:
        return ('مقبول', AppTheme.successColor);
      case RequestState.rejected:
        return ('مرفوض', AppTheme.errorColor);
      case RequestState.cancelled:
        return ('ملغي', AppTheme.textSecondary);
      case RequestState.pendingSync:
        return ('في الانتظار', AppTheme.warningColor);
      case RequestState.conflict:
        return ('تعارض', AppTheme.errorColor);
      case RequestState.processingFailed:
        return ('فشل', AppTheme.errorColor);
    }
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'اليوم';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
