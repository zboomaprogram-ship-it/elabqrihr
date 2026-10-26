import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_detail_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/approval_timeline_widget.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_status_chip.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/screens/dynamic_request_detail_screen.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

class RequestDetailScreen extends StatelessWidget {
  final String requestId;
  final bool isDynamic;

  const RequestDetailScreen(
      {super.key, required this.requestId, this.isDynamic = false});

  @override
  Widget build(BuildContext context) {
    if (isDynamic) return DynamicRequestDetailScreen(requestId: requestId);
    return BlocProvider(
      create: (context) => RequestDetailCubit(
        repository: context.read<RequestRepository>(),
      )..loadDetail(requestId),
      child: const _RequestDetailView(),
    );
  }
}

class _RequestDetailView extends StatelessWidget {
  const _RequestDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: BlocConsumer<RequestDetailCubit, RequestDetailState>(
        listener: (context, state) {
          if (state is RequestDetailCancelled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStringsAr.requestCancelledSuccess),
                backgroundColor: AppTheme.mint,
              ),
            );
          } else if (state is RequestDetailLoaded &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppTheme.coral,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RequestDetailLoading) {
            return const DetailScreenSkeleton();
          }

          if (state is RequestDetailError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.coral, size: 48),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              ),
            );
          }

          final request = state is RequestDetailLoaded
              ? state.request
              : (state is RequestDetailCancelled ? state.request : null);

          if (request == null) return const SizedBox.shrink();

          final isCancelling =
              state is RequestDetailLoaded && state.isCancelling;
          final canCancel = (request.state == RequestState.pendingApproval ||
                  request.state == RequestState.submitted ||
                  (request.state == RequestState.approved &&
                      request.type == RequestType.leave)) &&
              state is! RequestDetailCancelled;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _typeLabel(request.type),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkInk,
                          ),
                        ),
                        RequestStatusChip(state: request.state),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تاريخ التقديم: ${DateFormat('yyyy-MM-dd HH:mm').format(request.submittedAt.toLocal())}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (request.reasonCode != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _reasonLabel(request.reasonCode!),
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.coral),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Request Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بيانات الطلب',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkInk),
                    ),
                    const Divider(height: 20),
                    ..._buildDetailedRows(request),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Approval Timeline
              ApprovalTimelineWidget(steps: request.steps),
              const SizedBox(height: 28),
              // Cancellation Action Button
              if (canCancel)
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isCancelling
                        ? null
                        : () => _showCancelDialog(context, request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.coral,
                      side: const BorderSide(color: AppTheme.coral),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.coral),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text(
                      AppStringsAr.cancelRequest,
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDetailedRows(RequestEntity request) {
    final rows = <Widget>[];

    if (request.type == RequestType.leave) {
      rows.add(_row(
          'تاريخ البداية', request.details['startDate']?.toString() ?? '-'));
      rows.add(
          _row('تاريخ النهاية', request.details['endDate']?.toString() ?? '-'));
      rows.add(_row('المدة المحسوبة', '${request.requestedMinutes} دقيقة'));
    } else if (request.type == RequestType.permission) {
      rows.add(
          _row('وقت البدء', request.details['startsAt']?.toString() ?? '-'));
      rows.add(
          _row('وقت الانتهاء', request.details['endsAt']?.toString() ?? '-'));
      rows.add(_row('المدة المطلوبة', '${request.requestedMinutes} دقيقة'));
    } else if (request.type == RequestType.attendanceCorrection) {
      rows.add(_row(
          'نوع التصحيح', request.details['correctionKind']?.toString() ?? '-'));
      rows.add(_row(
          'التوقيت المقترح', request.details['proposedAt']?.toString() ?? '-'));
    }

    final reason = request.details['reason']?.toString() ?? '';
    if (reason.isNotEmpty) {
      rows.add(const SizedBox(height: 8));
      rows.add(_row('السبب المذكور', reason));
    }

    return rows;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkInk),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(
      BuildContext context, RequestEntity request) async {
    final controller = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text(AppStringsAr.confirmCancelRequest),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(AppStringsAr.confirmCancelRequestMessage,
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: AppStringsAr.cancelReasonLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('تراجع'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) return;
                Navigator.of(dialogCtx).pop();
                context
                    .read<RequestDetailCubit>()
                    .cancelRequest(reason: reason);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white),
              child: const Text(AppStringsAr.cancelRequest),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _typeLabel(RequestType type) {
    switch (type) {
      case RequestType.leave:
        return AppStringsAr.leaveTypeTitle;
      case RequestType.permission:
        return AppStringsAr.permissionTypeTitle;
      case RequestType.attendanceCorrection:
        return AppStringsAr.attendanceCorrectionTitle;
      case RequestType.dynamic:
        return 'طلب مخصص';
    }
  }

  String _reasonLabel(String code) => switch (code) {
        'VALIDATION_FAILED' => 'تعذر قبول البيانات المدخلة.',
        'CONFLICT_DUPLICATE' => 'تمت معالجة الطلب مسبقاً.',
        'QUEUED_OFFLINE' => 'الطلب محفوظ محلياً وبانتظار الاتصال.',
        _ => 'توجد ملاحظة على هذا الطلب. راجع التفاصيل أو أعد المحاولة.'
      };
}
