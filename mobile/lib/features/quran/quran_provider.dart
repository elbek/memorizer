import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/quran/font_cache.dart';
import 'package:memorizer/features/quran/page_line.dart';

enum MushafVersion { v1, v2, v4 }

class QuranState {
  const QuranState({
    this.mushaf = MushafVersion.v1,
    this.currentPage = 1,
    this.loading = false,
    this.error,
    this.totalPages = 604,
    this.surahStartPages = const {},
  });

  final MushafVersion mushaf;
  final int currentPage;
  final bool loading;
  final String? error;
  final int totalPages;

  /// Surah number (1–114) → start page for the current mushaf.
  final Map<int, int> surahStartPages;

  QuranState copyWith({
    MushafVersion? mushaf,
    int? currentPage,
    bool? loading,
    String? error,
    Map<int, int>? surahStartPages,
  }) =>
      QuranState(
        mushaf: mushaf ?? this.mushaf,
        currentPage: currentPage ?? this.currentPage,
        loading: loading ?? this.loading,
        error: error,
        surahStartPages: surahStartPages ?? this.surahStartPages,
      );
}

class QuranNotifier extends Notifier<QuranState> {
  @override
  QuranState build() => const QuranState();

  ApiClient get _api => ref.read(apiClientProvider);

  final FontCache _fontCache = FontCache();

  /// In-memory page cache: page number → list of page lines.
  final Map<int, List<PageLine>> _cache = {};

  String get _apiParam {
    switch (state.mushaf) {
      case MushafVersion.v1:
        return 'v1';
      case MushafVersion.v2:
      case MushafVersion.v4:
        return 'v2';
    }
  }

  String get fontPath {
    switch (state.mushaf) {
      case MushafVersion.v1:
        return 'v1';
      case MushafVersion.v2:
        return 'v2';
      case MushafVersion.v4:
        return 'v4/colrv1';
    }
  }

  String get apiParam => _apiParam;

  /// Returns cached lines for [page], or null if not yet loaded.
  List<PageLine>? getPageLines(int page) => _cache[page];

  /// Whether the QCF font for [page] is loaded and ready.
  bool isFontReady(int page) => _fontCache.isLoaded(fontPath, page);

  /// Load surah index for current mushaf from the backend.
  Future<void> loadIndex() async {
    try {
      final res = await _api.dio.get(
        '/api/quran/index',
        queryParameters: {'mushaf': _apiParam},
      );
      final data = res.data as Map<String, dynamic>;
      final map = <int, int>{};
      data.forEach((k, v) {
        final surahNum = int.tryParse(k);
        if (surahNum != null && v is int) {
          map[surahNum] = v;
        }
      });
      state = state.copyWith(surahStartPages: map);
    } catch (_) {
      // Non-critical; navigation still works without it
    }
  }

  Future<void> loadPage(int page) async {
    if (page < 1 || page > state.totalPages) return;
    state = state.copyWith(
        currentPage: page, loading: !_cache.containsKey(page));

    if (_cache.containsKey(page)) {
      // Ensure font is loaded even for cached data
      await _fontCache.ensureFont(fontPath, page);
      state = state.copyWith(loading: false);
      _preloadNeighbors(page);
      return;
    }

    try {
      // Fetch glyph data and font in parallel
      final results = await Future.wait([
        _fetchPage(page),
        _fontCache.ensureFont(fontPath, page),
      ]);
      final lines = results[0] as List<PageLine>;
      _cache[page] = lines;
      if (state.currentPage == page) {
        state = state.copyWith(loading: false);
      }
      _preloadNeighbors(page);
    } catch (e) {
      if (state.currentPage == page) {
        state = state.copyWith(error: e.toString(), loading: false);
      }
    }
  }

  /// Surahs that don't have Bismillah: Al-Fatihah (1) and At-Tawbah (9).
  static const _noBismillah = {1, 9};

  /// Fetch QCF glyph data from our backend.
  /// Backend returns: [{k: "1:1", j: 1, w: [{c: "ﭑ", l: 9}, ...]}, ...]
  Future<List<PageLine>> _fetchPage(int page) async {
    final res = await _api.dio.get(
      '/api/quran/page/$page',
      queryParameters: {'mushaf': _apiParam},
    );
    final ayahs = res.data as List<dynamic>;
    return parseLines(ayahs);
  }

  /// Group QCF glyphs by line number, detect surah headers and bismillah.
  ///
  /// The mushaf reserves empty lines before a surah's first text:
  ///   line N-2 = surah header, line N-1 = bismillah, line N = first text.
  /// Al-Fatihah (1) and At-Tawbah (9) have no bismillah line.
  static List<PageLine> parseLines(List<dynamic> ayahs) {
    final lineMap = <int, StringBuffer>{};

    // Track which surahs start on this page (ayah 1 present).
    final surahStarts = <({int surahNum, int firstTextLine})>[];

    for (final ayah in ayahs) {
      final key = ayah['k'] as String? ?? '';
      final parts = key.split(':');
      final surahNum = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
      final ayahNum = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
      final words = (ayah['w'] as List<dynamic>?) ?? [];

      if (ayahNum == 1 && words.isNotEmpty) {
        final firstLine = words[0]['l'] as int? ?? 0;
        surahStarts.add((surahNum: surahNum, firstTextLine: firstLine));
      }

      for (final word in words) {
        final lineNum = word['l'] as int? ?? 0;
        final glyph = word['c'] as String? ?? '';
        if (glyph.isEmpty) continue;
        lineMap.putIfAbsent(lineNum, () => StringBuffer());
        if (lineMap[lineNum]!.isNotEmpty) {
          lineMap[lineNum]!.write(' ');
        }
        lineMap[lineNum]!.write(glyph);
      }
    }

    // Build map of reserved header/bismillah lines.
    final headerLines = <int, PageLine>{};
    for (final start in surahStarts) {
      if (!_noBismillah.contains(start.surahNum)) {
        // Standard surah: header + bismillah before first text line.
        if (start.firstTextLine >= 3) {
          headerLines[start.firstTextLine - 2] =
              HeaderLine(start.surahNum);
          headerLines[start.firstTextLine - 1] = const BismillahLine();
        } else if (start.firstTextLine == 2) {
          headerLines[start.firstTextLine - 1] =
              HeaderLine(start.surahNum);
        }
      } else {
        // Al-Fatihah / At-Tawbah: header only, no bismillah.
        if (start.firstTextLine >= 2) {
          headerLines[start.firstTextLine - 1] =
              HeaderLine(start.surahNum);
        }
      }
    }

    // Determine line range.
    final allLineNums = {...lineMap.keys, ...headerLines.keys};
    if (allLineNums.isEmpty) return [];
    final minLine = allLineNums.reduce((a, b) => a < b ? a : b);
    final maxLine = allLineNums.reduce((a, b) => a > b ? a : b);

    // Build final list.
    final result = <PageLine>[];
    for (var i = minLine; i <= maxLine; i++) {
      final header = headerLines[i];
      final text = lineMap[i]?.toString();
      if (header != null && (text == null || text.isEmpty)) {
        result.add(header);
      } else if (text != null && text.isNotEmpty) {
        result.add(TextLine(text));
      }
    }
    return result;
  }

  void _preloadNeighbors(int page) {
    for (final p in [page - 1, page + 1]) {
      if (p >= 1 && p <= state.totalPages && !_cache.containsKey(p)) {
        Future.wait<void>([
          _fetchPage(p).then((lines) => _cache[p] = lines),
          _fontCache.ensureFont(fontPath, p),
        ]).catchError((_) {});
      }
    }
  }

  void setMushaf(MushafVersion v) {
    _cache.clear();
    state = state.copyWith(mushaf: v, surahStartPages: const {});
    loadIndex();
    loadPage(state.currentPage);
  }

  void nextPage() => loadPage(state.currentPage + 1);
  void prevPage() => loadPage(state.currentPage - 1);
  void goToPage(int page) => loadPage(page);
}

final quranProvider =
    NotifierProvider<QuranNotifier, QuranState>(QuranNotifier.new);
