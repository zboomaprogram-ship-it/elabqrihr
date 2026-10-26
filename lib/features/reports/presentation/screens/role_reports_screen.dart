import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import '../../domain/report_models.dart';
import '../../domain/report_repository.dart';
import '../cubit/reports_cubit.dart';
import '../cubit/reports_state.dart';

class RoleReportsScreen extends StatelessWidget {
  final UserRole role;

  const RoleReportsScreen({
    super.key,
    this.role = UserRole.employee,
  });

  static Route<void> route({
    UserRole role = UserRole.employee,
    ReportRepository? repository,
  }) {
    return MaterialPageRoute<void>(
      builder: (context) {
        final repo = repository ?? context.read<ReportRepository>();
        return BlocProvider<ReportsCubit>(
          create: (_) => ReportsCubit(repository: repo)..loadReports(),
          child: RoleReportsScreen(role: role),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = ReportScopeHelper.titleForRole(role);
    final subtitle = ReportScopeHelper.subtitleForRole(role);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          actions: [
            BlocBuilder<ReportsCubit, ReportsState>(
              builder: (context, state) {
                return IconButton(
                  key: const Key('reports_refresh_button'),
                  tooltip: 'تحديث البيانات',
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  onPressed: () {
                    context.read<ReportsCubit>().loadReports();
                  },
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<ReportsCubit, ReportsState>(
          listener: (context, state) {
            if (state is ReportsLoaded) {
              if (state.actionMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.actionMessage!),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
                context.read<ReportsCubit>().clearActionMessage();
              }
              if (state.actionError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.actionError!),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                context.read<ReportsCubit>().clearActionError();
              }
            }
          },
          builder: (context, state) {
            if (state is ReportsLoading || state is ReportsInitial) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'جارٍ تحميل ملخص القوى العاملة…',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state is ReportsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isForbidden
                            ? Icons.lock_outline
                            : Icons.error_outline,
                        size: 56,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        key: const Key('reports_retry_button'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(120, 44),
                        ),
                        onPressed: () =>
                            context.read<ReportsCubit>().loadReports(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final loaded = state as ReportsLoaded;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Eyebrow and Subtitle
                  Text(
                    'العبقري HR · التقارير',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // View Mode Tabs
                  _ViewModeSelector(
                    activeMode: loaded.viewMode,
                    roleTitle: title,
                    onModeChanged: (mode) =>
                        context.read<ReportsCubit>().switchViewMode(mode),
                  ),
                  const SizedBox(height: 16),

                  // Date Filter Card
                  _DateFilterCard(
                    from: loaded.from,
                    to: loaded.to,
                    onApply: (newFrom, newTo) {
                      context.read<ReportsCubit>().loadReports(
                            from: newFrom,
                            to: newTo,
                            viewMode: loaded.viewMode,
                          );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Content based on view mode
                  if (loaded.viewMode == ReportViewMode.workforce)
                    _WorkforceSummarySection(loaded: loaded)
                  else
                    _AttendanceLeaveSection(loaded: loaded),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ViewModeSelector extends StatelessWidget {
  final ReportViewMode activeMode;
  final String roleTitle;
  final ValueChanged<ReportViewMode> onModeChanged;

  const _ViewModeSelector({
    required this.activeMode,
    required this.roleTitle,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              key: const Key('reports_tab_workforce'),
              title: roleTitle,
              isSelected: activeMode == ReportViewMode.workforce,
              onTap: () => onModeChanged(ReportViewMode.workforce),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TabButton(
              key: const Key('reports_tab_attendance'),
              title: 'الحضور والإجازات والطلبات',
              isSelected: activeMode == ReportViewMode.attendance,
              onTap: () => onModeChanged(ReportViewMode.attendance),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color:
                  isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateFilterCard extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  final void Function(DateTime from, DateTime to) onApply;

  const _DateFilterCard({
    required this.from,
    required this.to,
    required this.onApply,
  });

  @override
  State<_DateFilterCard> createState() => _DateFilterCardState();
}

class _DateFilterCardState extends State<_DateFilterCard> {
  late DateTime _selectedFrom;
  late DateTime _selectedTo;

  @override
  void initState() {
    super.initState();
    _selectedFrom = widget.from;
    _selectedTo = widget.to;
  }

  @override
  void didUpdateWidget(covariant _DateFilterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) {
      _selectedFrom = widget.from;
      _selectedTo = widget.to;
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _selectedFrom : _selectedTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _selectedFrom = picked;
          if (_selectedTo.isBefore(_selectedFrom)) {
            _selectedTo = _selectedFrom;
          }
        } else {
          _selectedTo = picked;
          if (_selectedFrom.isAfter(_selectedTo)) {
            _selectedFrom = _selectedTo;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return WolfCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'من تاريخ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('reports_filter_from'),
                        onTap: () => _pickDate(isFrom: true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateFormat.format(_selectedFrom),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إلى تاريخ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('reports_filter_to'),
                        onTap: () => _pickDate(isFrom: false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateFormat.format(_selectedTo),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              key: const Key('reports_apply_filter_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => widget.onApply(_selectedFrom, _selectedTo),
              child: const Text(
                'تطبيق الفترة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkforceSummarySection extends StatelessWidget {
  final ReportsLoaded loaded;

  const _WorkforceSummarySection({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final summary = loaded.summary;

    if (summary == null || summary.totalEmployees == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: WolfCard(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'لا توجد بيانات ضمن النطاق المصرح.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grid of Metrics
        Semantics(
          label: 'إجماليات القوى العاملة',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _MetricCard(
                label: 'الموظفون النشطون',
                value: summary.activeEmployees,
                color: AppTheme.primaryColor,
              ),
              _MetricCard(
                label: 'الموقوفون',
                value: summary.suspendedEmployees,
                color: AppTheme.warningColor,
              ),
              _MetricCard(
                label: 'المؤرشفون',
                value: summary.archivedEmployees,
                color: AppTheme.textSecondary,
              ),
              _MetricCard(
                label: 'مواقع العمل النشطة',
                value: summary.activeLocations,
                color: AppTheme.secondaryColor,
              ),
              _MetricCard(
                label: 'بلا تكليف سارٍ',
                value: summary.unassignedEmployees,
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Reconciled Total
        WolfCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Semantics(
              label: 'مطابقة إجمالي الموظفين',
              child: Text(
                'إجمالي الموظفين: ${summary.totalEmployees}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceLeaveSection extends StatelessWidget {
  final ReportsLoaded loaded;

  const _AttendanceLeaveSection({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final report = loaded.attendanceReport;

    if (report == null || report.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: WolfCard(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'لا توجد سجلات حضور أو إجازات ضمن النطاق المصرح.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final totals = report.totals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Totals Card
        WolfCard(
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجماليات الحضور والإجازات',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SmallStat(
                        label: 'الموظفون',
                        value: '${totals.employees}',
                      ),
                    ),
                    Expanded(
                      child: _SmallStat(
                        label: 'الاستثناءات',
                        value: '${totals.attendanceExceptions}',
                      ),
                    ),
                    Expanded(
                      child: _SmallStat(
                        label: 'دقائق الإجازة',
                        value: '${totals.leaveMinutes}',
                      ),
                    ),
                    Expanded(
                      child: _SmallStat(
                        label: 'الطلبات',
                        value: '${totals.requests}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Export Action
        ElevatedButton.icon(
          key: const Key('reports_export_csv_button'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            backgroundColor: AppTheme.secondaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: loaded.isExporting
              ? null
              : () => context.read<ReportsCubit>().requestExport(),
          icon: loaded.isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.file_download_outlined, size: 20),
          label: Text(
            loaded.isExporting ? 'جارٍ إنشاء التصدير…' : 'تصدير تقرير CSV',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (loaded.exportJob != null) ...[
          const SizedBox(height: 10),
          WolfCard(
            key: const Key('reports_export_status_card'),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    loaded.exportJob!.isReady
                        ? Icons.check_circle_outline
                        : (loaded.exportJob!.isExpired
                            ? Icons.timer_off_outlined
                            : Icons.hourglass_top_outlined),
                    color: loaded.exportJob!.isReady
                        ? AppTheme.successColor
                        : (loaded.exportJob!.isExpired
                            ? AppTheme.warningColor
                            : AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loaded.exportJob!.isReady
                              ? 'ملف التصدير جاهز للتحميل'
                              : (loaded.exportJob!.isExpired
                                  ? 'انتهت صلاحية ملف التصدير'
                                  : 'طلب التصدير قيد المعالجة'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (loaded.exportJob!.rowCount != null)
                          Text(
                            'عدد السجلات: ${loaded.exportJob!.rowCount}',
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
            ),
          ),
          if (!loaded.exportJob!.isExpired) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('reports_refresh_export_button'),
              onPressed: loaded.isExporting
                  ? null
                  : () => context.read<ReportsCubit>().refreshExportStatus(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تحديث حالة التصدير'),
            ),
          ],
        ],
        const SizedBox(height: 14),

        // Detail Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: report.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = report.items[index];
            return WolfCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                title: Text(
                  item.employeeName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'التاريخ: ${item.businessDate} · الإجازة: ${item.leaveMinutes} د',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                trailing: Chip(
                  label: Text(
                    _attendanceStateArabic(item.attendanceState),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _attendanceStateColor(item.attendanceState)
                      .withValues(alpha: 0.15),
                ),
              ),
            );
          },
        ),

        if (report.nextCursor != null) ...[
          const SizedBox(height: 12),
          TextButton(
            key: const Key('reports_load_more_button'),
            onPressed: () => context.read<ReportsCubit>().loadMoreAttendance(),
            child: const Text('تحميل المزيد'),
          ),
        ],
      ],
    );
  }

  String _attendanceStateArabic(String state) {
    switch (state) {
      case 'present':
        return 'حاضر';
      case 'late':
        return 'متأخر';
      case 'early_leave':
        return 'مغادرة مبكرة';
      case 'leave':
        return 'إجازة';
      case 'absent':
      default:
        return 'غائب';
    }
  }

  Color _attendanceStateColor(String state) {
    switch (state) {
      case 'present':
        return AppTheme.successColor;
      case 'late':
      case 'early_leave':
        return AppTheme.warningColor;
      case 'leave':
        return AppTheme.secondaryColor;
      case 'absent':
      default:
        return AppTheme.errorColor;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
