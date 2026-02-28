import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/features/home/home_screen.dart';
import 'package:memorizer/features/schedule/schedule_provider.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildApp({List<TodayPool> pools = const []}) {
    return ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        scheduleProvider.overrideWith(() {
          return _FakeScheduleNotifier(pools);
        }),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  group('HomeScreen', () {
    testWidgets('shows greeting', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      // One of the greetings should appear
      final hasGreeting = find.textContaining('Good morning').evaluate().isNotEmpty ||
          find.textContaining('Good afternoon').evaluate().isNotEmpty ||
          find.textContaining('Good evening').evaluate().isNotEmpty;
      expect(hasGreeting, isTrue);
    });

    testWidgets('shows progress card with no assignments', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('No assignments today'), findsOneWidget);
    });

    testWidgets('shows empty banner when no schedule', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      expect(find.text('No schedule yet'), findsOneWidget);
    });

    testWidgets('shows pool summaries and continue button', (tester) async {
      final pools = [
        TodayPool(
          poolId: 1,
          poolName: 'Daily',
          dayNumber: 5,
          totalDays: 30,
          items: [
            ScheduleItem(
              id: 1,
              surahNumber: 36,
              surahName: 'Ya-Sin',
              arabic: 'يس',
              startPage: 440,
              endPage: 445,
              pages: 5,
              status: 'pending',
            ),
            ScheduleItem(
              id: 2,
              surahNumber: 67,
              surahName: 'Al-Mulk',
              arabic: 'الملك',
              startPage: 562,
              endPage: 564,
              pages: 2,
              status: 'done',
              quality: 15,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(buildApp(pools: pools));
      await tester.pump();

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('1 of 2 assignments done'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Continue Reciting'), findsOneWidget);
    });

    testWidgets('shows completed banner when all done', (tester) async {
      final pools = [
        TodayPool(
          poolId: 1,
          poolName: 'Daily',
          dayNumber: 5,
          totalDays: 30,
          items: [
            ScheduleItem(
              id: 1,
              surahNumber: 36,
              surahName: 'Ya-Sin',
              arabic: 'يس',
              startPage: 440,
              endPage: 445,
              pages: 5,
              status: 'done',
              quality: 18,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(buildApp(pools: pools));
      await tester.pump();

      expect(find.text('All done for today!'), findsOneWidget);
      expect(find.text('Continue Reciting'), findsNothing);
    });
  });
}

class _FakeScheduleNotifier extends ScheduleNotifier {
  _FakeScheduleNotifier(this._pools);
  final List<TodayPool> _pools;

  @override
  TodayState build() => TodayState(pools: _pools);

  @override
  Future<void> loadToday({String? date}) async {}
}
