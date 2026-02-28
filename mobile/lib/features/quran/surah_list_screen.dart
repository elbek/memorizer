import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/features/quran/bookmark_provider.dart';
import 'package:memorizer/features/settings/settings_provider.dart';
import 'package:memorizer/shared/surah_data.dart';

/// Key for storing recent surah numbers in SharedPreferences.
const _recentKey = 'recent_surahs';
const _maxRecent = 5;

/// Provider that reads/writes recent surah numbers from SharedPreferences.
final recentSurahsProvider =
    NotifierProvider<RecentSurahsNotifier, List<int>>(RecentSurahsNotifier.new);

class RecentSurahsNotifier extends Notifier<List<int>> {
  @override
  List<int> build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final stored = prefs.getStringList(_recentKey) ?? [];
    return stored.map(int.tryParse).whereType<int>().take(_maxRecent).toList();
  }

  Future<void> addRecent(int surahNumber) async {
    final prefs = ref.read(sharedPrefsProvider);
    final current = List<int>.from(state);
    current.remove(surahNumber);
    current.insert(0, surahNumber);
    if (current.length > _maxRecent) current.removeLast();
    await prefs.setStringList(
        _recentKey, current.map((e) => '$e').toList());
    state = current;
  }
}

class SurahListScreen extends ConsumerWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSurahsProvider);
    final bookmarks = ref.watch(bookmarkProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran'),
        actions: [
          if (bookmarks.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${bookmarks.length}'),
                child: const Icon(Icons.bookmark_rounded, size: 22),
              ),
              tooltip: 'Bookmarks',
              onPressed: () => _showBookmarksSheet(context, ref),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Recent surahs section
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Recent',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final surah = getSurah(recent[i]);
                    if (surah == null) return const SizedBox.shrink();
                    return _RecentCard(
                      surah: surah,
                      onTap: () => _navigateToSurah(context, ref, surah),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: Divider(
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                  color: cs.onSurface.withValues(alpha: 0.08)),
            ),
          ],
          // All surahs header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'All Surahs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          // 114 surahs list
          SliverList.builder(
            itemCount: surahs.length,
            itemBuilder: (_, i) {
              final surah = surahs[i];
              return _SurahTile(
                surah: surah,
                onTap: () => _navigateToSurah(context, ref, surah),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _navigateToSurah(
      BuildContext context, WidgetRef ref, SurahInfo surah) {
    ref.read(recentSurahsProvider.notifier).addRecent(surah.number);
    final page = startPageForSurah(surah.number);
    context.push('/read?page=$page');
  }

  void _showBookmarksSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => _BookmarksSheetContent(
          scrollController: scrollController,
          onPageTap: (page) {
            Navigator.pop(ctx);
            context.push('/read?page=$page');
          },
        ),
      ),
    );
  }
}

class _BookmarksSheetContent extends ConsumerWidget {
  const _BookmarksSheetContent({
    required this.scrollController,
    required this.onPageTap,
  });
  final ScrollController scrollController;
  final ValueChanged<int> onPageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final sorted = bookmarks.toList()..sort();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              Text(
                'Bookmarks (${sorted.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _confirmClearAll(context, ref);
                },
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: cs.error,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Bookmark list
        Expanded(
          child: sorted.isEmpty
              ? Center(
                  child: Text(
                    'No bookmarks',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: sorted.length,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (_, i) {
                    final page = sorted[i];
                    final surah = surahForPage(page);
                    return ListTile(
                      leading: Icon(Icons.bookmark_rounded,
                          color: cs.primary, size: 22),
                      title: Text(
                        surah.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Page $page',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                        onPressed: () =>
                            ref.read(bookmarkProvider.notifier).toggle(page),
                      ),
                      onTap: () => onPageTap(page),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    // Capture before showing dialog to avoid using ref after unmount.
    final notifier = ref.read(bookmarkProvider.notifier);
    final all = ref.read(bookmarkProvider).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Bookmarks'),
        content: const Text('Remove all bookmarks? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              for (final page in all) {
                notifier.toggle(page);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.surah, required this.onTap});
  final SurahInfo surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 130,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [cs.primary.withValues(alpha: 0.15), cs.primary.withValues(alpha: 0.06)]
                  : [cs.primary.withValues(alpha: 0.08), cs.primary.withValues(alpha: 0.02)],
            ),
            border: Border.all(
              color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                surah.arabic,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Text(
                surah.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Star/diamond ornamental shape with surah number inside.
class SurahNumberStar extends StatelessWidget {
  const SurahNumberStar({super.key, required this.number, this.size = 40, this.color});
  final int number;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StarPainter(color: c),
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;
    final innerR = r * 0.72;
    const points = 8;
    final path = Path();

    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? r : innerR;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.onTap});
  final SurahInfo surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            SurahNumberStar(number: surah.number),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${surah.ayahCount} ayahs  •  Juz ${surah.juz}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              surah.arabic,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}
