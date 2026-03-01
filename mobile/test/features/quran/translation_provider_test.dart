import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/features/quran/translation_provider.dart';

void main() {
  group('TranslationData', () {
    test('constructs with words and translations', () {
      final data = TranslationData(
        verseKey: '1:1',
        words: [
          WordTranslation(
            arabic: 'بِسْمِ',
            translation: 'In (the) name',
            transliteration: "bis'mi",
          ),
        ],
        translations: [
          VerseTranslation(
            resourceId: 20,
            resourceName: 'Saheeh International',
            text: 'In the name of Allah, the Entirely Merciful, the Especially Merciful.',
          ),
        ],
      );

      expect(data.verseKey, '1:1');
      expect(data.words.length, 1);
      expect(data.words.first.arabic, 'بِسْمِ');
      expect(data.words.first.translation, 'In (the) name');
      expect(data.translations.length, 1);
      expect(data.translations.first.resourceId, 20);
    });
  });

  group('TranslationResource', () {
    test('constructs from fields', () {
      final r = TranslationResource(
        id: 20,
        name: 'Saheeh International',
        authorName: 'Saheeh International',
        languageName: 'english',
      );
      expect(r.id, 20);
      expect(r.languageName, 'english');
    });
  });

  group('stripHtmlTags', () {
    test('removes HTML from translation text', () {
      expect(
        TranslationNotifier.stripHtmlTags('In the name of Allah<sup foot_note="1">1</sup>'),
        'In the name of Allah1',
      );
    });

    test('returns plain text unchanged', () {
      expect(
        TranslationNotifier.stripHtmlTags('In the name of Allah'),
        'In the name of Allah',
      );
    });
  });
}
