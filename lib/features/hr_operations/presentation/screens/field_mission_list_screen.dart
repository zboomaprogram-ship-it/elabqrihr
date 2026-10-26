import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../../domain/hr_operations_models.dart';
import '../../domain/hr_operations_repository.dart';
import '../cubit/field_mission_list_cubit.dart';
import 'field_mission_detail_screen.dart';

class FieldMissionListScreen extends StatelessWidget {
  final HrOperationsRepository repository;

  const FieldMissionListScreen({
    super.key,
    required this.repository,
  });

  static Route<void> route({required HrOperationsRepository repository}) {
    return MaterialPageRoute(
      builder: (_) => FieldMissionListScreen(repository: repository),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      context.read<FieldMissionListCubit>();
      return _buildContent(context);
    } catch (_) {
      return BlocProvider(
        create: (_) => FieldMissionListCubit(repository: repository)
          ..loadMissions(),
        child: Builder(
          builder: (childContext) => _buildContent(childContext),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مأموريات العمل الميدانية'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            _buildFilterBar(context),
            Expanded(
              child: BlocBuilder<FieldMissionListCubit, FieldMissionListState>(
                builder: (context, state) {
                  return switch (state) {
                    FieldMissionListInitial() ||
                    FieldMissionListLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    FieldMissionListForbidden(:final message) =>
                      _buildMessageState(
                        icon: Icons.lock_outline_rounded,
                        title: 'غير مصرح لك بالاطلاع',
                        message: message,
                      ),
                    FieldMissionListError(:final message) => _buildMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'تعذر تحميل المأموريات',
                        message: message,
                        onRetry: () => context
                            .read<FieldMissionListCubit>()
                            .loadMissions(),
                      ),
                    FieldMissionListEmpty() => _buildMessageState(
                        icon: Icons.assignment_outlined,
                        title: 'لا توجد مأموريات مسجلة',
                        message:
                            'لم يتم العثور على أي مأموريات عمل ميدانية تطابق الفلتر الحالي.',
                      ),
                    FieldMissionListLoaded(:final items) =>
                      _buildList(context, items),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return BlocBuilder<FieldMissionListCubit, FieldMissionListState>(
      builder: (context, state) {
        final activeFilter = switch (state) {
          FieldMissionListLoaded(:final activeFilter) => activeFilter,
          FieldMissionListEmpty(:final activeFilter) => activeFilter,
          _ => null,
        };

        final filters = [
          (null, 'الكل'),
          ('active', 'السارية'),
          ('pending', 'قيد الاعتماد'),
          ('revoked', 'الملغاة'),
          ('expired', 'المنتهية'),
        ];

        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final (key, label) = filters[index];
              final isSelected = activeFilter == key;
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  context
                      .read<FieldMissionListCubit>()
                      .loadMissions(stateFilter: key);
                },
                selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, List<HrOperationSummary> items) {
    final dateFormat = DateFormat('yyyy/MM/dd · hh:mm a');

    return RefreshIndicator(
      onRefresh: () => context.read<FieldMissionListCubit>().loadMissions(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return AttendCard(
            onTap: () {
              Navigator.of(context).push(
                FieldMissionDetailScreen.route(
                  operationId: item.id,
                  repository: repository,
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_walk_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.employeeName ?? 'مأمورية عمل',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          _buildStateChip(item.state),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تاريخ التقديم: ${dateFormat.format(item.submittedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (item.nextActionLabelAr != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.nextActionLabelAr!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStateChip(String state) {
    final (color, label) = switch (state) {
      'active' => (AppTheme.successColor, 'سارية'),
      'pending' => (Colors.orange, 'قيد المراجعة'),
      'revoked' => (AppTheme.errorColor, 'ملغاة'),
      'expired' => (Colors.grey, 'منتهية'),
      'rejected' => (AppTheme.errorColor, 'مرفوضة'),
      'cancelled' => (Colors.grey, 'ملغاة'),
      _ => (Colors.blueGrey, state),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
