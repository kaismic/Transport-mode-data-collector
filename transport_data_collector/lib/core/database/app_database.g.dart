// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceUuidMeta = const VerificationMeta(
    'deviceUuid',
  );
  @override
  late final GeneratedColumn<String> deviceUuid = GeneratedColumn<String>(
    'device_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleTypeMeta = const VerificationMeta(
    'vehicleType',
  );
  @override
  late final GeneratedColumn<String> vehicleType = GeneratedColumn<String>(
    'vehicle_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phonePositionMeta = const VerificationMeta(
    'phonePosition',
  );
  @override
  late final GeneratedColumn<String> phonePosition = GeneratedColumn<String>(
    'phone_position',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stoppedAtMsMeta = const VerificationMeta(
    'stoppedAtMs',
  );
  @override
  late final GeneratedColumn<int> stoppedAtMs = GeneratedColumn<int>(
    'stopped_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trimmedStartMsMeta = const VerificationMeta(
    'trimmedStartMs',
  );
  @override
  late final GeneratedColumn<int> trimmedStartMs = GeneratedColumn<int>(
    'trimmed_start_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trimmedEndMsMeta = const VerificationMeta(
    'trimmedEndMs',
  );
  @override
  late final GeneratedColumn<int> trimmedEndMs = GeneratedColumn<int>(
    'trimmed_end_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadedAtMsMeta = const VerificationMeta(
    'uploadedAtMs',
  );
  @override
  late final GeneratedColumn<int> uploadedAtMs = GeneratedColumn<int>(
    'uploaded_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sensorManifestMeta = const VerificationMeta(
    'sensorManifest',
  );
  @override
  late final GeneratedColumn<String> sensorManifest = GeneratedColumn<String>(
    'sensor_manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmPendingMeta = const VerificationMeta(
    'confirmPending',
  );
  @override
  late final GeneratedColumn<bool> confirmPending = GeneratedColumn<bool>(
    'confirm_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("confirm_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceUuid,
    vehicleType,
    phonePosition,
    startedAtMs,
    stoppedAtMs,
    trimmedStartMs,
    trimmedEndMs,
    uploadedAtMs,
    sensorManifest,
    confirmPending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_uuid')) {
      context.handle(
        _deviceUuidMeta,
        deviceUuid.isAcceptableOrUnknown(data['device_uuid']!, _deviceUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceUuidMeta);
    }
    if (data.containsKey('vehicle_type')) {
      context.handle(
        _vehicleTypeMeta,
        vehicleType.isAcceptableOrUnknown(
          data['vehicle_type']!,
          _vehicleTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vehicleTypeMeta);
    }
    if (data.containsKey('phone_position')) {
      context.handle(
        _phonePositionMeta,
        phonePosition.isAcceptableOrUnknown(
          data['phone_position']!,
          _phonePositionMeta,
        ),
      );
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('stopped_at_ms')) {
      context.handle(
        _stoppedAtMsMeta,
        stoppedAtMs.isAcceptableOrUnknown(
          data['stopped_at_ms']!,
          _stoppedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('trimmed_start_ms')) {
      context.handle(
        _trimmedStartMsMeta,
        trimmedStartMs.isAcceptableOrUnknown(
          data['trimmed_start_ms']!,
          _trimmedStartMsMeta,
        ),
      );
    }
    if (data.containsKey('trimmed_end_ms')) {
      context.handle(
        _trimmedEndMsMeta,
        trimmedEndMs.isAcceptableOrUnknown(
          data['trimmed_end_ms']!,
          _trimmedEndMsMeta,
        ),
      );
    }
    if (data.containsKey('uploaded_at_ms')) {
      context.handle(
        _uploadedAtMsMeta,
        uploadedAtMs.isAcceptableOrUnknown(
          data['uploaded_at_ms']!,
          _uploadedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('sensor_manifest')) {
      context.handle(
        _sensorManifestMeta,
        sensorManifest.isAcceptableOrUnknown(
          data['sensor_manifest']!,
          _sensorManifestMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sensorManifestMeta);
    }
    if (data.containsKey('confirm_pending')) {
      context.handle(
        _confirmPendingMeta,
        confirmPending.isAcceptableOrUnknown(
          data['confirm_pending']!,
          _confirmPendingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_uuid'],
      )!,
      vehicleType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_type'],
      )!,
      phonePosition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_position'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      stoppedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stopped_at_ms'],
      ),
      trimmedStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trimmed_start_ms'],
      ),
      trimmedEndMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trimmed_end_ms'],
      ),
      uploadedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uploaded_at_ms'],
      ),
      sensorManifest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sensor_manifest'],
      )!,
      confirmPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}confirm_pending'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String deviceUuid;
  final String vehicleType;
  final String phonePosition;
  final int startedAtMs;
  final int? stoppedAtMs;
  final int? trimmedStartMs;
  final int? trimmedEndMs;
  final int? uploadedAtMs;
  final String sensorManifest;
  final bool confirmPending;
  const Session({
    required this.id,
    required this.deviceUuid,
    required this.vehicleType,
    required this.phonePosition,
    required this.startedAtMs,
    this.stoppedAtMs,
    this.trimmedStartMs,
    this.trimmedEndMs,
    this.uploadedAtMs,
    required this.sensorManifest,
    required this.confirmPending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_uuid'] = Variable<String>(deviceUuid);
    map['vehicle_type'] = Variable<String>(vehicleType);
    map['phone_position'] = Variable<String>(phonePosition);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    if (!nullToAbsent || stoppedAtMs != null) {
      map['stopped_at_ms'] = Variable<int>(stoppedAtMs);
    }
    if (!nullToAbsent || trimmedStartMs != null) {
      map['trimmed_start_ms'] = Variable<int>(trimmedStartMs);
    }
    if (!nullToAbsent || trimmedEndMs != null) {
      map['trimmed_end_ms'] = Variable<int>(trimmedEndMs);
    }
    if (!nullToAbsent || uploadedAtMs != null) {
      map['uploaded_at_ms'] = Variable<int>(uploadedAtMs);
    }
    map['sensor_manifest'] = Variable<String>(sensorManifest);
    map['confirm_pending'] = Variable<bool>(confirmPending);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      deviceUuid: Value(deviceUuid),
      vehicleType: Value(vehicleType),
      phonePosition: Value(phonePosition),
      startedAtMs: Value(startedAtMs),
      stoppedAtMs: stoppedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(stoppedAtMs),
      trimmedStartMs: trimmedStartMs == null && nullToAbsent
          ? const Value.absent()
          : Value(trimmedStartMs),
      trimmedEndMs: trimmedEndMs == null && nullToAbsent
          ? const Value.absent()
          : Value(trimmedEndMs),
      uploadedAtMs: uploadedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadedAtMs),
      sensorManifest: Value(sensorManifest),
      confirmPending: Value(confirmPending),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      deviceUuid: serializer.fromJson<String>(json['deviceUuid']),
      vehicleType: serializer.fromJson<String>(json['vehicleType']),
      phonePosition: serializer.fromJson<String>(json['phonePosition']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      stoppedAtMs: serializer.fromJson<int?>(json['stoppedAtMs']),
      trimmedStartMs: serializer.fromJson<int?>(json['trimmedStartMs']),
      trimmedEndMs: serializer.fromJson<int?>(json['trimmedEndMs']),
      uploadedAtMs: serializer.fromJson<int?>(json['uploadedAtMs']),
      sensorManifest: serializer.fromJson<String>(json['sensorManifest']),
      confirmPending: serializer.fromJson<bool>(json['confirmPending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceUuid': serializer.toJson<String>(deviceUuid),
      'vehicleType': serializer.toJson<String>(vehicleType),
      'phonePosition': serializer.toJson<String>(phonePosition),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'stoppedAtMs': serializer.toJson<int?>(stoppedAtMs),
      'trimmedStartMs': serializer.toJson<int?>(trimmedStartMs),
      'trimmedEndMs': serializer.toJson<int?>(trimmedEndMs),
      'uploadedAtMs': serializer.toJson<int?>(uploadedAtMs),
      'sensorManifest': serializer.toJson<String>(sensorManifest),
      'confirmPending': serializer.toJson<bool>(confirmPending),
    };
  }

  Session copyWith({
    String? id,
    String? deviceUuid,
    String? vehicleType,
    String? phonePosition,
    int? startedAtMs,
    Value<int?> stoppedAtMs = const Value.absent(),
    Value<int?> trimmedStartMs = const Value.absent(),
    Value<int?> trimmedEndMs = const Value.absent(),
    Value<int?> uploadedAtMs = const Value.absent(),
    String? sensorManifest,
    bool? confirmPending,
  }) => Session(
    id: id ?? this.id,
    deviceUuid: deviceUuid ?? this.deviceUuid,
    vehicleType: vehicleType ?? this.vehicleType,
    phonePosition: phonePosition ?? this.phonePosition,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    stoppedAtMs: stoppedAtMs.present ? stoppedAtMs.value : this.stoppedAtMs,
    trimmedStartMs: trimmedStartMs.present
        ? trimmedStartMs.value
        : this.trimmedStartMs,
    trimmedEndMs: trimmedEndMs.present ? trimmedEndMs.value : this.trimmedEndMs,
    uploadedAtMs: uploadedAtMs.present ? uploadedAtMs.value : this.uploadedAtMs,
    sensorManifest: sensorManifest ?? this.sensorManifest,
    confirmPending: confirmPending ?? this.confirmPending,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      deviceUuid: data.deviceUuid.present
          ? data.deviceUuid.value
          : this.deviceUuid,
      vehicleType: data.vehicleType.present
          ? data.vehicleType.value
          : this.vehicleType,
      phonePosition: data.phonePosition.present
          ? data.phonePosition.value
          : this.phonePosition,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      stoppedAtMs: data.stoppedAtMs.present
          ? data.stoppedAtMs.value
          : this.stoppedAtMs,
      trimmedStartMs: data.trimmedStartMs.present
          ? data.trimmedStartMs.value
          : this.trimmedStartMs,
      trimmedEndMs: data.trimmedEndMs.present
          ? data.trimmedEndMs.value
          : this.trimmedEndMs,
      uploadedAtMs: data.uploadedAtMs.present
          ? data.uploadedAtMs.value
          : this.uploadedAtMs,
      sensorManifest: data.sensorManifest.present
          ? data.sensorManifest.value
          : this.sensorManifest,
      confirmPending: data.confirmPending.present
          ? data.confirmPending.value
          : this.confirmPending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('deviceUuid: $deviceUuid, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('phonePosition: $phonePosition, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('stoppedAtMs: $stoppedAtMs, ')
          ..write('trimmedStartMs: $trimmedStartMs, ')
          ..write('trimmedEndMs: $trimmedEndMs, ')
          ..write('uploadedAtMs: $uploadedAtMs, ')
          ..write('sensorManifest: $sensorManifest, ')
          ..write('confirmPending: $confirmPending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceUuid,
    vehicleType,
    phonePosition,
    startedAtMs,
    stoppedAtMs,
    trimmedStartMs,
    trimmedEndMs,
    uploadedAtMs,
    sensorManifest,
    confirmPending,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.deviceUuid == this.deviceUuid &&
          other.vehicleType == this.vehicleType &&
          other.phonePosition == this.phonePosition &&
          other.startedAtMs == this.startedAtMs &&
          other.stoppedAtMs == this.stoppedAtMs &&
          other.trimmedStartMs == this.trimmedStartMs &&
          other.trimmedEndMs == this.trimmedEndMs &&
          other.uploadedAtMs == this.uploadedAtMs &&
          other.sensorManifest == this.sensorManifest &&
          other.confirmPending == this.confirmPending);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String> deviceUuid;
  final Value<String> vehicleType;
  final Value<String> phonePosition;
  final Value<int> startedAtMs;
  final Value<int?> stoppedAtMs;
  final Value<int?> trimmedStartMs;
  final Value<int?> trimmedEndMs;
  final Value<int?> uploadedAtMs;
  final Value<String> sensorManifest;
  final Value<bool> confirmPending;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.deviceUuid = const Value.absent(),
    this.vehicleType = const Value.absent(),
    this.phonePosition = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.stoppedAtMs = const Value.absent(),
    this.trimmedStartMs = const Value.absent(),
    this.trimmedEndMs = const Value.absent(),
    this.uploadedAtMs = const Value.absent(),
    this.sensorManifest = const Value.absent(),
    this.confirmPending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String deviceUuid,
    required String vehicleType,
    this.phonePosition = const Value.absent(),
    required int startedAtMs,
    this.stoppedAtMs = const Value.absent(),
    this.trimmedStartMs = const Value.absent(),
    this.trimmedEndMs = const Value.absent(),
    this.uploadedAtMs = const Value.absent(),
    required String sensorManifest,
    this.confirmPending = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceUuid = Value(deviceUuid),
       vehicleType = Value(vehicleType),
       startedAtMs = Value(startedAtMs),
       sensorManifest = Value(sensorManifest);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? deviceUuid,
    Expression<String>? vehicleType,
    Expression<String>? phonePosition,
    Expression<int>? startedAtMs,
    Expression<int>? stoppedAtMs,
    Expression<int>? trimmedStartMs,
    Expression<int>? trimmedEndMs,
    Expression<int>? uploadedAtMs,
    Expression<String>? sensorManifest,
    Expression<bool>? confirmPending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceUuid != null) 'device_uuid': deviceUuid,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      if (phonePosition != null) 'phone_position': phonePosition,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (stoppedAtMs != null) 'stopped_at_ms': stoppedAtMs,
      if (trimmedStartMs != null) 'trimmed_start_ms': trimmedStartMs,
      if (trimmedEndMs != null) 'trimmed_end_ms': trimmedEndMs,
      if (uploadedAtMs != null) 'uploaded_at_ms': uploadedAtMs,
      if (sensorManifest != null) 'sensor_manifest': sensorManifest,
      if (confirmPending != null) 'confirm_pending': confirmPending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceUuid,
    Value<String>? vehicleType,
    Value<String>? phonePosition,
    Value<int>? startedAtMs,
    Value<int?>? stoppedAtMs,
    Value<int?>? trimmedStartMs,
    Value<int?>? trimmedEndMs,
    Value<int?>? uploadedAtMs,
    Value<String>? sensorManifest,
    Value<bool>? confirmPending,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      deviceUuid: deviceUuid ?? this.deviceUuid,
      vehicleType: vehicleType ?? this.vehicleType,
      phonePosition: phonePosition ?? this.phonePosition,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      stoppedAtMs: stoppedAtMs ?? this.stoppedAtMs,
      trimmedStartMs: trimmedStartMs ?? this.trimmedStartMs,
      trimmedEndMs: trimmedEndMs ?? this.trimmedEndMs,
      uploadedAtMs: uploadedAtMs ?? this.uploadedAtMs,
      sensorManifest: sensorManifest ?? this.sensorManifest,
      confirmPending: confirmPending ?? this.confirmPending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceUuid.present) {
      map['device_uuid'] = Variable<String>(deviceUuid.value);
    }
    if (vehicleType.present) {
      map['vehicle_type'] = Variable<String>(vehicleType.value);
    }
    if (phonePosition.present) {
      map['phone_position'] = Variable<String>(phonePosition.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (stoppedAtMs.present) {
      map['stopped_at_ms'] = Variable<int>(stoppedAtMs.value);
    }
    if (trimmedStartMs.present) {
      map['trimmed_start_ms'] = Variable<int>(trimmedStartMs.value);
    }
    if (trimmedEndMs.present) {
      map['trimmed_end_ms'] = Variable<int>(trimmedEndMs.value);
    }
    if (uploadedAtMs.present) {
      map['uploaded_at_ms'] = Variable<int>(uploadedAtMs.value);
    }
    if (sensorManifest.present) {
      map['sensor_manifest'] = Variable<String>(sensorManifest.value);
    }
    if (confirmPending.present) {
      map['confirm_pending'] = Variable<bool>(confirmPending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('deviceUuid: $deviceUuid, ')
          ..write('vehicleType: $vehicleType, ')
          ..write('phonePosition: $phonePosition, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('stoppedAtMs: $stoppedAtMs, ')
          ..write('trimmedStartMs: $trimmedStartMs, ')
          ..write('trimmedEndMs: $trimmedEndMs, ')
          ..write('uploadedAtMs: $uploadedAtMs, ')
          ..write('sensorManifest: $sensorManifest, ')
          ..write('confirmPending: $confirmPending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SamplesTable extends Samples with TableInfo<$SamplesTable, Sample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accelXMeta = const VerificationMeta('accelX');
  @override
  late final GeneratedColumn<double> accelX = GeneratedColumn<double>(
    'accel_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accelYMeta = const VerificationMeta('accelY');
  @override
  late final GeneratedColumn<double> accelY = GeneratedColumn<double>(
    'accel_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accelZMeta = const VerificationMeta('accelZ');
  @override
  late final GeneratedColumn<double> accelZ = GeneratedColumn<double>(
    'accel_z',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gyroXMeta = const VerificationMeta('gyroX');
  @override
  late final GeneratedColumn<double> gyroX = GeneratedColumn<double>(
    'gyro_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gyroYMeta = const VerificationMeta('gyroY');
  @override
  late final GeneratedColumn<double> gyroY = GeneratedColumn<double>(
    'gyro_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gyroZMeta = const VerificationMeta('gyroZ');
  @override
  late final GeneratedColumn<double> gyroZ = GeneratedColumn<double>(
    'gyro_z',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _magXMeta = const VerificationMeta('magX');
  @override
  late final GeneratedColumn<double> magX = GeneratedColumn<double>(
    'mag_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _magYMeta = const VerificationMeta('magY');
  @override
  late final GeneratedColumn<double> magY = GeneratedColumn<double>(
    'mag_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _magZMeta = const VerificationMeta('magZ');
  @override
  late final GeneratedColumn<double> magZ = GeneratedColumn<double>(
    'mag_z',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pressureMeta = const VerificationMeta(
    'pressure',
  );
  @override
  late final GeneratedColumn<double> pressure = GeneratedColumn<double>(
    'pressure',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    timestampMs,
    accelX,
    accelY,
    accelZ,
    gyroX,
    gyroY,
    gyroZ,
    magX,
    magY,
    magZ,
    pressure,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('accel_x')) {
      context.handle(
        _accelXMeta,
        accelX.isAcceptableOrUnknown(data['accel_x']!, _accelXMeta),
      );
    } else if (isInserting) {
      context.missing(_accelXMeta);
    }
    if (data.containsKey('accel_y')) {
      context.handle(
        _accelYMeta,
        accelY.isAcceptableOrUnknown(data['accel_y']!, _accelYMeta),
      );
    } else if (isInserting) {
      context.missing(_accelYMeta);
    }
    if (data.containsKey('accel_z')) {
      context.handle(
        _accelZMeta,
        accelZ.isAcceptableOrUnknown(data['accel_z']!, _accelZMeta),
      );
    } else if (isInserting) {
      context.missing(_accelZMeta);
    }
    if (data.containsKey('gyro_x')) {
      context.handle(
        _gyroXMeta,
        gyroX.isAcceptableOrUnknown(data['gyro_x']!, _gyroXMeta),
      );
    } else if (isInserting) {
      context.missing(_gyroXMeta);
    }
    if (data.containsKey('gyro_y')) {
      context.handle(
        _gyroYMeta,
        gyroY.isAcceptableOrUnknown(data['gyro_y']!, _gyroYMeta),
      );
    } else if (isInserting) {
      context.missing(_gyroYMeta);
    }
    if (data.containsKey('gyro_z')) {
      context.handle(
        _gyroZMeta,
        gyroZ.isAcceptableOrUnknown(data['gyro_z']!, _gyroZMeta),
      );
    } else if (isInserting) {
      context.missing(_gyroZMeta);
    }
    if (data.containsKey('mag_x')) {
      context.handle(
        _magXMeta,
        magX.isAcceptableOrUnknown(data['mag_x']!, _magXMeta),
      );
    }
    if (data.containsKey('mag_y')) {
      context.handle(
        _magYMeta,
        magY.isAcceptableOrUnknown(data['mag_y']!, _magYMeta),
      );
    }
    if (data.containsKey('mag_z')) {
      context.handle(
        _magZMeta,
        magZ.isAcceptableOrUnknown(data['mag_z']!, _magZMeta),
      );
    }
    if (data.containsKey('pressure')) {
      context.handle(
        _pressureMeta,
        pressure.isAcceptableOrUnknown(data['pressure']!, _pressureMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      accelX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accel_x'],
      )!,
      accelY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accel_y'],
      )!,
      accelZ: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accel_z'],
      )!,
      gyroX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gyro_x'],
      )!,
      gyroY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gyro_y'],
      )!,
      gyroZ: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gyro_z'],
      )!,
      magX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mag_x'],
      ),
      magY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mag_y'],
      ),
      magZ: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mag_z'],
      ),
      pressure: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pressure'],
      ),
    );
  }

  @override
  $SamplesTable createAlias(String alias) {
    return $SamplesTable(attachedDatabase, alias);
  }
}

class Sample extends DataClass implements Insertable<Sample> {
  final int id;
  final String sessionId;
  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double? magX;
  final double? magY;
  final double? magZ;
  final double? pressure;
  const Sample({
    required this.id,
    required this.sessionId,
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
    this.pressure,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['accel_x'] = Variable<double>(accelX);
    map['accel_y'] = Variable<double>(accelY);
    map['accel_z'] = Variable<double>(accelZ);
    map['gyro_x'] = Variable<double>(gyroX);
    map['gyro_y'] = Variable<double>(gyroY);
    map['gyro_z'] = Variable<double>(gyroZ);
    if (!nullToAbsent || magX != null) {
      map['mag_x'] = Variable<double>(magX);
    }
    if (!nullToAbsent || magY != null) {
      map['mag_y'] = Variable<double>(magY);
    }
    if (!nullToAbsent || magZ != null) {
      map['mag_z'] = Variable<double>(magZ);
    }
    if (!nullToAbsent || pressure != null) {
      map['pressure'] = Variable<double>(pressure);
    }
    return map;
  }

  SamplesCompanion toCompanion(bool nullToAbsent) {
    return SamplesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      timestampMs: Value(timestampMs),
      accelX: Value(accelX),
      accelY: Value(accelY),
      accelZ: Value(accelZ),
      gyroX: Value(gyroX),
      gyroY: Value(gyroY),
      gyroZ: Value(gyroZ),
      magX: magX == null && nullToAbsent ? const Value.absent() : Value(magX),
      magY: magY == null && nullToAbsent ? const Value.absent() : Value(magY),
      magZ: magZ == null && nullToAbsent ? const Value.absent() : Value(magZ),
      pressure: pressure == null && nullToAbsent
          ? const Value.absent()
          : Value(pressure),
    );
  }

  factory Sample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sample(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      accelX: serializer.fromJson<double>(json['accelX']),
      accelY: serializer.fromJson<double>(json['accelY']),
      accelZ: serializer.fromJson<double>(json['accelZ']),
      gyroX: serializer.fromJson<double>(json['gyroX']),
      gyroY: serializer.fromJson<double>(json['gyroY']),
      gyroZ: serializer.fromJson<double>(json['gyroZ']),
      magX: serializer.fromJson<double?>(json['magX']),
      magY: serializer.fromJson<double?>(json['magY']),
      magZ: serializer.fromJson<double?>(json['magZ']),
      pressure: serializer.fromJson<double?>(json['pressure']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'accelX': serializer.toJson<double>(accelX),
      'accelY': serializer.toJson<double>(accelY),
      'accelZ': serializer.toJson<double>(accelZ),
      'gyroX': serializer.toJson<double>(gyroX),
      'gyroY': serializer.toJson<double>(gyroY),
      'gyroZ': serializer.toJson<double>(gyroZ),
      'magX': serializer.toJson<double?>(magX),
      'magY': serializer.toJson<double?>(magY),
      'magZ': serializer.toJson<double?>(magZ),
      'pressure': serializer.toJson<double?>(pressure),
    };
  }

  Sample copyWith({
    int? id,
    String? sessionId,
    int? timestampMs,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    Value<double?> magX = const Value.absent(),
    Value<double?> magY = const Value.absent(),
    Value<double?> magZ = const Value.absent(),
    Value<double?> pressure = const Value.absent(),
  }) => Sample(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    timestampMs: timestampMs ?? this.timestampMs,
    accelX: accelX ?? this.accelX,
    accelY: accelY ?? this.accelY,
    accelZ: accelZ ?? this.accelZ,
    gyroX: gyroX ?? this.gyroX,
    gyroY: gyroY ?? this.gyroY,
    gyroZ: gyroZ ?? this.gyroZ,
    magX: magX.present ? magX.value : this.magX,
    magY: magY.present ? magY.value : this.magY,
    magZ: magZ.present ? magZ.value : this.magZ,
    pressure: pressure.present ? pressure.value : this.pressure,
  );
  Sample copyWithCompanion(SamplesCompanion data) {
    return Sample(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      accelX: data.accelX.present ? data.accelX.value : this.accelX,
      accelY: data.accelY.present ? data.accelY.value : this.accelY,
      accelZ: data.accelZ.present ? data.accelZ.value : this.accelZ,
      gyroX: data.gyroX.present ? data.gyroX.value : this.gyroX,
      gyroY: data.gyroY.present ? data.gyroY.value : this.gyroY,
      gyroZ: data.gyroZ.present ? data.gyroZ.value : this.gyroZ,
      magX: data.magX.present ? data.magX.value : this.magX,
      magY: data.magY.present ? data.magY.value : this.magY,
      magZ: data.magZ.present ? data.magZ.value : this.magZ,
      pressure: data.pressure.present ? data.pressure.value : this.pressure,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sample(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('accelX: $accelX, ')
          ..write('accelY: $accelY, ')
          ..write('accelZ: $accelZ, ')
          ..write('gyroX: $gyroX, ')
          ..write('gyroY: $gyroY, ')
          ..write('gyroZ: $gyroZ, ')
          ..write('magX: $magX, ')
          ..write('magY: $magY, ')
          ..write('magZ: $magZ, ')
          ..write('pressure: $pressure')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    timestampMs,
    accelX,
    accelY,
    accelZ,
    gyroX,
    gyroY,
    gyroZ,
    magX,
    magY,
    magZ,
    pressure,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sample &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.timestampMs == this.timestampMs &&
          other.accelX == this.accelX &&
          other.accelY == this.accelY &&
          other.accelZ == this.accelZ &&
          other.gyroX == this.gyroX &&
          other.gyroY == this.gyroY &&
          other.gyroZ == this.gyroZ &&
          other.magX == this.magX &&
          other.magY == this.magY &&
          other.magZ == this.magZ &&
          other.pressure == this.pressure);
}

class SamplesCompanion extends UpdateCompanion<Sample> {
  final Value<int> id;
  final Value<String> sessionId;
  final Value<int> timestampMs;
  final Value<double> accelX;
  final Value<double> accelY;
  final Value<double> accelZ;
  final Value<double> gyroX;
  final Value<double> gyroY;
  final Value<double> gyroZ;
  final Value<double?> magX;
  final Value<double?> magY;
  final Value<double?> magZ;
  final Value<double?> pressure;
  const SamplesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.accelX = const Value.absent(),
    this.accelY = const Value.absent(),
    this.accelZ = const Value.absent(),
    this.gyroX = const Value.absent(),
    this.gyroY = const Value.absent(),
    this.gyroZ = const Value.absent(),
    this.magX = const Value.absent(),
    this.magY = const Value.absent(),
    this.magZ = const Value.absent(),
    this.pressure = const Value.absent(),
  });
  SamplesCompanion.insert({
    this.id = const Value.absent(),
    required String sessionId,
    required int timestampMs,
    required double accelX,
    required double accelY,
    required double accelZ,
    required double gyroX,
    required double gyroY,
    required double gyroZ,
    this.magX = const Value.absent(),
    this.magY = const Value.absent(),
    this.magZ = const Value.absent(),
    this.pressure = const Value.absent(),
  }) : sessionId = Value(sessionId),
       timestampMs = Value(timestampMs),
       accelX = Value(accelX),
       accelY = Value(accelY),
       accelZ = Value(accelZ),
       gyroX = Value(gyroX),
       gyroY = Value(gyroY),
       gyroZ = Value(gyroZ);
  static Insertable<Sample> custom({
    Expression<int>? id,
    Expression<String>? sessionId,
    Expression<int>? timestampMs,
    Expression<double>? accelX,
    Expression<double>? accelY,
    Expression<double>? accelZ,
    Expression<double>? gyroX,
    Expression<double>? gyroY,
    Expression<double>? gyroZ,
    Expression<double>? magX,
    Expression<double>? magY,
    Expression<double>? magZ,
    Expression<double>? pressure,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (accelX != null) 'accel_x': accelX,
      if (accelY != null) 'accel_y': accelY,
      if (accelZ != null) 'accel_z': accelZ,
      if (gyroX != null) 'gyro_x': gyroX,
      if (gyroY != null) 'gyro_y': gyroY,
      if (gyroZ != null) 'gyro_z': gyroZ,
      if (magX != null) 'mag_x': magX,
      if (magY != null) 'mag_y': magY,
      if (magZ != null) 'mag_z': magZ,
      if (pressure != null) 'pressure': pressure,
    });
  }

  SamplesCompanion copyWith({
    Value<int>? id,
    Value<String>? sessionId,
    Value<int>? timestampMs,
    Value<double>? accelX,
    Value<double>? accelY,
    Value<double>? accelZ,
    Value<double>? gyroX,
    Value<double>? gyroY,
    Value<double>? gyroZ,
    Value<double?>? magX,
    Value<double?>? magY,
    Value<double?>? magZ,
    Value<double?>? pressure,
  }) {
    return SamplesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestampMs: timestampMs ?? this.timestampMs,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      magX: magX ?? this.magX,
      magY: magY ?? this.magY,
      magZ: magZ ?? this.magZ,
      pressure: pressure ?? this.pressure,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (accelX.present) {
      map['accel_x'] = Variable<double>(accelX.value);
    }
    if (accelY.present) {
      map['accel_y'] = Variable<double>(accelY.value);
    }
    if (accelZ.present) {
      map['accel_z'] = Variable<double>(accelZ.value);
    }
    if (gyroX.present) {
      map['gyro_x'] = Variable<double>(gyroX.value);
    }
    if (gyroY.present) {
      map['gyro_y'] = Variable<double>(gyroY.value);
    }
    if (gyroZ.present) {
      map['gyro_z'] = Variable<double>(gyroZ.value);
    }
    if (magX.present) {
      map['mag_x'] = Variable<double>(magX.value);
    }
    if (magY.present) {
      map['mag_y'] = Variable<double>(magY.value);
    }
    if (magZ.present) {
      map['mag_z'] = Variable<double>(magZ.value);
    }
    if (pressure.present) {
      map['pressure'] = Variable<double>(pressure.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SamplesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('accelX: $accelX, ')
          ..write('accelY: $accelY, ')
          ..write('accelZ: $accelZ, ')
          ..write('gyroX: $gyroX, ')
          ..write('gyroY: $gyroY, ')
          ..write('gyroZ: $gyroZ, ')
          ..write('magX: $magX, ')
          ..write('magY: $magY, ')
          ..write('magZ: $magZ, ')
          ..write('pressure: $pressure')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SamplesTable samples = $SamplesTable(this);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final SampleDao sampleDao = SampleDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sessions, samples];
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      required String deviceUuid,
      required String vehicleType,
      Value<String> phonePosition,
      required int startedAtMs,
      Value<int?> stoppedAtMs,
      Value<int?> trimmedStartMs,
      Value<int?> trimmedEndMs,
      Value<int?> uploadedAtMs,
      required String sensorManifest,
      Value<bool> confirmPending,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String> deviceUuid,
      Value<String> vehicleType,
      Value<String> phonePosition,
      Value<int> startedAtMs,
      Value<int?> stoppedAtMs,
      Value<int?> trimmedStartMs,
      Value<int?> trimmedEndMs,
      Value<int?> uploadedAtMs,
      Value<String> sensorManifest,
      Value<bool> confirmPending,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceUuid => $composableBuilder(
    column: $table.deviceUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phonePosition => $composableBuilder(
    column: $table.phonePosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trimmedStartMs => $composableBuilder(
    column: $table.trimmedStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trimmedEndMs => $composableBuilder(
    column: $table.trimmedEndMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uploadedAtMs => $composableBuilder(
    column: $table.uploadedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sensorManifest => $composableBuilder(
    column: $table.sensorManifest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get confirmPending => $composableBuilder(
    column: $table.confirmPending,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceUuid => $composableBuilder(
    column: $table.deviceUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phonePosition => $composableBuilder(
    column: $table.phonePosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trimmedStartMs => $composableBuilder(
    column: $table.trimmedStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trimmedEndMs => $composableBuilder(
    column: $table.trimmedEndMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uploadedAtMs => $composableBuilder(
    column: $table.uploadedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sensorManifest => $composableBuilder(
    column: $table.sensorManifest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get confirmPending => $composableBuilder(
    column: $table.confirmPending,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceUuid => $composableBuilder(
    column: $table.deviceUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleType => $composableBuilder(
    column: $table.vehicleType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phonePosition => $composableBuilder(
    column: $table.phonePosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stoppedAtMs => $composableBuilder(
    column: $table.stoppedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trimmedStartMs => $composableBuilder(
    column: $table.trimmedStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get trimmedEndMs => $composableBuilder(
    column: $table.trimmedEndMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get uploadedAtMs => $composableBuilder(
    column: $table.uploadedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sensorManifest => $composableBuilder(
    column: $table.sensorManifest,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get confirmPending => $composableBuilder(
    column: $table.confirmPending,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceUuid = const Value.absent(),
                Value<String> vehicleType = const Value.absent(),
                Value<String> phonePosition = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int?> stoppedAtMs = const Value.absent(),
                Value<int?> trimmedStartMs = const Value.absent(),
                Value<int?> trimmedEndMs = const Value.absent(),
                Value<int?> uploadedAtMs = const Value.absent(),
                Value<String> sensorManifest = const Value.absent(),
                Value<bool> confirmPending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                deviceUuid: deviceUuid,
                vehicleType: vehicleType,
                phonePosition: phonePosition,
                startedAtMs: startedAtMs,
                stoppedAtMs: stoppedAtMs,
                trimmedStartMs: trimmedStartMs,
                trimmedEndMs: trimmedEndMs,
                uploadedAtMs: uploadedAtMs,
                sensorManifest: sensorManifest,
                confirmPending: confirmPending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceUuid,
                required String vehicleType,
                Value<String> phonePosition = const Value.absent(),
                required int startedAtMs,
                Value<int?> stoppedAtMs = const Value.absent(),
                Value<int?> trimmedStartMs = const Value.absent(),
                Value<int?> trimmedEndMs = const Value.absent(),
                Value<int?> uploadedAtMs = const Value.absent(),
                required String sensorManifest,
                Value<bool> confirmPending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                deviceUuid: deviceUuid,
                vehicleType: vehicleType,
                phonePosition: phonePosition,
                startedAtMs: startedAtMs,
                stoppedAtMs: stoppedAtMs,
                trimmedStartMs: trimmedStartMs,
                trimmedEndMs: trimmedEndMs,
                uploadedAtMs: uploadedAtMs,
                sensorManifest: sensorManifest,
                confirmPending: confirmPending,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$AppDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$SamplesTableCreateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      required String sessionId,
      required int timestampMs,
      required double accelX,
      required double accelY,
      required double accelZ,
      required double gyroX,
      required double gyroY,
      required double gyroZ,
      Value<double?> magX,
      Value<double?> magY,
      Value<double?> magZ,
      Value<double?> pressure,
    });
typedef $$SamplesTableUpdateCompanionBuilder =
    SamplesCompanion Function({
      Value<int> id,
      Value<String> sessionId,
      Value<int> timestampMs,
      Value<double> accelX,
      Value<double> accelY,
      Value<double> accelZ,
      Value<double> gyroX,
      Value<double> gyroY,
      Value<double> gyroZ,
      Value<double?> magX,
      Value<double?> magY,
      Value<double?> magZ,
      Value<double?> pressure,
    });

class $$SamplesTableFilterComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accelX => $composableBuilder(
    column: $table.accelX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accelY => $composableBuilder(
    column: $table.accelY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accelZ => $composableBuilder(
    column: $table.accelZ,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gyroX => $composableBuilder(
    column: $table.gyroX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gyroY => $composableBuilder(
    column: $table.gyroY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gyroZ => $composableBuilder(
    column: $table.gyroZ,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get magX => $composableBuilder(
    column: $table.magX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get magY => $composableBuilder(
    column: $table.magY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get magZ => $composableBuilder(
    column: $table.magZ,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pressure => $composableBuilder(
    column: $table.pressure,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accelX => $composableBuilder(
    column: $table.accelX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accelY => $composableBuilder(
    column: $table.accelY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accelZ => $composableBuilder(
    column: $table.accelZ,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gyroX => $composableBuilder(
    column: $table.gyroX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gyroY => $composableBuilder(
    column: $table.gyroY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gyroZ => $composableBuilder(
    column: $table.gyroZ,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get magX => $composableBuilder(
    column: $table.magX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get magY => $composableBuilder(
    column: $table.magY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get magZ => $composableBuilder(
    column: $table.magZ,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pressure => $composableBuilder(
    column: $table.pressure,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get accelX =>
      $composableBuilder(column: $table.accelX, builder: (column) => column);

  GeneratedColumn<double> get accelY =>
      $composableBuilder(column: $table.accelY, builder: (column) => column);

  GeneratedColumn<double> get accelZ =>
      $composableBuilder(column: $table.accelZ, builder: (column) => column);

  GeneratedColumn<double> get gyroX =>
      $composableBuilder(column: $table.gyroX, builder: (column) => column);

  GeneratedColumn<double> get gyroY =>
      $composableBuilder(column: $table.gyroY, builder: (column) => column);

  GeneratedColumn<double> get gyroZ =>
      $composableBuilder(column: $table.gyroZ, builder: (column) => column);

  GeneratedColumn<double> get magX =>
      $composableBuilder(column: $table.magX, builder: (column) => column);

  GeneratedColumn<double> get magY =>
      $composableBuilder(column: $table.magY, builder: (column) => column);

  GeneratedColumn<double> get magZ =>
      $composableBuilder(column: $table.magZ, builder: (column) => column);

  GeneratedColumn<double> get pressure =>
      $composableBuilder(column: $table.pressure, builder: (column) => column);
}

class $$SamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SamplesTable,
          Sample,
          $$SamplesTableFilterComposer,
          $$SamplesTableOrderingComposer,
          $$SamplesTableAnnotationComposer,
          $$SamplesTableCreateCompanionBuilder,
          $$SamplesTableUpdateCompanionBuilder,
          (Sample, BaseReferences<_$AppDatabase, $SamplesTable, Sample>),
          Sample,
          PrefetchHooks Function()
        > {
  $$SamplesTableTableManager(_$AppDatabase db, $SamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<double> accelX = const Value.absent(),
                Value<double> accelY = const Value.absent(),
                Value<double> accelZ = const Value.absent(),
                Value<double> gyroX = const Value.absent(),
                Value<double> gyroY = const Value.absent(),
                Value<double> gyroZ = const Value.absent(),
                Value<double?> magX = const Value.absent(),
                Value<double?> magY = const Value.absent(),
                Value<double?> magZ = const Value.absent(),
                Value<double?> pressure = const Value.absent(),
              }) => SamplesCompanion(
                id: id,
                sessionId: sessionId,
                timestampMs: timestampMs,
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                gyroX: gyroX,
                gyroY: gyroY,
                gyroZ: gyroZ,
                magX: magX,
                magY: magY,
                magZ: magZ,
                pressure: pressure,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sessionId,
                required int timestampMs,
                required double accelX,
                required double accelY,
                required double accelZ,
                required double gyroX,
                required double gyroY,
                required double gyroZ,
                Value<double?> magX = const Value.absent(),
                Value<double?> magY = const Value.absent(),
                Value<double?> magZ = const Value.absent(),
                Value<double?> pressure = const Value.absent(),
              }) => SamplesCompanion.insert(
                id: id,
                sessionId: sessionId,
                timestampMs: timestampMs,
                accelX: accelX,
                accelY: accelY,
                accelZ: accelZ,
                gyroX: gyroX,
                gyroY: gyroY,
                gyroZ: gyroZ,
                magX: magX,
                magY: magY,
                magZ: magZ,
                pressure: pressure,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SamplesTable,
      Sample,
      $$SamplesTableFilterComposer,
      $$SamplesTableOrderingComposer,
      $$SamplesTableAnnotationComposer,
      $$SamplesTableCreateCompanionBuilder,
      $$SamplesTableUpdateCompanionBuilder,
      (Sample, BaseReferences<_$AppDatabase, $SamplesTable, Sample>),
      Sample,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SamplesTableTableManager get samples =>
      $$SamplesTableTableManager(_db, _db.samples);
}
