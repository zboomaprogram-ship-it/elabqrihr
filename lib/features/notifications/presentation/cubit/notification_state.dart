import 'package:equatable/equatable.dart';
import '../../domain/notification_models.dart';

sealed class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

final class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

final class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

final class NotificationLoaded extends NotificationState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final String? openingNotificationId;
  final String? nextCursor;
  final String? actionError;
  final bool isLoadingMore;
  final String? paginationError;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    this.openingNotificationId,
    this.nextCursor,
    this.actionError,
    this.isLoadingMore = false,
    this.paginationError,
  });

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  NotificationLoaded copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    String? openingNotificationId,
    bool clearOpeningId = false,
    String? nextCursor,
    bool clearNextCursor = false,
    String? actionError,
    bool clearActionError = false,
    bool? isLoadingMore,
    String? paginationError,
    bool clearPaginationError = false,
  }) {
    return NotificationLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      openingNotificationId: clearOpeningId
          ? null
          : (openingNotificationId ?? this.openingNotificationId),
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      paginationError: clearPaginationError
          ? null
          : (paginationError ?? this.paginationError),
    );
  }

  @override
  List<Object?> get props => [
        notifications,
        unreadCount,
        openingNotificationId,
        nextCursor,
        actionError,
        isLoadingMore,
        paginationError,
      ];
}

final class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object?> get props => [message];
}
