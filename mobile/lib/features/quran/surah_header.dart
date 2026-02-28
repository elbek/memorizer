import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:memorizer/shared/surah_data.dart';

String _toArabicNumeral(int n) {
  const digits = ['\u0660', '\u0661', '\u0662', '\u0663', '\u0664', '\u0665', '\u0666', '\u0667', '\u0668', '\u0669'];
  return n.toString().split('').map((c) => digits[int.parse(c)]).join();
}

class SurahHeader extends StatelessWidget {
  const SurahHeader({super.key, required this.surahNumber});
  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    final surah = getSurah(surahNumber);
    if (surah == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFDDD) : const Color(0xFF222222);

    return SizedBox(
      height: 46,
      child: Stack(
        children: [
          // Ornamental SVG frame
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: isDark
                  ? const ColorFilter.matrix(<double>[
                      -0.85, 0, 0, 0, 217,
                      0, -0.85, 0, 0, 217,
                      0, 0, -0.85, 0, 217,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.multiply),
              child: SvgPicture.asset(
                'assets/sura_border.svg',
                fit: BoxFit.fill,
                colorFilter: isDark
                    ? null
                    : const ColorFilter.mode(
                        Color(0xFF555555), BlendMode.srcIn),
              ),
            ),
          ),
          // Surah name centered
          Center(
            child: Text(
              '\u0633\u0648\u0631\u0629 ${surah.arabic}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          // Surah number in right medallion (20% from left)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(-0.60, 0),
              child: Text(
                _toArabicNumeral(surah.number),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
          ),
          // Ayah count in left medallion (80% from left)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: const Alignment(0.60, 0),
              child: Text(
                _toArabicNumeral(surah.ayahCount),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFamily: 'sans-serif',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
