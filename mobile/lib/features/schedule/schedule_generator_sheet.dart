import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/schedule/manage_provider.dart';

class ScheduleGeneratorSheet extends ConsumerStatefulWidget {
  const ScheduleGeneratorSheet({
    super.key,
    required this.poolId,
    required this.poolName,
    required this.scrollController,
  });

  final int poolId;
  final String poolName;
  final ScrollController scrollController;

  @override
  ConsumerState<ScheduleGeneratorSheet> createState() =>
      _ScheduleGeneratorSheetState();
}

class _ScheduleGeneratorSheetState
    extends ConsumerState<ScheduleGeneratorSheet> {
  final _cycleDaysController = TextEditingController(text: '7');
  final _totalRangeController = TextEditingController(text: '7');
  DateTime _startDate = DateTime.now();
  bool _shuffle = false;
  SchedulePreview? _preview;
  bool _previewing = false;
  bool _activating = false;

  @override
  void dispose() {
    _cycleDaysController.dispose();
    _totalRangeController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int? _parseDays(String text) {
    final v = int.tryParse(text.trim());
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _preview_() async {
    final cycleDays = _parseDays(_cycleDaysController.text);
    if (cycleDays == null) return;
    final totalRange = _parseDays(_totalRangeController.text);

    setState(() => _previewing = true);
    final result =
        await ref.read(manageProvider.notifier).previewSchedule(
          poolId: widget.poolId,
          totalDays: cycleDays,
          totalRangeDays: totalRange,
          startDate: _formatDate(_startDate),
          shuffle: _shuffle,
        );
    if (mounted) {
      setState(() {
        _preview = result;
        _previewing = false;
      });
    }
  }

  Future<void> _activate() async {
    final cycleDays = _parseDays(_cycleDaysController.text);
    if (cycleDays == null) return;
    final totalRange = _parseDays(_totalRangeController.text);

    setState(() => _activating = true);
    final ok =
        await ref.read(manageProvider.notifier).activateSchedule(
          poolId: widget.poolId,
          totalDays: cycleDays,
          totalRangeDays: totalRange,
          startDate: _formatDate(_startDate),
          shuffle: _shuffle,
        );
    if (!mounted) return;
    setState(() => _activating = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule activated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to activate schedule'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                'Generate Schedule',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                widget.poolName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Form + preview
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // Cycle length
              TextField(
                controller: _cycleDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cycle length (days)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Total range
              TextField(
                controller: _totalRangeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total range (days)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Start date
              Row(
                children: [
                  Text(
                    'Start date:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(_startDate),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, size: 20),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              // Shuffle
              SwitchListTile(
                title: const Text('Shuffle'),
                value: _shuffle,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _shuffle = v),
              ),
              const SizedBox(height: 8),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previewing ? null : _preview_,
                      child: _previewing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Preview'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _activating ? null : _activate,
                      child: _activating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Activate'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preview section
              if (_preview != null) ...[
                Text(
                  '${_preview!.days.length} days, '
                  '${_preview!.totalPages.toStringAsFixed(1)} pages '
                  '(${_preview!.pagesPerDay.toStringAsFixed(1)} pages/day), '
                  '${_preview!.cycles} cycles',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(_preview!.days.length, (i) {
                  final day = _preview!.days[i];
                  final chunks = day.chunks
                      .map((c) =>
                          '${c.surahName} pp. ${c.startPage.toStringAsFixed(0)}'
                          '-${c.endPage.toStringAsFixed(0)} '
                          '(${c.pages.toStringAsFixed(c.pages == c.pages.roundToDouble() ? 0 : 1)} pages)')
                      .join(', ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Day ${day.dayNumber} (${day.date}): $chunks',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
