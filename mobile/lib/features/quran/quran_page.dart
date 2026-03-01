import 'package:flutter/material.dart';
import 'package:memorizer/features/quran/font_cache.dart';
import 'package:memorizer/features/quran/page_line.dart';
import 'package:memorizer/features/quran/surah_header.dart';
import 'package:memorizer/shared/theme.dart';

const _gold = Color(0xFFCBB070);
const _goldDark = Color(0xFF8A7340);

class QuranPageView extends StatelessWidget {
  const QuranPageView({
    super.key,
    required this.lines,
    required this.pageNumber,
    required this.loading,
    required this.fontPath,
    this.isColorFont = false,
    this.activeAyahKey,
    this.onAyahTap,
  });

  final List<PageLine>? lines;
  final int pageNumber;
  final bool loading;
  final String fontPath;
  final bool isColorFont;
  final String? activeAyahKey;
  final ValueChanged<String>? onAyahTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? quranPageBgDark : quranPageBg,
      child: loading || lines == null || lines!.isEmpty
          ? _buildLoading(isDark)
          : _buildPage(isDark),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(
            isDark ? Colors.white30 : Colors.brown.shade300,
          ),
        ),
      ),
    );
  }

  /// Classify a line's relationship to the active ayah.
  /// Returns: 0 = no match, 1 = all words match, 2 = partial (mixed line).
  int _lineMatchType(List<WordSpan> words) {
    if (activeAyahKey == null || words.isEmpty) return 0;
    final matchCount = words.where((w) => w.ayahKey == activeAyahKey).length;
    if (matchCount == 0) return 0;
    if (matchCount == words.length) return 1;
    return 2;
  }

  /// Build a Text.rich with at most 3 grouped spans for partial-line highlight.
  /// Words from the same ayah are contiguous, so we split into
  /// [before] [active] [after] groups.
  Widget _buildPartialHighlight(
    List<WordSpan> words,
    String fontFamily,
    double fontSize,
    Color? textColor,
    Color highlightColor,
  ) {
    // Find the range of active words
    var firstActive = -1;
    var lastActive = -1;
    for (var i = 0; i < words.length; i++) {
      if (words[i].ayahKey == activeAyahKey) {
        if (firstActive == -1) firstActive = i;
        lastActive = i;
      }
    }

    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.6,
      color: isColorFont ? null : textColor,
    );

    final spans = <InlineSpan>[];

    // Before-active segment
    if (firstActive > 0) {
      final text = words.sublist(0, firstActive).map((w) => w.glyph).join(' ');
      spans.add(TextSpan(text: '$text ', style: baseStyle));
    }

    // Active segment
    final activeText =
        words.sublist(firstActive, lastActive + 1).map((w) => w.glyph).join(' ');
    spans.add(TextSpan(
      text: activeText,
      style: baseStyle.copyWith(backgroundColor: highlightColor),
    ));

    // After-active segment
    if (lastActive < words.length - 1) {
      final text =
          words.sublist(lastActive + 1).map((w) => w.glyph).join(' ');
      spans.add(TextSpan(text: ' $text', style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      maxLines: 1,
    );
  }

  Widget _buildPage(bool isDark) {
    final textColor =
        isDark ? const Color(0xFFE8DFD0) : const Color(0xFF3D2B1F);
    final borderColor = isDark ? _goldDark : _gold;
    final fontFamily = fontFamilyFor(fontPath, pageNumber);
    final highlightColor = _gold.withValues(alpha: isDark ? 0.15 : 0.18);

    return LayoutBuilder(
      builder: (context, constraints) {
        final lineCount = lines!.length;
        final availableHeight = constraints.maxHeight - 28;
        final fontSize =
            (availableHeight / (lineCount * 1.8)).clamp(16.0, 32.0);

        return Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final line in lines!)
                switch (line) {
                  HeaderLine(:final surahNumber) =>
                    SurahHeader(surahNumber: surahNumber),
                  BismillahLine() => Text(
                      '\u0628\u0650\u0633\u0652\u0645\u0650 \u0627\u0644\u0644\u0651\u064e\u0647\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0640\u0670\u0646\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: fontSize * 0.85,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                  TextLine(:final text, :final words) => GestureDetector(
                      onTap: onAyahTap != null && words.isNotEmpty
                          ? () => onAyahTap!(words.first.ayahKey)
                          : null,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: switch (_lineMatchType(words)) {
                          // Full line match — Container background (no text splitting)
                          1 => Container(
                              decoration: BoxDecoration(
                                color: highlightColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontSize: fontSize,
                                  height: 1.6,
                                  color: isColorFont ? null : textColor,
                                ),
                              ),
                            ),
                          // Partial match — Text.rich with 2-3 grouped spans
                          2 => _buildPartialHighlight(
                              words, fontFamily, fontSize, textColor, highlightColor),
                          // No match — plain Text
                          _ => Text(
                              text,
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: fontSize,
                                height: 1.6,
                                color: isColorFont ? null : textColor,
                              ),
                            ),
                        },
                      ),
                    ),
                },
            ],
          ),
        );
      },
    );
  }
}
