import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/forms/attendance_correction_form.dart';

class AttendanceCorrectionScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AttendanceCorrectionScreen({super.key, this.onBack});

  @override
  State<AttendanceCorrectionScreen> createState() =>
      _AttendanceCorrectionScreenState();
}

class _AttendanceCorrectionScreenState extends State<AttendanceCorrectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RequestEntity> _history = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final repo = context.read<RequestRepository>();
      final list = await repo.listMyRequests(
        type: RequestType.attendanceCorrection,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _history = list;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
        _historyError = 'تعذر تحميل سجل طلبات التصحيح. يرجى المحاولة لاحقاً.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStringsAr.attendanceCorrectionTitle),
        centerTitle: true,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_calendar),
              text: 'طلب جديد',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'السجل',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Submit Form
          AttendanceCorrectionForm(
            onSuccess: () {
              _loadHistory();
              _tabController.animateTo(1);
            },
          ),
          // Tab 2: History List
          _buildHistoryTab(theme),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _historyError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'لا توجد طلبات تصحيح حضور سابقة',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يمكنك تقديم طلب تصحيح جديد من علامة التبويب السابقة.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _history[index];
          return _buildHistoryCard(item, theme);
        },
      ),
    );
  }

  Widget _buildHistoryCard(RequestEntity item, ThemeData theme) {
    final stateLabel = _getStateLabel(item.state);
    final stateColor = _getStateColor(item.state, theme);
    final kind = item.details['correctionKind'] as String? ?? 'single';
    final kindLabel = kind == 'both'
        ? 'تصحيح حضور وانصراف'
        : kind.contains('in')
            ? 'تصحيح حضور'
            : 'تصحيح انصراف';

    final reason = item.details['reason'] as String? ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    kindLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: stateColor),
                  ),
                  child: Text(
                    stateLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reason,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  item.submittedAt.toLocal().toString().split('.').first,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (item.state == RequestState.pendingSync) ...[
                  const Spacer(),
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'في انتظار المزامنة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStateLabel(RequestState state) {
    switch (state) {
      case RequestState.submitted:
      case RequestState.pendingApproval:
        return 'قيد الاعتماد';
      case RequestState.approved:
        return 'معتمد';
      case RequestState.rejected:
        return 'مرفوض';
      case RequestState.cancelled:
        return 'ملغي';
      case RequestState.conflict:
        return 'تعارض';
      case RequestState.pendingSync:
        return 'محلي مؤقت';
      case RequestState.processingFailed:
        return 'فشل المعالجة';
    }
  }

  Color _getStateColor(RequestState state, ThemeData theme) {
    switch (state) {
      case RequestState.approved:
        return Colors.green.shade700;
      case RequestState.rejected:
      case RequestState.conflict:
      case RequestState.processingFailed:
        return theme.colorScheme.error;
      case RequestState.pendingSync:
        return Colors.orange.shade800;
      case RequestState.submitted:
      case RequestState.pendingApproval:
      case RequestState.cancelled:
        return theme.colorScheme.primary;
    }
  }
}
