// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_attendance_database.dart';

// ignore_for_file: type=lint
class $LocalAttendanceEntriesTable extends LocalAttendanceEntries
    with TableInfo<$LocalAttendanceEntriesTable, LocalAttendanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttendanceEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shiftInstanceIdMeta =
      const VerificationMeta('shiftInstanceId');
  @override
  late final GeneratedColumn<String> shiftInstanceId = GeneratedColumn<String>(
      'shift_instance_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventTypeMeta =
      const VerificationMeta('eventType');
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
      'event_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _capturedAtMeta =
      const VerificationMeta('capturedAt');
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
      'captured_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _locationCapturedAtMeta =
      const VerificationMeta('locationCapturedAt');
  @override
  late final GeneratedColumn<DateTime> locationCapturedAt =
      GeneratedColumn<DateTime>('location_captured_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _proofInstallationIdMeta =
      const VerificationMeta('proofInstallationId');
  @override
  late final GeneratedColumn<String> proofInstallationId =
      GeneratedColumn<String>('proof_installation_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _proofDigestMeta =
      const VerificationMeta('proofDigest');
  @override
  late final GeneratedColumn<String> proofDigest = GeneratedColumn<String>(
      'proof_digest', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _proofSignatureMeta =
      const VerificationMeta('proofSignature');
  @override
  late final GeneratedColumn<String> proofSignature = GeneratedColumn<String>(
      'proof_signature', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _accuracyMetersMeta =
      const VerificationMeta('accuracyMeters');
  @override
  late final GeneratedColumn<double> accuracyMeters = GeneratedColumn<double>(
      'accuracy_meters', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _deviceIdMeta =
      const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
      'device_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonCodeMeta =
      const VerificationMeta('reasonCode');
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
      'reason_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
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
        locationCapturedAt,
        proofInstallationId,
        proofDigest,
        proofSignature,
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
  String get actualTableName => $name;
  static const String $name = 'local_attendance_entries';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAttendanceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('shift_instance_id')) {
      context.handle(
          _shiftInstanceIdMeta,
          shiftInstanceId.isAcceptableOrUnknown(
              data['shift_instance_id']!, _shiftInstanceIdMeta));
    } else if (isInserting) {
      context.missing(_shiftInstanceIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(_eventTypeMeta,
          eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta));
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
          _capturedAtMeta,
          capturedAt.isAcceptableOrUnknown(
              data['captured_at']!, _capturedAtMeta));
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('location_captured_at')) {
      context.handle(
          _locationCapturedAtMeta,
          locationCapturedAt.isAcceptableOrUnknown(
              data['location_captured_at']!, _locationCapturedAtMeta));
    }
    if (data.containsKey('proof_installation_id')) {
      context.handle(
          _proofInstallationIdMeta,
          proofInstallationId.isAcceptableOrUnknown(
              data['proof_installation_id']!, _proofInstallationIdMeta));
    }
    if (data.containsKey('proof_digest')) {
      context.handle(
          _proofDigestMeta,
          proofDigest.isAcceptableOrUnknown(
              data['proof_digest']!, _proofDigestMeta));
    }
    if (data.containsKey('proof_signature')) {
      context.handle(
          _proofSignatureMeta,
          proofSignature.isAcceptableOrUnknown(
              data['proof_signature']!, _proofSignatureMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy_meters')) {
      context.handle(
          _accuracyMetersMeta,
          accuracyMeters.isAcceptableOrUnknown(
              data['accuracy_meters']!, _accuracyMetersMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta,
          deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    } else if (isInserting) {
      context.missing(_syncStatusMeta);
    }
    if (data.containsKey('reason_code')) {
      context.handle(
          _reasonCodeMeta,
          reasonCode.isAcceptableOrUnknown(
              data['reason_code']!, _reasonCodeMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

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
      locationCapturedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}location_captured_at']),
      proofInstallationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}proof_installation_id']),
      proofDigest: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proof_digest']),
      proofSignature: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}proof_signature']),
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

class LocalAttendanceRow extends DataClass
    implements Insertable<LocalAttendanceRow> {
  final String id;
  final String tenantId;
  final String userId;
  final String shiftInstanceId;
  final String eventType;
  final DateTime capturedAt;
  final DateTime? locationCapturedAt;
  final String? proofInstallationId;
  final String? proofDigest;
  final String? proofSignature;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String? deviceId;
  final String syncStatus;
  final String? reasonCode;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  const LocalAttendanceRow(
      {required this.id,
      required this.tenantId,
      required this.userId,
      required this.shiftInstanceId,
      required this.eventType,
      required this.capturedAt,
      this.locationCapturedAt,
      this.proofInstallationId,
      this.proofDigest,
      this.proofSignature,
      required this.latitude,
      required this.longitude,
      this.accuracyMeters,
      this.deviceId,
      required this.syncStatus,
      this.reasonCode,
      required this.retryCount,
      this.nextRetryAt,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['user_id'] = Variable<String>(userId);
    map['shift_instance_id'] = Variable<String>(shiftInstanceId);
    map['event_type'] = Variable<String>(eventType);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || locationCapturedAt != null) {
      map['location_captured_at'] = Variable<DateTime>(locationCapturedAt);
    }
    if (!nullToAbsent || proofInstallationId != null) {
      map['proof_installation_id'] = Variable<String>(proofInstallationId);
    }
    if (!nullToAbsent || proofDigest != null) {
      map['proof_digest'] = Variable<String>(proofDigest);
    }
    if (!nullToAbsent || proofSignature != null) {
      map['proof_signature'] = Variable<String>(proofSignature);
    }
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
      locationCapturedAt: locationCapturedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(locationCapturedAt),
      proofInstallationId: proofInstallationId == null && nullToAbsent
          ? const Value.absent()
          : Value(proofInstallationId),
      proofDigest: proofDigest == null && nullToAbsent
          ? const Value.absent()
          : Value(proofDigest),
      proofSignature: proofSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(proofSignature),
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
      locationCapturedAt:
          serializer.fromJson<DateTime?>(json['locationCapturedAt']),
      proofInstallationId:
          serializer.fromJson<String?>(json['proofInstallationId']),
      proofDigest: serializer.fromJson<String?>(json['proofDigest']),
      proofSignature: serializer.fromJson<String?>(json['proofSignature']),
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
      'locationCapturedAt': serializer.toJson<DateTime?>(locationCapturedAt),
      'proofInstallationId': serializer.toJson<String?>(proofInstallationId),
      'proofDigest': serializer.toJson<String?>(proofDigest),
      'proofSignature': serializer.toJson<String?>(proofSignature),
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

  LocalAttendanceRow copyWith(
          {String? id,
          String? tenantId,
          String? userId,
          String? shiftInstanceId,
          String? eventType,
          DateTime? capturedAt,
          Value<DateTime?> locationCapturedAt = const Value.absent(),
          Value<String?> proofInstallationId = const Value.absent(),
          Value<String?> proofDigest = const Value.absent(),
          Value<String?> proofSignature = const Value.absent(),
          double? latitude,
          double? longitude,
          Value<double?> accuracyMeters = const Value.absent(),
          Value<String?> deviceId = const Value.absent(),
          String? syncStatus,
          Value<String?> reasonCode = const Value.absent(),
          int? retryCount,
          Value<DateTime?> nextRetryAt = const Value.absent(),
          DateTime? createdAt}) =>
      LocalAttendanceRow(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        userId: userId ?? this.userId,
        shiftInstanceId: shiftInstanceId ?? this.shiftInstanceId,
        eventType: eventType ?? this.eventType,
        capturedAt: capturedAt ?? this.capturedAt,
        locationCapturedAt: locationCapturedAt.present
            ? locationCapturedAt.value
            : this.locationCapturedAt,
        proofInstallationId: proofInstallationId.present
            ? proofInstallationId.value
            : this.proofInstallationId,
        proofDigest: proofDigest.present ? proofDigest.value : this.proofDigest,
        proofSignature:
            proofSignature.present ? proofSignature.value : this.proofSignature,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        accuracyMeters:
            accuracyMeters.present ? accuracyMeters.value : this.accuracyMeters,
        deviceId: deviceId.present ? deviceId.value : this.deviceId,
        syncStatus: syncStatus ?? this.syncStatus,
        reasonCode: reasonCode.present ? reasonCode.value : this.reasonCode,
        retryCount: retryCount ?? this.retryCount,
        nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalAttendanceRow copyWithCompanion(LocalAttendanceEntriesCompanion data) {
    return LocalAttendanceRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      userId: data.userId.present ? data.userId.value : this.userId,
      shiftInstanceId: data.shiftInstanceId.present
          ? data.shiftInstanceId.value
          : this.shiftInstanceId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      capturedAt:
          data.capturedAt.present ? data.capturedAt.value : this.capturedAt,
      locationCapturedAt: data.locationCapturedAt.present
          ? data.locationCapturedAt.value
          : this.locationCapturedAt,
      proofInstallationId: data.proofInstallationId.present
          ? data.proofInstallationId.value
          : this.proofInstallationId,
      proofDigest:
          data.proofDigest.present ? data.proofDigest.value : this.proofDigest,
      proofSignature: data.proofSignature.present
          ? data.proofSignature.value
          : this.proofSignature,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracyMeters: data.accuracyMeters.present
          ? data.accuracyMeters.value
          : this.accuracyMeters,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      reasonCode:
          data.reasonCode.present ? data.reasonCode.value : this.reasonCode,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('shiftInstanceId: $shiftInstanceId, ')
          ..write('eventType: $eventType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('locationCapturedAt: $locationCapturedAt, ')
          ..write('proofInstallationId: $proofInstallationId, ')
          ..write('proofDigest: $proofDigest, ')
          ..write('proofSignature: $proofSignature, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      tenantId,
      userId,
      shiftInstanceId,
      eventType,
      capturedAt,
      locationCapturedAt,
      proofInstallationId,
      proofDigest,
      proofSignature,
      latitude,
      longitude,
      accuracyMeters,
      deviceId,
      syncStatus,
      reasonCode,
      retryCount,
      nextRetryAt,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttendanceRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.userId == this.userId &&
          other.shiftInstanceId == this.shiftInstanceId &&
          other.eventType == this.eventType &&
          other.capturedAt == this.capturedAt &&
          other.locationCapturedAt == this.locationCapturedAt &&
          other.proofInstallationId == this.proofInstallationId &&
          other.proofDigest == this.proofDigest &&
          other.proofSignature == this.proofSignature &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracyMeters == this.accuracyMeters &&
          other.deviceId == this.deviceId &&
          other.syncStatus == this.syncStatus &&
          other.reasonCode == this.reasonCode &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
}

class LocalAttendanceEntriesCompanion
    extends UpdateCompanion<LocalAttendanceRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> userId;
  final Value<String> shiftInstanceId;
  final Value<String> eventType;
  final Value<DateTime> capturedAt;
  final Value<DateTime?> locationCapturedAt;
  final Value<String?> proofInstallationId;
  final Value<String?> proofDigest;
  final Value<String?> proofSignature;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracyMeters;
  final Value<String?> deviceId;
  final Value<String> syncStatus;
  final Value<String?> reasonCode;
  final Value<int> retryCount;
  final Value<DateTime?> nextRetryAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalAttendanceEntriesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.userId = const Value.absent(),
    this.shiftInstanceId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.locationCapturedAt = const Value.absent(),
    this.proofInstallationId = const Value.absent(),
    this.proofDigest = const Value.absent(),
    this.proofSignature = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracyMeters = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttendanceEntriesCompanion.insert({
    required String id,
    required String tenantId,
    required String userId,
    required String shiftInstanceId,
    required String eventType,
    required DateTime capturedAt,
    this.locationCapturedAt = const Value.absent(),
    this.proofInstallationId = const Value.absent(),
    this.proofDigest = const Value.absent(),
    this.proofSignature = const Value.absent(),
    required double latitude,
    required double longitude,
    this.accuracyMeters = const Value.absent(),
    this.deviceId = const Value.absent(),
    required String syncStatus,
    this.reasonCode = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tenantId = Value(tenantId),
        userId = Value(userId),
        shiftInstanceId = Value(shiftInstanceId),
        eventType = Value(eventType),
        capturedAt = Value(capturedAt),
        latitude = Value(latitude),
        longitude = Value(longitude),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);
  static Insertable<LocalAttendanceRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? userId,
    Expression<String>? shiftInstanceId,
    Expression<String>? eventType,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? locationCapturedAt,
    Expression<String>? proofInstallationId,
    Expression<String>? proofDigest,
    Expression<String>? proofSignature,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracyMeters,
    Expression<String>? deviceId,
    Expression<String>? syncStatus,
    Expression<String>? reasonCode,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (userId != null) 'user_id': userId,
      if (shiftInstanceId != null) 'shift_instance_id': shiftInstanceId,
      if (eventType != null) 'event_type': eventType,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (locationCapturedAt != null)
        'location_captured_at': locationCapturedAt,
      if (proofInstallationId != null)
        'proof_installation_id': proofInstallationId,
      if (proofDigest != null) 'proof_digest': proofDigest,
      if (proofSignature != null) 'proof_signature': proofSignature,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (deviceId != null) 'device_id': deviceId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttendanceEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? tenantId,
      Value<String>? userId,
      Value<String>? shiftInstanceId,
      Value<String>? eventType,
      Value<DateTime>? capturedAt,
      Value<DateTime?>? locationCapturedAt,
      Value<String?>? proofInstallationId,
      Value<String?>? proofDigest,
      Value<String?>? proofSignature,
      Value<double>? latitude,
      Value<double>? longitude,
      Value<double?>? accuracyMeters,
      Value<String?>? deviceId,
      Value<String>? syncStatus,
      Value<String?>? reasonCode,
      Value<int>? retryCount,
      Value<DateTime?>? nextRetryAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return LocalAttendanceEntriesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      shiftInstanceId: shiftInstanceId ?? this.shiftInstanceId,
      eventType: eventType ?? this.eventType,
      capturedAt: capturedAt ?? this.capturedAt,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      proofInstallationId: proofInstallationId ?? this.proofInstallationId,
      proofDigest: proofDigest ?? this.proofDigest,
      proofSignature: proofSignature ?? this.proofSignature,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      deviceId: deviceId ?? this.deviceId,
      syncStatus: syncStatus ?? this.syncStatus,
      reasonCode: reasonCode ?? this.reasonCode,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (shiftInstanceId.present) {
      map['shift_instance_id'] = Variable<String>(shiftInstanceId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (locationCapturedAt.present) {
      map['location_captured_at'] =
          Variable<DateTime>(locationCapturedAt.value);
    }
    if (proofInstallationId.present) {
      map['proof_installation_id'] =
          Variable<String>(proofInstallationId.value);
    }
    if (proofDigest.present) {
      map['proof_digest'] = Variable<String>(proofDigest.value);
    }
    if (proofSignature.present) {
      map['proof_signature'] = Variable<String>(proofSignature.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracyMeters.present) {
      map['accuracy_meters'] = Variable<double>(accuracyMeters.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttendanceEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('shiftInstanceId: $shiftInstanceId, ')
          ..write('eventType: $eventType, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('locationCapturedAt: $locationCapturedAt, ')
          ..write('proofInstallationId: $proofInstallationId, ')
          ..write('proofDigest: $proofDigest, ')
          ..write('proofSignature: $proofSignature, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyMeters: $accuracyMeters, ')
          ..write('deviceId: $deviceId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRequestEntriesTable extends LocalRequestEntries
    with TableInfo<$LocalRequestEntriesTable, LocalRequestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRequestEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tenantIdMeta =
      const VerificationMeta('tenantId');
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
      'tenant_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _requestTypeMeta =
      const VerificationMeta('requestType');
  @override
  late final GeneratedColumn<String> requestType = GeneratedColumn<String>(
      'request_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reasonCodeMeta =
      const VerificationMeta('reasonCode');
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
      'reason_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextRetryAtMeta =
      const VerificationMeta('nextRetryAt');
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
      'next_retry_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
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
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_request_entries';
  @override
  VerificationContext validateIntegrity(Insertable<LocalRequestRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(_tenantIdMeta,
          tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta));
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('request_type')) {
      context.handle(
          _requestTypeMeta,
          requestType.isAcceptableOrUnknown(
              data['request_type']!, _requestTypeMeta));
    } else if (isInserting) {
      context.missing(_requestTypeMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    } else if (isInserting) {
      context.missing(_syncStatusMeta);
    }
    if (data.containsKey('reason_code')) {
      context.handle(
          _reasonCodeMeta,
          reasonCode.isAcceptableOrUnknown(
              data['reason_code']!, _reasonCodeMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
          _nextRetryAtMeta,
          nextRetryAt.isAcceptableOrUnknown(
              data['next_retry_at']!, _nextRetryAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

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
  const LocalRequestRow(
      {required this.id,
      required this.tenantId,
      required this.userId,
      required this.requestType,
      required this.payloadJson,
      required this.syncStatus,
      this.reasonCode,
      required this.retryCount,
      this.nextRetryAt,
      required this.createdAt});
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

  LocalRequestRow copyWith(
          {String? id,
          String? tenantId,
          String? userId,
          String? requestType,
          String? payloadJson,
          String? syncStatus,
          Value<String?> reasonCode = const Value.absent(),
          int? retryCount,
          Value<DateTime?> nextRetryAt = const Value.absent(),
          DateTime? createdAt}) =>
      LocalRequestRow(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        userId: userId ?? this.userId,
        requestType: requestType ?? this.requestType,
        payloadJson: payloadJson ?? this.payloadJson,
        syncStatus: syncStatus ?? this.syncStatus,
        reasonCode: reasonCode.present ? reasonCode.value : this.reasonCode,
        retryCount: retryCount ?? this.retryCount,
        nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalRequestRow copyWithCompanion(LocalRequestEntriesCompanion data) {
    return LocalRequestRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      userId: data.userId.present ? data.userId.value : this.userId,
      requestType:
          data.requestType.present ? data.requestType.value : this.requestType,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      reasonCode:
          data.reasonCode.present ? data.reasonCode.value : this.reasonCode,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRequestRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('requestType: $requestType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, userId, requestType,
      payloadJson, syncStatus, reasonCode, retryCount, nextRetryAt, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRequestRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.userId == this.userId &&
          other.requestType == this.requestType &&
          other.payloadJson == this.payloadJson &&
          other.syncStatus == this.syncStatus &&
          other.reasonCode == this.reasonCode &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
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
  final Value<int> rowid;
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
    this.rowid = const Value.absent(),
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
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tenantId = Value(tenantId),
        userId = Value(userId),
        requestType = Value(requestType),
        payloadJson = Value(payloadJson),
        syncStatus = Value(syncStatus),
        createdAt = Value(createdAt);
  static Insertable<LocalRequestRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? userId,
    Expression<String>? requestType,
    Expression<String>? payloadJson,
    Expression<String>? syncStatus,
    Expression<String>? reasonCode,
    Expression<int>? retryCount,
    Expression<DateTime>? nextRetryAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (userId != null) 'user_id': userId,
      if (requestType != null) 'request_type': requestType,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRequestEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? tenantId,
      Value<String>? userId,
      Value<String>? requestType,
      Value<String>? payloadJson,
      Value<String>? syncStatus,
      Value<String?>? reasonCode,
      Value<int>? retryCount,
      Value<DateTime?>? nextRetryAt,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
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
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (requestType.present) {
      map['request_type'] = Variable<String>(requestType.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRequestEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('userId: $userId, ')
          ..write('requestType: $requestType, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDriftDatabase extends GeneratedDatabase {
  _$AppDriftDatabase(QueryExecutor e) : super(e);
  $AppDriftDatabaseManager get managers => $AppDriftDatabaseManager(this);
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

typedef $$LocalAttendanceEntriesTableCreateCompanionBuilder
    = LocalAttendanceEntriesCompanion Function({
  required String id,
  required String tenantId,
  required String userId,
  required String shiftInstanceId,
  required String eventType,
  required DateTime capturedAt,
  Value<DateTime?> locationCapturedAt,
  Value<String?> proofInstallationId,
  Value<String?> proofDigest,
  Value<String?> proofSignature,
  required double latitude,
  required double longitude,
  Value<double?> accuracyMeters,
  Value<String?> deviceId,
  required String syncStatus,
  Value<String?> reasonCode,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$LocalAttendanceEntriesTableUpdateCompanionBuilder
    = LocalAttendanceEntriesCompanion Function({
  Value<String> id,
  Value<String> tenantId,
  Value<String> userId,
  Value<String> shiftInstanceId,
  Value<String> eventType,
  Value<DateTime> capturedAt,
  Value<DateTime?> locationCapturedAt,
  Value<String?> proofInstallationId,
  Value<String?> proofDigest,
  Value<String?> proofSignature,
  Value<double> latitude,
  Value<double> longitude,
  Value<double?> accuracyMeters,
  Value<String?> deviceId,
  Value<String> syncStatus,
  Value<String?> reasonCode,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalAttendanceEntriesTableFilterComposer
    extends Composer<_$AppDriftDatabase, $LocalAttendanceEntriesTable> {
  $$LocalAttendanceEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shiftInstanceId => $composableBuilder(
      column: $table.shiftInstanceId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proofInstallationId => $composableBuilder(
      column: $table.proofInstallationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proofDigest => $composableBuilder(
      column: $table.proofDigest, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get proofSignature => $composableBuilder(
      column: $table.proofSignature,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAttendanceEntriesTableOrderingComposer
    extends Composer<_$AppDriftDatabase, $LocalAttendanceEntriesTable> {
  $$LocalAttendanceEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shiftInstanceId => $composableBuilder(
      column: $table.shiftInstanceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventType => $composableBuilder(
      column: $table.eventType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proofInstallationId => $composableBuilder(
      column: $table.proofInstallationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proofDigest => $composableBuilder(
      column: $table.proofDigest, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get proofSignature => $composableBuilder(
      column: $table.proofSignature,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deviceId => $composableBuilder(
      column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAttendanceEntriesTableAnnotationComposer
    extends Composer<_$AppDriftDatabase, $LocalAttendanceEntriesTable> {
  $$LocalAttendanceEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get shiftInstanceId => $composableBuilder(
      column: $table.shiftInstanceId, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
      column: $table.capturedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get locationCapturedAt => $composableBuilder(
      column: $table.locationCapturedAt, builder: (column) => column);

  GeneratedColumn<String> get proofInstallationId => $composableBuilder(
      column: $table.proofInstallationId, builder: (column) => column);

  GeneratedColumn<String> get proofDigest => $composableBuilder(
      column: $table.proofDigest, builder: (column) => column);

  GeneratedColumn<String> get proofSignature => $composableBuilder(
      column: $table.proofSignature, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracyMeters => $composableBuilder(
      column: $table.accuracyMeters, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAttendanceEntriesTableTableManager extends RootTableManager<
    _$AppDriftDatabase,
    $LocalAttendanceEntriesTable,
    LocalAttendanceRow,
    $$LocalAttendanceEntriesTableFilterComposer,
    $$LocalAttendanceEntriesTableOrderingComposer,
    $$LocalAttendanceEntriesTableAnnotationComposer,
    $$LocalAttendanceEntriesTableCreateCompanionBuilder,
    $$LocalAttendanceEntriesTableUpdateCompanionBuilder,
    (
      LocalAttendanceRow,
      BaseReferences<_$AppDriftDatabase, $LocalAttendanceEntriesTable,
          LocalAttendanceRow>
    ),
    LocalAttendanceRow,
    PrefetchHooks Function()> {
  $$LocalAttendanceEntriesTableTableManager(
      _$AppDriftDatabase db, $LocalAttendanceEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttendanceEntriesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAttendanceEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAttendanceEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> shiftInstanceId = const Value.absent(),
            Value<String> eventType = const Value.absent(),
            Value<DateTime> capturedAt = const Value.absent(),
            Value<DateTime?> locationCapturedAt = const Value.absent(),
            Value<String?> proofInstallationId = const Value.absent(),
            Value<String?> proofDigest = const Value.absent(),
            Value<String?> proofSignature = const Value.absent(),
            Value<double> latitude = const Value.absent(),
            Value<double> longitude = const Value.absent(),
            Value<double?> accuracyMeters = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> reasonCode = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAttendanceEntriesCompanion(
            id: id,
            tenantId: tenantId,
            userId: userId,
            shiftInstanceId: shiftInstanceId,
            eventType: eventType,
            capturedAt: capturedAt,
            locationCapturedAt: locationCapturedAt,
            proofInstallationId: proofInstallationId,
            proofDigest: proofDigest,
            proofSignature: proofSignature,
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracyMeters,
            deviceId: deviceId,
            syncStatus: syncStatus,
            reasonCode: reasonCode,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tenantId,
            required String userId,
            required String shiftInstanceId,
            required String eventType,
            required DateTime capturedAt,
            Value<DateTime?> locationCapturedAt = const Value.absent(),
            Value<String?> proofInstallationId = const Value.absent(),
            Value<String?> proofDigest = const Value.absent(),
            Value<String?> proofSignature = const Value.absent(),
            required double latitude,
            required double longitude,
            Value<double?> accuracyMeters = const Value.absent(),
            Value<String?> deviceId = const Value.absent(),
            required String syncStatus,
            Value<String?> reasonCode = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAttendanceEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            userId: userId,
            shiftInstanceId: shiftInstanceId,
            eventType: eventType,
            capturedAt: capturedAt,
            locationCapturedAt: locationCapturedAt,
            proofInstallationId: proofInstallationId,
            proofDigest: proofDigest,
            proofSignature: proofSignature,
            latitude: latitude,
            longitude: longitude,
            accuracyMeters: accuracyMeters,
            deviceId: deviceId,
            syncStatus: syncStatus,
            reasonCode: reasonCode,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAttendanceEntriesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDriftDatabase,
        $LocalAttendanceEntriesTable,
        LocalAttendanceRow,
        $$LocalAttendanceEntriesTableFilterComposer,
        $$LocalAttendanceEntriesTableOrderingComposer,
        $$LocalAttendanceEntriesTableAnnotationComposer,
        $$LocalAttendanceEntriesTableCreateCompanionBuilder,
        $$LocalAttendanceEntriesTableUpdateCompanionBuilder,
        (
          LocalAttendanceRow,
          BaseReferences<_$AppDriftDatabase, $LocalAttendanceEntriesTable,
              LocalAttendanceRow>
        ),
        LocalAttendanceRow,
        PrefetchHooks Function()>;
typedef $$LocalRequestEntriesTableCreateCompanionBuilder
    = LocalRequestEntriesCompanion Function({
  required String id,
  required String tenantId,
  required String userId,
  required String requestType,
  required String payloadJson,
  required String syncStatus,
  Value<String?> reasonCode,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$LocalRequestEntriesTableUpdateCompanionBuilder
    = LocalRequestEntriesCompanion Function({
  Value<String> id,
  Value<String> tenantId,
  Value<String> userId,
  Value<String> requestType,
  Value<String> payloadJson,
  Value<String> syncStatus,
  Value<String?> reasonCode,
  Value<int> retryCount,
  Value<DateTime?> nextRetryAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$LocalRequestEntriesTableFilterComposer
    extends Composer<_$AppDriftDatabase, $LocalRequestEntriesTable> {
  $$LocalRequestEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requestType => $composableBuilder(
      column: $table.requestType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalRequestEntriesTableOrderingComposer
    extends Composer<_$AppDriftDatabase, $LocalRequestEntriesTable> {
  $$LocalRequestEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tenantId => $composableBuilder(
      column: $table.tenantId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requestType => $composableBuilder(
      column: $table.requestType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalRequestEntriesTableAnnotationComposer
    extends Composer<_$AppDriftDatabase, $LocalRequestEntriesTable> {
  $$LocalRequestEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get requestType => $composableBuilder(
      column: $table.requestType, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
      column: $table.reasonCode, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<DateTime> get nextRetryAt => $composableBuilder(
      column: $table.nextRetryAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalRequestEntriesTableTableManager extends RootTableManager<
    _$AppDriftDatabase,
    $LocalRequestEntriesTable,
    LocalRequestRow,
    $$LocalRequestEntriesTableFilterComposer,
    $$LocalRequestEntriesTableOrderingComposer,
    $$LocalRequestEntriesTableAnnotationComposer,
    $$LocalRequestEntriesTableCreateCompanionBuilder,
    $$LocalRequestEntriesTableUpdateCompanionBuilder,
    (
      LocalRequestRow,
      BaseReferences<_$AppDriftDatabase, $LocalRequestEntriesTable,
          LocalRequestRow>
    ),
    LocalRequestRow,
    PrefetchHooks Function()> {
  $$LocalRequestEntriesTableTableManager(
      _$AppDriftDatabase db, $LocalRequestEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRequestEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRequestEntriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRequestEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> tenantId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> requestType = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<String?> reasonCode = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRequestEntriesCompanion(
            id: id,
            tenantId: tenantId,
            userId: userId,
            requestType: requestType,
            payloadJson: payloadJson,
            syncStatus: syncStatus,
            reasonCode: reasonCode,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String tenantId,
            required String userId,
            required String requestType,
            required String payloadJson,
            required String syncStatus,
            Value<String?> reasonCode = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<DateTime?> nextRetryAt = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRequestEntriesCompanion.insert(
            id: id,
            tenantId: tenantId,
            userId: userId,
            requestType: requestType,
            payloadJson: payloadJson,
            syncStatus: syncStatus,
            reasonCode: reasonCode,
            retryCount: retryCount,
            nextRetryAt: nextRetryAt,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalRequestEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDriftDatabase,
    $LocalRequestEntriesTable,
    LocalRequestRow,
    $$LocalRequestEntriesTableFilterComposer,
    $$LocalRequestEntriesTableOrderingComposer,
    $$LocalRequestEntriesTableAnnotationComposer,
    $$LocalRequestEntriesTableCreateCompanionBuilder,
    $$LocalRequestEntriesTableUpdateCompanionBuilder,
    (
      LocalRequestRow,
      BaseReferences<_$AppDriftDatabase, $LocalRequestEntriesTable,
          LocalRequestRow>
    ),
    LocalRequestRow,
    PrefetchHooks Function()>;

class $AppDriftDatabaseManager {
  final _$AppDriftDatabase _db;
  $AppDriftDatabaseManager(this._db);
  $$LocalAttendanceEntriesTableTableManager get localAttendanceEntries =>
      $$LocalAttendanceEntriesTableTableManager(
          _db, _db.localAttendanceEntries);
  $$LocalRequestEntriesTableTableManager get localRequestEntries =>
      $$LocalRequestEntriesTableTableManager(_db, _db.localRequestEntries);
}
