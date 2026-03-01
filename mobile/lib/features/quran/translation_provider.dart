import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/quran/qdc_dio.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

class WordTranslation {
  const WordTranslation({
    required this.arabic,
    required this.translation,
    required this.transliteration,
  });
  final String arabic;
  final String translation;
  final String transliteration;
}

class VerseTranslation {
  const VerseTranslation({
    required this.resourceId,
    required this.resourceName,
    required this.text,
  });
  final int resourceId;
  final String resourceName;
  final String text;
}

class TranslationData {
  const TranslationData({
    required this.verseKey,
    required this.words,
    required this.translations,
  });
  final String verseKey;
  final List<WordTranslation> words;
  final List<VerseTranslation> translations;
}

class TranslationResource {
  const TranslationResource({
    required this.id,
    required this.name,
    required this.authorName,
    required this.languageName,
  });
  final int id;
  final String name;
  final String authorName;
  final String languageName;
}

class TranslationNotifier extends Notifier<AsyncValue<TranslationData?>> {
  final _dio = qdcDio;
  final _cache = <String, TranslationData>{};
  List<TranslationResource>? _availableTranslations;

  @override
  AsyncValue<TranslationData?> build() => const AsyncValue.data(null);

  Future<void> fetchForAyah(String ayahKey) async {
    final settings = ref.read(settingsProvider);
    final ids = settings.selectedTranslationIds;
    if (ids.isEmpty) return;

    final sortedIds = [...ids]..sort();
    final cacheKey = '$ayahKey:${sortedIds.join(',')}';
    if (_cache.containsKey(cacheKey)) {
      state = AsyncValue.data(_cache[cacheKey]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      // Pre-fetch translation names (cached after first call)
      final available = await fetchAvailableTranslations();
      final nameById = <int, String>{
        for (final r in available) r.id: r.name,
      };

      final res = await _dio.get(
        '/verses/by_key/$ayahKey',
        queryParameters: {
          'words': true,
          'word_fields': 'text_uthmani,translation',
          'translations': ids.join(','),
          'fields': 'chapter_id,verse_number',
        },
      );
      final data = res.data as Map<String, dynamic>;
      final verse = data['verse'] as Map<String, dynamic>;

      // Parse words
      final rawWords = (verse['words'] as List<dynamic>?) ?? [];
      final words = <WordTranslation>[];
      for (final w in rawWords) {
        final charType = w['char_type_name'] as String?;
        if (charType == 'end') continue; // skip verse-end markers
        words.add(WordTranslation(
          arabic: (w['text_uthmani'] as String?) ?? '',
          translation: (w['translation']?['text'] as String?) ?? '',
          transliteration: (w['transliteration']?['text'] as String?) ?? '',
        ));
      }

      // Parse translations
      final rawTranslations = (verse['translations'] as List<dynamic>?) ?? [];
      final translations = rawTranslations.map((t) {
        final rid = (t['resource_id'] as num?)?.toInt() ?? 0;
        return VerseTranslation(
          resourceId: rid,
          resourceName: nameById[rid] ?? (t['resource_name'] as String?) ?? '',
          text: stripHtmlTags((t['text'] as String?) ?? ''),
        );
      }).toList();

      final result = TranslationData(
        verseKey: ayahKey,
        words: words,
        translations: translations,
      );
      _cache[cacheKey] = result;
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<TranslationResource>> fetchAvailableTranslations() async {
    if (_availableTranslations != null) return _availableTranslations!;
    final res = await _dio.get('/resources/translations');
    final data = res.data as Map<String, dynamic>;
    final list = (data['translations'] as List<dynamic>?) ?? [];
    _availableTranslations = list.map((t) => TranslationResource(
      id: (t['id'] as num).toInt(),
      name: (t['translated_name']?['name'] as String?) ?? (t['name'] as String? ?? ''),
      authorName: (t['author_name'] as String?) ?? '',
      languageName: (t['language_name'] as String?) ?? '',
    )).toList();
    return _availableTranslations!;
  }

  static final _htmlTagRegex = RegExp(r'<[^>]*>');

  /// Remove HTML tags (footnote markers etc.) from translation text.
  static String stripHtmlTags(String html) => html.replaceAll(_htmlTagRegex, '');

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final translationProvider =
    NotifierProvider<TranslationNotifier, AsyncValue<TranslationData?>>(TranslationNotifier.new);
