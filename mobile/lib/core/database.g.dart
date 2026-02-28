// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecitationCacheTable extends RecitationCache
    with TableInfo<$RecitationCacheTable, RecitationCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecitationCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _surahNumberMeta = const VerificationMeta(
    'surahNumber',
  );
  @override
  late final GeneratedColumn<int> surahNumber = GeneratedColumn<int>(
    'surah_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startPageMeta = const VerificationMeta(
    'startPage',
  );
  @override
  late final GeneratedColumn<double> startPage = GeneratedColumn<double>(
    'start_page',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endPageMeta = const VerificationMeta(
    'endPage',
  );
  @override
  late final GeneratedColumn<double> endPage = GeneratedColumn<double>(
    'end_page',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recitedAtMeta = const VerificationMeta(
    'recitedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recitedAt = GeneratedColumn<DateTime>(
    'recited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surahNumber,
    startPage,
    endPage,
    quality,
    recitedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recitation_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecitationCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('surah_number')) {
      context.handle(
        _surahNumberMeta,
        surahNumber.isAcceptableOrUnknown(
          data['surah_number']!,
          _surahNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_surahNumberMeta);
    }
    if (data.containsKey('start_page')) {
      context.handle(
        _startPageMeta,
        startPage.isAcceptableOrUnknown(data['start_page']!, _startPageMeta),
      );
    } else if (isInserting) {
      context.missing(_startPageMeta);
    }
    if (data.containsKey('end_page')) {
      context.handle(
        _endPageMeta,
        endPage.isAcceptableOrUnknown(data['end_page']!, _endPageMeta),
      );
    } else if (isInserting) {
      context.missing(_endPageMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('recited_at')) {
      context.handle(
        _recitedAtMeta,
        recitedAt.isAcceptableOrUnknown(data['recited_at']!, _recitedAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecitationCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecitationCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      surahNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}surah_number'],
      )!,
      startPage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_page'],
      )!,
      endPage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}end_page'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      )!,
      recitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recited_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $RecitationCacheTable createAlias(String alias) {
    return $RecitationCacheTable(attachedDatabase, alias);
  }
}

class RecitationCacheData extends DataClass
    implements Insertable<RecitationCacheData> {
  final int id;
  final int surahNumber;
  final double startPage;
  final double endPage;
  final int quality;
  final DateTime recitedAt;
  final bool synced;
  const RecitationCacheData({
    required this.id,
    required this.surahNumber,
    required this.startPage,
    required this.endPage,
    required this.quality,
    required this.recitedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['surah_number'] = Variable<int>(surahNumber);
    map['start_page'] = Variable<double>(startPage);
    map['end_page'] = Variable<double>(endPage);
    map['quality'] = Variable<int>(quality);
    map['recited_at'] = Variable<DateTime>(recitedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  RecitationCacheCompanion toCompanion(bool nullToAbsent) {
    return RecitationCacheCompanion(
      id: Value(id),
      surahNumber: Value(surahNumber),
      startPage: Value(startPage),
      endPage: Value(endPage),
      quality: Value(quality),
      recitedAt: Value(recitedAt),
      synced: Value(synced),
    );
  }

  factory RecitationCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecitationCacheData(
      id: serializer.fromJson<int>(json['id']),
      surahNumber: serializer.fromJson<int>(json['surahNumber']),
      startPage: serializer.fromJson<double>(json['startPage']),
      endPage: serializer.fromJson<double>(json['endPage']),
      quality: serializer.fromJson<int>(json['quality']),
      recitedAt: serializer.fromJson<DateTime>(json['recitedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'surahNumber': serializer.toJson<int>(surahNumber),
      'startPage': serializer.toJson<double>(startPage),
      'endPage': serializer.toJson<double>(endPage),
      'quality': serializer.toJson<int>(quality),
      'recitedAt': serializer.toJson<DateTime>(recitedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  RecitationCacheData copyWith({
    int? id,
    int? surahNumber,
    double? startPage,
    double? endPage,
    int? quality,
    DateTime? recitedAt,
    bool? synced,
  }) => RecitationCacheData(
    id: id ?? this.id,
    surahNumber: surahNumber ?? this.surahNumber,
    startPage: startPage ?? this.startPage,
    endPage: endPage ?? this.endPage,
    quality: quality ?? this.quality,
    recitedAt: recitedAt ?? this.recitedAt,
    synced: synced ?? this.synced,
  );
  RecitationCacheData copyWithCompanion(RecitationCacheCompanion data) {
    return RecitationCacheData(
      id: data.id.present ? data.id.value : this.id,
      surahNumber: data.surahNumber.present
          ? data.surahNumber.value
          : this.surahNumber,
      startPage: data.startPage.present ? data.startPage.value : this.startPage,
      endPage: data.endPage.present ? data.endPage.value : this.endPage,
      quality: data.quality.present ? data.quality.value : this.quality,
      recitedAt: data.recitedAt.present ? data.recitedAt.value : this.recitedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecitationCacheData(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('startPage: $startPage, ')
          ..write('endPage: $endPage, ')
          ..write('quality: $quality, ')
          ..write('recitedAt: $recitedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surahNumber,
    startPage,
    endPage,
    quality,
    recitedAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecitationCacheData &&
          other.id == this.id &&
          other.surahNumber == this.surahNumber &&
          other.startPage == this.startPage &&
          other.endPage == this.endPage &&
          other.quality == this.quality &&
          other.recitedAt == this.recitedAt &&
          other.synced == this.synced);
}

class RecitationCacheCompanion extends UpdateCompanion<RecitationCacheData> {
  final Value<int> id;
  final Value<int> surahNumber;
  final Value<double> startPage;
  final Value<double> endPage;
  final Value<int> quality;
  final Value<DateTime> recitedAt;
  final Value<bool> synced;
  const RecitationCacheCompanion({
    this.id = const Value.absent(),
    this.surahNumber = const Value.absent(),
    this.startPage = const Value.absent(),
    this.endPage = const Value.absent(),
    this.quality = const Value.absent(),
    this.recitedAt = const Value.absent(),
    this.synced = const Value.absent(),
  });
  RecitationCacheCompanion.insert({
    this.id = const Value.absent(),
    required int surahNumber,
    required double startPage,
    required double endPage,
    required int quality,
    this.recitedAt = const Value.absent(),
    this.synced = const Value.absent(),
  }) : surahNumber = Value(surahNumber),
       startPage = Value(startPage),
       endPage = Value(endPage),
       quality = Value(quality);
  static Insertable<RecitationCacheData> custom({
    Expression<int>? id,
    Expression<int>? surahNumber,
    Expression<double>? startPage,
    Expression<double>? endPage,
    Expression<int>? quality,
    Expression<DateTime>? recitedAt,
    Expression<bool>? synced,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surahNumber != null) 'surah_number': surahNumber,
      if (startPage != null) 'start_page': startPage,
      if (endPage != null) 'end_page': endPage,
      if (quality != null) 'quality': quality,
      if (recitedAt != null) 'recited_at': recitedAt,
      if (synced != null) 'synced': synced,
    });
  }

  RecitationCacheCompanion copyWith({
    Value<int>? id,
    Value<int>? surahNumber,
    Value<double>? startPage,
    Value<double>? endPage,
    Value<int>? quality,
    Value<DateTime>? recitedAt,
    Value<bool>? synced,
  }) {
    return RecitationCacheCompanion(
      id: id ?? this.id,
      surahNumber: surahNumber ?? this.surahNumber,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      quality: quality ?? this.quality,
      recitedAt: recitedAt ?? this.recitedAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (surahNumber.present) {
      map['surah_number'] = Variable<int>(surahNumber.value);
    }
    if (startPage.present) {
      map['start_page'] = Variable<double>(startPage.value);
    }
    if (endPage.present) {
      map['end_page'] = Variable<double>(endPage.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (recitedAt.present) {
      map['recited_at'] = Variable<DateTime>(recitedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecitationCacheCompanion(')
          ..write('id: $id, ')
          ..write('surahNumber: $surahNumber, ')
          ..write('startPage: $startPage, ')
          ..write('endPage: $endPage, ')
          ..write('quality: $quality, ')
          ..write('recitedAt: $recitedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecitationCacheTable recitationCache = $RecitationCacheTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [recitationCache];
}

typedef $$RecitationCacheTableCreateCompanionBuilder =
    RecitationCacheCompanion Function({
      Value<int> id,
      required int surahNumber,
      required double startPage,
      required double endPage,
      required int quality,
      Value<DateTime> recitedAt,
      Value<bool> synced,
    });
typedef $$RecitationCacheTableUpdateCompanionBuilder =
    RecitationCacheCompanion Function({
      Value<int> id,
      Value<int> surahNumber,
      Value<double> startPage,
      Value<double> endPage,
      Value<int> quality,
      Value<DateTime> recitedAt,
      Value<bool> synced,
    });

class $$RecitationCacheTableFilterComposer
    extends Composer<_$AppDatabase, $RecitationCacheTable> {
  $$RecitationCacheTableFilterComposer({
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

  ColumnFilters<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startPage => $composableBuilder(
    column: $table.startPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endPage => $composableBuilder(
    column: $table.endPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recitedAt => $composableBuilder(
    column: $table.recitedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecitationCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $RecitationCacheTable> {
  $$RecitationCacheTableOrderingComposer({
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

  ColumnOrderings<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startPage => $composableBuilder(
    column: $table.startPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endPage => $composableBuilder(
    column: $table.endPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recitedAt => $composableBuilder(
    column: $table.recitedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecitationCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecitationCacheTable> {
  $$RecitationCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get surahNumber => $composableBuilder(
    column: $table.surahNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startPage =>
      $composableBuilder(column: $table.startPage, builder: (column) => column);

  GeneratedColumn<double> get endPage =>
      $composableBuilder(column: $table.endPage, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<DateTime> get recitedAt =>
      $composableBuilder(column: $table.recitedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$RecitationCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecitationCacheTable,
          RecitationCacheData,
          $$RecitationCacheTableFilterComposer,
          $$RecitationCacheTableOrderingComposer,
          $$RecitationCacheTableAnnotationComposer,
          $$RecitationCacheTableCreateCompanionBuilder,
          $$RecitationCacheTableUpdateCompanionBuilder,
          (
            RecitationCacheData,
            BaseReferences<
              _$AppDatabase,
              $RecitationCacheTable,
              RecitationCacheData
            >,
          ),
          RecitationCacheData,
          PrefetchHooks Function()
        > {
  $$RecitationCacheTableTableManager(
    _$AppDatabase db,
    $RecitationCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecitationCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecitationCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecitationCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> surahNumber = const Value.absent(),
                Value<double> startPage = const Value.absent(),
                Value<double> endPage = const Value.absent(),
                Value<int> quality = const Value.absent(),
                Value<DateTime> recitedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => RecitationCacheCompanion(
                id: id,
                surahNumber: surahNumber,
                startPage: startPage,
                endPage: endPage,
                quality: quality,
                recitedAt: recitedAt,
                synced: synced,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int surahNumber,
                required double startPage,
                required double endPage,
                required int quality,
                Value<DateTime> recitedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
              }) => RecitationCacheCompanion.insert(
                id: id,
                surahNumber: surahNumber,
                startPage: startPage,
                endPage: endPage,
                quality: quality,
                recitedAt: recitedAt,
                synced: synced,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecitationCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecitationCacheTable,
      RecitationCacheData,
      $$RecitationCacheTableFilterComposer,
      $$RecitationCacheTableOrderingComposer,
      $$RecitationCacheTableAnnotationComposer,
      $$RecitationCacheTableCreateCompanionBuilder,
      $$RecitationCacheTableUpdateCompanionBuilder,
      (
        RecitationCacheData,
        BaseReferences<
          _$AppDatabase,
          $RecitationCacheTable,
          RecitationCacheData
        >,
      ),
      RecitationCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecitationCacheTableTableManager get recitationCache =>
      $$RecitationCacheTableTableManager(_db, _db.recitationCache);
}
