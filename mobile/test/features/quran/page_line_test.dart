import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/features/quran/page_line.dart';
import 'package:memorizer/features/quran/quran_provider.dart';

void main() {
  group('parseLines', () {
    test('returns text lines for simple page data', () {
      final ayahs = [
        {
          'k': '10:107',
          'j': 11,
          'w': [
            {'c': 'ﭑ', 'l': 1},
            {'c': 'ﭒ', 'l': 1},
            {'c': 'ﭓ', 'l': 2},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(2));
      expect(lines[0], isA<TextLine>());
      expect((lines[0] as TextLine).text, 'ﭑ ﭒ');
      expect((lines[1] as TextLine).text, 'ﭓ');
    });

    test('detects surah header and bismillah for standard surah', () {
      // Surah 11 starts at line 5, so line 3 = header, line 4 = bismillah.
      // Lines 1-2 have text from previous surah.
      final ayahs = [
        {
          'k': '10:109',
          'j': 11,
          'w': [
            {'c': 'ﭑ', 'l': 1},
            {'c': 'ﭒ', 'l': 2},
          ],
        },
        {
          'k': '11:1',
          'j': 12,
          'w': [
            {'c': 'ﭓ', 'l': 5},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(5));
      expect(lines[0], isA<TextLine>()); // line 1: text
      expect(lines[1], isA<TextLine>()); // line 2: text
      expect(lines[2], isA<HeaderLine>()); // line 3: header
      expect((lines[2] as HeaderLine).surahNumber, 11);
      expect(lines[3], isA<BismillahLine>()); // line 4: bismillah
      expect(lines[4], isA<TextLine>()); // line 5: text
    });

    test('detects header only for Al-Fatihah (no bismillah)', () {
      // Al-Fatihah: surah 1, text starts at line 3, line 2 = header.
      final ayahs = [
        {
          'k': '1:1',
          'j': 1,
          'w': [
            {'c': 'ﭑ', 'l': 3},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(2));
      expect(lines[0], isA<HeaderLine>());
      expect((lines[0] as HeaderLine).surahNumber, 1);
      // No BismillahLine for Al-Fatihah
      expect(lines.whereType<BismillahLine>(), isEmpty);
      expect(lines[1], isA<TextLine>());
    });

    test('detects header only for At-Tawbah (no bismillah)', () {
      // At-Tawbah: surah 9, text starts at line 4, line 3 = header.
      final ayahs = [
        {
          'k': '8:75',
          'j': 10,
          'w': [
            {'c': 'ﭑ', 'l': 1},
            {'c': 'ﭒ', 'l': 2},
          ],
        },
        {
          'k': '9:1',
          'j': 10,
          'w': [
            {'c': 'ﭓ', 'l': 4},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(4));
      expect(lines[0], isA<TextLine>()); // line 1
      expect(lines[1], isA<TextLine>()); // line 2
      expect(lines[2], isA<HeaderLine>()); // line 3 - header for surah 9
      expect((lines[2] as HeaderLine).surahNumber, 9);
      expect(lines.whereType<BismillahLine>(), isEmpty);
      expect(lines[3], isA<TextLine>()); // line 4
    });

    test('handles surah starting at line 2 (header but no room for bismillah)',
        () {
      // Surah text starts at line 2, only room for header at line 1.
      final ayahs = [
        {
          'k': '2:1',
          'j': 1,
          'w': [
            {'c': 'ﭑ', 'l': 2},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(2));
      expect(lines[0], isA<HeaderLine>());
      expect((lines[0] as HeaderLine).surahNumber, 2);
      // No room for bismillah
      expect(lines.whereType<BismillahLine>(), isEmpty);
      expect(lines[1], isA<TextLine>());
    });

    test('returns empty list for empty input', () {
      final lines = QuranNotifier.parseLines([]);
      expect(lines, isEmpty);
    });

    test('handles page with no surah starts (middle of a surah)', () {
      final ayahs = [
        {
          'k': '2:10',
          'j': 1,
          'w': [
            {'c': 'ﭑ', 'l': 1},
            {'c': 'ﭒ', 'l': 2},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      expect(lines, hasLength(2));
      expect(lines.every((l) => l is TextLine), isTrue);
    });

    test('handles two surahs starting on the same page', () {
      // End of surah 112, surah 113 header+bismillah, surah 113 text,
      // then surah 114 header+bismillah+text.
      final ayahs = [
        {
          'k': '112:4',
          'j': 30,
          'w': [
            {'c': 'ﭑ', 'l': 1},
          ],
        },
        {
          'k': '113:1',
          'j': 30,
          'w': [
            {'c': 'ﭓ', 'l': 4},
          ],
        },
        {
          'k': '114:1',
          'j': 30,
          'w': [
            {'c': 'ﭔ', 'l': 8},
          ],
        },
      ];

      final lines = QuranNotifier.parseLines(ayahs);
      // line 1: text, line 2: header 113, line 3: bismillah,
      // line 4: text, lines 5-7 empty (skipped), line 6: header 114,
      // line 7: bismillah, line 8: text
      final headers = lines.whereType<HeaderLine>().toList();
      expect(headers, hasLength(2));
      expect(headers[0].surahNumber, 113);
      expect(headers[1].surahNumber, 114);

      final bismillahs = lines.whereType<BismillahLine>().toList();
      expect(bismillahs, hasLength(2));
    });
  });

  group('PageLine equality', () {
    test('TextLine equality', () {
      expect(const TextLine('abc'), equals(const TextLine('abc')));
      expect(const TextLine('abc'), isNot(equals(const TextLine('xyz'))));
    });

    test('HeaderLine equality', () {
      expect(const HeaderLine(1), equals(const HeaderLine(1)));
      expect(const HeaderLine(1), isNot(equals(const HeaderLine(2))));
    });

    test('BismillahLine equality', () {
      expect(const BismillahLine(), equals(const BismillahLine()));
    });
  });
}
