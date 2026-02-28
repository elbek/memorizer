import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({this.darkMode = false, this.mushafVersion = 'v1'});
  final bool darkMode;
  final String mushafVersion;
  SettingsState copyWith({bool? darkMode, String? mushafVersion}) =>
      SettingsState(darkMode: darkMode ?? this.darkMode, mushafVersion: mushafVersion ?? this.mushafVersion);
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return SettingsState(
      darkMode: prefs.getBool('darkMode') ?? false,
      mushafVersion: prefs.getString('mushafVersion') ?? 'v1',
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
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
