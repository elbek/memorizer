import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/pools/pools_provider.dart';
import 'package:memorizer/features/quran/surah_list_screen.dart';
import 'package:memorizer/shared/surah_data.dart';

class PoolDetailScreen extends ConsumerStatefulWidget {
  const PoolDetailScreen({super.key, required this.pool});
  final Pool pool;

  @override
  ConsumerState<PoolDetailScreen> createState() => _PoolDetailScreenState();
}

class _PoolDetailScreenState extends ConsumerState<PoolDetailScreen> {
  List<PoolSurah> _poolSurahs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    setState(() => _loading = true);
    try {
      final surahs = await ref
          .read(poolsProvider.notifier)
          .loadPoolSurahs(widget.pool.id);
      if (mounted) setState(() { _poolSurahs = surahs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeSurah(PoolSurah ps) async {
    try {
      await ref.read(poolsProvider.notifier).removeSurah(widget.pool.id, ps.surahNumber);
      await _loadSurahs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showAddPicker() async {
    final existingNumbers = _poolSurahs.map((s) => s.surahNumber).toSet();
    // Load surah→pool mapping for all pools so we can show which pool a surah is in.
    final surahPoolMap = await ref.read(poolsProvider.notifier).loadAllSurahAssignments();
    // Remove surahs that are in the current pool (they're already shown in main list).
    for (final n in existingNumbers) {
      surahPoolMap.remove(n);
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _AddPickerSheet(
          poolId: widget.pool.id,
          existingSurahNumbers: existingNumbers,
          surahPoolMap: surahPoolMap,
          scrollController: scrollController,
          onDone: () {
            Navigator.pop(context);
            _loadSurahs();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalPages = _poolSurahs.fold<double>(0, (s, e) => s + e.pages);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pool.name),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: cs.primary.withValues(alpha: 0.04),
            child: Row(
              children: [
                Icon(Icons.folder_rounded,
                    size: 18, color: cs.primary.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  '${_poolSurahs.length} surahs',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${totalPages.toStringAsFixed(totalPages == totalPages.roundToDouble() ? 0 : 1)} pages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Pool surahs list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _poolSurahs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.library_add_rounded,
                                size: 56,
                                color: cs.onSurface.withValues(alpha: 0.15)),
                            const SizedBox(height: 12),
                            Text(
                              'No surahs yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap + to add surahs or juz',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _poolSurahs.length,
                        padding: const EdgeInsets.only(top: 4, bottom: 80),
                        itemBuilder: (_, i) {
                          final ps = _poolSurahs[i];
                          return Dismissible(
                            key: ValueKey(ps.surahNumber),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: cs.error.withValues(alpha: 0.1),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: cs.error),
                            ),
                            onDismissed: (_) => _removeSurah(ps),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Row(
                                children: [
                                  SurahNumberStar(
                                    number: ps.surahNumber,
                                    size: 36,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ps.name,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${ps.pages} pages',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    ps.arabic,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPicker,
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

/// Bottom sheet with two tabs: Surahs (multi-select) and Juz (multi-select).
class _AddPickerSheet extends ConsumerStatefulWidget {
  const _AddPickerSheet({
    required this.poolId,
    required this.existingSurahNumbers,
    required this.surahPoolMap,
    required this.scrollController,
    required this.onDone,
  });
  final int poolId;
  final Set<int> existingSurahNumbers;
  /// surahNumber → poolName for surahs in OTHER pools (not the current one).
  final Map<int, String> surahPoolMap;
  final ScrollController scrollController;
  final VoidCallback onDone;

  @override
  ConsumerState<_AddPickerSheet> createState() => _AddPickerSheetState();
}

class _AddPickerSheetState extends ConsumerState<_AddPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedSurahs = {};
  final Set<int> _selectedJuz = {};
  String _query = '';
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SurahInfo> get _availableSurahs {
    final available =
        surahs.where((s) => !widget.existingSurahNumbers.contains(s.number));
    if (_query.isEmpty) return available.toList();
    return available
        .where((s) =>
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            s.arabic.contains(_query) ||
            '${s.number}' == _query)
        .toList();
  }

  int get _totalSelected => _selectedSurahs.length + _selectedJuz.length;

  Future<void> _confirmAdd() async {
    if (_totalSelected == 0) return;
    setState(() => _adding = true);
    final notifier = ref.read(poolsProvider.notifier);
    try {
      // Add individual surahs
      for (final num in _selectedSurahs) {
        await notifier.addSurah(widget.poolId, num);
      }
      // Add juz
      for (final juz in _selectedJuz) {
        await notifier.addJuz(widget.poolId, juz);
      }
      widget.onDone();
    } catch (e) {
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
        );
      }
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
        // Title + tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              Text(
                'Add to Pool',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_totalSelected > 0)
                FilledButton(
                  onPressed: _adding ? null : _confirmAdd,
                  child: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Add $_totalSelected'),
                ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Surahs'),
            Tab(text: 'Juz'),
          ],
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSurahTab(theme, cs),
              _buildJuzTab(theme, cs),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSurahTab(ThemeData theme, ColorScheme cs) {
    final filtered = _availableSurahs;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
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
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (_, i) {
              final surah = filtered[i];
              final selected = _selectedSurahs.contains(surah.number);
              final otherPool = widget.surahPoolMap[surah.number];
              return InkWell(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedSurahs.remove(surah.number);
                    } else {
                      _selectedSurahs.add(surah.number);
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      SurahNumberStar(
                        number: surah.number,
                        size: 34,
                        color: selected ? cs.primary : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              surah.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? cs.primary : cs.onSurface,
                              ),
                            ),
                            if (otherPool != null)
                              Text(
                                'In $otherPool',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: cs.tertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            else
                              Text(
                                '${surah.ayahCount} ayahs  •  ${surah.pages} pages',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        surah.arabic,
                        style: TextStyle(
                          fontSize: 18,
                          color: selected
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.45),
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 22,
                        color: selected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzTab(ThemeData theme, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(30, (i) {
          final juz = i + 1;
          final selected = _selectedJuz.contains(juz);
          return ChoiceChip(
            label: Text(
              'Juz $juz',
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : cs.onSurface,
              ),
            ),
            selected: selected,
            selectedColor: cs.primary,
            backgroundColor: cs.onSurface.withValues(alpha: 0.05),
            side: BorderSide(
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.12),
            ),
            showCheckmark: false,
            onSelected: (_) {
              setState(() {
                if (selected) {
                  _selectedJuz.remove(juz);
                } else {
                  _selectedJuz.add(juz);
                }
              });
            },
          );
        }),
      ),
    );
  }
}
