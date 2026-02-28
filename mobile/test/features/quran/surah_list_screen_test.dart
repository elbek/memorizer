import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/features/quran/surah_list_screen.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

void main() {
  group('SurahListScreen', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildApp({List<int> recentSurahs = const []}) {
      if (recentSurahs.isNotEmpty) {
        prefs.setStringList(
            'recent_surahs', recentSurahs.map((e) => '$e').toList());
      }
      return ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: SurahListScreen()),
      );
    }

    testWidgets('shows all 114 surahs', (tester) async {
      await tester.pumpWidget(buildApp());
      // First surah
      expect(find.text('Al-Fatihah'), findsOneWidget);
      // Scroll to find a later surah
      expect(find.text('All Surahs'), findsOneWidget);
    });

    testWidgets('shows "Recent" section when recent surahs exist',
        (tester) async {
      await tester.pumpWidget(buildApp(recentSurahs: [36, 67]));
      expect(find.text('Recent'), findsOneWidget);
      // Both should appear in the horizontal list
      expect(find.text('يس'), findsWidgets); // Ya-Sin arabic
    });

    testWidgets('hides "Recent" section when no recent surahs',
        (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.text('Recent'), findsNothing);
    });

    testWidgets('shows surah details in list tiles', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.text('7 ayahs  •  Juz 1'), findsOneWidget); // Al-Fatihah
      expect(find.text('الفاتحة'), findsOneWidget);
    });
  });

  group('RecentSurahsNotifier', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() => container.dispose());

    test('initial state is empty', () {
      expect(container.read(recentSurahsProvider), isEmpty);
    });

    test('addRecent adds surah and persists', () async {
      await container.read(recentSurahsProvider.notifier).addRecent(36);
      expect(container.read(recentSurahsProvider), [36]);
      expect(prefs.getStringList('recent_surahs'), ['36']);
    });

    test('addRecent moves duplicate to front', () async {
      final notifier = container.read(recentSurahsProvider.notifier);
      await notifier.addRecent(36);
      await notifier.addRecent(67);
      await notifier.addRecent(36);
      expect(container.read(recentSurahsProvider), [36, 67]);
    });

    test('addRecent caps at 5 items', () async {
      final notifier = container.read(recentSurahsProvider.notifier);
      for (int i = 1; i <= 7; i++) {
        await notifier.addRecent(i);
      }
      final state = container.read(recentSurahsProvider);
      expect(state.length, 5);
      expect(state.first, 7); // Most recent first
    });

    test('loads from SharedPreferences', () async {
      await prefs.setStringList('recent_surahs', ['1', '2', '3']);
      final c2 = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      expect(c2.read(recentSurahsProvider), [1, 2, 3]);
      c2.dispose();
    });
  });
}
