# Translation Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add ayah translation support — tap an ayah, see word-by-word + full verse translations in a bottom sheet. Translations configurable in settings.

**Architecture:** New `translation_provider.dart` fetches from QDC API (`api.qurancdn.com/api/qdc`) on demand per ayah, caches in memory. Settings provider extended with `selectedTranslationIds` and `wordByWordEnabled`. Translation bottom sheet triggered from ayah tap menu.

**Tech Stack:** Flutter, Riverpod, Dio (already in project), QDC API

---

### Task 1: Extend Settings Provider

**Files:**
- Modify: `mobile/lib/features/settings/settings_provider.dart`
- Modify: `mobile/test/features/settings/settings_provider_test.dart`

**Step 1: Write failing tests**

Add to `mobile/test/features/settings/settings_provider_test.dart`:

```dart
test('loads default translation settings', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  final state = container.read(settingsProvider);

  expect(state.selectedTranslationIds, [20]);
  expect(state.wordByWordEnabled, true);
  container.dispose();
});

test('loads saved translation settings', () async {
  SharedPreferences.setMockInitialValues({
    'selectedTranslationIds': '[20,85]',
    'wordByWordEnabled': false,
  });
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  final state = container.read(settingsProvider);

  expect(state.selectedTranslationIds, [20, 85]);
  expect(state.wordByWordEnabled, false);
  container.dispose();
});

test('setSelectedTranslationIds persists and updates state', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  await container.read(settingsProvider.notifier).setSelectedTranslationIds([20, 85]);

  expect(container.read(settingsProvider).selectedTranslationIds, [20, 85]);
  expect(prefs.getString('selectedTranslationIds'), '[20,85]');
  container.dispose();
});

test('setWordByWordEnabled persists and updates state', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  await container.read(settingsProvider.notifier).setWordByWordEnabled(false);

  expect(container.read(settingsProvider).wordByWordEnabled, false);
  expect(prefs.getBool('wordByWordEnabled'), false);
  container.dispose();
});
```

**Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/settings/settings_provider_test.dart`
Expected: FAIL — `selectedTranslationIds` and `wordByWordEnabled` don't exist on SettingsState.

**Step 3: Implement settings changes**

In `mobile/lib/features/settings/settings_provider.dart`, add `dart:convert` import, extend `SettingsState`:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.darkMode = false,
    this.mushafVersion = 'v1',
    this.reciterId = 7,
    this.selectedTranslationIds = const [20],
    this.wordByWordEnabled = true,
  });
  final bool darkMode;
  final String mushafVersion;
  final int reciterId;
  final List<int> selectedTranslationIds;
  final bool wordByWordEnabled;

  SettingsState copyWith({
    bool? darkMode,
    String? mushafVersion,
    int? reciterId,
    List<int>? selectedTranslationIds,
    bool? wordByWordEnabled,
  }) =>
      SettingsState(
        darkMode: darkMode ?? this.darkMode,
        mushafVersion: mushafVersion ?? this.mushafVersion,
        reciterId: reciterId ?? this.reciterId,
        selectedTranslationIds: selectedTranslationIds ?? this.selectedTranslationIds,
        wordByWordEnabled: wordByWordEnabled ?? this.wordByWordEnabled,
      );
}
```

In `SettingsNotifier.build()`, load the new fields:

```dart
final idsJson = prefs.getString('selectedTranslationIds');
final ids = idsJson != null
    ? (jsonDecode(idsJson) as List).cast<int>()
    : const <int>[20];

return SettingsState(
  darkMode: prefs.getBool('darkMode') ?? false,
  mushafVersion: prefs.getString('mushafVersion') ?? 'v1',
  reciterId: prefs.getInt('reciterId') ?? 7,
  selectedTranslationIds: ids,
  wordByWordEnabled: prefs.getBool('wordByWordEnabled') ?? true,
);
```

Add two new methods to `SettingsNotifier`:

```dart
Future<void> setSelectedTranslationIds(List<int> ids) async {
  final prefs = ref.read(sharedPrefsProvider);
  await prefs.setString('selectedTranslationIds', jsonEncode(ids));
  state = state.copyWith(selectedTranslationIds: ids);
}

Future<void> setWordByWordEnabled(bool value) async {
  final prefs = ref.read(sharedPrefsProvider);
  await prefs.setBool('wordByWordEnabled', value);
  state = state.copyWith(wordByWordEnabled: value);
}
```

**Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/features/settings/settings_provider_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add mobile/lib/features/settings/settings_provider.dart mobile/test/features/settings/settings_provider_test.dart
git commit -m "feat: add translation settings (selectedTranslationIds, wordByWordEnabled)"
```

---

### Task 2: Create Translation Provider

**Files:**
- Create: `mobile/lib/features/quran/translation_provider.dart`
- Create: `mobile/test/features/quran/translation_provider_test.dart`

**Step 1: Write failing tests**

Create `mobile/test/features/quran/translation_provider_test.dart`:

```dart
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
}
```

**Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/features/quran/translation_provider_test.dart`
Expected: FAIL — file does not exist.

**Step 3: Create translation provider**

Create `mobile/lib/features/quran/translation_provider.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _dio = Dio(BaseOptions(baseUrl: 'https://api.qurancdn.com/api/qdc'));
  final _cache = <String, TranslationData>{};
  List<TranslationResource>? _availableTranslations;

  @override
  AsyncValue<TranslationData?> build() => const AsyncValue.data(null);

  Future<void> fetchForAyah(String ayahKey) async {
    final settings = ref.read(settingsProvider);
    final ids = settings.selectedTranslationIds;
    if (ids.isEmpty) return;

    final cacheKey = '$ayahKey:${ids.join(',')}';
    if (_cache.containsKey(cacheKey)) {
      state = AsyncValue.data(_cache[cacheKey]);
      return;
    }

    state = const AsyncValue.loading();
    try {
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
      final translations = rawTranslations.map((t) => VerseTranslation(
        resourceId: (t['resource_id'] as num?)?.toInt() ?? 0,
        resourceName: (t['resource_name'] as String?) ?? '',
        text: _stripHtmlTags((t['text'] as String?) ?? ''),
      )).toList();

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

  /// Remove HTML tags (footnote markers etc.) from translation text.
  static String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final translationProvider =
    NotifierProvider<TranslationNotifier, AsyncValue<TranslationData?>>(TranslationNotifier.new);
```

**Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/features/quran/translation_provider_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add mobile/lib/features/quran/translation_provider.dart mobile/test/features/quran/translation_provider_test.dart
git commit -m "feat: add translation provider with QDC API integration"
```

---

### Task 3: Add "Translate" to Ayah Tap Menu + Translation Bottom Sheet

**Files:**
- Modify: `mobile/lib/features/quran/quran_screen.dart`

**Step 1: Add import**

At the top of `quran_screen.dart`, add:

```dart
import 'package:memorizer/features/quran/translation_provider.dart';
import 'package:memorizer/features/settings/settings_provider.dart';
```

**Step 2: Add "Translate" menu item**

In `_showAyahMenu()` (line ~100), add a 4th menu item:

```dart
const PopupMenuItem(value: 'translate', child: Text('Translate')),
```

Add handler in the `.then()` callback:

```dart
} else if (value == 'translate') {
  _showTranslationSheet(context, ayahKey);
}
```

**Step 3: Create `_showTranslationSheet` method**

Add to `_QuranScreenState`:

```dart
void _showTranslationSheet(BuildContext context, String ayahKey) {
  ref.read(translationProvider.notifier).fetchForAyah(ayahKey);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => _TranslationSheet(
        ayahKey: ayahKey,
        scrollController: scrollController,
      ),
    ),
  ).whenComplete(() {
    ref.read(translationProvider.notifier).clear();
  });
}
```

**Step 4: Create `_TranslationSheet` widget**

Add at the bottom of `quran_screen.dart` (before `_AyahPickerScreen`):

```dart
class _TranslationSheet extends ConsumerWidget {
  const _TranslationSheet({
    required this.ayahKey,
    required this.scrollController,
  });
  final String ayahKey;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translationState = ref.watch(translationProvider);
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;

    // Parse surah name for header
    final parts = ayahKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 1;
    final ayahNum = parts.length > 1 ? parts[1] : '1';
    final surah = getSurah(surahNum);
    final headerText = '${surah?.name ?? 'Surah $surahNum'}, Ayah $ayahNum';

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(headerText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 4),
          Expanded(
            child: translationState.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Failed to load translation',
                      style: TextStyle(color: cs.error)),
                ),
              ),
              data: (data) {
                if (data == null) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // Word-by-word section
                    if (settings.wordByWordEnabled && data.words.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text('Word by Word',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            )),
                      ),
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          reverse: true, // RTL
                          itemCount: data.words.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final w = data.words[i];
                            return Container(
                              constraints: const BoxConstraints(minWidth: 64),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.onSurface.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(w.arabic,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurface,
                                      ),
                                      textDirection: TextDirection.rtl),
                                  const SizedBox(height: 4),
                                  Text(w.translation,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center),
                                  if (w.transliteration.isNotEmpty)
                                    Text(w.transliteration,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                          color: cs.onSurface.withValues(alpha: 0.4),
                                        ),
                                        textAlign: TextAlign.center),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Full translations
                    for (final t in data.translations) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.resourceName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                )),
                            const SizedBox(height: 6),
                            Text(t.text,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: cs.onSurface,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 5: Run analyze and existing tests**

Run: `cd mobile && flutter analyze --no-fatal-infos && flutter test`
Expected: No errors, all tests pass.

**Step 6: Commit**

```bash
git add mobile/lib/features/quran/quran_screen.dart
git commit -m "feat: add translate option to ayah menu with translation bottom sheet"
```

---

### Task 4: Add Translation Settings UI

**Files:**
- Modify: `mobile/lib/features/settings/settings_screen.dart`

**Step 1: Add import**

```dart
import 'package:memorizer/features/quran/translation_provider.dart';
```

**Step 2: Add Translation section between Audio and Account**

After the Audio Card (after `const SizedBox(height: 8)` on line ~107), add:

```dart
// Translation section
_SectionHeader(title: 'Translation'),
Card(
  child: Column(
    children: [
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.translate_rounded, size: 20, color: cs.primary),
        ),
        title: const Text('Translations'),
        subtitle: Text(
          _translationSummary(settings.selectedTranslationIds),
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: cs.onSurface.withValues(alpha: 0.3)),
        onTap: () => _showTranslationPicker(context, ref, settings.selectedTranslationIds),
      ),
      SwitchListTile(
        title: const Text('Word-by-Word'),
        subtitle: Text(
          'English word-by-word translation',
          style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.text_fields_rounded, size: 20, color: cs.primary),
        ),
        value: settings.wordByWordEnabled,
        onChanged: (v) =>
            ref.read(settingsProvider.notifier).setWordByWordEnabled(v),
      ),
    ],
  ),
),
const SizedBox(height: 8),
```

**Step 3: Add helper methods to `SettingsScreen`**

```dart
String _translationSummary(List<int> ids) {
  if (ids.isEmpty) return 'None selected';
  // Use known names for common IDs, fall back to count
  const knownNames = {
    20: 'Saheeh International',
    85: 'Abdel Haleem',
    84: 'Mufti Taqi Usmani',
    95: 'Maududi',
    19: 'Pickthall',
    22: 'Yusuf Ali',
    203: 'Al-Hilali & Khan',
    149: 'Bridges',
  };
  final firstName = knownNames[ids.first];
  if (ids.length == 1) return firstName ?? 'Translation #${ids.first}';
  return '${firstName ?? 'Translation #${ids.first}'} +${ids.length - 1} more';
}

void _showTranslationPicker(BuildContext context, WidgetRef ref, List<int> currentIds) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _TranslationPickerScreen(
      selectedIds: currentIds,
      onChanged: (ids) {
        ref.read(settingsProvider.notifier).setSelectedTranslationIds(ids);
      },
    ),
  ));
}
```

**Step 4: Create `_TranslationPickerScreen` widget**

Add at the bottom of `settings_screen.dart`:

```dart
class _TranslationPickerScreen extends ConsumerStatefulWidget {
  const _TranslationPickerScreen({
    required this.selectedIds,
    required this.onChanged,
  });
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  @override
  ConsumerState<_TranslationPickerScreen> createState() =>
      _TranslationPickerScreenState();
}

class _TranslationPickerScreenState
    extends ConsumerState<_TranslationPickerScreen> {
  late Set<int> _selected;
  List<TranslationResource>? _translations;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedIds};
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    try {
      final list = await ref
          .read(translationProvider.notifier)
          .fetchAvailableTranslations();
      if (mounted) setState(() { _translations = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<TranslationResource>> get _grouped {
    if (_translations == null) return {};
    var list = _translations!;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) =>
          t.name.toLowerCase().contains(q) ||
          t.authorName.toLowerCase().contains(q) ||
          t.languageName.toLowerCase().contains(q)).toList();
    }
    final map = <String, List<TranslationResource>>{};
    for (final t in list) {
      final lang = t.languageName.isNotEmpty
          ? '${t.languageName[0].toUpperCase()}${t.languageName.substring(1)}'
          : 'Other';
      (map[lang] ??= []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;
    final sortedLangs = grouped.keys.toList()
      ..sort((a, b) {
        // English first, then alphabetical
        if (a == 'English') return -1;
        if (b == 'English') return 1;
        return a.compareTo(b);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translations'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onChanged(_selected.toList());
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search translations...',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: cs.onSurface.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final lang in sortedLangs) ...[
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            lang.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: cs.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        for (final t in grouped[lang]!)
                          CheckboxListTile(
                            value: _selected.contains(t.id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(t.id);
                                } else {
                                  _selected.remove(t.id);
                                }
                              });
                            },
                            title: Text(t.name,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: t.authorName.isNotEmpty
                                ? Text(t.authorName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5),
                                    ))
                                : null,
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
```

**Step 5: Run analyze and existing tests**

Run: `cd mobile && flutter analyze --no-fatal-infos && flutter test`
Expected: No errors, all tests pass.

**Step 6: Commit**

```bash
git add mobile/lib/features/settings/settings_screen.dart
git commit -m "feat: add translation picker and word-by-word toggle in settings"
```

---

### Task 5: Final Verification

**Step 1: Run full analysis**

Run: `cd mobile && flutter analyze --no-fatal-infos`
Expected: No errors or warnings.

**Step 2: Run all tests**

Run: `cd mobile && flutter test`
Expected: All tests pass.

**Step 3: Commit any remaining changes and push**

```bash
git push origin mobile
```
