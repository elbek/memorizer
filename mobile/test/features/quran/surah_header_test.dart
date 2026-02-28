import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/features/quran/surah_header.dart';

void main() {
  group('SurahHeader', () {
    testWidgets('displays surah name and numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SurahHeader(surahNumber: 1)),
        ),
      );
      // Arabic name "سورة الفاتحة" contains الفاتحة
      expect(find.textContaining('\u0627\u0644\u0641\u0627\u062a\u062d\u0629'),
          findsOneWidget);
      // Surah number (Arabic numeral)
      expect(find.text('\u0661'), findsOneWidget); // ١
      // Ayah count (Arabic numeral)
      expect(find.text('\u0667'), findsOneWidget); // ٧
    });

    testWidgets('shows nothing for invalid surah number', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SurahHeader(surahNumber: 999)),
        ),
      );
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders Al-Baqarah correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SurahHeader(surahNumber: 2)),
        ),
      );
      expect(find.textContaining('\u0627\u0644\u0628\u0642\u0631\u0629'),
          findsOneWidget);
      expect(find.text('\u0662\u0668\u0666'), findsOneWidget); // ٢٨٦
      expect(find.text('\u0662'), findsOneWidget); // ٢
    });
  });
}
