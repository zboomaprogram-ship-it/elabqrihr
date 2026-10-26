import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/app_motion.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/manager_inbox_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

class ManagerInboxScreen extends StatelessWidget {
  const ManagerInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        DynamicRequestRepository? dynamicRepository;
        try {
          dynamicRepository = context.read<DynamicRequestRepository>();
        } catch (_) {
          // Focused legacy tests do not provide the optional dynamic repository.
        }
        return ManagerInboxCubit(
          repository: context.read<RequestRepository>(),
          dynamicRepository: dynamicRepository,
        )..loadInbox(stateFilter: RequestState.pendingApproval);
      },
      child: const _ManagerInboxView(),
    );
  }
}

class _ManagerInboxView extends StatelessWidget {
  const _ManagerInboxView();

  @override
  Widget build(BuildContext context) {
    // This screen is embedded in RequestsHomeScreen in the app, but it is also
    // rendered on its own in accessibility and widget tests. A transparent
    // Material keeps filter controls usable in both contexts.
    return Material(
      color: Colors.transparent,
      child: BlocConsumer<ManagerInboxCubit, ManagerInboxState>(
        listener: (context, state) {
          if (state is ManagerInboxLoaded) {
            if (state.conflictMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.conflictMessage!),
                  backgroundColor: AppTheme.coral,
                  duration: const Duration(seconds: 4),
                ),
              );
            } else if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppTheme.coral,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildWorkspaceHeader(state),
              _buildFilterBar(context, state),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceHeader(ManagerInboxState state) {
    final pendingCount = state is ManagerInboxLoaded
        ? state.requests
            .where((request) =>
                request.state == RequestState.pendingApproval ||
                request.state == RequestState.submitted)
            .length
        : null;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                const Icon(Icons.fact_check_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إدارة الطلبات',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pendingCount == null
                      ? 'راجع الطلبات التي تقع ضمن صلاحياتك.'
                      : pendingCount == 0
                          ? 'لا توجد طلبات معلقة تحتاج إجراءً الآن.'
                          : '$pendingCount طلبات تحتاج إلى قرارك.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ManagerInboxState state) {
    final activeFilter = state is ManagerInboxLoaded
        ? state.filterState
        : RequestState.pendingApproval;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _filterChip(
              context: context,
              label: 'بانتظار الموافقة',
              isSelected: activeFilter == RequestState.pendingApproval,
              onSelected: () => context.read<ManagerInboxCubit>().loadInbox(
                    stateFilter: RequestState.pendingApproval,
                    refresh: true,
                  ),
            ),
            const SizedBox(width: 8),
            _filterChip(
              context: context,
              label: 'الكل',
              isSelected: activeFilter == null,
              onSelected: () => context.read<ManagerInboxCubit>().loadInbox(
                    stateFilter: null,
                    refresh: true,
                  ),
            ),
            const SizedBox(width: 8),
            _filterChip(
              context: context,
              label: 'المقبولة',
              isSelected: activeFilter == RequestState.approved,
              onSelected: () => context.read<ManagerInboxCubit>().loadInbox(
                    stateFilter: RequestState.approved,
                    refresh: true,
                  ),
            ),
            const SizedBox(width: 8),
            _filterChip(
              context: context,
              label: 'المرفوضة',
              isSelected: activeFilter == RequestState.rejected,
              onSelected: () => context.read<ManagerInboxCubit>().loadInbox(
                    stateFilter: RequestState.rejected,
                    refresh: true,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
        checkmarkColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.darkInk,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ManagerInboxState state) {
    if (state is ManagerInboxLoading) {
      return const InboxSkeleton();
    }

    if (state is ManagerInboxError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.coral),
              const SizedBox(height: 16),
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<ManagerInboxCubit>().loadInbox(refresh: true),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is ManagerInboxLoaded) {
      if (state.requests.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppMotion(
                asset: AppMotionAsset.noApprovals,
                semanticLabel: 'لا توجد موافقات معلقة',
                fallbackIcon: Icons.inbox_outlined,
              ),
              SizedBox(height: 12),
              Text(AppStringsAr.noRequestsFound,
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () =>
            context.read<ManagerInboxCubit>().loadInbox(refresh: true),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          itemCount: state.requests.length,
          itemBuilder: (context, index) {
            final req = state.requests[index];
            final isDecidingThis =
                state.isDeciding && state.decidedRequestId == req.id;

            return Column(
              key: ValueKey('inbox_item_${req.id}'),
              children: [
                RequestCard(
                  request: req,
                  footer: (req.state == RequestState.pendingApproval ||
                          req.state == RequestState.submitted)
                      ? _decisionActions(
                          context,
                          request: req,
                          isDeciding: isDecidingThis,
                          allRequests: state.requests,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(
                          requestId: req.id,
                          isDynamic: req.isDynamic,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _decisionActions(
    BuildContext context, {
    required RequestEntity request,
    required bool isDeciding,
    required List<RequestEntity> allRequests,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            key: ValueKey('approve_request_${request.id}'),
            onPressed: isDeciding
                ? null
                : () => _openDecisionDialog(
                      context,
                      request,
                      isApprove: true,
                      allRequests: allRequests,
                    ),
            icon: isDeciding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text(AppStringsAr.approveAction),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.mint,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey('reject_request_${request.id}'),
            onPressed: isDeciding
                ? null
                : () => _openDecisionDialog(
                      context,
                      request,
                      isApprove: false,
                      allRequests: allRequests,
                    ),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text(AppStringsAr.rejectAction),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.coral,
              side: const BorderSide(color: AppTheme.coral),
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ),
      ],
    );
  }

  static List<RequestEntity> _detectStaffingOverlap(
    RequestEntity target,
    List<RequestEntity> allRequests,
  ) {
    if (target.type != RequestType.leave &&
        target.type != RequestType.permission) {
      return [];
    }
    final targetStart = target.details['startDate'] ??
        target.details['startsAt'] ??
        target.submittedAt.toIso8601String().substring(0, 10);
    final targetEnd =
        target.details['endDate'] ?? target.details['endsAt'] ?? targetStart;

    return allRequests.where((other) {
      if (other.id == target.id || other.employeeId == target.employeeId) {
        return false;
      }
      if (other.state == RequestState.rejected ||
          other.state == RequestState.cancelled) {
        return false;
      }
      final otherStart = other.details['startDate'] ??
          other.details['startsAt'] ??
          other.submittedAt.toIso8601String().substring(0, 10);
      final otherEnd =
          other.details['endDate'] ?? other.details['endsAt'] ?? otherStart;
      return targetStart.toString().compareTo(otherEnd.toString()) <= 0 &&
          targetEnd.toString().compareTo(otherStart.toString()) >= 0;
    }).toList();
  }

  Future<void> _openDecisionDialog(
    BuildContext context,
    RequestEntity request, {
    required bool isApprove,
    List<RequestEntity> allRequests = const [],
  }) async {
    final commentController = TextEditingController();
    final cubit = context.read<ManagerInboxCubit>();
    final overlaps = isApprove
        ? _detectStaffingOverlap(request, allRequests)
        : <RequestEntity>[];

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(isApprove
              ? AppStringsAr.confirmApproveTitle
              : AppStringsAr.confirmRejectTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApprove
                    ? 'هل أنت متأكد من الموافقة على طلب ${request.employeeName ?? "الموظف"}؟'
                    : 'هل أنت متأكد من رفض طلب ${request.employeeName ?? "الموظف"}؟',
                style: const TextStyle(fontSize: 14),
              ),
              if (overlaps.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'إشعار استرشادي محلي (بناءً على الطلبات المعروضة حالياً فقط): يوجد ${overlaps.length} طلب متداخل لموظف آخر (${overlaps.first.employeeName ?? "زميل"}). هذا تنبيه تقريبي ولا يضمن كفاية التغطية ولا يغني عن مراجعة جدول الفريق المعتمد.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: AppStringsAr.reviewerCommentLabel,
                  hintText: 'ملاحظة اختيارية...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                cubit.decideRequest(
                  requestId: request.id,
                  expectedRevision: request.revision,
                  decision: isApprove ? 'approve' : 'reject',
                  comment: commentController.text.trim(),
                  isDynamic: request.isDynamic,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? AppTheme.mint : AppTheme.coral,
                foregroundColor: Colors.white,
              ),
              child: Text(isApprove
                  ? AppStringsAr.approveAction
                  : AppStringsAr.rejectAction),
            ),
          ],
        ),
      );
    } finally {
      commentController.dispose();
    }
  }
}
