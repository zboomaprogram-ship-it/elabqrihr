import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import '../../domain/notification_repository.dart';
import '../cubit/notification_cubit.dart';
import '../cubit/notification_state.dart';
import '../screens/notification_center_screen.dart';

class NotificationBadgeIcon extends StatelessWidget {
  final VoidCallback? onTap;

  const NotificationBadgeIcon({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Production composition owns this provider. A missing dependency must
    // surface as a composition error instead of a zero-count inert button.
    final cubit = context.read<NotificationCubit>();

    return BlocBuilder<NotificationCubit, NotificationState>(
      bloc: cubit,
      builder: (context, state) {
        final unreadCount = state is NotificationLoaded ? state.unreadCount : 0;
        return _buildContent(context, unreadCount, cubit);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    int unreadCount,
    NotificationCubit cubit,
  ) {
    final semanticText =
        unreadCount > 0 ? '$unreadCount إشعار غير مقروء' : 'مركز الإشعارات';

    return Semantics(
      label: semanticText,
      button: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            key: const Key('notification_badge_button'),
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.primaryColor,
              size: 26,
            ),
            tooltip: 'الإشعارات',
            onPressed: () {
              if (onTap != null) {
                onTap!();
              } else {
                NotificationRepository? repository;
                try {
                  repository = context.read<NotificationRepository>();
                } catch (_) {}
                Navigator.of(context, rootNavigator: true).push(
                  NotificationCenterScreen.route(
                    cubit: cubit,
                    repository: repository,
                  ),
                );
              }
            },
          ),
          if (unreadCount > 0)
            Positioned(
              top: 6,
              left: 6,
              child: IgnorePointer(
                child: Container(
                  key: const Key('notification_unread_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '+99' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
