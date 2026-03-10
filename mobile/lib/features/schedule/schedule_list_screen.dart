import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_provider.dart';

class ScheduleListScreen extends ConsumerStatefulWidget {
  const ScheduleListScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends ConsumerState<ScheduleListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(manageProvider.notifier).loadSchedules());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manageProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = state.schedulesLoading
        ? const Center(child: CircularProgressIndicator())
        : state.schedules.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 64, color: cs.primary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No schedules yet',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a schedule to start memorizing',
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
                    ref.read(manageProvider.notifier).loadSchedules(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: state.schedules.length,
                  itemBuilder: (_, i) =>
                      _ScheduleCard(schedule: state.schedules[i]),
                ),
              );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () =>
                ref.read(manageProvider.notifier).loadSchedules(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  const _ScheduleCard({required this.schedule});
  final ScheduleSummary schedule;

  bool get _isCreatedToday {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return schedule.createdAt.startsWith(todayStr);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCompleted = schedule.status == 'completed';
    final isActive = schedule.status == 'active';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showHistory(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: pool name + status badge
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded,
                        size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      schedule.poolName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatusBadge(status: schedule.status),
                ],
              ),
              const SizedBox(height: 10),
              // Date range
              Text(
                '${schedule.startDate} \u2013 ${schedule.endDate}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: schedule.progress,
                  minHeight: 4,
                  backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(
                    isCompleted ? cs.primary : cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Bottom row: progress text + actions
              Row(
                children: [
                  Text(
                    '${schedule.itemsDone} / ${schedule.itemsTotal} items',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (isActive) ...[
                    // End button for active schedules
                    IconButton(
                      icon: Icon(Icons.stop_circle_outlined,
                          size: 20,
                          color: Colors.orange.withValues(alpha: 0.8)),
                      tooltip: 'End schedule',
                      onPressed: () => _confirmEnd(context, ref),
                    ),
                    // Delete only if created today
                    if (_isCreatedToday)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 20,
                            color: cs.error.withValues(alpha: 0.7)),
                        tooltip: 'Delete schedule',
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                  ],
                  // Completed schedules are preserved (no delete)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ScheduleHistoryScreen(scheduleId: schedule.id, poolName: schedule.poolName),
      ),
    );
  }

  void _confirmEnd(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End schedule?'),
        content: Text(
          'This will end the active schedule for "${schedule.poolName}" and preserve your recitation history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              ref.read(manageProvider.notifier).endSchedule(schedule.id);
              Navigator.pop(context);
            },
            child: const Text('End Schedule'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete schedule?'),
        content: Text(
          'This will permanently delete the schedule for "${schedule.poolName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              ref.read(manageProvider.notifier).deleteSchedule(schedule.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleHistoryScreen extends ConsumerStatefulWidget {
  const _ScheduleHistoryScreen({required this.scheduleId, required this.poolName});
  final int scheduleId;
  final String poolName;

  @override
  ConsumerState<_ScheduleHistoryScreen> createState() => _ScheduleHistoryScreenState();
}

class _ScheduleHistoryScreenState extends ConsumerState<_ScheduleHistoryScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  // Filters
  String _statusFilter = 'all'; // all, done, partial, pending, missed
  String _sortBy = 'day'; // day, quality_asc, quality_desc
  int? _minQuality;
  int? _maxQuality;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(manageProvider.notifier).loadScheduleHistory(widget.scheduleId);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_data == null) return [];
    final items = (_data!['items'] as List).cast<Map<String, dynamic>>();

    var filtered = items.where((item) {
      if (_statusFilter != 'all' && item['status'] != _statusFilter) return false;
      final q = item['quality'] as int?;
      if (_minQuality != null && (q == null || q < _minQuality!)) return false;
      if (_maxQuality != null && (q == null || q > _maxQuality!)) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'quality_asc':
        filtered.sort((a, b) => ((a['quality'] as int?) ?? 0).compareTo((b['quality'] as int?) ?? 0));
        break;
      case 'quality_desc':
        filtered.sort((a, b) => ((b['quality'] as int?) ?? 0).compareTo((a['quality'] as int?) ?? 0));
        break;
      default: // day
        filtered.sort((a, b) => (a['day_number'] as int).compareTo(b['day_number'] as int));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.poolName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Failed to load history'))
              : Column(
                  children: [
                    // Stats summary
                    _buildStats(theme, cs),
                    // Filters
                    _buildFilters(theme, cs),
                    // Items list
                    Expanded(child: _buildItemsList(theme, cs)),
                  ],
                ),
    );
  }

  Widget _buildStats(ThemeData theme, ColorScheme cs) {
    final stats = _data!['stats'] as Map<String, dynamic>;
    final sched = _data!['schedule'] as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.all(16),
      color: cs.primary.withValues(alpha: 0.04),
      child: Column(
        children: [
          Row(
            children: [
              _StatChip(label: 'Done', value: '${stats['done']}', color: cs.primary),
              const SizedBox(width: 6),
              _StatChip(label: 'Partial', value: '${stats['partial']}', color: Colors.orange),
              const SizedBox(width: 6),
              _StatChip(label: 'Missed', value: '${stats['missed'] ?? 0}', color: Colors.red),
              const SizedBox(width: 6),
              _StatChip(label: 'Avg', value: '${stats['avg_quality']}/20', color: cs.tertiary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${sched['start_date']} \u2013 ${sched['end_date']}  \u00B7  ${sched['status']}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Status filter + sort
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'done', label: Text('Done')),
                    ButtonSegment(value: 'partial', label: Text('Partial')),
                    ButtonSegment(value: 'missed', label: Text('Missed')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (v) => setState(() => _statusFilter = v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(theme.textTheme.labelSmall),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Sort:', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('By Day'),
                selected: _sortBy == 'day',
                onSelected: (_) => setState(() => _sortBy = 'day'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Best'),
                selected: _sortBy == 'quality_desc',
                onSelected: (_) => setState(() => _sortBy = 'quality_desc'),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: const Text('Worst'),
                selected: _sortBy == 'quality_asc',
                onSelected: (_) => setState(() => _sortBy = 'quality_asc'),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              // Quality range filter
              IconButton(
                icon: Icon(Icons.tune_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
                tooltip: 'Filter by quality',
                onPressed: () => _showQualityFilter(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualityFilter(BuildContext context) {
    int min = _minQuality ?? 1;
    int max = _maxQuality ?? 20;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Quality Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$min - $max'),
              RangeSlider(
                values: RangeValues(min.toDouble(), max.toDouble()),
                min: 1,
                max: 20,
                divisions: 19,
                labels: RangeLabels('$min', '$max'),
                onChanged: (v) => setDialogState(() { min = v.start.round(); max = v.end.round(); }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() { _minQuality = null; _maxQuality = null; });
                Navigator.pop(context);
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                setState(() { _minQuality = min; _maxQuality = max; });
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme, ColorScheme cs) {
    final items = _filteredItems;
    if (items.isEmpty) {
      return Center(
        child: Text('No items match filters', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final isDone = item['status'] == 'done';
        final isPartial = item['status'] == 'partial';
        final isMissed = item['status'] == 'missed';
        final quality = item['quality'] as int?;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone
                      ? cs.primary.withValues(alpha: 0.12)
                      : isPartial
                          ? Colors.orange.withValues(alpha: 0.12)
                          : isMissed
                              ? Colors.red.withValues(alpha: 0.12)
                              : cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : isPartial ? Icons.timelapse_rounded : isMissed ? Icons.close_rounded : Icons.circle_outlined,
                  size: 16,
                  color: isDone ? cs.primary : isPartial ? Colors.orange : isMissed ? Colors.red : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['surah_name']}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Day ${item['day_number']} \u00B7 ${item['date']} \u00B7 pp. ${(item['start_page'] as num).toStringAsFixed(0)}-${(item['end_page'] as num).toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Quality badge
              if (isDone && quality != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _qualityColor(quality).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$quality/20',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _qualityColor(quality),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _qualityColor(int quality) {
    if (quality >= 15) return Colors.green;
    if (quality >= 10) return Colors.orange;
    return Colors.red;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted = status == 'completed';
    final color = isCompleted ? cs.primary : Colors.orange;
    final label = isCompleted ? 'Completed' : 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
      ),
    );
  }
}
