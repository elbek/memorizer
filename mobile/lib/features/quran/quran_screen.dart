import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/quran/bookmark_provider.dart';
import 'package:memorizer/features/quran/quran_provider.dart';
import 'package:memorizer/features/quran/quran_page.dart';
import 'package:memorizer/features/quran/surah_list_screen.dart';
import 'package:memorizer/shared/surah_data.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key, this.initialPage = 1, this.standalone = false});
  final int initialPage;
  final bool standalone;

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  late PageController _controller;
  final _focusNode = FocusNode();
  bool _readMode = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _readMode = widget.standalone;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(quranProvider.notifier);
      notifier.loadIndex();
      notifier.loadPage(widget.initialPage);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _controller.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() => _goToPage(ref.read(quranProvider).currentPage + 1);
  void _prevPage() => _goToPage(ref.read(quranProvider).currentPage - 1);

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _prevPage();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _nextPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Find which surah the current page belongs to using the loaded index.
  SurahInfo? _surahForPage(int page, Map<int, int> startPages) {
    if (startPages.isEmpty) return null;
    int matchedSurah = 1;
    for (int s = 1; s <= 114; s++) {
      final sp = startPages[s];
      if (sp != null && sp <= page) {
        matchedSurah = s;
      } else if (sp != null && sp > page) {
        break;
      }
    }
    return getSurah(matchedSurah);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quranProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final isBookmarked = bookmarks.contains(state.currentPage);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentSurah = _surahForPage(state.currentPage, state.surahStartPages);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Scaffold(
        appBar: _readMode
            ? null
            : AppBar(
                leading: widget.standalone
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    : null,
                titleSpacing: 0,
                title: Row(
                  children: [
                    if (!widget.standalone) const SizedBox(width: 12),
                    // Surah dropdown
                    Expanded(
                      child: _SurahDropdown(
                        currentSurah: currentSurah,
                        surahStartPages: state.surahStartPages,
                        onSelected: (surahNum) {
                          final page = state.surahStartPages[surahNum];
                          if (page != null) _goToPage(page);
                        },
                      ),
                    ),
                    // Page indicator (tappable to jump)
                    GestureDetector(
                      onTap: () =>
                          _showPageJumpDialog(context, state.currentPage),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${state.currentPage}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
                toolbarHeight: 52,
                actions: [
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 22,
                      color: isBookmarked ? cs.primary : null,
                    ),
                    tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                    onPressed: () => ref.read(bookmarkProvider.notifier).toggle(state.currentPage),
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, size: 22),
                    tooltip: 'Read mode',
                    onPressed: () => setState(() => _readMode = true),
                  ),
                  PopupMenuButton<MushafVersion>(
                    icon: Icon(Icons.auto_stories_rounded,
                        size: 20,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                    onSelected: (v) =>
                        ref.read(quranProvider.notifier).setMushaf(v),
                    itemBuilder: (_) => [
                      _mushafItem(
                          MushafVersion.v1, 'Madinah (1405AH)', state.mushaf),
                      _mushafItem(
                          MushafVersion.v2, 'Madinah (1421AH)', state.mushaf),
                      _mushafItem(
                          MushafVersion.v4, 'Tajweed Color', state.mushaf),
                    ],
                  ),
                ],
              ),
        body: GestureDetector(
          onTap: _readMode ? () => setState(() => _readMode = false) : null,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                reverse: true,
                itemCount: state.totalPages,
                onPageChanged: (index) {
                  ref.read(quranProvider.notifier).goToPage(index + 1);
                },
                itemBuilder: (_, index) {
                  final pageNum = index + 1;
                  final notifier = ref.read(quranProvider.notifier);
                  final cachedLines = notifier.getPageLines(pageNum);
                  final isCurrent = pageNum == state.currentPage;
                  return QuranPageView(
                    lines: cachedLines,
                    pageNumber: pageNum,
                    loading: isCurrent ? state.loading : cachedLines == null,
                    fontPath: notifier.fontPath,
                    isColorFont: state.mushaf == MushafVersion.v4,
                  );
                },
              ),
              if (!_readMode) ...[
                // Left arrow (next page in RTL)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      onPressed: state.currentPage < state.totalPages
                          ? _nextPage
                          : null,
                    ),
                  ),
                ),
                // Right arrow (prev page in RTL)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      onPressed: state.currentPage > 1 ? _prevPage : null,
                    ),
                  ),
                ),
              ],
              // Bookmark indicator
              if (isBookmarked)
                Positioned(
                  top: 0,
                  right: 12,
                  child: Icon(Icons.bookmark_rounded,
                      size: 28, color: cs.primary.withValues(alpha: 0.6)),
                ),
              // Page number overlay in read mode
              if (_readMode)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '${state.currentPage}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, int currentPage) {
    final ctrl = TextEditingController(text: '$currentPage');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Go to Page'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Page number (1–604)'),
          onSubmitted: (v) {
            final page = int.tryParse(v);
            if (page != null && page >= 1 && page <= 604) {
              Navigator.pop(context);
              _goToPage(page);
            }
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= 604) {
                Navigator.pop(context);
                _goToPage(page);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<MushafVersion> _mushafItem(
      MushafVersion v, String label, MushafVersion current) {
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          if (v == current)
            Icon(Icons.check_rounded,
                size: 18, color: Theme.of(context).colorScheme.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

/// Surah selector — tapping opens a bottom sheet with search.
class _SurahDropdown extends StatelessWidget {
  const _SurahDropdown({
    required this.currentSurah,
    required this.surahStartPages,
    required this.onSelected,
  });

  final SurahInfo? currentSurah;
  final Map<int, int> surahStartPages;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showSurahSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (currentSurah != null) ...[
              Text(
                currentSurah!.arabic,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  currentSurah!.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Text(
                'Select Surah',
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showSurahSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _SurahSheetContent(
            currentSurah: currentSurah,
            onSelected: (num) {
              Navigator.pop(context);
              onSelected(num);
            },
            scrollController: scrollController,
          );
        },
      ),
    );
  }
}

class _SurahSheetContent extends StatefulWidget {
  const _SurahSheetContent({
    required this.currentSurah,
    required this.onSelected,
    required this.scrollController,
  });
  final SurahInfo? currentSurah;
  final ValueChanged<int> onSelected;
  final ScrollController scrollController;

  @override
  State<_SurahSheetContent> createState() => _SurahSheetContentState();
}

class _SurahSheetContentState extends State<_SurahSheetContent> {
  String _query = '';

  List<SurahInfo> get _filtered => _query.isEmpty
      ? surahs
      : surahs
          .where((s) =>
              s.name.toLowerCase().contains(_query.toLowerCase()) ||
              s.arabic.contains(_query) ||
              '${s.number}' == _query)
          .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filtered;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search surahs...',
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
              filled: true,
              fillColor: cs.onSurface.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        // Surah list
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (_, i) {
              final s = filtered[i];
              final isCurrent = widget.currentSurah?.number == s.number;
              return ListTile(
                onTap: () => widget.onSelected(s.number),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: SurahNumberStar(
                  number: s.number,
                  size: 36,
                  color: isCurrent ? cs.primary : null,
                ),
                title: Text(
                  s.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${s.ayahCount} ayahs  •  Juz ${s.juz}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                trailing: Text(
                  s.arabic,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: isCurrent
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.55),
                  ),
                  textDirection: TextDirection.rtl,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (onPressed == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(icon, size: 32),
      color: isDark ? Colors.white24 : Colors.brown.shade300,
      onPressed: onPressed,
    );
  }
}
