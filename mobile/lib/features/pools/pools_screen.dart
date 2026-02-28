import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pool_detail_screen.dart';
import 'pools_provider.dart';

class PoolsScreen extends ConsumerStatefulWidget {
  const PoolsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  ConsumerState<PoolsScreen> createState() => _PoolsScreenState();
}

class _PoolsScreenState extends ConsumerState<PoolsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(poolsProvider.notifier).loadPools());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(poolsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = state.loading
        ? const Center(child: CircularProgressIndicator())
        : state.pools.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open_rounded,
                        size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text('No pools yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: state.pools.length,
                itemBuilder: (_, i) {
                  final pool = state.pools[i];
                  return _PoolCard(pool: pool);
                },
              );

    final fab = FloatingActionButton(
      onPressed: () => _showCreateDialog(context),
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      child: const Icon(Icons.add_rounded),
    );

    if (widget.embedded) {
      return Scaffold(body: body, floatingActionButton: fab);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pools')),
      body: body,
      floatingActionButton: fab,
    );
  }

  void _showCreateDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Pool'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Pool name',
            hintText: 'e.g. Juz Amma',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(poolsProvider.notifier).createPool(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PoolCard extends ConsumerWidget {
  const _PoolCard({required this.pool});
  final Pool pool;

  static const _poolIcons = <String, IconData>{
    'Daily': Icons.today_rounded,
    'Manzil': Icons.auto_stories_rounded,
    'Sabak': Icons.school_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = _poolIcons[pool.name] ?? Icons.folder_rounded;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PoolDetailScreen(pool: pool)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pool.isSystem
                      ? cs.primary.withValues(alpha: 0.1)
                      : cs.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: pool.isSystem ? cs.primary : cs.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pool.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pool.isSystem ? 'System pool' : 'Custom pool',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (!pool.isSystem)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                  onPressed: () => _confirmDelete(context, ref),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Pool'),
        content: Text('Delete "${pool.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              ref.read(poolsProvider.notifier).deletePool(pool.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
