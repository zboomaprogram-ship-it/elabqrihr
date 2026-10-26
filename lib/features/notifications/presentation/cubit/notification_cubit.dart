import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/notification_models.dart';
import '../../domain/notification_repository.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final NotificationRepository repository;
  final Uuid _uuid;
  String? _pendingReadCommandId;

  NotificationCubit({
    required this.repository,
    Uuid? uuid,
  })  : _uuid = uuid ?? const Uuid(),
        super(const NotificationInitial());

  @override
  void emit(NotificationState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Loads initial notifications page and unread count.
  Future<void> loadNotifications() async {
    emit(const NotificationLoading());
    try {
      final page = await repository.listNotifications(limit: 50);
      final unreadCount = await repository.getUnreadCount();
      emit(NotificationLoaded(
        notifications: page.items,
        unreadCount: unreadCount,
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      emit(const NotificationError('تعذر تحميل الإشعارات. حاول مرة أخرى.'));
    }
  }

  /// Refreshes the unread count independently (e.g. for badges).
  Future<void> refreshUnreadCount() async {
    try {
      final count = await repository.getUnreadCount();
      if (state is NotificationLoaded) {
        emit((state as NotificationLoaded).copyWith(unreadCount: count));
      } else if (state is NotificationInitial) {
        emit(NotificationLoaded(
          notifications: const [],
          unreadCount: count,
        ));
      }
    } catch (_) {}
  }

  /// Loads next page of notifications using cursor without duplicates.
  Future<void> loadMoreNotifications() async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;
    if (current.isLoadingMore || !current.hasMore) return;

    emit(current.copyWith(
      isLoadingMore: true,
      clearPaginationError: true,
    ));

    try {
      final page = await repository.listNotifications(
        cursor: current.nextCursor,
        limit: 50,
      );

      final existingIds = current.notifications.map((n) => n.id).toSet();
      final newItems =
          page.items.where((n) => !existingIds.contains(n.id)).toList();
      final merged = [...current.notifications, ...newItems];

      emit(current.copyWith(
        notifications: merged,
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
        isLoadingMore: false,
      ));
    } catch (_) {
      emit(current.copyWith(
        isLoadingMore: false,
        paginationError: 'تعذر تحميل المزيد من الإشعارات. حاول مرة أخرى.',
      ));
    }
  }

  /// Marks a single notification as read only upon server confirmation.
  Future<void> markAsRead(String notificationId) async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;

    final targetItem =
        current.notifications.where((n) => n.id == notificationId).firstOrNull;

    // Monotonic guard: if item is already marked read, skip redundant action
    if (targetItem != null && !targetItem.isUnread) {
      return;
    }

    try {
      final confirmed = await repository.markAsRead(notificationId);
      final updatedList = current.notifications.map((item) {
        if (item.id == notificationId) {
          return confirmed;
        }
        return item;
      }).toList();

      final newCount = (current.unreadCount > 0) ? current.unreadCount - 1 : 0;

      emit(current.copyWith(
        notifications: updatedList,
        unreadCount: newCount,
        clearActionError: true,
      ));
    } catch (_) {
      // Leave item unread on server failure and show safe Arabic retry state
      emit(current.copyWith(
        actionError: 'تعذر تحديث حالة القراءة. حاول مرة أخرى.',
      ));
    }
  }

  /// Marks all current notifications as read using a persistent command ID across retries.
  Future<void> markAllAsRead() async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;

    // Retain one command ID across uncertain retries
    _pendingReadCommandId ??= _uuid.v4();

    try {
      await repository.markAllAsRead(
        commandId: _pendingReadCommandId,
      );
      _pendingReadCommandId = null;

      final now = DateTime.now();
      final updatedList = current.notifications.map((item) {
        return item.copyWith(
          readState: NotificationReadState.read,
          readAt: item.readAt ?? now,
        );
      }).toList();

      emit(current.copyWith(
        notifications: updatedList,
        unreadCount: 0,
        clearActionError: true,
      ));
    } catch (_) {
      // Retain command ID for retry, leave items unread, emit error
      emit(current.copyWith(
        actionError: 'تعذر تحديث حالة القراءة. حاول مرة أخرى.',
      ));
    }
  }

  /// Opens a notification by confirming read and reauthorizing destination via live API.
  Future<void> openNotification({
    required NotificationEntity item,
    required void Function(
      NotificationDestinationKind kind,
      String destinationId,
      bool isDynamicRequest,
    ) onAuthorizedNavigation,
  }) async {
    if (state is! NotificationLoaded) return;
    final current = state as NotificationLoaded;

    // Informational notifications (such as employee administration or destination-less items)
    // are read-only: mark read without attempting navigation or showing a destination error.
    if (!item.isActionable) {
      if (item.isUnread) {
        await markAsRead(item.id);
      }
      return;
    }

    emit(current.copyWith(
      openingNotificationId: item.id,
      clearActionError: true,
    ));

    try {
      NotificationEntity readItem = item;
      if (item.isUnread) {
        readItem = await repository.markAsRead(item.id);
      }

      final reauth = await repository.reauthorizeDestination(
        item.destinationKind,
        item.destinationId,
      );

      final updatedList = current.notifications.map((candidate) {
        if (candidate.id == item.id) {
          return readItem;
        }
        return candidate;
      }).toList();

      final newCount = (current.unreadCount > 0 && item.isUnread)
          ? current.unreadCount - 1
          : current.unreadCount;

      switch (reauth) {
        case ReauthorizationResult.authorized:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            clearActionError: true,
          ));
          onAuthorizedNavigation(
            item.destinationKind,
            item.destinationId,
            false,
          );
        case ReauthorizationResult.authorizedDynamicRequest:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            clearActionError: true,
          ));
          onAuthorizedNavigation(
            item.destinationKind,
            item.destinationId,
            true,
          );
        case ReauthorizationResult.unavailable:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            actionError: 'هذه الوجهة غير متاحة على تطبيق الجوال.',
          ));
        case ReauthorizationResult.forbidden:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            actionError: 'لم تعد لديك صلاحية فتح هذه الوجهة.',
          ));
        case ReauthorizationResult.notFound:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            actionError: 'الوجهة المطلوبة لم تعد موجودة.',
          ));
        case ReauthorizationResult.error:
          emit(current.copyWith(
            notifications: updatedList,
            unreadCount: newCount,
            clearOpeningId: true,
            actionError: 'تعذر التحقق من وجهة الإشعار. حاول مرة أخرى.',
          ));
      }
    } catch (_) {
      emit(current.copyWith(
        clearOpeningId: true,
        actionError: 'تعذر فتح الإشعار. حاول مرة أخرى.',
      ));
    }
  }

  void clearActionError() {
    if (state is NotificationLoaded) {
      emit((state as NotificationLoaded).copyWith(clearActionError: true));
    }
  }

  void clearPaginationError() {
    if (state is NotificationLoaded) {
      emit((state as NotificationLoaded).copyWith(clearPaginationError: true));
    }
  }
}
