enum NotificationDestinationKind {
  attendance,
  request,
  approval,
  employee,
  report,
  announcement,
  finalSettlement;

  static NotificationDestinationKind fromString(String value) {
    return switch (value) {
      'attendance' => NotificationDestinationKind.attendance,
      'request' => NotificationDestinationKind.request,
      'approval' => NotificationDestinationKind.approval,
      'employee' => NotificationDestinationKind.employee,
      'report' => NotificationDestinationKind.report,
      'announcement' => NotificationDestinationKind.announcement,
      'final_settlement' => NotificationDestinationKind.finalSettlement,
      _ => NotificationDestinationKind.attendance,
    };
  }
}

enum NotificationReadState {
  unread,
  read;

  static NotificationReadState fromString(String value) {
    return switch (value) {
      'read' => NotificationReadState.read,
      _ => NotificationReadState.unread,
    };
  }
}

enum ReauthorizationResult {
  authorized,
  authorizedDynamicRequest,
  forbidden,
  notFound,
  unavailable,
  error;
}

class NotificationEntity {
  final String id;
  final String kind;
  final String titleKey;
  final String bodyKey;
  final NotificationDestinationKind destinationKind;
  final String destinationId;
  final NotificationReadState readState;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationEntity({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.bodyKey,
    required this.destinationKind,
    required this.destinationId,
    required this.readState,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readState == NotificationReadState.unread;
  bool get isRead => readState == NotificationReadState.read;

  /// In the mobile client, `employee` notifications and destination-less items
  /// are informational/read-only because there is no mobile employee detail route.
  bool get isActionable =>
      destinationKind != NotificationDestinationKind.employee &&
      destinationId.trim().isNotEmpty;

  NotificationEntity copyWith({
    String? id,
    String? kind,
    String? titleKey,
    String? bodyKey,
    NotificationDestinationKind? destinationKind,
    String? destinationId,
    NotificationReadState? readState,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      titleKey: titleKey ?? this.titleKey,
      bodyKey: bodyKey ?? this.bodyKey,
      destinationKind: destinationKind ?? this.destinationKind,
      destinationId: destinationId ?? this.destinationId,
      readState: readState ?? this.readState,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPageEntity {
  final List<NotificationEntity> items;
  final String? nextCursor;

  const NotificationPageEntity({
    required this.items,
    this.nextCursor,
  });
}
