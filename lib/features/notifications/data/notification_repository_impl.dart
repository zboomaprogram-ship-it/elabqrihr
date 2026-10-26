import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import '../domain/notification_models.dart';
import '../domain/notification_repository.dart';

extension on RecipientNotificationDto {
  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        kind: kind,
        titleKey: titleKey,
        bodyKey: bodyKey,
        destinationKind: switch (destinationKind) {
          NotificationDestinationKindDto.attendance =>
            NotificationDestinationKind.attendance,
          NotificationDestinationKindDto.request =>
            NotificationDestinationKind.request,
          NotificationDestinationKindDto.approval =>
            NotificationDestinationKind.approval,
          NotificationDestinationKindDto.employee =>
            NotificationDestinationKind.employee,
          NotificationDestinationKindDto.report =>
            NotificationDestinationKind.report,
          NotificationDestinationKindDto.announcement =>
            NotificationDestinationKind.announcement,
          NotificationDestinationKindDto.finalSettlement =>
            NotificationDestinationKind.finalSettlement,
        },
        destinationId: destinationId,
        readState: switch (readState) {
          NotificationReadStateDto.unread => NotificationReadState.unread,
          NotificationReadStateDto.read => NotificationReadState.read,
        },
        readAt: readAt,
        createdAt: createdAt,
      );
}

extension on NotificationPageDto {
  NotificationPageEntity toEntity() => NotificationPageEntity(
        items: items.map((e) => e.toEntity()).toList(),
        nextCursor: nextCursor,
      );
}

class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient apiClient;
  final Uuid _uuid;

  NotificationRepositoryImpl({
    required this.apiClient,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<NotificationPageEntity> listNotifications({
    String? cursor,
    int limit = 50,
  }) async {
    final dto = await apiClient.listNotifications(
      cursor: cursor,
      limit: limit,
    );
    return dto.toEntity();
  }

  @override
  Future<NotificationEntity?> getNotification(String notificationId) async {
    try {
      return (await apiClient.getNotification(notificationId)).toEntity();
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final dto = await apiClient.getUnreadNotificationCount();
    return dto.count;
  }

  @override
  Future<NotificationEntity> markAsRead(String notificationId) async {
    final dto = await apiClient.markNotificationRead(notificationId);
    return dto.toEntity();
  }

  @override
  Future<int> markAllAsRead({
    String? commandId,
    DateTime? before,
  }) async {
    final effectiveCommandId = commandId ?? _uuid.v4();
    final dto = await apiClient.markAllNotificationsRead(
      commandId: effectiveCommandId,
      before: before,
    );
    return dto.count;
  }

  @override
  Future<ReauthorizationResult> reauthorizeDestination(
    NotificationDestinationKind kind,
    String destinationId,
  ) async {
    if (kind == NotificationDestinationKind.employee) {
      // Mobile has no approved employee administration screen.
      return ReauthorizationResult.unavailable;
    }

    try {
      if (kind == NotificationDestinationKind.report) {
        // Reauthorize via live workforce report endpoint with required date range
        final now = DateTime.now();
        final from = now.subtract(const Duration(days: 30));
        await apiClient.getWorkforceSummary(from: from, to: now);
        return ReauthorizationResult.authorized;
      }

      final path = switch (kind) {
        NotificationDestinationKind.attendance => '/attendance/current',
        NotificationDestinationKind.request ||
        NotificationDestinationKind.approval =>
          '/requests/$destinationId',
        NotificationDestinationKind.announcement =>
          '/company-announcements/$destinationId',
        NotificationDestinationKind.finalSettlement =>
          '/final-settlements/$destinationId',
        _ => null,
      };

      if (path == null) {
        return ReauthorizationResult.unavailable;
      }

      final response = await apiClient.dio.get(path);
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ReauthorizationResult.authorized;
      }
      return ReauthorizationResult.error;
    } on ApiException catch (e) {
      if ((kind == NotificationDestinationKind.request ||
              kind == NotificationDestinationKind.approval) &&
          e.statusCode == 404) {
        return _reauthorizeDynamicRequest(destinationId);
      }
      if (e.statusCode == 403) {
        return ReauthorizationResult.forbidden;
      }
      if (e.statusCode == 404) {
        return ReauthorizationResult.notFound;
      }
      return ReauthorizationResult.error;
    } on DioException catch (e) {
      if ((kind == NotificationDestinationKind.request ||
              kind == NotificationDestinationKind.approval) &&
          e.response?.statusCode == 404) {
        return _reauthorizeDynamicRequest(destinationId);
      }
      final statusCode = e.response?.statusCode;
      if (statusCode == 403) {
        return ReauthorizationResult.forbidden;
      }
      if (statusCode == 404) {
        return ReauthorizationResult.notFound;
      }
      return ReauthorizationResult.error;
    } catch (_) {
      return ReauthorizationResult.error;
    }
  }

  Future<ReauthorizationResult> _reauthorizeDynamicRequest(
    String destinationId,
  ) async {
    try {
      final response =
          await apiClient.dio.get('/dynamic-requests/$destinationId');
      return response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 300
          ? ReauthorizationResult.authorizedDynamicRequest
          : ReauthorizationResult.error;
    } on ApiException catch (error) {
      return switch (error.statusCode) {
        403 => ReauthorizationResult.forbidden,
        404 => ReauthorizationResult.notFound,
        _ => ReauthorizationResult.error,
      };
    } on DioException catch (error) {
      return switch (error.response?.statusCode) {
        403 => ReauthorizationResult.forbidden,
        404 => ReauthorizationResult.notFound,
        _ => ReauthorizationResult.error,
      };
    }
  }
}
