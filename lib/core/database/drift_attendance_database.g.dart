// GENERATED CODE - COMPATIBLE WITH DRIFT 2.31.0
// ignore_for_file: type=lint
part of 'drift_attendance_database.dart';

class LocalAttendanceRow extends DataClass
    implements Insertable<LocalAttendanceRow> {
  final String id;
  final String tenantId;
  final String userId;
  final String shiftInstanceId;
  final String eventType;
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? deviceId;
  final String syncStatus;
  final String? reasonCode;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;

  const LocalAttendanceRow({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.shiftInstanceId,
    required this.eventType,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.deviceId,
    required this.syncStatus,
    this.reasonCode,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['user_id'] = Variable<String>(userId);
    map['shift_instance_id'] = Variable<String>(shiftInstanceId);
    map['event_type'] = Variable<String>(eventType);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || accuracyMeters != null) {
      map['accuracy_meters'] = Variable<double>(accuracyMeters);
    }
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || reasonCode != null) {
      map['reason_code'] = Variable<String>(reasonCode);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAttendanceEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalAttendanceEntriesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      userId: Value(userId),
      shiftInstanceId: Value(shiftInstanceId),
      eventType: Value(eventType),
      capturedAt: Value(capturedAt),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracyMeters: accuracyMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyMeters),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      syncStatus: Value(syncStatus),
      reasonCode: reasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonCode),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAttendanceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttendanceRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      userId: serializer.fromJson<String>(json['userId']),
      shiftInstanceId: serializer.fromJson<String>(json['shiftInstanceId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracyMeters: serializer.fromJson<double?>(json['accuracyMeters']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      reasonCode: serializer.fromJson<String?>(json['reasonCode']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'userId': serializer.toJson<String>(userId),
      'shiftInstanceId': serializer.toJson<String>(shiftInstanceId),
      'eventType': serializer.toJson<String>(eventType),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracyMeters': serializer.toJson<double?>(accuracyMeters),
      'deviceId': serializer.toJson<String?>(deviceId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'reasonCode': serializer.toJson<String?>(reasonCode),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }
}

class LocalAttendanceEntriesCompanion
    extends UpdateCompanion<LocalAttendanceRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> userId;
  final Value<String> shiftInstanceId;
  final Value<String> eventType;
  final Value<DateTime> capturedAt;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracyMeters;
  final Value<String?> deviceId;
  final Value<String> syncStatus;
  final Value<String?> reasonCode;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;

  const LocalAttendanceEntriesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.userId = const Value.absent(),
    this.shiftInstanceId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracyMeters = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  LocalAttendanceEntriesCompanion.custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? userId,
    Expression<String>? shiftInstanceId,
    Expression<String>? eventType,
    Expression<DateTime>? capturedAt,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracyMeters,
    Expression<String>? deviceId,
    Expression<String>? syncStatus,
    Expression<String>? reasonCode,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
  })  : id = id != null ? Value.absent() : const Value.absent(),
        tenantId = tenantId != null ? Value.absent() : const Value.absent(),
        userId = userId != null ? Value.absent() : const Value.absent(),
        shiftInstanceId =
            shiftInstanceId != null ? Value.absent() : const Value.absent(),
        eventType = eventType != null ? Value.absent() : const Value.absent(),
        capturedAt = capturedAt != null ? Value.absent() : const Value.absent(),
        latitude = latitude != null ? Value.absent() : const Value.absent(),
        longitude = longitude != null ? Value.absent() : const Value.absent(),
        accuracyMeters =
            accuracyMeters != null ? Value.absent() : const Value.absent(),
        deviceId = deviceId != null ? Value.absent() : const Value.absent(),
        syncStatus = syncStatus != null ? Value.absent() : const Value.absent(),
        reasonCode = reasonCode != null ? Value.absent() : const Value.absent(),
        retryCount = retryCount != null ? Value.absent() : const Value.absent(),
        nextRetryAt =
            nextRetryAt != null ? Value.absent() : const Value.absent(),
        createdAt = createdAt != null ? Value.absent() : const Value.absent();

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (tenantId.present) map['tenant_id'] = Variable<String>(tenantId.value);
    if (userId.present) map['user_id'] = Variable<String>(userId.value);
    if (shiftInstanceId.present)
      map['shift_instance_id'] = Variable<String>(shiftInstanceId.value);
    if (eventType.present)
      map['event_type'] = Variable<String>(eventType.value);
    if (capturedAt.present)
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    if (latitude.present) map['latitude'] = Variable<double>(latitude.value);
    if (longitude.present) map['longitude'] = Variable<double>(longitude.value);
    if (accuracyMeters.present)
      map['accuracy_meters'] = Variable<double>(accuracyMeters.value);
    if (deviceId.present) map['device_id'] = Variable<String>(deviceId.value);
    if (syncStatus.present)
      map['sync_status'] = Variable<String>(syncStatus.value);
    if (reasonCode.present)
      map['reason_code'] = Variable<String>(reasonCode.value);
    if (retryCount.present)
      map['retry_count'] = Variable<int>(retryCount.value);
    if (nextRetryAt.present)
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    if (createdAt.present)
      map['created_at'] = Variable<DateTime>(createdAt.value);
    return map;
  }
}

class $LocalAttendanceEntriesTable extends LocalAttendanceEntries
    with TableInfo<$LocalAttendanceEntriesTable, LocalAttendanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceEntriesTable(this.attachedDatabase, [this._alias]);

  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> shiftInstanceId = GeneratedColumn<String>(
      'shift_instance_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);

  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);

  late final GeneratedColumn<double> accuracyMeters = GeneratedColumn<double>(
      'accuracy_meters', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);

  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);

  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
      'reason_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);

  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);

  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        userId,
        shiftInstanceId,
        eventType,
        capturedAt,
        latitude,
        longitude,
        accuracyMeters,
        deviceId,
        syncStatus,
        reasonCode,
        retryCount,
        nextRetryAt,
        createdAt
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => 'local_attendance_entries';

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, userId, id};

  @override
  LocalAttendanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttendanceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      shiftInstanceId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}shift_instance_id'])!,
      eventType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_type'])!,
      capturedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}captured_at'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude'])!,
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude'])!,
      accuracyMeters: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}accuracy_meters']),
      deviceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_id']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      reasonCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason_code']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}next_retry_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalAttendanceEntriesTable createAlias(String alias) {
    return $LocalAttendanceEntriesTable(attachedDatabase, alias);
  }
}

class LocalRequestRow extends DataClass implements Insertable<LocalRequestRow> {
  final String id;
  final String tenantId;
  final String userId;
  final String requestType;
  final String payloadJson;
  final String syncStatus;
  final String? reasonCode;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;

  const LocalRequestRow({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.requestType,
    required this.payloadJson,
    required this.syncStatus,
    this.reasonCode,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
  });

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['user_id'] = Variable<String>(userId);
    map['request_type'] = Variable<String>(requestType);
    map['payload_json'] = Variable<String>(payloadJson);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || reasonCode != null) {
      map['reason_code'] = Variable<String>(reasonCode);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalRequestEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalRequestEntriesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      userId: Value(userId),
      requestType: Value(requestType),
      payloadJson: Value(payloadJson),
      syncStatus: Value(syncStatus),
      reasonCode: reasonCode == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonCode),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory LocalRequestRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRequestRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      userId: serializer.fromJson<String>(json['userId']),
      requestType: serializer.fromJson<String>(json['requestType']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      reasonCode: serializer.fromJson<String?>(json['reasonCode']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }

  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'userId': serializer.toJson<String>(userId),
      'requestType': serializer.toJson<String>(requestType),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'reasonCode': serializer.toJson<String?>(reasonCode),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }
}

class LocalRequestEntriesCompanion extends UpdateCompanion<LocalRequestRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> userId;
  final Value<String> requestType;
  final Value<String> payloadJson;
  final Value<String> syncStatus;
  final Value<String?> reasonCode;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;

  const LocalRequestEntriesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.userId = const Value.absent(),
    this.requestType = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });

  LocalRequestEntriesCompanion.insert({
    required String id,
    required String tenantId,
    required String userId,
    required String requestType,
    required String payloadJson,
    required String syncStatus,
    this.reasonCode = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime createdAt,
  })  : id = Value(id),
        tenantId = Value(tenantId),
        userId = Value(userId),
        requestType = Value(requestType),
        payloadJson = Value(payloadJson),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);

  LocalRequestEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? userId,
    Value<String>? requestType,
    Value<String>? payloadJson,
    Value<String>? syncStatus,
    Value<String?>? reasonCode,
    Value<int>? retryCount,
    Value<DateTime?>? nextRetryAt,
    Value<DateTime>? createdAt,
  }) {
    return LocalRequestEntriesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      requestType: requestType ?? this.requestType,
      payloadJson: payloadJson ?? this.payloadJson,
      syncStatus: syncStatus ?? this.syncStatus,
      reasonCode: reasonCode ?? this.reasonCode,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) map['id'] = Variable<String>(id.value);
    if (tenantId.present) map['tenant_id'] = Variable<String>(tenantId.value);
    if (userId.present) map['user_id'] = Variable<String>(userId.value);
    if (requestType.present)
      map['request_type'] = Variable<String>(requestType.value);
    if (payloadJson.present)
      map['payload_json'] = Variable<String>(payloadJson.value);
    if (syncStatus.present)
      map['sync_status'] = Variable<String>(syncStatus.value);
    if (reasonCode.present)
      map['reason_code'] = Variable<String>(reasonCode.value);
    if (retryCount.present)
      map['retry_count'] = Variable<int>(retryCount.value);
    if (nextRetryAt.present)
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    if (createdAt.present)
      map['created_at'] = Variable<DateTime>(createdAt.value);
    return map;
  }
}

class $LocalRequestEntriesTable extends LocalRequestEntries
    with TableInfo<$LocalRequestEntriesTable, LocalRequestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRequestEntriesTable(this.attachedDatabase, [this._alias]);

  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> requestType = GeneratedColumn<String>(
      'request_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);

  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
      'reason_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);

  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));

  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);

  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);

  @override
  List<GeneratedColumn> get $columns => [
        id,
        tenantId,
        userId,
        requestType,
        payloadJson,
        syncStatus,
        reasonCode,
        retryCount,
        nextRetryAt,
        createdAt,
      ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => 'local_request_entries';

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, userId, id};

  @override
  LocalRequestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRequestRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      tenantId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tenant_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      requestType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}request_type'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      reasonCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reason_code']),
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      nextRetryAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}next_retry_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalRequestEntriesTable createAlias(String alias) {
    return $LocalRequestEntriesTable(attachedDatabase, alias);
  }
}

abstract class _$AppDriftDatabase extends GeneratedDatabase {
  _$AppDriftDatabase(QueryExecutor e) : super(e);
  late final $LocalAttendanceEntriesTable localAttendanceEntries =
      $LocalAttendanceEntriesTable(this);
  late final $LocalRequestEntriesTable localRequestEntries =
      $LocalRequestEntriesTable(this);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localAttendanceEntries, localRequestEntries];
}
