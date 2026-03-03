import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _sortBy = 'surah';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(manageProvider.notifier).loadReports());
  }

  List<SurahReport> _sorted(List<SurahReport> reports) {
    final list = List<SurahReport>.from(reports);
    switch (_sortBy) {
      case 'times':
        list.sort((a, b) => b.timesRecited.compareTo(a.timesRecited));
      case 'quality':
        list.sort((a, b) => b.avgQuality.compareTo(a.avgQuality));
      case 'recent':
        list.sort((a, b) => b.lastRecited.compareTo(a.lastRecited));
      default:
        list.sort((a, b) => a.surahNumber.compareTo(b.surahNumber));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manageProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final sorted = _sorted(state.reports);

    final body = state.reportsLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => ref.read(manageProvider.notifier).loadReports(),
            child: Column(
              children: [
                // Summary card
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: _SummaryCard(reports: state.reports),
                ),
                // Sort dropdown row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Sort by',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(12),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'surah', child: Text('Surah #')),
                          DropdownMenuItem(value: 'times', child: Text('Times recited')),
                          DropdownMenuItem(value: 'quality', child: Text('Avg quality')),
                          DropdownMenuItem(value: 'recent', child: Text('Last recited')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sortBy = v);
                        },
                      ),
                    ],
                  ),
                ),
                // Surah report list
                Expanded(
                  child: sorted.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'No recitations yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: sorted.length,
                          itemBuilder: (_, i) => _SurahReportRow(report: sorted[i]),
                        ),
                ),
              ],
            ),
          );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.read(manageProvider.notifier).loadReports(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.reports});
  final List<SurahReport> reports;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (reports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'No recitations yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final totalRecitations =
        reports.fold<int>(0, (sum, r) => sum + r.timesRecited);
    final totalWeighted =
        reports.fold<double>(0, (sum, r) => sum + r.avgQuality * r.timesRecited);
    final weightedAvg =
        totalRecitations > 0 ? totalWeighted / totalRecitations : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalRecitations',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total recitations',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  weightedAvg.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Avg quality',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahReportRow extends StatelessWidget {
  const _SurahReportRow({required this.report});
  final SurahReport report;

  Color _qualityColor(ColorScheme cs) {
    if (report.avgQuality >= 15) return cs.primary;
    if (report.avgQuality >= 10) return Colors.amber;
    return Colors.red;
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final qColor = _qualityColor(cs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Surah number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${report.surahNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + arabic + last recited
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        report.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.arabic,
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last: ${_formatDate(report.lastRecited)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Times recited badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${report.timesRecited}x',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avg quality indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: qColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              report.avgQuality.toStringAsFixed(1),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: qColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
