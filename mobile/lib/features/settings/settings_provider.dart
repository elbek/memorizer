import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    this.darkMode = false,
    this.mushafVersion = 'v1',
    this.reciterId = 7,
    this.selectedTranslationIds = const [20],
    this.wordByWordEnabled = true,
  });
  final bool darkMode;
  final String mushafVersion;
  final int reciterId;
  final List<int> selectedTranslationIds;
  final bool wordByWordEnabled;
  SettingsState copyWith({
    bool? darkMode,
    String? mushafVersion,
    int? reciterId,
    List<int>? selectedTranslationIds,
    bool? wordByWordEnabled,
  }) =>
      SettingsState(
        darkMode: darkMode ?? this.darkMode,
        mushafVersion: mushafVersion ?? this.mushafVersion,
        reciterId: reciterId ?? this.reciterId,
        selectedTranslationIds: selectedTranslationIds ?? this.selectedTranslationIds,
        wordByWordEnabled: wordByWordEnabled ?? this.wordByWordEnabled,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final translationIdsJson = prefs.getString('selectedTranslationIds');
    List<int> selectedTranslationIds;
    if (translationIdsJson != null) {
      try {
        selectedTranslationIds = List<int>.unmodifiable(
            (jsonDecode(translationIdsJson) as List).cast<int>());
      } catch (_) {
        selectedTranslationIds = const [20];
      }
    } else {
      selectedTranslationIds = const [20];
    }
    return SettingsState(
      darkMode: prefs.getBool('darkMode') ?? false,
      mushafVersion: prefs.getString('mushafVersion') ?? 'v1',
      reciterId: prefs.getInt('reciterId') ?? 7,
      selectedTranslationIds: selectedTranslationIds,
      wordByWordEnabled: prefs.getBool('wordByWordEnabled') ?? true,
    );
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('darkMode', value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> setMushafVersion(String version) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('mushafVersion', version);
    state = state.copyWith(mushafVersion: version);
  }

  Future<void> setReciterId(int id) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setInt('reciterId', id);
    state = state.copyWith(reciterId: id);
  }

  Future<void> setSelectedTranslationIds(List<int> ids) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString('selectedTranslationIds', jsonEncode(ids));
    state = state.copyWith(selectedTranslationIds: List<int>.unmodifiable(ids));
  }

  Future<void> setWordByWordEnabled(bool value) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('wordByWordEnabled', value);
    state = state.copyWith(wordByWordEnabled: value);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
