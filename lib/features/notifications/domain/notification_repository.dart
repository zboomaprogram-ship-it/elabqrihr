import 'notification_models.dart';

abstract class NotificationRepository {
  /// Reads an opaque notification ID. Concrete production implementations use
  /// the dedicated endpoint; this fallback keeps older test doubles usable.
  Future<NotificationEntity?> getNotification(String notificationId) async {
    String? cursor;
    do {
      final page = await listNotifications(cursor: cursor, limit: 100);
      for (final item in page.items) {
        if (item.id == notificationId) return item;
      }
      cursor = page.nextCursor;
    } while (cursor != null);
    return null;
  }

  /// Fetches a paginated list of recipient notifications.
  Future<NotificationPageEntity> listNotifications({
    String? cursor,
    int limit = 50,
  });

  /// Fetches the authoritative unread notification count.
  Future<int> getUnreadCount();

  /// Marks a specific notification as read.
  Future<NotificationEntity> markAsRead(String notificationId);

  /// Marks all eligible notifications as read up to [before] using [commandId].
  Future<int> markAllAsRead({
    String? commandId,
    DateTime? before,
  });

  /// Reauthorizes the notification destination before navigation.
  /// Returns [ReauthorizationResult.authorized] if access is valid,
  /// [ReauthorizationResult.forbidden] or [ReauthorizationResult.notFound]
  /// if access was revoked or resource deleted.
  Future<ReauthorizationResult> reauthorizeDestination(
    NotificationDestinationKind kind,
    String destinationId,
  );
}
