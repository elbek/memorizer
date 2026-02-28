import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

const _bookmarkKey = 'bookmarked_pages';

class BookmarkNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final stored = prefs.getStringList(_bookmarkKey) ?? [];
    return stored.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> toggle(int page) async {
    final prefs = ref.read(sharedPrefsProvider);
    final current = Set<int>.from(state);
    if (current.contains(page)) {
      current.remove(page);
    } else {
      current.add(page);
    }
    await prefs.setStringList(_bookmarkKey, current.map((e) => '$e').toList());
    state = current;
  }

  bool isBookmarked(int page) => state.contains(page);
}

final bookmarkProvider =
    NotifierProvider<BookmarkNotifier, Set<int>>(BookmarkNotifier.new);
