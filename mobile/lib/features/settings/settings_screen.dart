import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/quran/translation_provider.dart';
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
          // Translation section
          _SectionHeader(title: 'Translation'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.translate_rounded, size: 20, color: cs.primary),
                  ),
                  title: const Text('Translations'),
                  subtitle: Text(
                    _translationSummary(settings.selectedTranslationIds),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.3)),
                  onTap: () => _showTranslationPicker(context, ref, settings.selectedTranslationIds),
                ),
                SwitchListTile(
                  title: const Text('Word-by-Word'),
                  subtitle: Text(
                    'English word-by-word translation',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.text_fields_rounded, size: 20, color: cs.primary),
                  ),
                  value: settings.wordByWordEnabled,
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).setWordByWordEnabled(v),
                ),
              ],
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

  String _translationSummary(List<int> ids) {
    if (ids.isEmpty) return 'None selected';
    const knownNames = {
      20: 'Saheeh International',
      85: 'Abdel Haleem',
      84: 'Mufti Taqi Usmani',
      95: 'Maududi',
      19: 'Pickthall',
      22: 'Yusuf Ali',
      203: 'Al-Hilali & Khan',
      149: 'Bridges',
    };
    final firstName = knownNames[ids.first];
    if (ids.length == 1) return firstName ?? 'Translation #${ids.first}';
    return '${firstName ?? 'Translation #${ids.first}'} +${ids.length - 1} more';
  }

  void _showTranslationPicker(BuildContext context, WidgetRef ref, List<int> currentIds) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _TranslationPickerScreen(
        selectedIds: currentIds,
        onChanged: (ids) {
          ref.read(settingsProvider.notifier).setSelectedTranslationIds(ids);
        },
      ),
    ));
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
    (2, 'AbdulBaset AbdulSamad (Murattal)'),
    (1, 'AbdulBaset AbdulSamad (Mujawwad)'),
    (3, 'Abdur-Rahman as-Sudais'),
    (4, 'Abu Bakr al-Shatri'),
    (10, 'Sa\'ud ash-Shuraym'),
    (5, 'Hani ar-Rifai'),
    (6, 'Mahmoud Khalil Al-Husary'),
    (12, 'Mahmoud Khalil Al-Husary (Muallim)'),
    (9, 'Mohamed Siddiq al-Minshawi'),
    (97, 'Yasser Ad-Dussary'),
    (158, 'Ali Jaber'),
    (13, 'Saad Al-Ghamdi'),
    (104, 'Nasser Al-Qatami'),
    (19, 'Ahmed Al-Ajmy'),
    (161, 'Khalifah Al-Tunaiji'),
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

class _TranslationPickerScreen extends ConsumerStatefulWidget {
  const _TranslationPickerScreen({
    required this.selectedIds,
    required this.onChanged,
  });
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;

  @override
  ConsumerState<_TranslationPickerScreen> createState() =>
      _TranslationPickerScreenState();
}

class _TranslationPickerScreenState
    extends ConsumerState<_TranslationPickerScreen> {
  late Set<int> _selected;
  List<TranslationResource>? _translations;
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedIds};
    _loadTranslations();
  }

  Future<void> _loadTranslations() async {
    try {
      final list = await ref
          .read(translationProvider.notifier)
          .fetchAvailableTranslations();
      if (mounted) setState(() { _translations = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<TranslationResource>> get _grouped {
    if (_translations == null) return {};
    var list = _translations!;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) =>
          t.name.toLowerCase().contains(q) ||
          t.authorName.toLowerCase().contains(q) ||
          t.languageName.toLowerCase().contains(q)).toList();
    }
    final map = <String, List<TranslationResource>>{};
    for (final t in list) {
      final lang = t.languageName.isNotEmpty
          ? '${t.languageName[0].toUpperCase()}${t.languageName.substring(1)}'
          : 'Other';
      (map[lang] ??= []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;
    final sortedLangs = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'English') return -1;
        if (b == 'English') return 1;
        return a.compareTo(b);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translations'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onChanged(_selected.toList());
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search translations...',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: cs.onSurface.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final lang in sortedLangs) ...[
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            lang.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: cs.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                        for (final t in grouped[lang]!)
                          CheckboxListTile(
                            value: _selected.contains(t.id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(t.id);
                                } else {
                                  _selected.remove(t.id);
                                }
                              });
                            },
                            title: Text(t.name,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: t.authorName.isNotEmpty
                                ? Text(t.authorName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface
                                          .withValues(alpha: 0.5),
                                    ))
                                : null,
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                          ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
