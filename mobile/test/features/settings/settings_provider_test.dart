import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

void main() {
  group('SettingsNotifier', () {
    test('loads defaults when prefs are empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      final state = container.read(settingsProvider);

      expect(state.darkMode, false);
      expect(state.mushafVersion, 'v1');
      container.dispose();
    });

    test('loads saved preferences', () async {
      SharedPreferences.setMockInitialValues({'darkMode': true, 'mushafVersion': 'v2'});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      final state = container.read(settingsProvider);

      expect(state.darkMode, true);
      expect(state.mushafVersion, 'v2');
      container.dispose();
    });

    test('setDarkMode persists and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      await container.read(settingsProvider.notifier).setDarkMode(true);

      expect(container.read(settingsProvider).darkMode, true);
      expect(prefs.getBool('darkMode'), true);
      container.dispose();
    });

    test('setMushafVersion persists and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      await container.read(settingsProvider.notifier).setMushafVersion('v4');

      expect(container.read(settingsProvider).mushafVersion, 'v4');
      expect(prefs.getString('mushafVersion'), 'v4');
      container.dispose();
    });
  });
}
