# Translation Feature Design

## Overview

Add ayah translation support to the Quran reader. User taps an ayah → "Translate" → bottom sheet shows full verse translation(s) and optional word-by-word breakdown.

## API

QDC API (`api.qurancdn.com/api/qdc`), same base as audio.

### Endpoints

- `GET /verses/by_key/{surah}:{ayah}?words=true&word_fields=text_uthmani,translation&translations={id1},{id2}` — verse with word-by-word + selected translations
- `GET /resources/translations` — list all available translations (87+ across 50+ languages, fetched once)

### Response Shape

Verse-level translations:
```json
{
  "translations": [
    { "resource_id": 20, "text": "In the name of Allah...", "resource_name": "Saheeh International" }
  ]
}
```

Word-level (English only):
```json
{
  "words": [
    { "text_uthmani": "بِسْمِ", "translation": { "text": "In (the) name" }, "transliteration": { "text": "bis'mi" } }
  ]
}
```

## Data Layer

### `translation_provider.dart` (new)

- Fetches on demand per ayah using user's selected translation IDs
- In-memory cache keyed by `"ayahKey:translationIdsSorted"`
- Also fetches/caches available translations list from `/resources/translations`

### Settings additions (`settings_provider.dart`)

- `selectedTranslationIds: List<int>` — default `[20]` (Saheeh International)
- `wordByWordEnabled: bool` — default `true`
- Persisted in SharedPreferences as JSON-encoded list + bool

## UI

### Ayah Tap Menu (quran_screen.dart)

Add 4th menu item: **"Translate"** after existing play/repeat options.

### Translation Bottom Sheet

Opened when user taps "Translate":

**Header**: "Surah Name, Ayah N"

**Word-by-word section** (if enabled):
- Horizontal scrollable row of cards (RTL)
- Each card: Arabic word (top), English translation (middle), transliteration (small, bottom)

**Full translations section**:
- Stacked vertically, one card per selected translation
- Card header: translator/resource name
- Card body: translation text

**Loading state**: Spinner while fetching

### Settings Screen

New "Translation" section between "Audio" and "Account":

1. **"Translations"** ListTile — shows selected count, taps to open picker
   - Bottom sheet with all translations grouped by language
   - Section headers per language (English, Urdu, Turkish, ...)
   - Checkbox per translation (multi-select)
   - Search bar at top

2. **"Word-by-Word"** SwitchListTile — toggle English word-by-word display

## Fetching Strategy

On-demand per ayah. Translation is fetched only when user taps "Translate" on a specific ayah. Results cached in memory for the session.
