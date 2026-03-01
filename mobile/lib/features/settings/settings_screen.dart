import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8),
        children: [
          // Appearance section
          _SectionHeader(title: 'Appearance'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    settings.darkMode ? 'On' : 'Off',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: 13),
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      settings.darkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                  value: settings.darkMode,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setDarkMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Quran section
          _SectionHeader(title: 'Quran'),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_stories_rounded,
                    size: 20, color: cs.primary),
              ),
              title: const Text('Mushaf Version'),
              subtitle: Text(
                _mushafLabel(settings.mushafVersion),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              onTap: () => _showMushafPicker(context, ref, settings.mushafVersion),
            ),
          ),
          const SizedBox(height: 8),
          // Audio section
          _SectionHeader(title: 'Audio'),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.headphones_rounded,
                    size: 20, color: cs.primary),
              ),
              title: const Text('Reciter'),
              subtitle: Text(
                _reciterName(settings.reciterId),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              onTap: () => _showReciterPicker(context, ref, settings.reciterId),
            ),
          ),
          const SizedBox(height: 8),
          // Account section
          _SectionHeader(title: 'Account'),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 20, color: Colors.red),
              ),
              title: const Text('Sign Out'),
              subtitle: Text(
                'Log out of your account',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  String _mushafLabel(String v) => switch (v) {
        'v1' => 'Madinah (1405AH)',
        'v2' => 'Madinah (1421AH)',
        'v4' => 'Tajweed Color',
        _ => v,
      };

  void _showMushafPicker(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Mushaf Version',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            for (final entry in [
              ('v1', 'Madinah (1405AH)', 'Classic Madinah print'),
              ('v2', 'Madinah (1421AH)', 'Updated Madinah print'),
              ('v4', 'Tajweed Color', 'Color-coded tajweed rules'),
            ])
              ListTile(
                leading: Radio<String>(
                  value: entry.$1,
                  groupValue: current,
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(settingsProvider.notifier).setMushafVersion(v);
                    }
                    Navigator.pop(context);
                  },
                ),
                title: Text(entry.$2),
                subtitle: Text(entry.$3,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5))),
                onTap: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setMushafVersion(entry.$1);
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static const _reciters = [
    (7, 'Mishari Rashid al-Afasy'),
    (1, 'Abdul Basit (Murattal)'),
    (2, 'Abdul Rahman al-Sudais'),
    (3, 'Abu Bakr al-Shatri'),
    (4, 'Sa\'ud ash-Shuraym'),
    (5, 'Hani ar-Rifai'),
    (6, 'Mahmoud Khalil al-Husary'),
    (8, 'Maher al-Muaiqly'),
    (9, 'Muhammad Ayyub'),
    (10, 'Muhammad Jibreel'),
  ];

  String _reciterName(int id) =>
      _reciters.firstWhere((r) => r.$1 == id, orElse: () => (id, 'Reciter $id')).$2;

  void _showReciterPicker(BuildContext context, WidgetRef ref, int current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Reciter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    for (final entry in _reciters)
                      ListTile(
                        leading: Radio<int>(
                          value: entry.$1,
                          groupValue: current,
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(settingsProvider.notifier).setReciterId(v);
                            }
                            Navigator.pop(context);
                          },
                        ),
                        title: Text(entry.$2),
                        onTap: () {
                          ref.read(settingsProvider.notifier).setReciterId(entry.$1);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
