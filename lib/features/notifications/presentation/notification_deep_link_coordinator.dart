import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';

sealed class DeepLinkNavigationResult {
  const DeepLinkNavigationResult();
}

final class DeepLinkAuthorized extends DeepLinkNavigationResult {
  const DeepLinkAuthorized({
    required this.destinationKind,
    required this.destinationId,
    this.isDynamicRequest = false,
  });

  final NotificationDestinationKind destinationKind;
  final String destinationId;
  final bool isDynamicRequest;
}

final class DeepLinkForbidden extends DeepLinkNavigationResult {
  const DeepLinkForbidden();
}

final class DeepLinkNotFound extends DeepLinkNavigationResult {
  const DeepLinkNotFound();
}

final class DeepLinkUnavailable extends DeepLinkNavigationResult {
  const DeepLinkUnavailable();
}

final class DeepLinkError extends DeepLinkNavigationResult {
  const DeepLinkError();
}

/// Resolves opaque notification IDs through the authorized repository
/// before navigating to the target screen.
///
/// Implements Feature 012 Task T061.
final class NotificationDeepLinkCoordinator {
  const NotificationDeepLinkCoordinator({
    required NotificationRepository repository,
  }) : _repository = repository;

  final NotificationRepository _repository;

  /// Resolves an opaque notification ID by fetching its destination and reauthorizing it.
  ///
  /// Never navigates directly using unverified query parameters or raw payloads.
  Future<DeepLinkNavigationResult> resolveOpaqueNotification(
      String notificationId) async {
    try {
      // A system notification can be older than the first inbox page.
      final item = await _repository.getNotification(notificationId);

      if (item == null) {
        return const DeepLinkNotFound();
      }

      // Mark as read upon open if unread
      if (item.isUnread) {
        await _repository.markAsRead(item.id);
      }

      // 2. Reauthorize destination via live API
      final reauth = await _repository.reauthorizeDestination(
        item.destinationKind,
        item.destinationId,
      );

      return switch (reauth) {
        ReauthorizationResult.authorized => DeepLinkAuthorized(
            destinationKind: item.destinationKind,
            destinationId: item.destinationId,
            isDynamicRequest: item.kind.startsWith('dynamic_request.'),
          ),
        ReauthorizationResult.authorizedDynamicRequest => DeepLinkAuthorized(
            destinationKind: item.destinationKind,
            destinationId: item.destinationId,
            isDynamicRequest: true,
          ),
        ReauthorizationResult.forbidden => const DeepLinkForbidden(),
        ReauthorizationResult.notFound => const DeepLinkNotFound(),
        ReauthorizationResult.unavailable => const DeepLinkUnavailable(),
        ReauthorizationResult.error => const DeepLinkError(),
      };
    } catch (_) {
      return const DeepLinkError();
    }
  }

  /// Reauthorizes a known destination kind and ID directly.
  Future<DeepLinkNavigationResult> reauthorizeDirect({
    required NotificationDestinationKind destinationKind,
    required String destinationId,
  }) async {
    try {
      final reauth = await _repository.reauthorizeDestination(
        destinationKind,
        destinationId,
      );

      return switch (reauth) {
        ReauthorizationResult.authorized => DeepLinkAuthorized(
            destinationKind: destinationKind,
            destinationId: destinationId,
          ),
        ReauthorizationResult.authorizedDynamicRequest => DeepLinkAuthorized(
            destinationKind: destinationKind,
            destinationId: destinationId,
            isDynamicRequest: true,
          ),
        ReauthorizationResult.forbidden => const DeepLinkForbidden(),
        ReauthorizationResult.notFound => const DeepLinkNotFound(),
        ReauthorizationResult.unavailable => const DeepLinkUnavailable(),
        ReauthorizationResult.error => const DeepLinkError(),
      };
    } catch (_) {
      return const DeepLinkError();
    }
  }
}
