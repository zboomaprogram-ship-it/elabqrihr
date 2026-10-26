import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/navigation/main_navigation_shell.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/requests/presentation/screens/request_detail_screen.dart';
import 'package:attend_mobile/features/reports/presentation/screens/role_reports_screen.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_repository.dart';
import 'package:attend_mobile/features/final_settlement/presentation/cubit/final_settlement_cubit.dart';
import 'package:attend_mobile/features/final_settlement/presentation/screens/final_settlement_statement_screen.dart';
import '../../domain/notification_models.dart';
import '../../domain/notification_repository.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';
import 'announcement_details_screen.dart';

const Map<String, String> _notificationArabic = {
  'notification.employee.invited.title': 'دعوة موظف جديد',
  'notification.employee.invited.body': 'تم إرسال دعوة انضمام للموظف.',
  'notification.employee.archived.title': 'أرشفة موظف',
  'notification.employee.archived.body': 'تمت أرشفة سجل الموظف في النظام.',
  'notification.employee.created.title': 'إضافة موظف جديد',
  'notification.employee.created.body': 'تمت إضافة موظف جديد بنجاح.',
  'notification.employee.updated.title': 'تحديث بيانات موظف',
  'notification.employee.updated.body': 'تم تحديث بيانات الموظف.',
  'notification.assignment.scheduled.title': 'تكليف وظيفي جديد',
  'notification.assignment.scheduled.body': 'تمت جدولة تكليف وظيفي.',
  'notification.attendance.accepted.title': 'تسجيل حضور',
  'notification.attendance.accepted.body': 'تم قبول حركة الحضور.',
  'notification.attendance.rejected.title': 'رفض حركة الحضور',
  'notification.attendance.rejected.body': 'تم رفض تسجيل حركة الحضور لمخالفة السياسة.',
  'notification.attendance.pending_review.title': 'مراجعة حركة الحضور',
  'notification.attendance.pending_review.body': 'حركة الحضور قيد المراجعة الإدارية.',
  'notification.request.submitted.title': 'طلب جديد',
  'notification.request.submitted.body': 'تم إرسال طلب للمراجعة.',
  'notification.request.decided.title': 'تحديث قرار الطلب',
  'notification.request.decided.body': 'تم تحديث حالة الطلب.',
  'notification.support.updated.title': 'تحديث وصول الدعم',
  'notification.support.updated.body': 'تم تحديث حالة وصول الدعم المؤقت.',
  'settlement.published.title': 'تم نشر المخالصة النهائية',
  'settlement.published.body': 'يمكنك فتح كشف المخالصة المصرح لك به.',
  'company_announcement': 'إعلان إداري رسمي',
  'open_company_announcement': 'اضغط هنا لقراءة تفاصيل الإعلان الإداري.',
  'notification.company_announcement.title': 'إعلان إداري رسمي',
  'notification.company_announcement.body':
      'تم نشر إعلان إداري جديد من الشركة.',
};

String translateNotificationKey(String key, {String fallback = 'إشعار جديد'}) {
  return _notificationArabic[key] ?? fallback;
}

/// Opens a notification destination only after [NotificationDeepLinkCoordinator]
/// has reauthorized it. This is shared by the notification centre and FCM taps.
void navigateAuthorizedNotificationDestination(
  BuildContext context,
  NotificationDestinationKind kind,
  String destinationId, {
  bool isDynamicRequest = false,
}) {
  switch (kind) {
    case NotificationDestinationKind.attendance:
      Navigator.of(context).popUntil((route) => route.isFirst);
      MainTabController.switchCurrentTab(1);
    case NotificationDestinationKind.request:
    case NotificationDestinationKind.approval:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestDetailScreen(
            requestId: destinationId,
            isDynamic: isDynamicRequest,
          ),
        ),
      );
    case NotificationDestinationKind.employee:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الوجهة غير متاحة على تطبيق الجوال.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    case NotificationDestinationKind.report:
      final authState = context.read<AuthCubit>().state;
      if (authState is! Authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر التحقق من صلاحية التقرير. سجّل الدخول مجدداً.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      Navigator.of(context)
          .push(RoleReportsScreen.route(role: authState.session.role));
    case NotificationDestinationKind.announcement:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnnouncementDetailsScreen(
            announcementId: destinationId,
            apiClient: context.read<ApiClient>(),
          ),
        ),
      );
    case NotificationDestinationKind.finalSettlement:
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => FinalSettlementCubit(
              repository: context.read<FinalSettlementRepository>(),
            ),
            child: FinalSettlementStatementScreen(settlementId: destinationId),
          ),
        ),
      );
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  static Route<void> route({
    NotificationCubit? cubit,
    NotificationRepository? repository,
  }) {
    return MaterialPageRoute<void>(
      builder: (context) {
        Widget screen = const NotificationCenterScreen();
        if (cubit != null) {
          screen = BlocProvider<NotificationCubit>.value(
            value: cubit,
            child: screen,
          );
        }
        if (repository != null) {
          screen = RepositoryProvider<NotificationRepository>.value(
            value: repository,
            child: screen,
          );
        }
        return screen;
      },
    );
  }

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  NotificationCubit? _cubit;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<NotificationCubit>();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    if (_scaffoldMessenger?.mounted ?? false) {
      _scaffoldMessenger?.removeCurrentSnackBar();
    }
    _cubit?.clearActionError();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<NotificationCubit>();
      if (cubit.state is NotificationInitial ||
          (cubit.state is NotificationLoaded &&
              (cubit.state as NotificationLoaded).notifications.isEmpty)) {
        cubit.loadNotifications();
      }
    });
  }

  void _handleNavigation(
    BuildContext context,
    NotificationDestinationKind kind,
    String destinationId,
    bool isDynamicRequest,
  ) {
    if (_scaffoldMessenger?.mounted ?? false) {
      _scaffoldMessenger?.removeCurrentSnackBar();
    }
    _cubit?.clearActionError();
    navigateAuthorizedNotificationDestination(
      context,
      kind,
      destinationId,
      isDynamicRequest: isDynamicRequest,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            if (_scaffoldMessenger?.mounted ?? false) {
              _scaffoldMessenger?.removeCurrentSnackBar();
            }
            _cubit?.clearActionError();
          }
        },
        child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Semantics(
            label: 'مركز الإشعارات',
            child: const Text(
              'الإشعارات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          actions: [
            BlocBuilder<NotificationCubit, NotificationState>(
              builder: (context, state) {
                final hasItems = state is NotificationLoaded &&
                    state.notifications.isNotEmpty;
                return TextButton(
                  key: const Key('mark_all_read_button'),
                  onPressed: hasItems
                      ? () => context.read<NotificationCubit>().markAllAsRead()
                      : null,
                  child: const Text(
                    'تعليم الكل كمقروء',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<NotificationCubit, NotificationState>(
          listener: (context, state) {
            if (state is NotificationLoaded && state.actionError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: AppTheme.errorColor,
                  action: SnackBarAction(
                    label: 'حسناً',
                    textColor: Colors.white,
                    onPressed: () =>
                        context.read<NotificationCubit>().clearActionError(),
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is NotificationLoading || state is NotificationInitial) {
              return const NotificationListSkeleton();
            }

            if (state is NotificationError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 56,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        key: const Key('notification_retry_button'),
                        onPressed: () => context
                            .read<NotificationCubit>()
                            .loadNotifications(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final loaded = state as NotificationLoaded;
            final items = loaded.notifications;

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: WolfCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 54,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'لا توجد إشعارات',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ستظهر هنا التنبيهات المباشرة التي تحتاج إلى متابعتك.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final hasFooter = loaded.hasMore ||
                loaded.isLoadingMore ||
                loaded.paginationError != null;

            return RefreshIndicator(
              onRefresh: () =>
                  context.read<NotificationCubit>().loadNotifications(),
              color: AppTheme.primaryColor,
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: items.length + (hasFooter ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= items.length) {
                    if (loaded.isLoadingMore) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    if (loaded.paginationError != null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            Text(
                              loaded.paginationError!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              key: const Key('retry_load_more_button'),
                              onPressed: () => context
                                  .read<NotificationCubit>()
                                  .loadMoreNotifications(),
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: OutlinedButton(
                          key: const Key('load_more_notifications_button'),
                          onPressed: () => context
                              .read<NotificationCubit>()
                              .loadMoreNotifications(),
                          child: const Text('تحميل المزيد من الإشعارات'),
                        ),
                      ),
                    );
                  }

                  final item = items[index];
                  final isOpening = loaded.openingNotificationId == item.id;
                  final title = translateNotificationKey(item.titleKey);
                  final body = translateNotificationKey(
                    item.bodyKey,
                    fallback: 'إشعار نظام جديد.',
                  );
                  final timeFormatted =
                      DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt);

                  return Semantics(
                    label:
                        '$title، $body، ${item.isUnread ? "غير مقروء" : "مقروء"}',
                    button: true,
                    child: WolfCard(
                      key: Key('notification_item_${item.id}'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16.0),
                        onTap: isOpening
                            ? null
                            : () {
                                context
                                    .read<NotificationCubit>()
                                    .openNotification(
                                      item: item,
                                      onAuthorizedNavigation:
                                          (kind, id, isDynamicRequest) =>
                                              _handleNavigation(
                                        context,
                                        kind,
                                        id,
                                        isDynamicRequest,
                                      ),
                                    );
                              },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 64),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Unread indicator dot or loading indicator
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: isOpening
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primaryColor,
                                          ),
                                        )
                                      : Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: item.isUnread
                                                ? AppTheme.primaryColor
                                                : Colors.transparent,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: item.isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: AppTheme.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            timeFormatted,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        body,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: item.isUnread
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );
}
}
