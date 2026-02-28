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
  });

  final List<PageLine>? lines;
  final int pageNumber;
  final bool loading;
  final String fontPath;
  final bool isColorFont;

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

  Widget _buildPage(bool isDark) {
    final textColor =
        isDark ? const Color(0xFFE8DFD0) : const Color(0xFF3D2B1F);
    final borderColor = isDark ? _goldDark : _gold;
    final fontFamily = fontFamilyFor(fontPath, pageNumber);

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
                  TextLine(:final text) => Text(
                      text,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: fontSize,
                        height: 1.6,
                        color: isColorFont ? null : textColor,
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
