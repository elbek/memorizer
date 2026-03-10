import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_provider.dart';
import 'schedule_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late int _year;
  late int _month;
  Map<String, DayStatus> _dayStatuses = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    Future.microtask(() => _loadMonth());
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    await ref.read(manageProvider.notifier).loadSchedules();
    final schedules = ref.read(manageProvider).schedules;

    final firstOfMonth = DateTime(_year, _month, 1);
    final lastOfMonth = DateTime(_year, _month + 1, 0);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final Map<String, DayStatus> statuses = {};

    for (final s in schedules) {
      final start = DateTime.parse(s.startDate);
      final end = DateTime.parse(s.endDate);

      // Skip schedules that don't overlap with this month
      if (end.isBefore(firstOfMonth) || start.isAfter(lastOfMonth)) continue;

      final rangeStart = start.isBefore(firstOfMonth) ? firstOfMonth : start;
      final rangeEnd = end.isAfter(lastOfMonth) ? lastOfMonth : end;

      for (var d = rangeStart;
          !d.isAfter(rangeEnd);
          d = d.add(const Duration(days: 1))) {
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

        DayStatus status;
        if (s.itemsDone == s.itemsTotal && s.itemsTotal > 0) {
          status = DayStatus.done;
        } else if (s.itemsPartial > 0) {
          status = DayStatus.partial;
        } else if (d.isBefore(todayDate) && s.itemsPending > 0) {
          status = DayStatus.missed;
        } else {
          status = DayStatus.upcoming;
        }

        // Keep the most important status if multiple schedules overlap
        final existing = statuses[key];
        if (existing == null || _statusPriority(status) > _statusPriority(existing)) {
          statuses[key] = status;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _dayStatuses = statuses;
      _loading = false;
    });
  }

  int _statusPriority(DayStatus s) {
    switch (s) {
      case DayStatus.missed:
        return 4;
      case DayStatus.partial:
        return 3;
      case DayStatus.done:
        return 2;
      case DayStatus.upcoming:
        return 1;
      case DayStatus.empty:
        return 0;
    }
  }

  void _prevMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _loadMonth();
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
    _loadMonth();
  }

  void _showDayDetail(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayDetailSheet(dateStr: dateStr, ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final firstOfMonth = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7; // Sunday = 0

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    final body = Column(
      children: [
        // Month navigation header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _prevMonth,
              ),
              Text(
                '${monthNames[_month - 1]} $_year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Day-of-week headers
        Row(
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // Empty cells for offset
              for (int i = 0; i < startWeekday; i++) const SizedBox.shrink(),
              // Day cells
              for (int day = 1; day <= daysInMonth; day++)
                _buildDayCell(day, todayKey, cs, theme),
            ],
          ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SingleChildScrollView(child: body),
    );
  }

  Widget _buildDayCell(
      int day, String todayKey, ColorScheme cs, ThemeData theme) {
    final key =
        '$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final isToday = key == todayKey;
    final status = _dayStatuses[key];

    Color? dotColor;
    switch (status) {
      case DayStatus.done:
        dotColor = const Color(0xFF4CAF50);
        break;
      case DayStatus.partial:
        dotColor = const Color(0xFFFFC107);
        break;
      case DayStatus.missed:
        dotColor = const Color(0xFFF44336);
        break;
      case DayStatus.upcoming:
        dotColor = const Color(0xFF9E9E9E);
        break;
      case DayStatus.empty:
      case null:
        dotColor = null;
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showDayDetail(DateTime(_year, _month, day)),
      child: Container(
        decoration: isToday
            ? BoxDecoration(
                border: Border.all(color: cs.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? cs.primary : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor ?? Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({required this.dateStr, required this.ref});
  final String dateStr;
  final WidgetRef ref;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  List<TodayPool>? _pools;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDay();
  }

  Future<void> _fetchDay() async {
    final pools =
        await widget.ref.read(manageProvider.notifier).loadDay(widget.dateStr);
    if (!mounted) return;
    setState(() {
      _pools = pools;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.dateStr,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_pools == null || _pools!.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No assignments for this day',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              ..._pools!.map((pool) => _buildPoolDetail(pool, theme, cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolDetail(TodayPool pool, ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pool header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder_rounded, size: 16, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pool.poolName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Day ${pool.dayNumber}/${pool.totalDays}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Items
          for (final item in pool.items) _buildItemRow(item, theme, cs),
        ],
      ),
    );
  }

  Widget _buildItemRow(ScheduleItem item, ThemeData theme, ColorScheme cs) {
    final isDone = item.status == 'done';
    final isPartial = item.status == 'partial';
    final isMissed = item.status == 'missed';
    // Treat pending items on past dates as missed for display
    final isPastPending = item.status == 'pending' &&
        DateTime.tryParse(widget.dateStr)?.isBefore(
            DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) == true;
    final showMissed = isMissed || isPastPending;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                      : showMissed
                          ? Colors.red.withValues(alpha: 0.12)
                          : cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isDone
                  ? Icons.check_rounded
                  : isPartial
                      ? Icons.timelapse_rounded
                      : showMissed
                          ? Icons.close_rounded
                          : Icons.circle_outlined,
              size: 16,
              color: isDone
                  ? cs.primary
                  : isPartial
                      ? Colors.orange
                      : showMissed
                          ? Colors.red
                          : cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.surahName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? cs.onSurface.withValues(alpha: 0.4)
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.arabic,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDone
                            ? cs.onSurface.withValues(alpha: 0.3)
                            : cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
                Text(
                  'Pages ${item.startPage.toStringAsFixed(0)}-${item.endPage.toStringAsFixed(0)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (isDone && item.quality != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${item.quality}/20',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
