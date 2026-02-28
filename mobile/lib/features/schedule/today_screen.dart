import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memorizer/shared/surah_data.dart';
import 'schedule_provider.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(scheduleProvider.notifier).loadToday());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scheduleProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.pools.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 64, color: cs.primary.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'All caught up!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No assignments for today',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(scheduleProvider.notifier).loadToday(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: state.pools.length,
                    itemBuilder: (_, i) => _PoolSection(pool: state.pools[i]),
                  ),
                );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(scheduleProvider.notifier).loadToday(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _PoolSection extends ConsumerWidget {
  const _PoolSection({required this.pool});
  final TodayPool pool;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final doneCount = pool.items.where((i) => i.status == 'done').length;
    final total = pool.items.length;
    final progress = total > 0 ? doneCount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pool header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.folder_rounded, size: 18, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pool.poolName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Day ${pool.dayNumber} of ${pool.totalDays}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: doneCount == total && total > 0
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$doneCount / $total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: doneCount == total && total > 0
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
          ),
          // Items
          for (final item in pool.items)
            _ScheduleItemCard(item: item),
        ],
      ),
    );
  }
}

class _ScheduleItemCard extends ConsumerWidget {
  const _ScheduleItemCard({required this.item});
  final ScheduleItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDone = item.status == 'done';
    final isPartial = item.status == 'partial';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isDone ? null : () => _showReviewDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone
                      ? cs.primary.withValues(alpha: 0.12)
                      : isPartial
                          ? Colors.orange.withValues(alpha: 0.12)
                          : cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_rounded
                      : isPartial
                          ? Icons.timelapse_rounded
                          : Icons.play_arrow_rounded,
                  size: 20,
                  color: isDone
                      ? cs.primary
                      : isPartial
                          ? Colors.orange
                          : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 14),
              // Surah info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.surahName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.arabic,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDone
                                ? cs.onSurface.withValues(alpha: 0.3)
                                : cs.onSurface.withValues(alpha: 0.7),
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pages ${item.startPage.toStringAsFixed(0)}–${item.endPage.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Navigate to Quran reader
              IconButton(
                icon: Icon(Icons.menu_book_rounded,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                tooltip: 'Read in Quran',
                onPressed: () {
                  final mushafPage = startPageForSurah(item.surahNumber) + item.startPage.toInt();
                  context.push('/read?page=$mushafPage');
                },
              ),
              if (isDone && item.quality != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.quality}/20',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (!isDone)
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int quality = 10;
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(item.surahName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.arabic,
                style: const TextStyle(fontSize: 24),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 20),
              Text(
                '$quality',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Text('out of 20',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Slider(
                value: quality.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$quality',
                onChanged: (v) =>
                    setDialogState(() => quality = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ref
                    .read(scheduleProvider.notifier)
                    .markDone(item.id, quality);
                Navigator.pop(context);
              },
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }
}
