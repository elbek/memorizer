import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/core/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase', () {
    test('inserts and retrieves a recitation entry', () async {
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 1,
        startPage: 1,
        endPage: 2,
        quality: 15,
      ));

      final entries = await db.getAllRecitations();
      expect(entries, hasLength(1));
      expect(entries.first.surahNumber, 1);
      expect(entries.first.startPage, 1.0);
      expect(entries.first.endPage, 2.0);
      expect(entries.first.quality, 15);
      expect(entries.first.synced, false);
    });

    test('getUnsynced returns only unsynced entries', () async {
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 1,
        startPage: 1,
        endPage: 2,
        quality: 10,
      ));
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 2,
        startPage: 5,
        endPage: 52,
        quality: 18,
      ));

      // Mark the first one as synced
      final all = await db.getAllRecitations();
      await db.markSynced([all.first.id]);

      final unsynced = await db.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.surahNumber, 2);
    });

    test('markSynced updates synced flag', () async {
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 36,
        startPage: 440,
        endPage: 445,
        quality: 20,
      ));

      final before = await db.getAllRecitations();
      expect(before.first.synced, false);

      await db.markSynced([before.first.id]);

      final after = await db.getAllRecitations();
      expect(after.first.synced, true);
    });

    test('clearAll removes all entries', () async {
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 1,
        startPage: 1,
        endPage: 2,
        quality: 10,
      ));
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 2,
        startPage: 5,
        endPage: 52,
        quality: 15,
      ));

      final deleted = await db.clearAll();
      expect(deleted, 2);

      final remaining = await db.getAllRecitations();
      expect(remaining, isEmpty);
    });

    test('multiple inserts assign unique IDs', () async {
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 1,
        startPage: 1,
        endPage: 1,
        quality: 5,
      ));
      await db.insertRecitation(RecitationCacheCompanion.insert(
        surahNumber: 2,
        startPage: 3,
        endPage: 50,
        quality: 10,
      ));

      final entries = await db.getAllRecitations();
      expect(entries, hasLength(2));
      expect(entries[0].id, isNot(entries[1].id));
    });
  });
}
