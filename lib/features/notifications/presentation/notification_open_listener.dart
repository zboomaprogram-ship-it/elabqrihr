import 'dart:async';

import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/notification_deep_link_coordinator.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bridges FCM system-notification taps into an authenticated, reauthorized
/// in-app destination. The FCM payload contains only an opaque notification
/// ID; permissions are checked again by [NotificationDeepLinkCoordinator].
final class NotificationOpenListener extends StatefulWidget {
  const NotificationOpenListener({required this.child, super.key});

  final Widget child;

  @override
  State<NotificationOpenListener> createState() =>
      _NotificationOpenListenerState();
}

final class _NotificationOpenListenerState
    extends State<NotificationOpenListener> {
  StreamSubscription<String>? _openedSubscription;
  String? _lastHandledId;

  @override
  void initState() {
    super.initState();
    final port = _notificationPortOrNull();
    if (port == null) return;

    _openedSubscription = port.openedMessageIds.listen(_openNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialId = await port.initialMessageId();
      if (mounted && initialId != null) _openNotification(initialId);
    });
  }

  PushNotificationPort? _notificationPortOrNull() {
    try {
      return context.read<PushNotificationPort>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNotification(String notificationId) async {
    if (!mounted ||
        notificationId.isEmpty ||
        notificationId == _lastHandledId) {
      return;
    }
    _lastHandledId = notificationId;
    final result = await NotificationDeepLinkCoordinator(
      repository: context.read<NotificationRepository>(),
    ).resolveOpaqueNotification(notificationId);
    if (!mounted) return;
    try {
      context.read<NotificationCubit>().refreshUnreadCount();
    } catch (_) {
      // The authenticated application always provides the Cubit. Keeping this
      // listener tolerant also lets an isolated screen render safely.
    }
    if (result
        case DeepLinkAuthorized(
          :final destinationKind,
          :final destinationId,
          :final isDynamicRequest,
        )) {
      navigateAuthorizedNotificationDestination(
        context,
        destinationKind,
        destinationId,
        isDynamicRequest: isDynamicRequest,
      );
    }
  }

  @override
  void dispose() {
    _openedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
