import 'package:equatable/equatable.dart';

/// Categories of attendance reminders supported by the client.
enum ReminderCategory {
  shiftStart('shift_start', 'تنبيه بداية الوردية'),
  checkout('checkout', 'تذكير تسجيل الانصراف'),
  permissionReturn('permission_return', 'تنبيه استئناف العمل');

  final String wireValue;
  final String labelAr;

  const ReminderCategory(this.wireValue, this.labelAr);

  static ReminderCategory fromWire(String value) {
    return switch (value) {
      'shift_start' => ReminderCategory.shiftStart,
      'checkout' => ReminderCategory.checkout,
      'permission_return' => ReminderCategory.permissionReturn,
      _ => throw ArgumentError('Unknown reminder category: $value'),
    };
  }
}

/// Source type for an authoritative reminder event.
enum ReminderSourceKind {
  shift('shift'),
  permission('permission');

  final String wireValue;

  const ReminderSourceKind(this.wireValue);

  static ReminderSourceKind fromWire(String value) {
    return switch (value) {
      'shift' => ReminderSourceKind.shift,
      'permission' => ReminderSourceKind.permission,
      _ => throw ArgumentError('Unknown reminder source kind: $value'),
    };
  }
}

/// Authoritative fact returned by the server feed.
class ReminderFeedItem extends Equatable {
  final ReminderSourceKind sourceKind;
  final String sourceId;
  final int sourceRevision;
  final ReminderCategory category;
  final DateTime scheduledFor;
  final bool eligible;
  final String? reasonCode;

  const ReminderFeedItem({
    required this.sourceKind,
    required this.sourceId,
    required this.sourceRevision,
    required this.category,
    required this.scheduledFor,
    required this.eligible,
    this.reasonCode,
  });

  factory ReminderFeedItem.fromJson(Map<String, dynamic> json) {
    return ReminderFeedItem(
      sourceKind: ReminderSourceKind.fromWire(json['sourceKind'] as String),
      sourceId: json['sourceId'] as String,
      sourceRevision: json['sourceRevision'] as int,
      category: ReminderCategory.fromWire(json['category'] as String),
      scheduledFor: DateTime.parse(json['scheduledFor'] as String),
      eligible: json['eligible'] as bool? ?? true,
      reasonCode: json['reasonCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sourceKind': sourceKind.wireValue,
      'sourceId': sourceId,
      'sourceRevision': sourceRevision,
      'category': category.wireValue,
      'scheduledFor': scheduledFor.toIso8601String(),
      'eligible': eligible,
      if (reasonCode != null) 'reasonCode': reasonCode,
    };
  }

  /// Unique deterministic key for scheduling on the local device.
  String get deterministicKey => '${category.wireValue}_${sourceId}_$sourceRevision';

  @override
  List<Object?> get props => [
        sourceKind,
        sourceId,
        sourceRevision,
        category,
        scheduledFor,
        eligible,
        reasonCode,
      ];
}

/// Bounded feed of authoritative facts for scheduling reminders.
class ReminderFeed extends Equatable {
  final String feedRevision;
  final DateTime generatedAt;
  final String timezone;
  final List<ReminderFeedItem> items;

  const ReminderFeed({
    required this.feedRevision,
    required this.generatedAt,
    required this.timezone,
    required this.items,
  });

  factory ReminderFeed.fromJson(Map<String, dynamic> json) {
    final list = (json['items'] as List<dynamic>? ?? [])
        .map((item) => ReminderFeedItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return ReminderFeed(
      feedRevision: json['feedRevision'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      timezone: json['timezone'] as String? ?? 'UTC',
      items: list,
    );
  }

  @override
  List<Object?> get props => [feedRevision, generatedAt, timezone, items];
}

/// Client-side preferences stored per employee and tenant.
class ReminderPreferences extends Equatable {
  final bool shiftStartEnabled;
  final int shiftStartLeadMinutes; // 15 or 30 minutes
  final bool checkoutEnabled;
  final bool permissionReturnEnabled;
  final int permissionReturnLeadMinutes; // default 10 minutes
  final DateTime? lastSyncAt;
  final bool permissionGranted;

  const ReminderPreferences({
    this.shiftStartEnabled = false,
    this.shiftStartLeadMinutes = 15,
    this.checkoutEnabled = false,
    this.permissionReturnEnabled = false,
    this.permissionReturnLeadMinutes = 10,
    this.lastSyncAt,
    this.permissionGranted = false,
  });

  ReminderPreferences copyWith({
    bool? shiftStartEnabled,
    int? shiftStartLeadMinutes,
    bool? checkoutEnabled,
    bool? permissionReturnEnabled,
    int? permissionReturnLeadMinutes,
    DateTime? lastSyncAt,
    bool? permissionGranted,
  }) {
    return ReminderPreferences(
      shiftStartEnabled: shiftStartEnabled ?? this.shiftStartEnabled,
      shiftStartLeadMinutes:
          shiftStartLeadMinutes ?? this.shiftStartLeadMinutes,
      checkoutEnabled: checkoutEnabled ?? this.checkoutEnabled,
      permissionReturnEnabled:
          permissionReturnEnabled ?? this.permissionReturnEnabled,
      permissionReturnLeadMinutes:
          permissionReturnLeadMinutes ?? this.permissionReturnLeadMinutes,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shiftStartEnabled': shiftStartEnabled,
      'shiftStartLeadMinutes': shiftStartLeadMinutes,
      'checkoutEnabled': checkoutEnabled,
      'permissionReturnEnabled': permissionReturnEnabled,
      'permissionReturnLeadMinutes': permissionReturnLeadMinutes,
      if (lastSyncAt != null) 'lastSyncAt': lastSyncAt!.toIso8601String(),
      'permissionGranted': permissionGranted,
    };
  }

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    return ReminderPreferences(
      shiftStartEnabled: json['shiftStartEnabled'] as bool? ?? false,
      shiftStartLeadMinutes: json['shiftStartLeadMinutes'] as int? ?? 15,
      checkoutEnabled: json['checkoutEnabled'] as bool? ?? false,
      permissionReturnEnabled: json['permissionReturnEnabled'] as bool? ?? false,
      permissionReturnLeadMinutes:
          json['permissionReturnLeadMinutes'] as int? ?? 10,
      lastSyncAt: json['lastSyncAt'] != null
          ? DateTime.parse(json['lastSyncAt'] as String)
          : null,
      permissionGranted: json['permissionGranted'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        shiftStartEnabled,
        shiftStartLeadMinutes,
        checkoutEnabled,
        permissionReturnEnabled,
        permissionReturnLeadMinutes,
        lastSyncAt,
        permissionGranted,
      ];
}

/// A scheduled reminder instance tracked locally on device.
class ScheduledReminderInstance extends Equatable {
  final int notificationId;
  final String deterministicKey;
  final ReminderCategory category;
  final DateTime scheduledAt;
  final String titleAr;
  final String bodyAr;

  const ScheduledReminderInstance({
    required this.notificationId,
    required this.deterministicKey,
    required this.category,
    required this.scheduledAt,
    required this.titleAr,
    required this.bodyAr,
  });

  @override
  List<Object?> get props => [
        notificationId,
        deterministicKey,
        category,
        scheduledAt,
        titleAr,
        bodyAr,
      ];
}
