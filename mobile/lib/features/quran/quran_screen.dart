import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/quran/audio_provider.dart';
import 'package:memorizer/features/quran/bookmark_provider.dart';
import 'package:memorizer/features/quran/page_line.dart';
import 'package:memorizer/features/quran/quran_provider.dart';
import 'package:memorizer/features/quran/quran_page.dart';
import 'package:memorizer/features/quran/surah_list_screen.dart';
import 'package:memorizer/features/quran/translation_provider.dart';
import 'package:memorizer/features/settings/settings_provider.dart';
import 'package:memorizer/shared/surah_data.dart';
import 'package:memorizer/shared/theme.dart';

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key, this.initialPage = 1, this.standalone = false});
  final int initialPage;
  final bool standalone;

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  late PageController _controller;
  late AudioNotifier _audioNotifier;
  final _focusNode = FocusNode();
  bool _readMode = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  String? _selectedAyahKey;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _readMode = widget.standalone;
    _audioNotifier = ref.read(audioProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(quranProvider.notifier);
      notifier.loadIndex();
      notifier.loadPage(widget.initialPage);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _audioNotifier.onPageComplete = null;
    Future(_audioNotifier.stop);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _startHideTimer();
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

  List<String> _ayahKeysForPage(int page) {
    final lines = ref.read(quranProvider.notifier).getPageLines(page);
    if (lines == null) return [];
    final seen = <String>{};
    final keys = <String>[];
    for (final line in lines) {
      if (line is TextLine) {
        for (final w in line.words) {
          if (seen.add(w.ayahKey)) keys.add(w.ayahKey);
        }
      }
    }
    return keys;
  }

  Future<void> _startAudio(int page, {String? fromAyahKey, String? toAyahKey}) async {
    final ayahKeys = _ayahKeysForPage(page);
    if (ayahKeys.isEmpty) return;
    final audioNotifier = ref.read(audioProvider.notifier);
    audioNotifier.onPageComplete = () {
      if (!mounted) return;
      final currentPage = ref.read(quranProvider).currentPage;
      if (currentPage < 604) {
        _goToPage(currentPage + 1);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startAudio(currentPage + 1);
        });
      }
    };
    await audioNotifier.playPageWithKeys(page, ayahKeys, fromAyahKey: fromAyahKey, toAyahKey: toAyahKey);
  }

  void _showAyahMenu(BuildContext context, Offset position, int page, String ayahKey) {
    if (_readMode) setState(() { _readMode = false; });
    setState(() => _selectedAyahKey = ayahKey);
    final rect = RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy);
    showMenu<String>(
      context: context,
      position: rect,
      items: [
        const PopupMenuItem(value: 'play', child: Text('Start reciting')),
        const PopupMenuItem(value: 'repeat', child: Text('Repeat reciting')),
        const PopupMenuItem(value: 'repeatPage', child: Text('Repeat page')),
        const PopupMenuItem(value: 'translate', child: Text('Translate')),
      ],
    ).then((value) async {
      if (mounted) setState(() => _selectedAyahKey = null);
      if (value == 'play') {
        _startAudio(page, fromAyahKey: ayahKey);
      } else if (value == 'repeat') {
        await _startAudio(page, fromAyahKey: ayahKey);
        ref.read(audioProvider.notifier).repeatAyah();
      } else if (value == 'repeatPage') {
        await _startAudio(page);
        ref.read(audioProvider.notifier).repeatAyah();
      } else if (value == 'translate') {
        if (!mounted) return;
        _showTranslationSheet(context, ayahKey);
      }
    });
  }

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

  void _showRangeMenu(BuildContext context, Offset position, int page, String startKey, String endKey) {
    if (_readMode) setState(() => _readMode = false);
    final rect = RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy);
    showMenu<String>(
      context: context,
      position: rect,
      items: [
        PopupMenuItem(value: 'play', child: Text('Recite $startKey – $endKey')),
        PopupMenuItem(value: 'repeat', child: Text('Repeat $startKey – $endKey')),
      ],
    ).then((value) async {
      final audioNotifier = ref.read(audioProvider.notifier);
      audioNotifier.onPageComplete = null;
      if (value == 'play') {
        _startAudio(page, fromAyahKey: startKey, toAyahKey: endKey);
      } else if (value == 'repeat') {
        await _startAudio(page, fromAyahKey: startKey, toAyahKey: endKey);
        audioNotifier.repeatAyah();
      }
    });
  }

  void _showRangeConfigSheet(BuildContext context, AudioState audioState) {
    final currentKey = audioState.currentAyahKey ?? audioState.ayahKeys.firstOrNull ?? '1:1';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RangeConfigSheet(
        initialStartKey: audioState.hasRange
            ? audioState.ayahKeys[audioState.rangeStartIndex!]
            : currentKey,
        initialEndKey: audioState.hasRange
            ? audioState.ayahKeys[audioState.rangeEndIndex!]
            : currentKey,
        pageAyahKeys: audioState.ayahKeys,
        onApply: (startKey, endKey) async {
          final page = audioState.currentPage;
          final allKeys = _generateAyahKeys(startKey, endKey);
          if (allKeys.isEmpty) return;
          final audioNotifier = ref.read(audioProvider.notifier);
          audioNotifier.onPageComplete = null;
          await audioNotifier.playPageWithKeys(page, allKeys, fromAyahKey: startKey, toAyahKey: endKey);
          audioNotifier.repeatAyah();
        },
      ),
    );
  }

  static List<String> _generateAyahKeys(String startKey, String endKey) {
    final sp = startKey.split(':');
    final ep = endKey.split(':');
    final startSurah = int.parse(sp[0]);
    final startAyah = int.parse(sp[1]);
    final endSurah = int.parse(ep[0]);
    final endAyah = int.parse(ep[1]);

    final keys = <String>[];
    for (var s = startSurah; s <= endSurah; s++) {
      final surah = getSurah(s);
      if (surah == null) continue;
      final first = s == startSurah ? startAyah : 1;
      final last = s == endSurah ? endAyah : surah.ayahCount;
      for (var a = first; a <= last; a++) {
        keys.add('$s:$a');
      }
    }
    return keys;
  }

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
    final audioState = ref.watch(audioProvider);

    // Start hide timer when audio becomes active, reset visibility when it stops
    if (audioState.isActive && _hideTimer == null) {
      _controlsVisible = true;
      _startHideTimer();
    } else if (!audioState.isActive) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _controlsVisible = true;
    }
    final bookmarks = ref.watch(bookmarkProvider);
    final isBookmarked = bookmarks.contains(state.currentPage);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pageBgColor = quranPageBgFor(settings.pageColorIndex, isDark);
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
                      audioState.isActive
                          ? (audioState.status == AudioPlaybackStatus.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded)
                          : Icons.play_arrow_rounded,
                      size: 22,
                    ),
                    tooltip: audioState.isActive ? 'Pause' : 'Play audio',
                    onPressed: () {
                      if (audioState.isActive) {
                        ref.read(audioProvider.notifier).togglePlayPause();
                      } else {
                        _startAudio(state.currentPage);
                      }
                    },
                  ),
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
          onTap: () {
            if (_readMode) {
              setState(() => _readMode = false);
            } else if (audioState.isActive) {
              _showControls();
            }
          },
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                reverse: true,
                itemCount: state.totalPages,
                onPageChanged: (index) {
                  final newPage = index + 1;
                  final audio = ref.read(audioProvider);
                  if (audio.isActive && audio.currentPage != newPage) {
                    ref.read(audioProvider.notifier).stop();
                  }
                  ref.read(quranProvider.notifier).goToPage(newPage);
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
                    backgroundColor: pageBgColor,
                    activeAyahKey: audioState.currentPage == pageNum
                        ? audioState.currentAyahKey
                        : (pageNum == state.currentPage ? _selectedAyahKey : null),
                    onAyahTap: (ayahKey, position) =>
                        _showAyahMenu(context, position, pageNum, ayahKey),
                    onRangeSelected: (startKey, endKey, position) =>
                        _showRangeMenu(context, position, pageNum, startKey, endKey),
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
              // Audio mini controls
              if (audioState.isActive)
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    top: false,
                    child: AnimatedSlide(
                      offset: _controlsVisible ? Offset.zero : const Offset(0, 1.5),
                      duration: const Duration(milliseconds: 300),
                      curve: _controlsVisible ? Curves.easeOut : Curves.easeIn,
                      child: AnimatedOpacity(
                        opacity: _controlsVisible ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: GestureDetector(
                          onTap: _showControls,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Builder(
                              builder: (context) {
                                // Compute surah-level progress
                                final key = audioState.currentAyahKey;
                                final keyParts = key?.split(':');
                                final surahNum = int.tryParse(keyParts?.first ?? '') ?? 0;
                                final ayahNum = int.tryParse(keyParts != null && keyParts.length > 1 ? keyParts[1] : '') ?? 0;
                                final surahInfo = getSurah(surahNum);
                                final totalAyahs = surahInfo?.ayahCount ?? 1;

                                return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Progress bar (surah-level)
                                if (totalAyahs > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                                    child: _AyahProgressBar(
                                      total: totalAyahs,
                                      current: ayahNum - 1,
                                      color: cs.primary,
                                    ),
                                  ),
                                Row(
                                  children: [
                                    // Ayah label
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: audioState.repeating
                                            ? () {
                                                _showControls();
                                                _showRangeConfigSheet(context, audioState);
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: _AudioLabel(audioState: audioState),
                                        ),
                                      ),
                                    ),
                                    // Transport controls
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous_rounded, size: 20),
                                      onPressed: audioState.currentAyahIndex > 0
                                          ? () {
                                              _showControls();
                                              ref.read(audioProvider.notifier).skipPrevious();
                                            }
                                          : null,
                                      tooltip: 'Previous ayah',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    // Hero play/pause button
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          audioState.status == AudioPlaybackStatus.playing
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 22,
                                          color: cs.onPrimary,
                                        ),
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          _showControls();
                                          ref.read(audioProvider.notifier).togglePlayPause();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next_rounded, size: 20),
                                      onPressed: () {
                                        _showControls();
                                        ref.read(audioProvider.notifier).skipNext();
                                      },
                                      tooltip: 'Next ayah',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.stop_rounded, size: 20,
                                          color: cs.onSurface.withValues(alpha: 0.5)),
                                      onPressed: () => ref.read(audioProvider.notifier).stop(),
                                      tooltip: 'Stop',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Page number overlay in read mode
              if (_readMode && !audioState.isActive)
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

class _RangeConfigSheet extends StatefulWidget {
  const _RangeConfigSheet({
    required this.initialStartKey,
    required this.initialEndKey,
    required this.pageAyahKeys,
    required this.onApply,
  });
  final String initialStartKey;
  final String initialEndKey;
  final List<String> pageAyahKeys;
  final Future<void> Function(String startKey, String endKey) onApply;

  @override
  State<_RangeConfigSheet> createState() => _RangeConfigSheetState();
}

class _RangeConfigSheetState extends State<_RangeConfigSheet> {
  late String _startKey;
  late String _endKey;

  @override
  void initState() {
    super.initState();
    _startKey = widget.initialStartKey;
    _endKey = widget.initialEndKey;
  }

  int _surahOf(String key) => int.parse(key.split(':').first);
  int _ayahOf(String key) => int.parse(key.split(':').last);

  String _label(String key) {
    final s = _surahOf(key);
    final a = _ayahOf(key);
    final name = getSurah(s)?.name ?? 'Surah $s';
    return '$name, Ayah $a';
  }

  /// Juz start verse keys (1-indexed: juzStarts[1] = start of juz 1).
  static const _juzStarts = <int, String>{
    1: '1:1', 2: '2:142', 3: '2:253', 4: '3:93', 5: '4:24',
    6: '4:148', 7: '5:82', 8: '6:111', 9: '7:88', 10: '8:41',
    11: '9:93', 12: '11:6', 13: '12:53', 14: '15:1', 15: '17:1',
    16: '18:75', 17: '21:1', 18: '23:1', 19: '25:21', 20: '27:56',
    21: '29:46', 22: '33:31', 23: '36:28', 24: '39:32', 25: '41:47',
    26: '46:1', 27: '51:31', 28: '58:1', 29: '67:1', 30: '78:1',
  };

  /// Find which juz a verse belongs to.
  int _juzOf(String key) {
    for (var j = 30; j >= 1; j--) {
      final start = _juzStarts[j]!;
      if (_compareKeys(key, start) >= 0) return j;
    }
    return 1;
  }

  /// End key of a juz (last ayah before the next juz starts).
  String _juzEndKey(int juz) {
    if (juz >= 30) return '114:6';
    final nextStart = _juzStarts[juz + 1]!;
    final s = _surahOf(nextStart);
    final a = _ayahOf(nextStart);
    if (a > 1) return '$s:${a - 1}';
    // Previous surah's last ayah
    final prevSurah = getSurah(s - 1);
    return '${s - 1}:${prevSurah?.ayahCount ?? 1}';
  }

  /// Compare two verse keys numerically.
  int _compareKeys(String a, String b) {
    final sa = _surahOf(a), aa = _ayahOf(a);
    final sb = _surahOf(b), ab = _ayahOf(b);
    if (sa != sb) return sa.compareTo(sb);
    return aa.compareTo(ab);
  }

  void _showPicker(BuildContext context, String current, bool isEnd, ValueChanged<String> onPicked) {
    final startSurah = _surahOf(_startKey);
    final startAyah = _ayahOf(_startKey);

    // Build searchable list
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => _AyahPickerScreen(
        current: current,
        minSurah: isEnd ? startSurah : 1,
        minAyah: isEnd ? startAyah : 1,
        onPicked: (key) {
          Navigator.pop(ctx);
          onPicked(key);
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentJuz = _juzOf(_startKey);

    // Surahs on current page for preset
    final pageSurahs = <int>{};
    for (final k in widget.pageAyahKeys) {
      pageSurahs.add(_surahOf(k));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Repeat Range',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Quick presets
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: Icon(Icons.menu_book_rounded, size: 16, color: cs.primary),
                  label: const Text('This page'),
                  onPressed: () => setState(() {
                    _startKey = widget.pageAyahKeys.first;
                    _endKey = widget.pageAyahKeys.last;
                  }),
                ),
                for (final s in pageSurahs)
                  ActionChip(
                    avatar: Icon(Icons.bookmark_rounded, size: 16, color: cs.primary),
                    label: Text(getSurah(s)?.name ?? 'Surah $s'),
                    onPressed: () {
                      final surah = getSurah(s);
                      if (surah == null) return;
                      setState(() {
                        _startKey = '$s:1';
                        _endKey = '$s:${surah.ayahCount}';
                      });
                    },
                  ),
                ActionChip(
                  avatar: Icon(Icons.layers_rounded, size: 16, color: cs.primary),
                  label: Text('Juz $currentJuz'),
                  onPressed: () => setState(() {
                    _startKey = _juzStarts[currentJuz]!;
                    _endKey = _juzEndKey(currentJuz);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // From
            _buildSelector(context, label: 'From', value: _startKey, onTap: () {
              _showPicker(context, _startKey, false, (key) {
                setState(() {
                  _startKey = key;
                  if (_compareKeys(_endKey, _startKey) < 0) _endKey = _startKey;
                });
              });
            }),
            const SizedBox(height: 12),
            // To
            _buildSelector(context, label: 'To', value: _endKey, onTap: () {
              _showPicker(context, _endKey, true, (key) {
                setState(() => _endKey = key);
              });
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply(_startKey, _endKey);
                },
                child: Text(_startKey == _endKey
                    ? 'Repeat ${_label(_startKey)}'
                    : 'Repeat $_startKey – $_endKey'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(BuildContext context, {required String label, required String value, required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.5),
            )),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_label(value), style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

/// Full-screen ayah picker with search.
class _AyahPickerScreen extends StatefulWidget {
  const _AyahPickerScreen({
    required this.current,
    required this.minSurah,
    required this.minAyah,
    required this.onPicked,
  });
  final String current;
  final int minSurah;
  final int minAyah;
  final ValueChanged<String> onPicked;

  @override
  State<_AyahPickerScreen> createState() => _AyahPickerScreenState();
}

class _AyahPickerScreenState extends State<_AyahPickerScreen> {
  int? _expandedSurah;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _expandedSurah = int.parse(widget.current.split(':').first);
  }

  List<SurahInfo> get _filteredSurahs {
    var list = surahs.where((s) => s.number >= widget.minSurah).toList();
    if (_query.isNotEmpty) {
      list = list.where((s) =>
          s.name.toLowerCase().contains(_query.toLowerCase()) ||
          s.arabic.contains(_query) ||
          '${s.number}' == _query).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filteredSurahs;
    final currentSurah = int.parse(widget.current.split(':').first);
    final currentAyah = int.parse(widget.current.split(':').last);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Ayah')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search surahs...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: cs.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                final isExpanded = _expandedSurah == s.number;
                final minAyah = s.number == widget.minSurah ? widget.minAyah : 1;

                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: Text('${s.number}. ${s.name}',
                          style: TextStyle(
                            fontWeight: isExpanded ? FontWeight.w600 : FontWeight.w400,
                            color: isExpanded ? cs.primary : null,
                          )),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.arabic, style: TextStyle(fontSize: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                              textDirection: TextDirection.rtl),
                          const SizedBox(width: 4),
                          Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                        ],
                      ),
                      onTap: () => setState(() =>
                          _expandedSurah = isExpanded ? null : s.number),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (var a = minAyah; a <= s.ayahCount; a++)
                              ChoiceChip(
                                label: Text('$a', style: const TextStyle(fontSize: 13)),
                                selected: s.number == currentSurah && a == currentAyah,
                                onSelected: (_) => widget.onPicked('${s.number}:$a'),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                      ),
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

class _TranslationSheet extends ConsumerStatefulWidget {
  const _TranslationSheet({
    required this.ayahKey,
    required this.scrollController,
  });
  final String ayahKey;
  final ScrollController scrollController;

  @override
  ConsumerState<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends ConsumerState<_TranslationSheet> {
  late String _currentKey;

  @override
  void initState() {
    super.initState();
    _currentKey = widget.ayahKey;
  }

  void _goToAyah(String key) {
    setState(() => _currentKey = key);
    ref.read(translationProvider.notifier).fetchForAyah(key);
  }

  String? _prevAyahKey() {
    final parts = _currentKey.split(':');
    final surah = int.tryParse(parts[0]) ?? 1;
    final ayah = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    if (ayah > 1) return '$surah:${ayah - 1}';
    if (surah <= 1) return null;
    final prevSurah = getSurah(surah - 1);
    if (prevSurah == null) return null;
    return '${surah - 1}:${prevSurah.ayahCount}';
  }

  String? _nextAyahKey() {
    final parts = _currentKey.split(':');
    final surah = int.tryParse(parts[0]) ?? 1;
    final ayah = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final currentSurah = getSurah(surah);
    if (currentSurah != null && ayah < currentSurah.ayahCount) return '$surah:${ayah + 1}';
    if (surah >= 114) return null;
    return '${surah + 1}:1';
  }

  @override
  Widget build(BuildContext context) {
    final translationState = ref.watch(translationProvider);
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;

    final parts = _currentKey.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 1;
    final ayahNum = parts.length > 1 ? parts[1] : '1';
    final surah = getSurah(surahNum);
    final headerText = '${surah?.name ?? 'Surah $surahNum'}, Ayah $ayahNum';
    final prev = _prevAyahKey();
    final next = _nextAyahKey();

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
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: next != null ? () => _goToAyah(next) : null,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Text(headerText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: prev != null ? () => _goToAyah(prev) : null,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],
          ),
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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No translations selected.\nConfigure in Settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                    ),
                  );
                }
                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    // Word-by-word section
                    if (settings.wordByWordEnabled && data.words.isNotEmpty) ...[
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
                            Text('Word by Word',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                )),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 0,
                              runSpacing: 2,
                              textDirection: TextDirection.rtl,
                              children: [
                                for (final w in data.words)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(w.arabic,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                              color: cs.onSurface,
                                            ),
                                            textDirection: TextDirection.rtl),
                                        Text(w.translation,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onSurface.withValues(alpha: 0.6),
                                            )),
                                        if (w.transliteration.isNotEmpty)
                                          Text(w.transliteration,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: cs.onSurface.withValues(alpha: 0.35),
                                              )),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
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

class _AudioLabel extends StatelessWidget {
  const _AudioLabel({required this.audioState});
  final AudioState audioState;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final key = audioState.currentAyahKey;
    if (key == null) return const SizedBox.shrink();

    final parts = key.split(':');
    final surahNum = int.tryParse(parts[0]) ?? 0;
    final surah = getSurah(surahNum);
    final ayahNum = parts.length > 1 ? parts[1] : '';

    if (audioState.repeating) {
      final label = audioState.hasRange
          ? '${audioState.ayahKeys[audioState.rangeStartIndex!]} – ${audioState.ayahKeys[audioState.rangeEndIndex!]}'
          : key;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(surah?.name ?? 'Surah $surahNum',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        Text('Ayah $ayahNum',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _AyahProgressBar extends StatelessWidget {
  const _AyahProgressBar({
    required this.total,
    required this.current,
    required this.color,
    this.rangeStart,
    this.rangeEnd,
  });
  final int total;
  final int current;
  final Color color;
  final int? rangeStart;
  final int? rangeEnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 3),
            painter: _ProgressPainter(
              total: total,
              current: current,
              activeColor: color,
              trackColor: cs.onSurface.withValues(alpha: 0.08),
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
            ),
          );
        },
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.total,
    required this.current,
    required this.activeColor,
    required this.trackColor,
    this.rangeStart,
    this.rangeEnd,
  });

  final int total;
  final int current;
  final Color activeColor;
  final Color trackColor;
  final int? rangeStart;
  final int? rangeEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = trackColor;
    final rr = RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(1.5));
    canvas.drawRRect(rr, trackPaint);

    if (total <= 0) return;
    final fraction = (current + 1) / total;
    final fillWidth = size.width * fraction;
    final fillPaint = Paint()..color = activeColor;
    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, fillWidth, size.height, const Radius.circular(1.5)),
      fillPaint,
    );

    // Range indicator
    if (rangeStart != null && rangeEnd != null) {
      final rangeStartX = size.width * rangeStart! / total;
      final rangeEndX = size.width * (rangeEnd! + 1) / total;
      final rangePaint = Paint()..color = activeColor.withValues(alpha: 0.2);
      canvas.drawRRect(
        RRect.fromLTRBR(rangeStartX, 0, rangeEndX, size.height, const Radius.circular(1.5)),
        rangePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.total != total || old.current != current ||
      old.rangeStart != rangeStart || old.rangeEnd != rangeEnd;
}
