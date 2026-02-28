const String apiBaseUrl = 'https://quran-memorizer.quran-memorizer.workers.dev';
const String fontCdnBase =
    'https://verses.quran.foundation/fonts/quran/hafs';

/// Build a font URL for a given mushaf version and page number.
/// [fontPath] is e.g. "v1", "v2", or "v4/colrv1".
String fontUrl(String fontPath, int pageNumber) =>
    '$fontCdnBase/$fontPath/ttf/p$pageNumber.ttf';
