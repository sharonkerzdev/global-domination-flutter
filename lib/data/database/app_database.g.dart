// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ActiveBoostTable extends ActiveBoost
    with TableInfo<$ActiveBoostTable, ActiveBoostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveBoostTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> multiplier =
      GeneratedColumn<String>(
        'multiplier',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($ActiveBoostTable.$convertermultiplier);
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [singletonId, multiplier, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_boost';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveBoostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  ActiveBoostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveBoostRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      multiplier: $ActiveBoostTable.$convertermultiplier.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}multiplier'],
        )!,
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $ActiveBoostTable createAlias(String alias) {
    return $ActiveBoostTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $convertermultiplier =
      const DecimalConverter();
}

class ActiveBoostRow extends DataClass implements Insertable<ActiveBoostRow> {
  final int singletonId;
  final Decimal multiplier;
  final DateTime expiresAt;
  const ActiveBoostRow({
    required this.singletonId,
    required this.multiplier,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    {
      map['multiplier'] = Variable<String>(
        $ActiveBoostTable.$convertermultiplier.toSql(multiplier),
      );
    }
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  ActiveBoostCompanion toCompanion(bool nullToAbsent) {
    return ActiveBoostCompanion(
      singletonId: Value(singletonId),
      multiplier: Value(multiplier),
      expiresAt: Value(expiresAt),
    );
  }

  factory ActiveBoostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveBoostRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      multiplier: serializer.fromJson<Decimal>(json['multiplier']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'multiplier': serializer.toJson<Decimal>(multiplier),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  ActiveBoostRow copyWith({
    int? singletonId,
    Decimal? multiplier,
    DateTime? expiresAt,
  }) => ActiveBoostRow(
    singletonId: singletonId ?? this.singletonId,
    multiplier: multiplier ?? this.multiplier,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  ActiveBoostRow copyWithCompanion(ActiveBoostCompanion data) {
    return ActiveBoostRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      multiplier: data.multiplier.present
          ? data.multiplier.value
          : this.multiplier,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveBoostRow(')
          ..write('singletonId: $singletonId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singletonId, multiplier, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveBoostRow &&
          other.singletonId == this.singletonId &&
          other.multiplier == this.multiplier &&
          other.expiresAt == this.expiresAt);
}

class ActiveBoostCompanion extends UpdateCompanion<ActiveBoostRow> {
  final Value<int> singletonId;
  final Value<Decimal> multiplier;
  final Value<DateTime> expiresAt;
  const ActiveBoostCompanion({
    this.singletonId = const Value.absent(),
    this.multiplier = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  ActiveBoostCompanion.insert({
    this.singletonId = const Value.absent(),
    required Decimal multiplier,
    required DateTime expiresAt,
  }) : multiplier = Value(multiplier),
       expiresAt = Value(expiresAt);
  static Insertable<ActiveBoostRow> custom({
    Expression<int>? singletonId,
    Expression<String>? multiplier,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (multiplier != null) 'multiplier': multiplier,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  ActiveBoostCompanion copyWith({
    Value<int>? singletonId,
    Value<Decimal>? multiplier,
    Value<DateTime>? expiresAt,
  }) {
    return ActiveBoostCompanion(
      singletonId: singletonId ?? this.singletonId,
      multiplier: multiplier ?? this.multiplier,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (multiplier.present) {
      map['multiplier'] = Variable<String>(
        $ActiveBoostTable.$convertermultiplier.toSql(multiplier.value),
      );
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveBoostCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $ActiveGlobalUpgradesTable extends ActiveGlobalUpgrades
    with TableInfo<$ActiveGlobalUpgradesTable, ActiveGlobalUpgradeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveGlobalUpgradesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_global_upgrades';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveGlobalUpgradeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveGlobalUpgradeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveGlobalUpgradeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $ActiveGlobalUpgradesTable createAlias(String alias) {
    return $ActiveGlobalUpgradesTable(attachedDatabase, alias);
  }
}

class ActiveGlobalUpgradeRow extends DataClass
    implements Insertable<ActiveGlobalUpgradeRow> {
  final String id;
  const ActiveGlobalUpgradeRow({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  ActiveGlobalUpgradesCompanion toCompanion(bool nullToAbsent) {
    return ActiveGlobalUpgradesCompanion(id: Value(id));
  }

  factory ActiveGlobalUpgradeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveGlobalUpgradeRow(id: serializer.fromJson<String>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  ActiveGlobalUpgradeRow copyWith({String? id}) =>
      ActiveGlobalUpgradeRow(id: id ?? this.id);
  ActiveGlobalUpgradeRow copyWithCompanion(ActiveGlobalUpgradesCompanion data) {
    return ActiveGlobalUpgradeRow(
      id: data.id.present ? data.id.value : this.id,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGlobalUpgradeRow(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveGlobalUpgradeRow && other.id == this.id);
}

class ActiveGlobalUpgradesCompanion
    extends UpdateCompanion<ActiveGlobalUpgradeRow> {
  final Value<String> id;
  final Value<int> rowid;
  const ActiveGlobalUpgradesCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveGlobalUpgradesCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ActiveGlobalUpgradeRow> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveGlobalUpgradesCompanion copyWith({
    Value<String>? id,
    Value<int>? rowid,
  }) {
    return ActiveGlobalUpgradesCompanion(
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGlobalUpgradesCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveGoldenEffectTable extends ActiveGoldenEffect
    with TableInfo<$ActiveGoldenEffectTable, ActiveGoldenEffectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveGoldenEffectTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _goldenIdMeta = const VerificationMeta(
    'goldenId',
  );
  @override
  late final GeneratedColumn<String> goldenId = GeneratedColumn<String>(
    'golden_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _multiplierMeta = const VerificationMeta(
    'multiplier',
  );
  @override
  late final GeneratedColumn<int> multiplier = GeneratedColumn<int>(
    'multiplier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    goldenId,
    multiplier,
    expiresAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_golden_effect';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveGoldenEffectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('golden_id')) {
      context.handle(
        _goldenIdMeta,
        goldenId.isAcceptableOrUnknown(data['golden_id']!, _goldenIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goldenIdMeta);
    }
    if (data.containsKey('multiplier')) {
      context.handle(
        _multiplierMeta,
        multiplier.isAcceptableOrUnknown(data['multiplier']!, _multiplierMeta),
      );
    } else if (isInserting) {
      context.missing(_multiplierMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  ActiveGoldenEffectRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveGoldenEffectRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      goldenId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}golden_id'],
      )!,
      multiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}multiplier'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $ActiveGoldenEffectTable createAlias(String alias) {
    return $ActiveGoldenEffectTable(attachedDatabase, alias);
  }
}

class ActiveGoldenEffectRow extends DataClass
    implements Insertable<ActiveGoldenEffectRow> {
  final int singletonId;
  final String goldenId;
  final int multiplier;
  final DateTime expiresAt;
  const ActiveGoldenEffectRow({
    required this.singletonId,
    required this.goldenId,
    required this.multiplier,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['golden_id'] = Variable<String>(goldenId);
    map['multiplier'] = Variable<int>(multiplier);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  ActiveGoldenEffectCompanion toCompanion(bool nullToAbsent) {
    return ActiveGoldenEffectCompanion(
      singletonId: Value(singletonId),
      goldenId: Value(goldenId),
      multiplier: Value(multiplier),
      expiresAt: Value(expiresAt),
    );
  }

  factory ActiveGoldenEffectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveGoldenEffectRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      goldenId: serializer.fromJson<String>(json['goldenId']),
      multiplier: serializer.fromJson<int>(json['multiplier']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'goldenId': serializer.toJson<String>(goldenId),
      'multiplier': serializer.toJson<int>(multiplier),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  ActiveGoldenEffectRow copyWith({
    int? singletonId,
    String? goldenId,
    int? multiplier,
    DateTime? expiresAt,
  }) => ActiveGoldenEffectRow(
    singletonId: singletonId ?? this.singletonId,
    goldenId: goldenId ?? this.goldenId,
    multiplier: multiplier ?? this.multiplier,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  ActiveGoldenEffectRow copyWithCompanion(ActiveGoldenEffectCompanion data) {
    return ActiveGoldenEffectRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      goldenId: data.goldenId.present ? data.goldenId.value : this.goldenId,
      multiplier: data.multiplier.present
          ? data.multiplier.value
          : this.multiplier,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGoldenEffectRow(')
          ..write('singletonId: $singletonId, ')
          ..write('goldenId: $goldenId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singletonId, goldenId, multiplier, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveGoldenEffectRow &&
          other.singletonId == this.singletonId &&
          other.goldenId == this.goldenId &&
          other.multiplier == this.multiplier &&
          other.expiresAt == this.expiresAt);
}

class ActiveGoldenEffectCompanion
    extends UpdateCompanion<ActiveGoldenEffectRow> {
  final Value<int> singletonId;
  final Value<String> goldenId;
  final Value<int> multiplier;
  final Value<DateTime> expiresAt;
  const ActiveGoldenEffectCompanion({
    this.singletonId = const Value.absent(),
    this.goldenId = const Value.absent(),
    this.multiplier = const Value.absent(),
    this.expiresAt = const Value.absent(),
  });
  ActiveGoldenEffectCompanion.insert({
    this.singletonId = const Value.absent(),
    required String goldenId,
    required int multiplier,
    required DateTime expiresAt,
  }) : goldenId = Value(goldenId),
       multiplier = Value(multiplier),
       expiresAt = Value(expiresAt);
  static Insertable<ActiveGoldenEffectRow> custom({
    Expression<int>? singletonId,
    Expression<String>? goldenId,
    Expression<int>? multiplier,
    Expression<DateTime>? expiresAt,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (goldenId != null) 'golden_id': goldenId,
      if (multiplier != null) 'multiplier': multiplier,
      if (expiresAt != null) 'expires_at': expiresAt,
    });
  }

  ActiveGoldenEffectCompanion copyWith({
    Value<int>? singletonId,
    Value<String>? goldenId,
    Value<int>? multiplier,
    Value<DateTime>? expiresAt,
  }) {
    return ActiveGoldenEffectCompanion(
      singletonId: singletonId ?? this.singletonId,
      goldenId: goldenId ?? this.goldenId,
      multiplier: multiplier ?? this.multiplier,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (goldenId.present) {
      map['golden_id'] = Variable<String>(goldenId.value);
    }
    if (multiplier.present) {
      map['multiplier'] = Variable<int>(multiplier.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGoldenEffectCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('goldenId: $goldenId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }
}

class $ActiveGoldensTable extends ActiveGoldens
    with TableInfo<$ActiveGoldensTable, ActiveGoldenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveGoldensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryIdMeta = const VerificationMeta(
    'countryId',
  );
  @override
  late final GeneratedColumn<String> countryId = GeneratedColumn<String>(
    'country_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _multiplierMeta = const VerificationMeta(
    'multiplier',
  );
  @override
  late final GeneratedColumn<int> multiplier = GeneratedColumn<int>(
    'multiplier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, countryId, multiplier, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_goldens';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveGoldenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('country_id')) {
      context.handle(
        _countryIdMeta,
        countryId.isAcceptableOrUnknown(data['country_id']!, _countryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_countryIdMeta);
    }
    if (data.containsKey('multiplier')) {
      context.handle(
        _multiplierMeta,
        multiplier.isAcceptableOrUnknown(data['multiplier']!, _multiplierMeta),
      );
    } else if (isInserting) {
      context.missing(_multiplierMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActiveGoldenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveGoldenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      countryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country_id'],
      )!,
      multiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}multiplier'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $ActiveGoldensTable createAlias(String alias) {
    return $ActiveGoldensTable(attachedDatabase, alias);
  }
}

class ActiveGoldenRow extends DataClass implements Insertable<ActiveGoldenRow> {
  final String id;
  final String countryId;
  final int multiplier;
  final DateTime expiresAt;
  const ActiveGoldenRow({
    required this.id,
    required this.countryId,
    required this.multiplier,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['country_id'] = Variable<String>(countryId);
    map['multiplier'] = Variable<int>(multiplier);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  ActiveGoldensCompanion toCompanion(bool nullToAbsent) {
    return ActiveGoldensCompanion(
      id: Value(id),
      countryId: Value(countryId),
      multiplier: Value(multiplier),
      expiresAt: Value(expiresAt),
    );
  }

  factory ActiveGoldenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveGoldenRow(
      id: serializer.fromJson<String>(json['id']),
      countryId: serializer.fromJson<String>(json['countryId']),
      multiplier: serializer.fromJson<int>(json['multiplier']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'countryId': serializer.toJson<String>(countryId),
      'multiplier': serializer.toJson<int>(multiplier),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  ActiveGoldenRow copyWith({
    String? id,
    String? countryId,
    int? multiplier,
    DateTime? expiresAt,
  }) => ActiveGoldenRow(
    id: id ?? this.id,
    countryId: countryId ?? this.countryId,
    multiplier: multiplier ?? this.multiplier,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  ActiveGoldenRow copyWithCompanion(ActiveGoldensCompanion data) {
    return ActiveGoldenRow(
      id: data.id.present ? data.id.value : this.id,
      countryId: data.countryId.present ? data.countryId.value : this.countryId,
      multiplier: data.multiplier.present
          ? data.multiplier.value
          : this.multiplier,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGoldenRow(')
          ..write('id: $id, ')
          ..write('countryId: $countryId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, countryId, multiplier, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveGoldenRow &&
          other.id == this.id &&
          other.countryId == this.countryId &&
          other.multiplier == this.multiplier &&
          other.expiresAt == this.expiresAt);
}

class ActiveGoldensCompanion extends UpdateCompanion<ActiveGoldenRow> {
  final Value<String> id;
  final Value<String> countryId;
  final Value<int> multiplier;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const ActiveGoldensCompanion({
    this.id = const Value.absent(),
    this.countryId = const Value.absent(),
    this.multiplier = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveGoldensCompanion.insert({
    required String id,
    required String countryId,
    required int multiplier,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       countryId = Value(countryId),
       multiplier = Value(multiplier),
       expiresAt = Value(expiresAt);
  static Insertable<ActiveGoldenRow> custom({
    Expression<String>? id,
    Expression<String>? countryId,
    Expression<int>? multiplier,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (countryId != null) 'country_id': countryId,
      if (multiplier != null) 'multiplier': multiplier,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveGoldensCompanion copyWith({
    Value<String>? id,
    Value<String>? countryId,
    Value<int>? multiplier,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return ActiveGoldensCompanion(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      multiplier: multiplier ?? this.multiplier,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (countryId.present) {
      map['country_id'] = Variable<String>(countryId.value);
    }
    if (multiplier.present) {
      map['multiplier'] = Variable<int>(multiplier.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveGoldensCompanion(')
          ..write('id: $id, ')
          ..write('countryId: $countryId, ')
          ..write('multiplier: $multiplier, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveMissionsTable extends ActiveMissions
    with TableInfo<$ActiveMissionsTable, ActiveMissionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveMissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> rewardIntel =
      GeneratedColumn<String>(
        'reward_intel',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($ActiveMissionsTable.$converterrewardIntel);
  @override
  List<GeneratedColumn> get $columns => [
    slot,
    id,
    progress,
    target,
    rewardIntel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_missions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveMissionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slot};
  @override
  ActiveMissionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveMissionRow(
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target'],
      )!,
      rewardIntel: $ActiveMissionsTable.$converterrewardIntel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reward_intel'],
        )!,
      ),
    );
  }

  @override
  $ActiveMissionsTable createAlias(String alias) {
    return $ActiveMissionsTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterrewardIntel =
      const DecimalConverter();
}

class ActiveMissionRow extends DataClass
    implements Insertable<ActiveMissionRow> {
  final int slot;
  final String id;
  final int progress;
  final int target;
  final Decimal rewardIntel;
  const ActiveMissionRow({
    required this.slot,
    required this.id,
    required this.progress,
    required this.target,
    required this.rewardIntel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slot'] = Variable<int>(slot);
    map['id'] = Variable<String>(id);
    map['progress'] = Variable<int>(progress);
    map['target'] = Variable<int>(target);
    {
      map['reward_intel'] = Variable<String>(
        $ActiveMissionsTable.$converterrewardIntel.toSql(rewardIntel),
      );
    }
    return map;
  }

  ActiveMissionsCompanion toCompanion(bool nullToAbsent) {
    return ActiveMissionsCompanion(
      slot: Value(slot),
      id: Value(id),
      progress: Value(progress),
      target: Value(target),
      rewardIntel: Value(rewardIntel),
    );
  }

  factory ActiveMissionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveMissionRow(
      slot: serializer.fromJson<int>(json['slot']),
      id: serializer.fromJson<String>(json['id']),
      progress: serializer.fromJson<int>(json['progress']),
      target: serializer.fromJson<int>(json['target']),
      rewardIntel: serializer.fromJson<Decimal>(json['rewardIntel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slot': serializer.toJson<int>(slot),
      'id': serializer.toJson<String>(id),
      'progress': serializer.toJson<int>(progress),
      'target': serializer.toJson<int>(target),
      'rewardIntel': serializer.toJson<Decimal>(rewardIntel),
    };
  }

  ActiveMissionRow copyWith({
    int? slot,
    String? id,
    int? progress,
    int? target,
    Decimal? rewardIntel,
  }) => ActiveMissionRow(
    slot: slot ?? this.slot,
    id: id ?? this.id,
    progress: progress ?? this.progress,
    target: target ?? this.target,
    rewardIntel: rewardIntel ?? this.rewardIntel,
  );
  ActiveMissionRow copyWithCompanion(ActiveMissionsCompanion data) {
    return ActiveMissionRow(
      slot: data.slot.present ? data.slot.value : this.slot,
      id: data.id.present ? data.id.value : this.id,
      progress: data.progress.present ? data.progress.value : this.progress,
      target: data.target.present ? data.target.value : this.target,
      rewardIntel: data.rewardIntel.present
          ? data.rewardIntel.value
          : this.rewardIntel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveMissionRow(')
          ..write('slot: $slot, ')
          ..write('id: $id, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('rewardIntel: $rewardIntel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slot, id, progress, target, rewardIntel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveMissionRow &&
          other.slot == this.slot &&
          other.id == this.id &&
          other.progress == this.progress &&
          other.target == this.target &&
          other.rewardIntel == this.rewardIntel);
}

class ActiveMissionsCompanion extends UpdateCompanion<ActiveMissionRow> {
  final Value<int> slot;
  final Value<String> id;
  final Value<int> progress;
  final Value<int> target;
  final Value<Decimal> rewardIntel;
  const ActiveMissionsCompanion({
    this.slot = const Value.absent(),
    this.id = const Value.absent(),
    this.progress = const Value.absent(),
    this.target = const Value.absent(),
    this.rewardIntel = const Value.absent(),
  });
  ActiveMissionsCompanion.insert({
    this.slot = const Value.absent(),
    required String id,
    required int progress,
    required int target,
    required Decimal rewardIntel,
  }) : id = Value(id),
       progress = Value(progress),
       target = Value(target),
       rewardIntel = Value(rewardIntel);
  static Insertable<ActiveMissionRow> custom({
    Expression<int>? slot,
    Expression<String>? id,
    Expression<int>? progress,
    Expression<int>? target,
    Expression<String>? rewardIntel,
  }) {
    return RawValuesInsertable({
      if (slot != null) 'slot': slot,
      if (id != null) 'id': id,
      if (progress != null) 'progress': progress,
      if (target != null) 'target': target,
      if (rewardIntel != null) 'reward_intel': rewardIntel,
    });
  }

  ActiveMissionsCompanion copyWith({
    Value<int>? slot,
    Value<String>? id,
    Value<int>? progress,
    Value<int>? target,
    Value<Decimal>? rewardIntel,
  }) {
    return ActiveMissionsCompanion(
      slot: slot ?? this.slot,
      id: id ?? this.id,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      rewardIntel: rewardIntel ?? this.rewardIntel,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (rewardIntel.present) {
      map['reward_intel'] = Variable<String>(
        $ActiveMissionsTable.$converterrewardIntel.toSql(rewardIntel.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveMissionsCompanion(')
          ..write('slot: $slot, ')
          ..write('id: $id, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('rewardIntel: $rewardIntel')
          ..write(')'))
        .toString();
  }
}

class $CompletedMissionsTable extends CompletedMissions
    with TableInfo<$CompletedMissionsTable, CompletedMissionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletedMissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completed_missions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CompletedMissionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CompletedMissionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletedMissionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $CompletedMissionsTable createAlias(String alias) {
    return $CompletedMissionsTable(attachedDatabase, alias);
  }
}

class CompletedMissionRow extends DataClass
    implements Insertable<CompletedMissionRow> {
  final String id;
  const CompletedMissionRow({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  CompletedMissionsCompanion toCompanion(bool nullToAbsent) {
    return CompletedMissionsCompanion(id: Value(id));
  }

  factory CompletedMissionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletedMissionRow(id: serializer.fromJson<String>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  CompletedMissionRow copyWith({String? id}) =>
      CompletedMissionRow(id: id ?? this.id);
  CompletedMissionRow copyWithCompanion(CompletedMissionsCompanion data) {
    return CompletedMissionRow(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('CompletedMissionRow(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedMissionRow && other.id == this.id);
}

class CompletedMissionsCompanion extends UpdateCompanion<CompletedMissionRow> {
  final Value<String> id;
  final Value<int> rowid;
  const CompletedMissionsCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletedMissionsCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<CompletedMissionRow> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletedMissionsCompanion copyWith({Value<String>? id, Value<int>? rowid}) {
    return CompletedMissionsCompanion(
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletedMissionsCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContinentsTable extends Continents
    with TableInfo<$ContinentsTable, ContinentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContinentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, unlocked, completed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'continents';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContinentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    } else if (isInserting) {
      context.missing(_completedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContinentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContinentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $ContinentsTable createAlias(String alias) {
    return $ContinentsTable(attachedDatabase, alias);
  }
}

class ContinentRow extends DataClass implements Insertable<ContinentRow> {
  final String id;
  final bool unlocked;
  final bool completed;
  const ContinentRow({
    required this.id,
    required this.unlocked,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unlocked'] = Variable<bool>(unlocked);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  ContinentsCompanion toCompanion(bool nullToAbsent) {
    return ContinentsCompanion(
      id: Value(id),
      unlocked: Value(unlocked),
      completed: Value(completed),
    );
  }

  factory ContinentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContinentRow(
      id: serializer.fromJson<String>(json['id']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unlocked': serializer.toJson<bool>(unlocked),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  ContinentRow copyWith({String? id, bool? unlocked, bool? completed}) =>
      ContinentRow(
        id: id ?? this.id,
        unlocked: unlocked ?? this.unlocked,
        completed: completed ?? this.completed,
      );
  ContinentRow copyWithCompanion(ContinentsCompanion data) {
    return ContinentRow(
      id: data.id.present ? data.id.value : this.id,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContinentRow(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, unlocked, completed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContinentRow &&
          other.id == this.id &&
          other.unlocked == this.unlocked &&
          other.completed == this.completed);
}

class ContinentsCompanion extends UpdateCompanion<ContinentRow> {
  final Value<String> id;
  final Value<bool> unlocked;
  final Value<bool> completed;
  final Value<int> rowid;
  const ContinentsCompanion({
    this.id = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContinentsCompanion.insert({
    required String id,
    required bool unlocked,
    required bool completed,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unlocked = Value(unlocked),
       completed = Value(completed);
  static Insertable<ContinentRow> custom({
    Expression<String>? id,
    Expression<bool>? unlocked,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unlocked != null) 'unlocked': unlocked,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContinentsCompanion copyWith({
    Value<String>? id,
    Value<bool>? unlocked,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return ContinentsCompanion(
      id: id ?? this.id,
      unlocked: unlocked ?? this.unlocked,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContinentsCompanion(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContinentMilestonesTable extends ContinentMilestones
    with TableInfo<$ContinentMilestonesTable, ContinentMilestoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContinentMilestonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _continentIdMeta = const VerificationMeta(
    'continentId',
  );
  @override
  late final GeneratedColumn<String> continentId = GeneratedColumn<String>(
    'continent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES continents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _milestoneMeta = const VerificationMeta(
    'milestone',
  );
  @override
  late final GeneratedColumn<int> milestone = GeneratedColumn<int>(
    'milestone',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [continentId, milestone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'continent_milestones';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContinentMilestoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('continent_id')) {
      context.handle(
        _continentIdMeta,
        continentId.isAcceptableOrUnknown(
          data['continent_id']!,
          _continentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_continentIdMeta);
    }
    if (data.containsKey('milestone')) {
      context.handle(
        _milestoneMeta,
        milestone.isAcceptableOrUnknown(data['milestone']!, _milestoneMeta),
      );
    } else if (isInserting) {
      context.missing(_milestoneMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {continentId, milestone};
  @override
  ContinentMilestoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContinentMilestoneRow(
      continentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}continent_id'],
      )!,
      milestone: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}milestone'],
      )!,
    );
  }

  @override
  $ContinentMilestonesTable createAlias(String alias) {
    return $ContinentMilestonesTable(attachedDatabase, alias);
  }
}

class ContinentMilestoneRow extends DataClass
    implements Insertable<ContinentMilestoneRow> {
  final String continentId;
  final int milestone;
  const ContinentMilestoneRow({
    required this.continentId,
    required this.milestone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['continent_id'] = Variable<String>(continentId);
    map['milestone'] = Variable<int>(milestone);
    return map;
  }

  ContinentMilestonesCompanion toCompanion(bool nullToAbsent) {
    return ContinentMilestonesCompanion(
      continentId: Value(continentId),
      milestone: Value(milestone),
    );
  }

  factory ContinentMilestoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContinentMilestoneRow(
      continentId: serializer.fromJson<String>(json['continentId']),
      milestone: serializer.fromJson<int>(json['milestone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'continentId': serializer.toJson<String>(continentId),
      'milestone': serializer.toJson<int>(milestone),
    };
  }

  ContinentMilestoneRow copyWith({String? continentId, int? milestone}) =>
      ContinentMilestoneRow(
        continentId: continentId ?? this.continentId,
        milestone: milestone ?? this.milestone,
      );
  ContinentMilestoneRow copyWithCompanion(ContinentMilestonesCompanion data) {
    return ContinentMilestoneRow(
      continentId: data.continentId.present
          ? data.continentId.value
          : this.continentId,
      milestone: data.milestone.present ? data.milestone.value : this.milestone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContinentMilestoneRow(')
          ..write('continentId: $continentId, ')
          ..write('milestone: $milestone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(continentId, milestone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContinentMilestoneRow &&
          other.continentId == this.continentId &&
          other.milestone == this.milestone);
}

class ContinentMilestonesCompanion
    extends UpdateCompanion<ContinentMilestoneRow> {
  final Value<String> continentId;
  final Value<int> milestone;
  final Value<int> rowid;
  const ContinentMilestonesCompanion({
    this.continentId = const Value.absent(),
    this.milestone = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContinentMilestonesCompanion.insert({
    required String continentId,
    required int milestone,
    this.rowid = const Value.absent(),
  }) : continentId = Value(continentId),
       milestone = Value(milestone);
  static Insertable<ContinentMilestoneRow> custom({
    Expression<String>? continentId,
    Expression<int>? milestone,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (continentId != null) 'continent_id': continentId,
      if (milestone != null) 'milestone': milestone,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContinentMilestonesCompanion copyWith({
    Value<String>? continentId,
    Value<int>? milestone,
    Value<int>? rowid,
  }) {
    return ContinentMilestonesCompanion(
      continentId: continentId ?? this.continentId,
      milestone: milestone ?? this.milestone,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (continentId.present) {
      map['continent_id'] = Variable<String>(continentId.value);
    }
    if (milestone.present) {
      map['milestone'] = Variable<int>(milestone.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContinentMilestonesCompanion(')
          ..write('continentId: $continentId, ')
          ..write('milestone: $milestone, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CountriesTable extends Countries
    with TableInfo<$CountriesTable, CountryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CountriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _ipLevelMeta = const VerificationMeta(
    'ipLevel',
  );
  @override
  late final GeneratedColumn<int> ipLevel = GeneratedColumn<int>(
    'ip_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leaderTierMeta = const VerificationMeta(
    'leaderTier',
  );
  @override
  late final GeneratedColumn<String> leaderTier = GeneratedColumn<String>(
    'leader_tier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> bankedInfluence =
      GeneratedColumn<String>(
        'banked_influence',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($CountriesTable.$converterbankedInfluence);
  static const VerificationMeta _lastCollectedAtMeta = const VerificationMeta(
    'lastCollectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCollectedAt =
      GeneratedColumn<DateTime>(
        'last_collected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unlocked,
    ipLevel,
    leaderTier,
    bankedInfluence,
    lastCollectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'countries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CountryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedMeta);
    }
    if (data.containsKey('ip_level')) {
      context.handle(
        _ipLevelMeta,
        ipLevel.isAcceptableOrUnknown(data['ip_level']!, _ipLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_ipLevelMeta);
    }
    if (data.containsKey('leader_tier')) {
      context.handle(
        _leaderTierMeta,
        leaderTier.isAcceptableOrUnknown(data['leader_tier']!, _leaderTierMeta),
      );
    } else if (isInserting) {
      context.missing(_leaderTierMeta);
    }
    if (data.containsKey('last_collected_at')) {
      context.handle(
        _lastCollectedAtMeta,
        lastCollectedAt.isAcceptableOrUnknown(
          data['last_collected_at']!,
          _lastCollectedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CountryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CountryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      ipLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ip_level'],
      )!,
      leaderTier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}leader_tier'],
      )!,
      bankedInfluence: $CountriesTable.$converterbankedInfluence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}banked_influence'],
        )!,
      ),
      lastCollectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_collected_at'],
      ),
    );
  }

  @override
  $CountriesTable createAlias(String alias) {
    return $CountriesTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $converterbankedInfluence =
      const DecimalConverter();
}

class CountryRow extends DataClass implements Insertable<CountryRow> {
  final String id;
  final bool unlocked;
  final int ipLevel;

  /// Persisted as [LeaderTier.name] in the mapper (no table-level converter).
  final String leaderTier;
  final Decimal bankedInfluence;
  final DateTime? lastCollectedAt;
  const CountryRow({
    required this.id,
    required this.unlocked,
    required this.ipLevel,
    required this.leaderTier,
    required this.bankedInfluence,
    this.lastCollectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unlocked'] = Variable<bool>(unlocked);
    map['ip_level'] = Variable<int>(ipLevel);
    map['leader_tier'] = Variable<String>(leaderTier);
    {
      map['banked_influence'] = Variable<String>(
        $CountriesTable.$converterbankedInfluence.toSql(bankedInfluence),
      );
    }
    if (!nullToAbsent || lastCollectedAt != null) {
      map['last_collected_at'] = Variable<DateTime>(lastCollectedAt);
    }
    return map;
  }

  CountriesCompanion toCompanion(bool nullToAbsent) {
    return CountriesCompanion(
      id: Value(id),
      unlocked: Value(unlocked),
      ipLevel: Value(ipLevel),
      leaderTier: Value(leaderTier),
      bankedInfluence: Value(bankedInfluence),
      lastCollectedAt: lastCollectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCollectedAt),
    );
  }

  factory CountryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CountryRow(
      id: serializer.fromJson<String>(json['id']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      ipLevel: serializer.fromJson<int>(json['ipLevel']),
      leaderTier: serializer.fromJson<String>(json['leaderTier']),
      bankedInfluence: serializer.fromJson<Decimal>(json['bankedInfluence']),
      lastCollectedAt: serializer.fromJson<DateTime?>(json['lastCollectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unlocked': serializer.toJson<bool>(unlocked),
      'ipLevel': serializer.toJson<int>(ipLevel),
      'leaderTier': serializer.toJson<String>(leaderTier),
      'bankedInfluence': serializer.toJson<Decimal>(bankedInfluence),
      'lastCollectedAt': serializer.toJson<DateTime?>(lastCollectedAt),
    };
  }

  CountryRow copyWith({
    String? id,
    bool? unlocked,
    int? ipLevel,
    String? leaderTier,
    Decimal? bankedInfluence,
    Value<DateTime?> lastCollectedAt = const Value.absent(),
  }) => CountryRow(
    id: id ?? this.id,
    unlocked: unlocked ?? this.unlocked,
    ipLevel: ipLevel ?? this.ipLevel,
    leaderTier: leaderTier ?? this.leaderTier,
    bankedInfluence: bankedInfluence ?? this.bankedInfluence,
    lastCollectedAt: lastCollectedAt.present
        ? lastCollectedAt.value
        : this.lastCollectedAt,
  );
  CountryRow copyWithCompanion(CountriesCompanion data) {
    return CountryRow(
      id: data.id.present ? data.id.value : this.id,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      ipLevel: data.ipLevel.present ? data.ipLevel.value : this.ipLevel,
      leaderTier: data.leaderTier.present
          ? data.leaderTier.value
          : this.leaderTier,
      bankedInfluence: data.bankedInfluence.present
          ? data.bankedInfluence.value
          : this.bankedInfluence,
      lastCollectedAt: data.lastCollectedAt.present
          ? data.lastCollectedAt.value
          : this.lastCollectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CountryRow(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('ipLevel: $ipLevel, ')
          ..write('leaderTier: $leaderTier, ')
          ..write('bankedInfluence: $bankedInfluence, ')
          ..write('lastCollectedAt: $lastCollectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unlocked,
    ipLevel,
    leaderTier,
    bankedInfluence,
    lastCollectedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryRow &&
          other.id == this.id &&
          other.unlocked == this.unlocked &&
          other.ipLevel == this.ipLevel &&
          other.leaderTier == this.leaderTier &&
          other.bankedInfluence == this.bankedInfluence &&
          other.lastCollectedAt == this.lastCollectedAt);
}

class CountriesCompanion extends UpdateCompanion<CountryRow> {
  final Value<String> id;
  final Value<bool> unlocked;
  final Value<int> ipLevel;
  final Value<String> leaderTier;
  final Value<Decimal> bankedInfluence;
  final Value<DateTime?> lastCollectedAt;
  final Value<int> rowid;
  const CountriesCompanion({
    this.id = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.ipLevel = const Value.absent(),
    this.leaderTier = const Value.absent(),
    this.bankedInfluence = const Value.absent(),
    this.lastCollectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CountriesCompanion.insert({
    required String id,
    required bool unlocked,
    required int ipLevel,
    required String leaderTier,
    required Decimal bankedInfluence,
    this.lastCollectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unlocked = Value(unlocked),
       ipLevel = Value(ipLevel),
       leaderTier = Value(leaderTier),
       bankedInfluence = Value(bankedInfluence);
  static Insertable<CountryRow> custom({
    Expression<String>? id,
    Expression<bool>? unlocked,
    Expression<int>? ipLevel,
    Expression<String>? leaderTier,
    Expression<String>? bankedInfluence,
    Expression<DateTime>? lastCollectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unlocked != null) 'unlocked': unlocked,
      if (ipLevel != null) 'ip_level': ipLevel,
      if (leaderTier != null) 'leader_tier': leaderTier,
      if (bankedInfluence != null) 'banked_influence': bankedInfluence,
      if (lastCollectedAt != null) 'last_collected_at': lastCollectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CountriesCompanion copyWith({
    Value<String>? id,
    Value<bool>? unlocked,
    Value<int>? ipLevel,
    Value<String>? leaderTier,
    Value<Decimal>? bankedInfluence,
    Value<DateTime?>? lastCollectedAt,
    Value<int>? rowid,
  }) {
    return CountriesCompanion(
      id: id ?? this.id,
      unlocked: unlocked ?? this.unlocked,
      ipLevel: ipLevel ?? this.ipLevel,
      leaderTier: leaderTier ?? this.leaderTier,
      bankedInfluence: bankedInfluence ?? this.bankedInfluence,
      lastCollectedAt: lastCollectedAt ?? this.lastCollectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (ipLevel.present) {
      map['ip_level'] = Variable<int>(ipLevel.value);
    }
    if (leaderTier.present) {
      map['leader_tier'] = Variable<String>(leaderTier.value);
    }
    if (bankedInfluence.present) {
      map['banked_influence'] = Variable<String>(
        $CountriesTable.$converterbankedInfluence.toSql(bankedInfluence.value),
      );
    }
    if (lastCollectedAt.present) {
      map['last_collected_at'] = Variable<DateTime>(lastCollectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CountriesCompanion(')
          ..write('id: $id, ')
          ..write('unlocked: $unlocked, ')
          ..write('ipLevel: $ipLevel, ')
          ..write('leaderTier: $leaderTier, ')
          ..write('bankedInfluence: $bankedInfluence, ')
          ..write('lastCollectedAt: $lastCollectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CrashLogsTable extends CrashLogs
    with TableInfo<$CrashLogsTable, CrashLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CrashLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CrashLogLevel, String> level =
      GeneratedColumn<String>(
        'level',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CrashLogLevel>($CrashLogsTable.$converterlevel);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stackTraceMeta = const VerificationMeta(
    'stackTrace',
  );
  @override
  late final GeneratedColumn<String> stackTrace = GeneratedColumn<String>(
    'stack_trace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timestamp,
    level,
    tag,
    message,
    stackTrace,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crash_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CrashLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('stack_trace')) {
      context.handle(
        _stackTraceMeta,
        stackTrace.isAcceptableOrUnknown(data['stack_trace']!, _stackTraceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CrashLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CrashLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      level: $CrashLogsTable.$converterlevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}level'],
        )!,
      ),
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      stackTrace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stack_trace'],
      ),
    );
  }

  @override
  $CrashLogsTable createAlias(String alias) {
    return $CrashLogsTable(attachedDatabase, alias);
  }

  static TypeConverter<CrashLogLevel, String> $converterlevel =
      const CrashLogLevelConverter();
}

class CrashLogRow extends DataClass implements Insertable<CrashLogRow> {
  final int id;
  final DateTime timestamp;
  final CrashLogLevel level;
  final String tag;
  final String message;
  final String? stackTrace;
  const CrashLogRow({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.stackTrace,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    {
      map['level'] = Variable<String>(
        $CrashLogsTable.$converterlevel.toSql(level),
      );
    }
    map['tag'] = Variable<String>(tag);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || stackTrace != null) {
      map['stack_trace'] = Variable<String>(stackTrace);
    }
    return map;
  }

  CrashLogsCompanion toCompanion(bool nullToAbsent) {
    return CrashLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      level: Value(level),
      tag: Value(tag),
      message: Value(message),
      stackTrace: stackTrace == null && nullToAbsent
          ? const Value.absent()
          : Value(stackTrace),
    );
  }

  factory CrashLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CrashLogRow(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      level: serializer.fromJson<CrashLogLevel>(json['level']),
      tag: serializer.fromJson<String>(json['tag']),
      message: serializer.fromJson<String>(json['message']),
      stackTrace: serializer.fromJson<String?>(json['stackTrace']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'level': serializer.toJson<CrashLogLevel>(level),
      'tag': serializer.toJson<String>(tag),
      'message': serializer.toJson<String>(message),
      'stackTrace': serializer.toJson<String?>(stackTrace),
    };
  }

  CrashLogRow copyWith({
    int? id,
    DateTime? timestamp,
    CrashLogLevel? level,
    String? tag,
    String? message,
    Value<String?> stackTrace = const Value.absent(),
  }) => CrashLogRow(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    level: level ?? this.level,
    tag: tag ?? this.tag,
    message: message ?? this.message,
    stackTrace: stackTrace.present ? stackTrace.value : this.stackTrace,
  );
  CrashLogRow copyWithCompanion(CrashLogsCompanion data) {
    return CrashLogRow(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      level: data.level.present ? data.level.value : this.level,
      tag: data.tag.present ? data.tag.value : this.tag,
      message: data.message.present ? data.message.value : this.message,
      stackTrace: data.stackTrace.present
          ? data.stackTrace.value
          : this.stackTrace,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CrashLogRow(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('level: $level, ')
          ..write('tag: $tag, ')
          ..write('message: $message, ')
          ..write('stackTrace: $stackTrace')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, timestamp, level, tag, message, stackTrace);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CrashLogRow &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.level == this.level &&
          other.tag == this.tag &&
          other.message == this.message &&
          other.stackTrace == this.stackTrace);
}

class CrashLogsCompanion extends UpdateCompanion<CrashLogRow> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<CrashLogLevel> level;
  final Value<String> tag;
  final Value<String> message;
  final Value<String?> stackTrace;
  const CrashLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.level = const Value.absent(),
    this.tag = const Value.absent(),
    this.message = const Value.absent(),
    this.stackTrace = const Value.absent(),
  });
  CrashLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime timestamp,
    required CrashLogLevel level,
    required String tag,
    required String message,
    this.stackTrace = const Value.absent(),
  }) : timestamp = Value(timestamp),
       level = Value(level),
       tag = Value(tag),
       message = Value(message);
  static Insertable<CrashLogRow> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? level,
    Expression<String>? tag,
    Expression<String>? message,
    Expression<String>? stackTrace,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (level != null) 'level': level,
      if (tag != null) 'tag': tag,
      if (message != null) 'message': message,
      if (stackTrace != null) 'stack_trace': stackTrace,
    });
  }

  CrashLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<CrashLogLevel>? level,
    Value<String>? tag,
    Value<String>? message,
    Value<String?>? stackTrace,
  }) {
    return CrashLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      tag: tag ?? this.tag,
      message: message ?? this.message,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(
        $CrashLogsTable.$converterlevel.toSql(level.value),
      );
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (stackTrace.present) {
      map['stack_trace'] = Variable<String>(stackTrace.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CrashLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('level: $level, ')
          ..write('tag: $tag, ')
          ..write('message: $message, ')
          ..write('stackTrace: $stackTrace')
          ..write(')'))
        .toString();
  }
}

class $DailyStreaksTable extends DailyStreaks
    with TableInfo<$DailyStreaksTable, DailyStreakRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastClaimDateMeta = const VerificationMeta(
    'lastClaimDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastClaimDate =
      GeneratedColumn<DateTime>(
        'last_claim_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [singletonId, day, lastClaimDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_streaks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyStreakRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('last_claim_date')) {
      context.handle(
        _lastClaimDateMeta,
        lastClaimDate.isAcceptableOrUnknown(
          data['last_claim_date']!,
          _lastClaimDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  DailyStreakRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStreakRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      )!,
      lastClaimDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_claim_date'],
      ),
    );
  }

  @override
  $DailyStreaksTable createAlias(String alias) {
    return $DailyStreaksTable(attachedDatabase, alias);
  }
}

class DailyStreakRow extends DataClass implements Insertable<DailyStreakRow> {
  final int singletonId;
  final int day;
  final DateTime? lastClaimDate;
  const DailyStreakRow({
    required this.singletonId,
    required this.day,
    this.lastClaimDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['day'] = Variable<int>(day);
    if (!nullToAbsent || lastClaimDate != null) {
      map['last_claim_date'] = Variable<DateTime>(lastClaimDate);
    }
    return map;
  }

  DailyStreaksCompanion toCompanion(bool nullToAbsent) {
    return DailyStreaksCompanion(
      singletonId: Value(singletonId),
      day: Value(day),
      lastClaimDate: lastClaimDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastClaimDate),
    );
  }

  factory DailyStreakRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStreakRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      day: serializer.fromJson<int>(json['day']),
      lastClaimDate: serializer.fromJson<DateTime?>(json['lastClaimDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'day': serializer.toJson<int>(day),
      'lastClaimDate': serializer.toJson<DateTime?>(lastClaimDate),
    };
  }

  DailyStreakRow copyWith({
    int? singletonId,
    int? day,
    Value<DateTime?> lastClaimDate = const Value.absent(),
  }) => DailyStreakRow(
    singletonId: singletonId ?? this.singletonId,
    day: day ?? this.day,
    lastClaimDate: lastClaimDate.present
        ? lastClaimDate.value
        : this.lastClaimDate,
  );
  DailyStreakRow copyWithCompanion(DailyStreaksCompanion data) {
    return DailyStreakRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      day: data.day.present ? data.day.value : this.day,
      lastClaimDate: data.lastClaimDate.present
          ? data.lastClaimDate.value
          : this.lastClaimDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStreakRow(')
          ..write('singletonId: $singletonId, ')
          ..write('day: $day, ')
          ..write('lastClaimDate: $lastClaimDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(singletonId, day, lastClaimDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStreakRow &&
          other.singletonId == this.singletonId &&
          other.day == this.day &&
          other.lastClaimDate == this.lastClaimDate);
}

class DailyStreaksCompanion extends UpdateCompanion<DailyStreakRow> {
  final Value<int> singletonId;
  final Value<int> day;
  final Value<DateTime?> lastClaimDate;
  const DailyStreaksCompanion({
    this.singletonId = const Value.absent(),
    this.day = const Value.absent(),
    this.lastClaimDate = const Value.absent(),
  });
  DailyStreaksCompanion.insert({
    this.singletonId = const Value.absent(),
    required int day,
    this.lastClaimDate = const Value.absent(),
  }) : day = Value(day);
  static Insertable<DailyStreakRow> custom({
    Expression<int>? singletonId,
    Expression<int>? day,
    Expression<DateTime>? lastClaimDate,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (day != null) 'day': day,
      if (lastClaimDate != null) 'last_claim_date': lastClaimDate,
    });
  }

  DailyStreaksCompanion copyWith({
    Value<int>? singletonId,
    Value<int>? day,
    Value<DateTime?>? lastClaimDate,
  }) {
    return DailyStreaksCompanion(
      singletonId: singletonId ?? this.singletonId,
      day: day ?? this.day,
      lastClaimDate: lastClaimDate ?? this.lastClaimDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (lastClaimDate.present) {
      map['last_claim_date'] = Variable<DateTime>(lastClaimDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStreaksCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('day: $day, ')
          ..write('lastClaimDate: $lastClaimDate')
          ..write(')'))
        .toString();
  }
}

class $EarnedAchievementsTable extends EarnedAchievements
    with TableInfo<$EarnedAchievementsTable, EarnedAchievementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EarnedAchievementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'earned_achievements';
  @override
  VerificationContext validateIntegrity(
    Insertable<EarnedAchievementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EarnedAchievementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EarnedAchievementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $EarnedAchievementsTable createAlias(String alias) {
    return $EarnedAchievementsTable(attachedDatabase, alias);
  }
}

class EarnedAchievementRow extends DataClass
    implements Insertable<EarnedAchievementRow> {
  final String id;
  const EarnedAchievementRow({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    return map;
  }

  EarnedAchievementsCompanion toCompanion(bool nullToAbsent) {
    return EarnedAchievementsCompanion(id: Value(id));
  }

  factory EarnedAchievementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EarnedAchievementRow(id: serializer.fromJson<String>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<String>(id)};
  }

  EarnedAchievementRow copyWith({String? id}) =>
      EarnedAchievementRow(id: id ?? this.id);
  EarnedAchievementRow copyWithCompanion(EarnedAchievementsCompanion data) {
    return EarnedAchievementRow(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('EarnedAchievementRow(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EarnedAchievementRow && other.id == this.id);
}

class EarnedAchievementsCompanion
    extends UpdateCompanion<EarnedAchievementRow> {
  final Value<String> id;
  final Value<int> rowid;
  const EarnedAchievementsCompanion({
    this.id = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EarnedAchievementsCompanion.insert({
    required String id,
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<EarnedAchievementRow> custom({
    Expression<String>? id,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EarnedAchievementsCompanion copyWith({Value<String>? id, Value<int>? rowid}) {
    return EarnedAchievementsCompanion(
      id: id ?? this.id,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EarnedAchievementsCompanion(')
          ..write('id: $id, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _singletonIdMeta = const VerificationMeta(
    'singletonId',
  );
  @override
  late final GeneratedColumn<int> singletonId = GeneratedColumn<int>(
    'singleton_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSavedAtMeta = const VerificationMeta(
    'lastSavedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSavedAt = GeneratedColumn<DateTime>(
    'last_saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> totalInfluence =
      GeneratedColumn<String>(
        'total_influence',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($MetaTable.$convertertotalInfluence);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> totalIntel =
      GeneratedColumn<String>(
        'total_intel',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($MetaTable.$convertertotalIntel);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String>
  goldenOpportunityMultiplier = GeneratedColumn<String>(
    'golden_opportunity_multiplier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Decimal>($MetaTable.$convertergoldenOpportunityMultiplier);
  @override
  late final GeneratedColumnWithTypeConverter<Decimal, String> boostMultiplier =
      GeneratedColumn<String>(
        'boost_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Decimal>($MetaTable.$converterboostMultiplier);
  @override
  List<GeneratedColumn> get $columns => [
    singletonId,
    schemaVersion,
    lastSavedAt,
    totalInfluence,
    totalIntel,
    goldenOpportunityMultiplier,
    boostMultiplier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('singleton_id')) {
      context.handle(
        _singletonIdMeta,
        singletonId.isAcceptableOrUnknown(
          data['singleton_id']!,
          _singletonIdMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('last_saved_at')) {
      context.handle(
        _lastSavedAtMeta,
        lastSavedAt.isAcceptableOrUnknown(
          data['last_saved_at']!,
          _lastSavedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSavedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {singletonId};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      singletonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}singleton_id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      lastSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_saved_at'],
      )!,
      totalInfluence: $MetaTable.$convertertotalInfluence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}total_influence'],
        )!,
      ),
      totalIntel: $MetaTable.$convertertotalIntel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}total_intel'],
        )!,
      ),
      goldenOpportunityMultiplier: $MetaTable
          .$convertergoldenOpportunityMultiplier
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}golden_opportunity_multiplier'],
            )!,
          ),
      boostMultiplier: $MetaTable.$converterboostMultiplier.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}boost_multiplier'],
        )!,
      ),
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }

  static TypeConverter<Decimal, String> $convertertotalInfluence =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertertotalIntel =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $convertergoldenOpportunityMultiplier =
      const DecimalConverter();
  static TypeConverter<Decimal, String> $converterboostMultiplier =
      const DecimalConverter();
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final int singletonId;
  final int schemaVersion;
  final DateTime lastSavedAt;
  final Decimal totalInfluence;
  final Decimal totalIntel;
  final Decimal goldenOpportunityMultiplier;
  final Decimal boostMultiplier;
  const MetaRow({
    required this.singletonId,
    required this.schemaVersion,
    required this.lastSavedAt,
    required this.totalInfluence,
    required this.totalIntel,
    required this.goldenOpportunityMultiplier,
    required this.boostMultiplier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['singleton_id'] = Variable<int>(singletonId);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['last_saved_at'] = Variable<DateTime>(lastSavedAt);
    {
      map['total_influence'] = Variable<String>(
        $MetaTable.$convertertotalInfluence.toSql(totalInfluence),
      );
    }
    {
      map['total_intel'] = Variable<String>(
        $MetaTable.$convertertotalIntel.toSql(totalIntel),
      );
    }
    {
      map['golden_opportunity_multiplier'] = Variable<String>(
        $MetaTable.$convertergoldenOpportunityMultiplier.toSql(
          goldenOpportunityMultiplier,
        ),
      );
    }
    {
      map['boost_multiplier'] = Variable<String>(
        $MetaTable.$converterboostMultiplier.toSql(boostMultiplier),
      );
    }
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(
      singletonId: Value(singletonId),
      schemaVersion: Value(schemaVersion),
      lastSavedAt: Value(lastSavedAt),
      totalInfluence: Value(totalInfluence),
      totalIntel: Value(totalIntel),
      goldenOpportunityMultiplier: Value(goldenOpportunityMultiplier),
      boostMultiplier: Value(boostMultiplier),
    );
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      singletonId: serializer.fromJson<int>(json['singletonId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      lastSavedAt: serializer.fromJson<DateTime>(json['lastSavedAt']),
      totalInfluence: serializer.fromJson<Decimal>(json['totalInfluence']),
      totalIntel: serializer.fromJson<Decimal>(json['totalIntel']),
      goldenOpportunityMultiplier: serializer.fromJson<Decimal>(
        json['goldenOpportunityMultiplier'],
      ),
      boostMultiplier: serializer.fromJson<Decimal>(json['boostMultiplier']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'singletonId': serializer.toJson<int>(singletonId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'lastSavedAt': serializer.toJson<DateTime>(lastSavedAt),
      'totalInfluence': serializer.toJson<Decimal>(totalInfluence),
      'totalIntel': serializer.toJson<Decimal>(totalIntel),
      'goldenOpportunityMultiplier': serializer.toJson<Decimal>(
        goldenOpportunityMultiplier,
      ),
      'boostMultiplier': serializer.toJson<Decimal>(boostMultiplier),
    };
  }

  MetaRow copyWith({
    int? singletonId,
    int? schemaVersion,
    DateTime? lastSavedAt,
    Decimal? totalInfluence,
    Decimal? totalIntel,
    Decimal? goldenOpportunityMultiplier,
    Decimal? boostMultiplier,
  }) => MetaRow(
    singletonId: singletonId ?? this.singletonId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    totalInfluence: totalInfluence ?? this.totalInfluence,
    totalIntel: totalIntel ?? this.totalIntel,
    goldenOpportunityMultiplier:
        goldenOpportunityMultiplier ?? this.goldenOpportunityMultiplier,
    boostMultiplier: boostMultiplier ?? this.boostMultiplier,
  );
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      singletonId: data.singletonId.present
          ? data.singletonId.value
          : this.singletonId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      lastSavedAt: data.lastSavedAt.present
          ? data.lastSavedAt.value
          : this.lastSavedAt,
      totalInfluence: data.totalInfluence.present
          ? data.totalInfluence.value
          : this.totalInfluence,
      totalIntel: data.totalIntel.present
          ? data.totalIntel.value
          : this.totalIntel,
      goldenOpportunityMultiplier: data.goldenOpportunityMultiplier.present
          ? data.goldenOpportunityMultiplier.value
          : this.goldenOpportunityMultiplier,
      boostMultiplier: data.boostMultiplier.present
          ? data.boostMultiplier.value
          : this.boostMultiplier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('singletonId: $singletonId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('lastSavedAt: $lastSavedAt, ')
          ..write('totalInfluence: $totalInfluence, ')
          ..write('totalIntel: $totalIntel, ')
          ..write('goldenOpportunityMultiplier: $goldenOpportunityMultiplier, ')
          ..write('boostMultiplier: $boostMultiplier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    singletonId,
    schemaVersion,
    lastSavedAt,
    totalInfluence,
    totalIntel,
    goldenOpportunityMultiplier,
    boostMultiplier,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow &&
          other.singletonId == this.singletonId &&
          other.schemaVersion == this.schemaVersion &&
          other.lastSavedAt == this.lastSavedAt &&
          other.totalInfluence == this.totalInfluence &&
          other.totalIntel == this.totalIntel &&
          other.goldenOpportunityMultiplier ==
              this.goldenOpportunityMultiplier &&
          other.boostMultiplier == this.boostMultiplier);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<int> singletonId;
  final Value<int> schemaVersion;
  final Value<DateTime> lastSavedAt;
  final Value<Decimal> totalInfluence;
  final Value<Decimal> totalIntel;
  final Value<Decimal> goldenOpportunityMultiplier;
  final Value<Decimal> boostMultiplier;
  const MetaCompanion({
    this.singletonId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.lastSavedAt = const Value.absent(),
    this.totalInfluence = const Value.absent(),
    this.totalIntel = const Value.absent(),
    this.goldenOpportunityMultiplier = const Value.absent(),
    this.boostMultiplier = const Value.absent(),
  });
  MetaCompanion.insert({
    this.singletonId = const Value.absent(),
    required int schemaVersion,
    required DateTime lastSavedAt,
    required Decimal totalInfluence,
    required Decimal totalIntel,
    required Decimal goldenOpportunityMultiplier,
    required Decimal boostMultiplier,
  }) : schemaVersion = Value(schemaVersion),
       lastSavedAt = Value(lastSavedAt),
       totalInfluence = Value(totalInfluence),
       totalIntel = Value(totalIntel),
       goldenOpportunityMultiplier = Value(goldenOpportunityMultiplier),
       boostMultiplier = Value(boostMultiplier);
  static Insertable<MetaRow> custom({
    Expression<int>? singletonId,
    Expression<int>? schemaVersion,
    Expression<DateTime>? lastSavedAt,
    Expression<String>? totalInfluence,
    Expression<String>? totalIntel,
    Expression<String>? goldenOpportunityMultiplier,
    Expression<String>? boostMultiplier,
  }) {
    return RawValuesInsertable({
      if (singletonId != null) 'singleton_id': singletonId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (lastSavedAt != null) 'last_saved_at': lastSavedAt,
      if (totalInfluence != null) 'total_influence': totalInfluence,
      if (totalIntel != null) 'total_intel': totalIntel,
      if (goldenOpportunityMultiplier != null)
        'golden_opportunity_multiplier': goldenOpportunityMultiplier,
      if (boostMultiplier != null) 'boost_multiplier': boostMultiplier,
    });
  }

  MetaCompanion copyWith({
    Value<int>? singletonId,
    Value<int>? schemaVersion,
    Value<DateTime>? lastSavedAt,
    Value<Decimal>? totalInfluence,
    Value<Decimal>? totalIntel,
    Value<Decimal>? goldenOpportunityMultiplier,
    Value<Decimal>? boostMultiplier,
  }) {
    return MetaCompanion(
      singletonId: singletonId ?? this.singletonId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      totalInfluence: totalInfluence ?? this.totalInfluence,
      totalIntel: totalIntel ?? this.totalIntel,
      goldenOpportunityMultiplier:
          goldenOpportunityMultiplier ?? this.goldenOpportunityMultiplier,
      boostMultiplier: boostMultiplier ?? this.boostMultiplier,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (singletonId.present) {
      map['singleton_id'] = Variable<int>(singletonId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (lastSavedAt.present) {
      map['last_saved_at'] = Variable<DateTime>(lastSavedAt.value);
    }
    if (totalInfluence.present) {
      map['total_influence'] = Variable<String>(
        $MetaTable.$convertertotalInfluence.toSql(totalInfluence.value),
      );
    }
    if (totalIntel.present) {
      map['total_intel'] = Variable<String>(
        $MetaTable.$convertertotalIntel.toSql(totalIntel.value),
      );
    }
    if (goldenOpportunityMultiplier.present) {
      map['golden_opportunity_multiplier'] = Variable<String>(
        $MetaTable.$convertergoldenOpportunityMultiplier.toSql(
          goldenOpportunityMultiplier.value,
        ),
      );
    }
    if (boostMultiplier.present) {
      map['boost_multiplier'] = Variable<String>(
        $MetaTable.$converterboostMultiplier.toSql(boostMultiplier.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('singletonId: $singletonId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('lastSavedAt: $lastSavedAt, ')
          ..write('totalInfluence: $totalInfluence, ')
          ..write('totalIntel: $totalIntel, ')
          ..write('goldenOpportunityMultiplier: $goldenOpportunityMultiplier, ')
          ..write('boostMultiplier: $boostMultiplier')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ActiveBoostTable activeBoost = $ActiveBoostTable(this);
  late final $ActiveGlobalUpgradesTable activeGlobalUpgrades =
      $ActiveGlobalUpgradesTable(this);
  late final $ActiveGoldenEffectTable activeGoldenEffect =
      $ActiveGoldenEffectTable(this);
  late final $ActiveGoldensTable activeGoldens = $ActiveGoldensTable(this);
  late final $ActiveMissionsTable activeMissions = $ActiveMissionsTable(this);
  late final $CompletedMissionsTable completedMissions =
      $CompletedMissionsTable(this);
  late final $ContinentsTable continents = $ContinentsTable(this);
  late final $ContinentMilestonesTable continentMilestones =
      $ContinentMilestonesTable(this);
  late final $CountriesTable countries = $CountriesTable(this);
  late final $CrashLogsTable crashLogs = $CrashLogsTable(this);
  late final $DailyStreaksTable dailyStreaks = $DailyStreaksTable(this);
  late final $EarnedAchievementsTable earnedAchievements =
      $EarnedAchievementsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    activeBoost,
    activeGlobalUpgrades,
    activeGoldenEffect,
    activeGoldens,
    activeMissions,
    completedMissions,
    continents,
    continentMilestones,
    countries,
    crashLogs,
    dailyStreaks,
    earnedAchievements,
    meta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'continents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('continent_milestones', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ActiveBoostTableCreateCompanionBuilder =
    ActiveBoostCompanion Function({
      Value<int> singletonId,
      required Decimal multiplier,
      required DateTime expiresAt,
    });
typedef $$ActiveBoostTableUpdateCompanionBuilder =
    ActiveBoostCompanion Function({
      Value<int> singletonId,
      Value<Decimal> multiplier,
      Value<DateTime> expiresAt,
    });

class $$ActiveBoostTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveBoostTable> {
  $$ActiveBoostTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get multiplier =>
      $composableBuilder(
        column: $table.multiplier,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveBoostTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveBoostTable> {
  $$ActiveBoostTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveBoostTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveBoostTable> {
  $$ActiveBoostTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get multiplier =>
      $composableBuilder(
        column: $table.multiplier,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$ActiveBoostTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveBoostTable,
          ActiveBoostRow,
          $$ActiveBoostTableFilterComposer,
          $$ActiveBoostTableOrderingComposer,
          $$ActiveBoostTableAnnotationComposer,
          $$ActiveBoostTableCreateCompanionBuilder,
          $$ActiveBoostTableUpdateCompanionBuilder,
          (
            ActiveBoostRow,
            BaseReferences<_$AppDatabase, $ActiveBoostTable, ActiveBoostRow>,
          ),
          ActiveBoostRow,
          PrefetchHooks Function()
        > {
  $$ActiveBoostTableTableManager(_$AppDatabase db, $ActiveBoostTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveBoostTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveBoostTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveBoostTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<Decimal> multiplier = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
              }) => ActiveBoostCompanion(
                singletonId: singletonId,
                multiplier: multiplier,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                required Decimal multiplier,
                required DateTime expiresAt,
              }) => ActiveBoostCompanion.insert(
                singletonId: singletonId,
                multiplier: multiplier,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveBoostTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveBoostTable,
      ActiveBoostRow,
      $$ActiveBoostTableFilterComposer,
      $$ActiveBoostTableOrderingComposer,
      $$ActiveBoostTableAnnotationComposer,
      $$ActiveBoostTableCreateCompanionBuilder,
      $$ActiveBoostTableUpdateCompanionBuilder,
      (
        ActiveBoostRow,
        BaseReferences<_$AppDatabase, $ActiveBoostTable, ActiveBoostRow>,
      ),
      ActiveBoostRow,
      PrefetchHooks Function()
    >;
typedef $$ActiveGlobalUpgradesTableCreateCompanionBuilder =
    ActiveGlobalUpgradesCompanion Function({
      required String id,
      Value<int> rowid,
    });
typedef $$ActiveGlobalUpgradesTableUpdateCompanionBuilder =
    ActiveGlobalUpgradesCompanion Function({
      Value<String> id,
      Value<int> rowid,
    });

class $$ActiveGlobalUpgradesTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveGlobalUpgradesTable> {
  $$ActiveGlobalUpgradesTableFilterComposer({
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
}

class $$ActiveGlobalUpgradesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveGlobalUpgradesTable> {
  $$ActiveGlobalUpgradesTableOrderingComposer({
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
}

class $$ActiveGlobalUpgradesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveGlobalUpgradesTable> {
  $$ActiveGlobalUpgradesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$ActiveGlobalUpgradesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveGlobalUpgradesTable,
          ActiveGlobalUpgradeRow,
          $$ActiveGlobalUpgradesTableFilterComposer,
          $$ActiveGlobalUpgradesTableOrderingComposer,
          $$ActiveGlobalUpgradesTableAnnotationComposer,
          $$ActiveGlobalUpgradesTableCreateCompanionBuilder,
          $$ActiveGlobalUpgradesTableUpdateCompanionBuilder,
          (
            ActiveGlobalUpgradeRow,
            BaseReferences<
              _$AppDatabase,
              $ActiveGlobalUpgradesTable,
              ActiveGlobalUpgradeRow
            >,
          ),
          ActiveGlobalUpgradeRow,
          PrefetchHooks Function()
        > {
  $$ActiveGlobalUpgradesTableTableManager(
    _$AppDatabase db,
    $ActiveGlobalUpgradesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveGlobalUpgradesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveGlobalUpgradesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ActiveGlobalUpgradesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveGlobalUpgradesCompanion(id: id, rowid: rowid),
          createCompanionCallback:
              ({required String id, Value<int> rowid = const Value.absent()}) =>
                  ActiveGlobalUpgradesCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveGlobalUpgradesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveGlobalUpgradesTable,
      ActiveGlobalUpgradeRow,
      $$ActiveGlobalUpgradesTableFilterComposer,
      $$ActiveGlobalUpgradesTableOrderingComposer,
      $$ActiveGlobalUpgradesTableAnnotationComposer,
      $$ActiveGlobalUpgradesTableCreateCompanionBuilder,
      $$ActiveGlobalUpgradesTableUpdateCompanionBuilder,
      (
        ActiveGlobalUpgradeRow,
        BaseReferences<
          _$AppDatabase,
          $ActiveGlobalUpgradesTable,
          ActiveGlobalUpgradeRow
        >,
      ),
      ActiveGlobalUpgradeRow,
      PrefetchHooks Function()
    >;
typedef $$ActiveGoldenEffectTableCreateCompanionBuilder =
    ActiveGoldenEffectCompanion Function({
      Value<int> singletonId,
      required String goldenId,
      required int multiplier,
      required DateTime expiresAt,
    });
typedef $$ActiveGoldenEffectTableUpdateCompanionBuilder =
    ActiveGoldenEffectCompanion Function({
      Value<int> singletonId,
      Value<String> goldenId,
      Value<int> multiplier,
      Value<DateTime> expiresAt,
    });

class $$ActiveGoldenEffectTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveGoldenEffectTable> {
  $$ActiveGoldenEffectTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldenId => $composableBuilder(
    column: $table.goldenId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveGoldenEffectTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveGoldenEffectTable> {
  $$ActiveGoldenEffectTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldenId => $composableBuilder(
    column: $table.goldenId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveGoldenEffectTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveGoldenEffectTable> {
  $$ActiveGoldenEffectTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goldenId =>
      $composableBuilder(column: $table.goldenId, builder: (column) => column);

  GeneratedColumn<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$ActiveGoldenEffectTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveGoldenEffectTable,
          ActiveGoldenEffectRow,
          $$ActiveGoldenEffectTableFilterComposer,
          $$ActiveGoldenEffectTableOrderingComposer,
          $$ActiveGoldenEffectTableAnnotationComposer,
          $$ActiveGoldenEffectTableCreateCompanionBuilder,
          $$ActiveGoldenEffectTableUpdateCompanionBuilder,
          (
            ActiveGoldenEffectRow,
            BaseReferences<
              _$AppDatabase,
              $ActiveGoldenEffectTable,
              ActiveGoldenEffectRow
            >,
          ),
          ActiveGoldenEffectRow,
          PrefetchHooks Function()
        > {
  $$ActiveGoldenEffectTableTableManager(
    _$AppDatabase db,
    $ActiveGoldenEffectTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveGoldenEffectTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveGoldenEffectTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveGoldenEffectTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<String> goldenId = const Value.absent(),
                Value<int> multiplier = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
              }) => ActiveGoldenEffectCompanion(
                singletonId: singletonId,
                goldenId: goldenId,
                multiplier: multiplier,
                expiresAt: expiresAt,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                required String goldenId,
                required int multiplier,
                required DateTime expiresAt,
              }) => ActiveGoldenEffectCompanion.insert(
                singletonId: singletonId,
                goldenId: goldenId,
                multiplier: multiplier,
                expiresAt: expiresAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveGoldenEffectTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveGoldenEffectTable,
      ActiveGoldenEffectRow,
      $$ActiveGoldenEffectTableFilterComposer,
      $$ActiveGoldenEffectTableOrderingComposer,
      $$ActiveGoldenEffectTableAnnotationComposer,
      $$ActiveGoldenEffectTableCreateCompanionBuilder,
      $$ActiveGoldenEffectTableUpdateCompanionBuilder,
      (
        ActiveGoldenEffectRow,
        BaseReferences<
          _$AppDatabase,
          $ActiveGoldenEffectTable,
          ActiveGoldenEffectRow
        >,
      ),
      ActiveGoldenEffectRow,
      PrefetchHooks Function()
    >;
typedef $$ActiveGoldensTableCreateCompanionBuilder =
    ActiveGoldensCompanion Function({
      required String id,
      required String countryId,
      required int multiplier,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$ActiveGoldensTableUpdateCompanionBuilder =
    ActiveGoldensCompanion Function({
      Value<String> id,
      Value<String> countryId,
      Value<int> multiplier,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$ActiveGoldensTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveGoldensTable> {
  $$ActiveGoldensTableFilterComposer({
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

  ColumnFilters<String> get countryId => $composableBuilder(
    column: $table.countryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveGoldensTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveGoldensTable> {
  $$ActiveGoldensTableOrderingComposer({
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

  ColumnOrderings<String> get countryId => $composableBuilder(
    column: $table.countryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveGoldensTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveGoldensTable> {
  $$ActiveGoldensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get countryId =>
      $composableBuilder(column: $table.countryId, builder: (column) => column);

  GeneratedColumn<int> get multiplier => $composableBuilder(
    column: $table.multiplier,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$ActiveGoldensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveGoldensTable,
          ActiveGoldenRow,
          $$ActiveGoldensTableFilterComposer,
          $$ActiveGoldensTableOrderingComposer,
          $$ActiveGoldensTableAnnotationComposer,
          $$ActiveGoldensTableCreateCompanionBuilder,
          $$ActiveGoldensTableUpdateCompanionBuilder,
          (
            ActiveGoldenRow,
            BaseReferences<_$AppDatabase, $ActiveGoldensTable, ActiveGoldenRow>,
          ),
          ActiveGoldenRow,
          PrefetchHooks Function()
        > {
  $$ActiveGoldensTableTableManager(_$AppDatabase db, $ActiveGoldensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveGoldensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveGoldensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveGoldensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> countryId = const Value.absent(),
                Value<int> multiplier = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveGoldensCompanion(
                id: id,
                countryId: countryId,
                multiplier: multiplier,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String countryId,
                required int multiplier,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => ActiveGoldensCompanion.insert(
                id: id,
                countryId: countryId,
                multiplier: multiplier,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveGoldensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveGoldensTable,
      ActiveGoldenRow,
      $$ActiveGoldensTableFilterComposer,
      $$ActiveGoldensTableOrderingComposer,
      $$ActiveGoldensTableAnnotationComposer,
      $$ActiveGoldensTableCreateCompanionBuilder,
      $$ActiveGoldensTableUpdateCompanionBuilder,
      (
        ActiveGoldenRow,
        BaseReferences<_$AppDatabase, $ActiveGoldensTable, ActiveGoldenRow>,
      ),
      ActiveGoldenRow,
      PrefetchHooks Function()
    >;
typedef $$ActiveMissionsTableCreateCompanionBuilder =
    ActiveMissionsCompanion Function({
      Value<int> slot,
      required String id,
      required int progress,
      required int target,
      required Decimal rewardIntel,
    });
typedef $$ActiveMissionsTableUpdateCompanionBuilder =
    ActiveMissionsCompanion Function({
      Value<int> slot,
      Value<String> id,
      Value<int> progress,
      Value<int> target,
      Value<Decimal> rewardIntel,
    });

class $$ActiveMissionsTableFilterComposer
    extends Composer<_$AppDatabase, $ActiveMissionsTable> {
  $$ActiveMissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get rewardIntel =>
      $composableBuilder(
        column: $table.rewardIntel,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$ActiveMissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActiveMissionsTable> {
  $$ActiveMissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardIntel => $composableBuilder(
    column: $table.rewardIntel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveMissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActiveMissionsTable> {
  $$ActiveMissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Decimal, String> get rewardIntel =>
      $composableBuilder(
        column: $table.rewardIntel,
        builder: (column) => column,
      );
}

class $$ActiveMissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActiveMissionsTable,
          ActiveMissionRow,
          $$ActiveMissionsTableFilterComposer,
          $$ActiveMissionsTableOrderingComposer,
          $$ActiveMissionsTableAnnotationComposer,
          $$ActiveMissionsTableCreateCompanionBuilder,
          $$ActiveMissionsTableUpdateCompanionBuilder,
          (
            ActiveMissionRow,
            BaseReferences<
              _$AppDatabase,
              $ActiveMissionsTable,
              ActiveMissionRow
            >,
          ),
          ActiveMissionRow,
          PrefetchHooks Function()
        > {
  $$ActiveMissionsTableTableManager(
    _$AppDatabase db,
    $ActiveMissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveMissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveMissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveMissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> slot = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<int> target = const Value.absent(),
                Value<Decimal> rewardIntel = const Value.absent(),
              }) => ActiveMissionsCompanion(
                slot: slot,
                id: id,
                progress: progress,
                target: target,
                rewardIntel: rewardIntel,
              ),
          createCompanionCallback:
              ({
                Value<int> slot = const Value.absent(),
                required String id,
                required int progress,
                required int target,
                required Decimal rewardIntel,
              }) => ActiveMissionsCompanion.insert(
                slot: slot,
                id: id,
                progress: progress,
                target: target,
                rewardIntel: rewardIntel,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveMissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActiveMissionsTable,
      ActiveMissionRow,
      $$ActiveMissionsTableFilterComposer,
      $$ActiveMissionsTableOrderingComposer,
      $$ActiveMissionsTableAnnotationComposer,
      $$ActiveMissionsTableCreateCompanionBuilder,
      $$ActiveMissionsTableUpdateCompanionBuilder,
      (
        ActiveMissionRow,
        BaseReferences<_$AppDatabase, $ActiveMissionsTable, ActiveMissionRow>,
      ),
      ActiveMissionRow,
      PrefetchHooks Function()
    >;
typedef $$CompletedMissionsTableCreateCompanionBuilder =
    CompletedMissionsCompanion Function({required String id, Value<int> rowid});
typedef $$CompletedMissionsTableUpdateCompanionBuilder =
    CompletedMissionsCompanion Function({Value<String> id, Value<int> rowid});

class $$CompletedMissionsTableFilterComposer
    extends Composer<_$AppDatabase, $CompletedMissionsTable> {
  $$CompletedMissionsTableFilterComposer({
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
}

class $$CompletedMissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletedMissionsTable> {
  $$CompletedMissionsTableOrderingComposer({
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
}

class $$CompletedMissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletedMissionsTable> {
  $$CompletedMissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$CompletedMissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CompletedMissionsTable,
          CompletedMissionRow,
          $$CompletedMissionsTableFilterComposer,
          $$CompletedMissionsTableOrderingComposer,
          $$CompletedMissionsTableAnnotationComposer,
          $$CompletedMissionsTableCreateCompanionBuilder,
          $$CompletedMissionsTableUpdateCompanionBuilder,
          (
            CompletedMissionRow,
            BaseReferences<
              _$AppDatabase,
              $CompletedMissionsTable,
              CompletedMissionRow
            >,
          ),
          CompletedMissionRow,
          PrefetchHooks Function()
        > {
  $$CompletedMissionsTableTableManager(
    _$AppDatabase db,
    $CompletedMissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletedMissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletedMissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletedMissionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CompletedMissionsCompanion(id: id, rowid: rowid),
          createCompanionCallback:
              ({required String id, Value<int> rowid = const Value.absent()}) =>
                  CompletedMissionsCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompletedMissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CompletedMissionsTable,
      CompletedMissionRow,
      $$CompletedMissionsTableFilterComposer,
      $$CompletedMissionsTableOrderingComposer,
      $$CompletedMissionsTableAnnotationComposer,
      $$CompletedMissionsTableCreateCompanionBuilder,
      $$CompletedMissionsTableUpdateCompanionBuilder,
      (
        CompletedMissionRow,
        BaseReferences<
          _$AppDatabase,
          $CompletedMissionsTable,
          CompletedMissionRow
        >,
      ),
      CompletedMissionRow,
      PrefetchHooks Function()
    >;
typedef $$ContinentsTableCreateCompanionBuilder =
    ContinentsCompanion Function({
      required String id,
      required bool unlocked,
      required bool completed,
      Value<int> rowid,
    });
typedef $$ContinentsTableUpdateCompanionBuilder =
    ContinentsCompanion Function({
      Value<String> id,
      Value<bool> unlocked,
      Value<bool> completed,
      Value<int> rowid,
    });

final class $$ContinentsTableReferences
    extends BaseReferences<_$AppDatabase, $ContinentsTable, ContinentRow> {
  $$ContinentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $ContinentMilestonesTable,
    List<ContinentMilestoneRow>
  >
  _continentMilestonesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.continentMilestones,
        aliasName: $_aliasNameGenerator(
          db.continents.id,
          db.continentMilestones.continentId,
        ),
      );

  $$ContinentMilestonesTableProcessedTableManager get continentMilestonesRefs {
    final manager = $$ContinentMilestonesTableTableManager(
      $_db,
      $_db.continentMilestones,
    ).filter((f) => f.continentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _continentMilestonesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContinentsTableFilterComposer
    extends Composer<_$AppDatabase, $ContinentsTable> {
  $$ContinentsTableFilterComposer({
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

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> continentMilestonesRefs(
    Expression<bool> Function($$ContinentMilestonesTableFilterComposer f) f,
  ) {
    final $$ContinentMilestonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.continentMilestones,
      getReferencedColumn: (t) => t.continentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContinentMilestonesTableFilterComposer(
            $db: $db,
            $table: $db.continentMilestones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContinentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContinentsTable> {
  $$ContinentsTableOrderingComposer({
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

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContinentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContinentsTable> {
  $$ContinentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  Expression<T> continentMilestonesRefs<T extends Object>(
    Expression<T> Function($$ContinentMilestonesTableAnnotationComposer a) f,
  ) {
    final $$ContinentMilestonesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.continentMilestones,
          getReferencedColumn: (t) => t.continentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ContinentMilestonesTableAnnotationComposer(
                $db: $db,
                $table: $db.continentMilestones,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ContinentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContinentsTable,
          ContinentRow,
          $$ContinentsTableFilterComposer,
          $$ContinentsTableOrderingComposer,
          $$ContinentsTableAnnotationComposer,
          $$ContinentsTableCreateCompanionBuilder,
          $$ContinentsTableUpdateCompanionBuilder,
          (ContinentRow, $$ContinentsTableReferences),
          ContinentRow,
          PrefetchHooks Function({bool continentMilestonesRefs})
        > {
  $$ContinentsTableTableManager(_$AppDatabase db, $ContinentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContinentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContinentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContinentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContinentsCompanion(
                id: id,
                unlocked: unlocked,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required bool unlocked,
                required bool completed,
                Value<int> rowid = const Value.absent(),
              }) => ContinentsCompanion.insert(
                id: id,
                unlocked: unlocked,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContinentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({continentMilestonesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (continentMilestonesRefs) db.continentMilestones,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (continentMilestonesRefs)
                    await $_getPrefetchedData<
                      ContinentRow,
                      $ContinentsTable,
                      ContinentMilestoneRow
                    >(
                      currentTable: table,
                      referencedTable: $$ContinentsTableReferences
                          ._continentMilestonesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ContinentsTableReferences(
                            db,
                            table,
                            p0,
                          ).continentMilestonesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.continentId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ContinentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContinentsTable,
      ContinentRow,
      $$ContinentsTableFilterComposer,
      $$ContinentsTableOrderingComposer,
      $$ContinentsTableAnnotationComposer,
      $$ContinentsTableCreateCompanionBuilder,
      $$ContinentsTableUpdateCompanionBuilder,
      (ContinentRow, $$ContinentsTableReferences),
      ContinentRow,
      PrefetchHooks Function({bool continentMilestonesRefs})
    >;
typedef $$ContinentMilestonesTableCreateCompanionBuilder =
    ContinentMilestonesCompanion Function({
      required String continentId,
      required int milestone,
      Value<int> rowid,
    });
typedef $$ContinentMilestonesTableUpdateCompanionBuilder =
    ContinentMilestonesCompanion Function({
      Value<String> continentId,
      Value<int> milestone,
      Value<int> rowid,
    });

final class $$ContinentMilestonesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ContinentMilestonesTable,
          ContinentMilestoneRow
        > {
  $$ContinentMilestonesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ContinentsTable _continentIdTable(_$AppDatabase db) =>
      db.continents.createAlias(
        $_aliasNameGenerator(
          db.continentMilestones.continentId,
          db.continents.id,
        ),
      );

  $$ContinentsTableProcessedTableManager get continentId {
    final $_column = $_itemColumn<String>('continent_id')!;

    final manager = $$ContinentsTableTableManager(
      $_db,
      $_db.continents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_continentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContinentMilestonesTableFilterComposer
    extends Composer<_$AppDatabase, $ContinentMilestonesTable> {
  $$ContinentMilestonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get milestone => $composableBuilder(
    column: $table.milestone,
    builder: (column) => ColumnFilters(column),
  );

  $$ContinentsTableFilterComposer get continentId {
    final $$ContinentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.continentId,
      referencedTable: $db.continents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContinentsTableFilterComposer(
            $db: $db,
            $table: $db.continents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContinentMilestonesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContinentMilestonesTable> {
  $$ContinentMilestonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get milestone => $composableBuilder(
    column: $table.milestone,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContinentsTableOrderingComposer get continentId {
    final $$ContinentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.continentId,
      referencedTable: $db.continents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContinentsTableOrderingComposer(
            $db: $db,
            $table: $db.continents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContinentMilestonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContinentMilestonesTable> {
  $$ContinentMilestonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get milestone =>
      $composableBuilder(column: $table.milestone, builder: (column) => column);

  $$ContinentsTableAnnotationComposer get continentId {
    final $$ContinentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.continentId,
      referencedTable: $db.continents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContinentsTableAnnotationComposer(
            $db: $db,
            $table: $db.continents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContinentMilestonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContinentMilestonesTable,
          ContinentMilestoneRow,
          $$ContinentMilestonesTableFilterComposer,
          $$ContinentMilestonesTableOrderingComposer,
          $$ContinentMilestonesTableAnnotationComposer,
          $$ContinentMilestonesTableCreateCompanionBuilder,
          $$ContinentMilestonesTableUpdateCompanionBuilder,
          (ContinentMilestoneRow, $$ContinentMilestonesTableReferences),
          ContinentMilestoneRow,
          PrefetchHooks Function({bool continentId})
        > {
  $$ContinentMilestonesTableTableManager(
    _$AppDatabase db,
    $ContinentMilestonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContinentMilestonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContinentMilestonesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContinentMilestonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> continentId = const Value.absent(),
                Value<int> milestone = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContinentMilestonesCompanion(
                continentId: continentId,
                milestone: milestone,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String continentId,
                required int milestone,
                Value<int> rowid = const Value.absent(),
              }) => ContinentMilestonesCompanion.insert(
                continentId: continentId,
                milestone: milestone,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContinentMilestonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({continentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (continentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.continentId,
                                referencedTable:
                                    $$ContinentMilestonesTableReferences
                                        ._continentIdTable(db),
                                referencedColumn:
                                    $$ContinentMilestonesTableReferences
                                        ._continentIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ContinentMilestonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContinentMilestonesTable,
      ContinentMilestoneRow,
      $$ContinentMilestonesTableFilterComposer,
      $$ContinentMilestonesTableOrderingComposer,
      $$ContinentMilestonesTableAnnotationComposer,
      $$ContinentMilestonesTableCreateCompanionBuilder,
      $$ContinentMilestonesTableUpdateCompanionBuilder,
      (ContinentMilestoneRow, $$ContinentMilestonesTableReferences),
      ContinentMilestoneRow,
      PrefetchHooks Function({bool continentId})
    >;
typedef $$CountriesTableCreateCompanionBuilder =
    CountriesCompanion Function({
      required String id,
      required bool unlocked,
      required int ipLevel,
      required String leaderTier,
      required Decimal bankedInfluence,
      Value<DateTime?> lastCollectedAt,
      Value<int> rowid,
    });
typedef $$CountriesTableUpdateCompanionBuilder =
    CountriesCompanion Function({
      Value<String> id,
      Value<bool> unlocked,
      Value<int> ipLevel,
      Value<String> leaderTier,
      Value<Decimal> bankedInfluence,
      Value<DateTime?> lastCollectedAt,
      Value<int> rowid,
    });

class $$CountriesTableFilterComposer
    extends Composer<_$AppDatabase, $CountriesTable> {
  $$CountriesTableFilterComposer({
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

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ipLevel => $composableBuilder(
    column: $table.ipLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaderTier => $composableBuilder(
    column: $table.leaderTier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get bankedInfluence => $composableBuilder(
    column: $table.bankedInfluence,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get lastCollectedAt => $composableBuilder(
    column: $table.lastCollectedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CountriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CountriesTable> {
  $$CountriesTableOrderingComposer({
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

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ipLevel => $composableBuilder(
    column: $table.ipLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaderTier => $composableBuilder(
    column: $table.leaderTier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bankedInfluence => $composableBuilder(
    column: $table.bankedInfluence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCollectedAt => $composableBuilder(
    column: $table.lastCollectedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CountriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CountriesTable> {
  $$CountriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<int> get ipLevel =>
      $composableBuilder(column: $table.ipLevel, builder: (column) => column);

  GeneratedColumn<String> get leaderTier => $composableBuilder(
    column: $table.leaderTier,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get bankedInfluence =>
      $composableBuilder(
        column: $table.bankedInfluence,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get lastCollectedAt => $composableBuilder(
    column: $table.lastCollectedAt,
    builder: (column) => column,
  );
}

class $$CountriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CountriesTable,
          CountryRow,
          $$CountriesTableFilterComposer,
          $$CountriesTableOrderingComposer,
          $$CountriesTableAnnotationComposer,
          $$CountriesTableCreateCompanionBuilder,
          $$CountriesTableUpdateCompanionBuilder,
          (
            CountryRow,
            BaseReferences<_$AppDatabase, $CountriesTable, CountryRow>,
          ),
          CountryRow,
          PrefetchHooks Function()
        > {
  $$CountriesTableTableManager(_$AppDatabase db, $CountriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CountriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CountriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CountriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> ipLevel = const Value.absent(),
                Value<String> leaderTier = const Value.absent(),
                Value<Decimal> bankedInfluence = const Value.absent(),
                Value<DateTime?> lastCollectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountriesCompanion(
                id: id,
                unlocked: unlocked,
                ipLevel: ipLevel,
                leaderTier: leaderTier,
                bankedInfluence: bankedInfluence,
                lastCollectedAt: lastCollectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required bool unlocked,
                required int ipLevel,
                required String leaderTier,
                required Decimal bankedInfluence,
                Value<DateTime?> lastCollectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CountriesCompanion.insert(
                id: id,
                unlocked: unlocked,
                ipLevel: ipLevel,
                leaderTier: leaderTier,
                bankedInfluence: bankedInfluence,
                lastCollectedAt: lastCollectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CountriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CountriesTable,
      CountryRow,
      $$CountriesTableFilterComposer,
      $$CountriesTableOrderingComposer,
      $$CountriesTableAnnotationComposer,
      $$CountriesTableCreateCompanionBuilder,
      $$CountriesTableUpdateCompanionBuilder,
      (CountryRow, BaseReferences<_$AppDatabase, $CountriesTable, CountryRow>),
      CountryRow,
      PrefetchHooks Function()
    >;
typedef $$CrashLogsTableCreateCompanionBuilder =
    CrashLogsCompanion Function({
      Value<int> id,
      required DateTime timestamp,
      required CrashLogLevel level,
      required String tag,
      required String message,
      Value<String?> stackTrace,
    });
typedef $$CrashLogsTableUpdateCompanionBuilder =
    CrashLogsCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<CrashLogLevel> level,
      Value<String> tag,
      Value<String> message,
      Value<String?> stackTrace,
    });

class $$CrashLogsTableFilterComposer
    extends Composer<_$AppDatabase, $CrashLogsTable> {
  $$CrashLogsTableFilterComposer({
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

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CrashLogLevel, CrashLogLevel, String>
  get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CrashLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $CrashLogsTable> {
  $$CrashLogsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CrashLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CrashLogsTable> {
  $$CrashLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CrashLogLevel, String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => column,
  );
}

class $$CrashLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CrashLogsTable,
          CrashLogRow,
          $$CrashLogsTableFilterComposer,
          $$CrashLogsTableOrderingComposer,
          $$CrashLogsTableAnnotationComposer,
          $$CrashLogsTableCreateCompanionBuilder,
          $$CrashLogsTableUpdateCompanionBuilder,
          (
            CrashLogRow,
            BaseReferences<_$AppDatabase, $CrashLogsTable, CrashLogRow>,
          ),
          CrashLogRow,
          PrefetchHooks Function()
        > {
  $$CrashLogsTableTableManager(_$AppDatabase db, $CrashLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CrashLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CrashLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CrashLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<CrashLogLevel> level = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String?> stackTrace = const Value.absent(),
              }) => CrashLogsCompanion(
                id: id,
                timestamp: timestamp,
                level: level,
                tag: tag,
                message: message,
                stackTrace: stackTrace,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime timestamp,
                required CrashLogLevel level,
                required String tag,
                required String message,
                Value<String?> stackTrace = const Value.absent(),
              }) => CrashLogsCompanion.insert(
                id: id,
                timestamp: timestamp,
                level: level,
                tag: tag,
                message: message,
                stackTrace: stackTrace,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CrashLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CrashLogsTable,
      CrashLogRow,
      $$CrashLogsTableFilterComposer,
      $$CrashLogsTableOrderingComposer,
      $$CrashLogsTableAnnotationComposer,
      $$CrashLogsTableCreateCompanionBuilder,
      $$CrashLogsTableUpdateCompanionBuilder,
      (
        CrashLogRow,
        BaseReferences<_$AppDatabase, $CrashLogsTable, CrashLogRow>,
      ),
      CrashLogRow,
      PrefetchHooks Function()
    >;
typedef $$DailyStreaksTableCreateCompanionBuilder =
    DailyStreaksCompanion Function({
      Value<int> singletonId,
      required int day,
      Value<DateTime?> lastClaimDate,
    });
typedef $$DailyStreaksTableUpdateCompanionBuilder =
    DailyStreaksCompanion Function({
      Value<int> singletonId,
      Value<int> day,
      Value<DateTime?> lastClaimDate,
    });

class $$DailyStreaksTableFilterComposer
    extends Composer<_$AppDatabase, $DailyStreaksTable> {
  $$DailyStreaksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastClaimDate => $composableBuilder(
    column: $table.lastClaimDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyStreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyStreaksTable> {
  $$DailyStreaksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastClaimDate => $composableBuilder(
    column: $table.lastClaimDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyStreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyStreaksTable> {
  $$DailyStreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<DateTime> get lastClaimDate => $composableBuilder(
    column: $table.lastClaimDate,
    builder: (column) => column,
  );
}

class $$DailyStreaksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStreaksTable,
          DailyStreakRow,
          $$DailyStreaksTableFilterComposer,
          $$DailyStreaksTableOrderingComposer,
          $$DailyStreaksTableAnnotationComposer,
          $$DailyStreaksTableCreateCompanionBuilder,
          $$DailyStreaksTableUpdateCompanionBuilder,
          (
            DailyStreakRow,
            BaseReferences<_$AppDatabase, $DailyStreaksTable, DailyStreakRow>,
          ),
          DailyStreakRow,
          PrefetchHooks Function()
        > {
  $$DailyStreaksTableTableManager(_$AppDatabase db, $DailyStreaksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyStreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyStreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyStreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<DateTime?> lastClaimDate = const Value.absent(),
              }) => DailyStreaksCompanion(
                singletonId: singletonId,
                day: day,
                lastClaimDate: lastClaimDate,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                required int day,
                Value<DateTime?> lastClaimDate = const Value.absent(),
              }) => DailyStreaksCompanion.insert(
                singletonId: singletonId,
                day: day,
                lastClaimDate: lastClaimDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStreaksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStreaksTable,
      DailyStreakRow,
      $$DailyStreaksTableFilterComposer,
      $$DailyStreaksTableOrderingComposer,
      $$DailyStreaksTableAnnotationComposer,
      $$DailyStreaksTableCreateCompanionBuilder,
      $$DailyStreaksTableUpdateCompanionBuilder,
      (
        DailyStreakRow,
        BaseReferences<_$AppDatabase, $DailyStreaksTable, DailyStreakRow>,
      ),
      DailyStreakRow,
      PrefetchHooks Function()
    >;
typedef $$EarnedAchievementsTableCreateCompanionBuilder =
    EarnedAchievementsCompanion Function({
      required String id,
      Value<int> rowid,
    });
typedef $$EarnedAchievementsTableUpdateCompanionBuilder =
    EarnedAchievementsCompanion Function({Value<String> id, Value<int> rowid});

class $$EarnedAchievementsTableFilterComposer
    extends Composer<_$AppDatabase, $EarnedAchievementsTable> {
  $$EarnedAchievementsTableFilterComposer({
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
}

class $$EarnedAchievementsTableOrderingComposer
    extends Composer<_$AppDatabase, $EarnedAchievementsTable> {
  $$EarnedAchievementsTableOrderingComposer({
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
}

class $$EarnedAchievementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EarnedAchievementsTable> {
  $$EarnedAchievementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$EarnedAchievementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EarnedAchievementsTable,
          EarnedAchievementRow,
          $$EarnedAchievementsTableFilterComposer,
          $$EarnedAchievementsTableOrderingComposer,
          $$EarnedAchievementsTableAnnotationComposer,
          $$EarnedAchievementsTableCreateCompanionBuilder,
          $$EarnedAchievementsTableUpdateCompanionBuilder,
          (
            EarnedAchievementRow,
            BaseReferences<
              _$AppDatabase,
              $EarnedAchievementsTable,
              EarnedAchievementRow
            >,
          ),
          EarnedAchievementRow,
          PrefetchHooks Function()
        > {
  $$EarnedAchievementsTableTableManager(
    _$AppDatabase db,
    $EarnedAchievementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EarnedAchievementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EarnedAchievementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EarnedAchievementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EarnedAchievementsCompanion(id: id, rowid: rowid),
          createCompanionCallback:
              ({required String id, Value<int> rowid = const Value.absent()}) =>
                  EarnedAchievementsCompanion.insert(id: id, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EarnedAchievementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EarnedAchievementsTable,
      EarnedAchievementRow,
      $$EarnedAchievementsTableFilterComposer,
      $$EarnedAchievementsTableOrderingComposer,
      $$EarnedAchievementsTableAnnotationComposer,
      $$EarnedAchievementsTableCreateCompanionBuilder,
      $$EarnedAchievementsTableUpdateCompanionBuilder,
      (
        EarnedAchievementRow,
        BaseReferences<
          _$AppDatabase,
          $EarnedAchievementsTable,
          EarnedAchievementRow
        >,
      ),
      EarnedAchievementRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      Value<int> singletonId,
      required int schemaVersion,
      required DateTime lastSavedAt,
      required Decimal totalInfluence,
      required Decimal totalIntel,
      required Decimal goldenOpportunityMultiplier,
      required Decimal boostMultiplier,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<int> singletonId,
      Value<int> schemaVersion,
      Value<DateTime> lastSavedAt,
      Value<Decimal> totalInfluence,
      Value<Decimal> totalIntel,
      Value<Decimal> goldenOpportunityMultiplier,
      Value<Decimal> boostMultiplier,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get totalInfluence =>
      $composableBuilder(
        column: $table.totalInfluence,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String> get totalIntel =>
      $composableBuilder(
        column: $table.totalIntel,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get goldenOpportunityMultiplier => $composableBuilder(
    column: $table.goldenOpportunityMultiplier,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Decimal, Decimal, String>
  get boostMultiplier => $composableBuilder(
    column: $table.boostMultiplier,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalInfluence => $composableBuilder(
    column: $table.totalInfluence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalIntel => $composableBuilder(
    column: $table.totalIntel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldenOpportunityMultiplier => $composableBuilder(
    column: $table.goldenOpportunityMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get boostMultiplier => $composableBuilder(
    column: $table.boostMultiplier,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get singletonId => $composableBuilder(
    column: $table.singletonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get totalInfluence =>
      $composableBuilder(
        column: $table.totalInfluence,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String> get totalIntel =>
      $composableBuilder(
        column: $table.totalIntel,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<Decimal, String>
  get goldenOpportunityMultiplier => $composableBuilder(
    column: $table.goldenOpportunityMultiplier,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Decimal, String> get boostMultiplier =>
      $composableBuilder(
        column: $table.boostMultiplier,
        builder: (column) => column,
      );
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<DateTime> lastSavedAt = const Value.absent(),
                Value<Decimal> totalInfluence = const Value.absent(),
                Value<Decimal> totalIntel = const Value.absent(),
                Value<Decimal> goldenOpportunityMultiplier =
                    const Value.absent(),
                Value<Decimal> boostMultiplier = const Value.absent(),
              }) => MetaCompanion(
                singletonId: singletonId,
                schemaVersion: schemaVersion,
                lastSavedAt: lastSavedAt,
                totalInfluence: totalInfluence,
                totalIntel: totalIntel,
                goldenOpportunityMultiplier: goldenOpportunityMultiplier,
                boostMultiplier: boostMultiplier,
              ),
          createCompanionCallback:
              ({
                Value<int> singletonId = const Value.absent(),
                required int schemaVersion,
                required DateTime lastSavedAt,
                required Decimal totalInfluence,
                required Decimal totalIntel,
                required Decimal goldenOpportunityMultiplier,
                required Decimal boostMultiplier,
              }) => MetaCompanion.insert(
                singletonId: singletonId,
                schemaVersion: schemaVersion,
                lastSavedAt: lastSavedAt,
                totalInfluence: totalInfluence,
                totalIntel: totalIntel,
                goldenOpportunityMultiplier: goldenOpportunityMultiplier,
                boostMultiplier: boostMultiplier,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ActiveBoostTableTableManager get activeBoost =>
      $$ActiveBoostTableTableManager(_db, _db.activeBoost);
  $$ActiveGlobalUpgradesTableTableManager get activeGlobalUpgrades =>
      $$ActiveGlobalUpgradesTableTableManager(_db, _db.activeGlobalUpgrades);
  $$ActiveGoldenEffectTableTableManager get activeGoldenEffect =>
      $$ActiveGoldenEffectTableTableManager(_db, _db.activeGoldenEffect);
  $$ActiveGoldensTableTableManager get activeGoldens =>
      $$ActiveGoldensTableTableManager(_db, _db.activeGoldens);
  $$ActiveMissionsTableTableManager get activeMissions =>
      $$ActiveMissionsTableTableManager(_db, _db.activeMissions);
  $$CompletedMissionsTableTableManager get completedMissions =>
      $$CompletedMissionsTableTableManager(_db, _db.completedMissions);
  $$ContinentsTableTableManager get continents =>
      $$ContinentsTableTableManager(_db, _db.continents);
  $$ContinentMilestonesTableTableManager get continentMilestones =>
      $$ContinentMilestonesTableTableManager(_db, _db.continentMilestones);
  $$CountriesTableTableManager get countries =>
      $$CountriesTableTableManager(_db, _db.countries);
  $$CrashLogsTableTableManager get crashLogs =>
      $$CrashLogsTableTableManager(_db, _db.crashLogs);
  $$DailyStreaksTableTableManager get dailyStreaks =>
      $$DailyStreaksTableTableManager(_db, _db.dailyStreaks);
  $$EarnedAchievementsTableTableManager get earnedAchievements =>
      $$EarnedAchievementsTableTableManager(_db, _db.earnedAchievements);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
