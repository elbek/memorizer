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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCompleted = schedule.status == 'completed';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
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
              // Bottom row: progress text + delete button
              Row(
                children: [
                  Text(
                    '${schedule.itemsDone} / ${schedule.itemsTotal} items',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 20,
                          color: cs.error.withValues(alpha: 0.7)),
                      tooltip: 'Delete schedule',
                      onPressed: () =>
                          _confirmDelete(context, ref),
                    ),
                ],
              ),
            ],
          ),
        ),
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
