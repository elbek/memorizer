import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memorizer/features/quran/font_cache.dart';
import 'package:memorizer/features/quran/page_line.dart';
import 'package:memorizer/features/quran/surah_header.dart';
import 'package:memorizer/shared/theme.dart';

const _gold = Color(0xFFCBB070);
const _goldDark = Color(0xFF8A7340);
const _longPressDuration = Duration(milliseconds: 300);

class QuranPageView extends StatefulWidget {
  const QuranPageView({
    super.key,
    required this.lines,
    required this.pageNumber,
    required this.loading,
    required this.fontPath,
    this.isColorFont = false,
    this.activeAyahKey,
    this.backgroundColor,
    this.onAyahTap,
    this.onRangeSelected,
  });

  final List<PageLine>? lines;
  final int pageNumber;
  final bool loading;
  final String fontPath;
  final bool isColorFont;
  final String? activeAyahKey;
  final Color? backgroundColor;
  final void Function(String ayahKey, Offset globalPosition)? onAyahTap;
  final void Function(String startKey, String endKey, Offset globalPosition)?
      onRangeSelected;

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  Set<String> _dragHighlightKeys = const {};
  bool _isDragging = false;
  String? _dragStartKey;
  int _dragStartLineIdx = -1;
  Timer? _longPressTimer;
  Offset? _pointerDownLocal;
  double _columnHeight = 1;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: widget.backgroundColor ?? (isDark ? quranPageBgDark : quranPageBg),
      child: widget.loading || widget.lines == null || widget.lines!.isEmpty
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

  Set<String> get _highlightKeys {
    if (_dragHighlightKeys.isNotEmpty) return _dragHighlightKeys;
    if (widget.activeAyahKey != null) return {widget.activeAyahKey!};
    return const {};
  }

  int _lineMatchType(List<WordSpan> words) {
    final keys = _highlightKeys;
    if (keys.isEmpty || words.isEmpty) return 0;
    final matchCount = words.where((w) => keys.contains(w.ayahKey)).length;
    if (matchCount == 0) return 0;
    if (matchCount == words.length) return 1;
    return 2;
  }

  Widget _buildPartialHighlight(
    List<WordSpan> words,
    String fontFamily,
    double fontSize,
    Color? textColor,
    Color highlightColor,
  ) {
    final keys = _highlightKeys;
    var firstActive = -1;
    var lastActive = -1;
    for (var i = 0; i < words.length; i++) {
      if (keys.contains(words[i].ayahKey)) {
        if (firstActive == -1) firstActive = i;
        lastActive = i;
      }
    }

    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.0,
      color: widget.isColorFont ? null : textColor,
    );

    final spans = <InlineSpan>[];

    if (firstActive > 0) {
      final text =
          words.sublist(0, firstActive).map((w) => w.glyph).join(' ');
      spans.add(TextSpan(text: '$text ', style: baseStyle));
    }

    final activeText = words
        .sublist(firstActive, lastActive + 1)
        .map((w) => w.glyph)
        .join(' ');
    spans.add(TextSpan(
      text: activeText,
      style: baseStyle.copyWith(backgroundColor: highlightColor),
    ));

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

  int _lineIndexAtY(double y) {
    final lineCount = widget.lines!.length;
    return (y / _columnHeight * lineCount).floor().clamp(0, lineCount - 1);
  }

  String? _ayahKeyAtLineIndex(int idx) {
    final lines = widget.lines!;
    final lineCount = lines.length;
    for (var d = 0; d < lineCount; d++) {
      for (final i in [idx + d, idx - d]) {
        if (i >= 0 && i < lineCount) {
          final line = lines[i];
          if (line is TextLine && line.words.isNotEmpty) {
            return line.words.first.ayahKey;
          }
        }
      }
    }
    return null;
  }

  Set<String> _ayahKeysBetweenLines(int a, int b) {
    final lo = a < b ? a : b;
    final hi = a > b ? a : b;
    final keys = <String>{};
    for (var i = lo; i <= hi; i++) {
      final line = widget.lines![i];
      if (line is TextLine) {
        for (final word in line.words) {
          keys.add(word.ayahKey);
        }
      }
    }
    return keys;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownLocal = event.localPosition;
    _longPressTimer?.cancel();

    if (widget.onRangeSelected == null && widget.onAyahTap == null) return;

    _longPressTimer = Timer(_longPressDuration, () {
      if (!mounted) return;
      final idx = _lineIndexAtY(_pointerDownLocal!.dy);
      final key = _ayahKeyAtLineIndex(idx);
      if (key == null) return;
      _isDragging = true;
      _dragStartKey = key;
      _dragStartLineIdx = idx;
      setState(() {
        _dragHighlightKeys = _ayahKeysBetweenLines(idx, idx);
      });
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDragging) {
      if (_pointerDownLocal != null) {
        final dx = (event.localPosition.dx - _pointerDownLocal!.dx).abs();
        if (dx > 18) {
          _longPressTimer?.cancel();
          _pointerDownLocal = null;
        }
      }
      return;
    }
    if (!mounted) return;
    final idx = _lineIndexAtY(event.localPosition.dy);
    setState(() {
      _dragHighlightKeys = _ayahKeysBetweenLines(_dragStartLineIdx, idx);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _longPressTimer?.cancel();

    if (_isDragging) {
      final idx = _lineIndexAtY(event.localPosition.dy);
      final endKey = _ayahKeyAtLineIndex(idx);
      final startKey = _dragStartKey;
      _isDragging = false;
      _dragStartKey = null;
      final startIdx = _dragStartLineIdx;
      _dragStartLineIdx = -1;
      if (mounted) {
        setState(() {
          _dragHighlightKeys = const {};
        });
      }
      if (startKey != null && endKey != null) {
        if (idx == startIdx) {
          // Long-press without drag → open ayah menu
          widget.onAyahTap?.call(startKey, event.position);
        } else {
          widget.onRangeSelected?.call(startKey, endKey, event.position);
        }
      }
      return;
    }

    // Single tap — no action (menu only on long-press)
    _pointerDownLocal = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _longPressTimer?.cancel();
    _isDragging = false;
    _dragStartKey = null;
    _dragStartLineIdx = -1;
    _pointerDownLocal = null;
    if (mounted) {
      setState(() {
        _dragHighlightKeys = const {};
      });
    }
  }

  Widget _buildPage(bool isDark) {
    final textColor =
        isDark ? const Color(0xFFE8DFD0) : const Color(0xFF3D2B1F);
    final borderColor = isDark ? _goldDark : _gold;
    final fontFamily = fontFamilyFor(widget.fontPath, widget.pageNumber);
    final highlightColor = _gold.withValues(alpha: isDark ? 0.15 : 0.18);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Count header/bismillah lines that use fixed height
        var fixedHeight = 0.0;
        var textLineCount = 0;
        for (final line in widget.lines!) {
          if (line is HeaderLine) {
            fixedHeight += 46;
          } else if (line is BismillahLine) {
            fixedHeight += 30;
          } else {
            textLineCount++;
          }
        }
        final padV = 4.0;
        final padH = 8.0;
        final marginV = 2.0;
        final availableHeight = constraints.maxHeight - (padV + marginV) * 2;
        final textHeight = availableHeight - fixedHeight;
        final fontSize = textLineCount > 0
            ? (textHeight / (textLineCount * 1.12)).clamp(16.0, 100.0)
            : 24.0;
        _columnHeight = constraints.maxHeight - (padV + marginV) * 2;


        return Container(
          margin: EdgeInsets.fromLTRB(6, marginV, 6, marginV),
          child: CustomPaint(
            painter: _OrnamentBorderPainter(color: borderColor),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final line in widget.lines!)
                      switch (line) {
                        HeaderLine(:final surahNumber) =>
                          SurahHeader(surahNumber: surahNumber),
                        BismillahLine() => Text(
                            '\u0628\u0650\u0633\u0652\u0645\u0650 \u0627\u0644\u0644\u0651\u064e\u0647\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0640\u0670\u0646\u0650 \u0627\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: fontSize * 0.85,
                              height: 1.0,
                              color: textColor,
                            ),
                          ),
                        TextLine(:final text, :final words) => FittedBox(
                            fit: BoxFit.scaleDown,
                            child: switch (_lineMatchType(words)) {
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
                                      height: 1.0,
                                      color: widget.isColorFont ? null : textColor,
                                    ),
                                  ),
                                ),
                              2 => _buildPartialHighlight(words, fontFamily,
                                  fontSize, textColor, highlightColor),
                              _ => Text(
                                  text,
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.rtl,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: fontFamily,
                                    fontSize: fontSize,
                                    height: 1.0,
                                    color: widget.isColorFont ? null : textColor,
                                  ),
                                ),
                            },
                          ),
                      },
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrnamentBorderPainter extends CustomPainter {
  _OrnamentBorderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Outer frame
    final outer = RRect.fromLTRBR(0, 0, w, h, const Radius.circular(6));
    canvas.drawRRect(outer, paint);

    // Inner frame with gap
    const g = 4.0; // gap between outer and inner
    final inner = RRect.fromLTRBR(g, g, w - g, h - g, const Radius.circular(4));
    canvas.drawRRect(inner, paint..strokeWidth = 0.7);

    // Corner ornaments
    paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
    const cs = 10.0; // corner size
    _drawCorner(canvas, paint, 0, 0, cs, 1, 1); // top-left
    _drawCorner(canvas, paint, w, 0, cs, -1, 1); // top-right
    _drawCorner(canvas, paint, 0, h, cs, 1, -1); // bottom-left
    _drawCorner(canvas, paint, w, h, cs, -1, -1); // bottom-right

    // Edge midpoint ornaments
    _drawEdgeDiamond(canvas, paint, w / 2, 0, 5); // top
    _drawEdgeDiamond(canvas, paint, w / 2, h, 5); // bottom
    _drawEdgeDiamond(canvas, paint, 0, h / 2, 5); // left
    _drawEdgeDiamond(canvas, paint, w, h / 2, 5); // right
  }

  void _drawCorner(
      Canvas canvas, Paint paint, double cx, double cy, double s, int dx, int dy) {
    // Small decorative petal at each corner
    final path = Path();
    // Arc petal
    path.moveTo(cx, cy);
    path.quadraticBezierTo(
      cx + dx * s * 0.8,
      cy + dy * s * 0.15,
      cx + dx * s,
      cy + dy * s * 0.5,
    );
    path.quadraticBezierTo(
      cx + dx * s * 0.6,
      cy + dy * s * 0.6,
      cx + dx * s * 0.5,
      cy + dy * s,
    );
    path.quadraticBezierTo(
      cx + dx * s * 0.15,
      cy + dy * s * 0.8,
      cx,
      cy,
    );
    canvas.drawPath(path, paint);
  }

  void _drawEdgeDiamond(Canvas canvas, Paint paint, double cx, double cy, double r) {
    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.6, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r * 0.6, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OrnamentBorderPainter old) => old.color != color;
}
