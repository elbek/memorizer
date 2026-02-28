import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/features/quran/font_cache.dart';

void main() {
  group('FontCache', () {
    test('isLoaded returns false for uncached font', () {
      final cache = FontCache();
      expect(cache.isLoaded('v1', 1), false);
    });

    test('isLoaded returns true after marking loaded', () {
      final cache = FontCache();
      cache.markLoaded('v1', 1);
      expect(cache.isLoaded('v1', 1), true);
    });

    test('different pages are tracked independently', () {
      final cache = FontCache();
      cache.markLoaded('v1', 1);
      expect(cache.isLoaded('v1', 1), true);
      expect(cache.isLoaded('v1', 2), false);
    });

    test('different mushaf versions are tracked independently', () {
      final cache = FontCache();
      cache.markLoaded('v1', 1);
      expect(cache.isLoaded('v1', 1), true);
      expect(cache.isLoaded('v2', 1), false);
    });
  });
}
