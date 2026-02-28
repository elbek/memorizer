import 'package:drift/drift.dart';

part 'database.g.dart';

/// Local cache of recitation log entries for offline access.
class RecitationCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get surahNumber => integer()();
  RealColumn get startPage => real()();
  RealColumn get endPage => real()();
  IntColumn get quality => integer()();
  DateTimeColumn get recitedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [RecitationCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  /// Insert a recitation entry.
  Future<int> insertRecitation(RecitationCacheCompanion entry) =>
      into(recitationCache).insert(entry);

  /// Get all unsynced entries.
  Future<List<RecitationCacheData>> getUnsynced() =>
      (select(recitationCache)..where((t) => t.synced.equals(false))).get();

  /// Mark entries as synced.
  Future<void> markSynced(List<int> ids) async {
    await (update(recitationCache)..where((t) => t.id.isIn(ids)))
        .write(const RecitationCacheCompanion(synced: Value(true)));
  }

  /// Get all entries.
  Future<List<RecitationCacheData>> getAllRecitations() =>
      select(recitationCache).get();

  /// Delete all entries.
  Future<int> clearAll() => delete(recitationCache).go();
}
