import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/quran/quran_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late ProviderContainer container;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApi)],
    );
  });

  tearDown(() => container.dispose());

  group('QuranNotifier', () {
    test('initial state has page 1 and v1 mushaf', () {
      final state = container.read(quranProvider);
      expect(state.currentPage, 1);
      expect(state.mushaf, MushafVersion.v1);
      expect(state.loading, false);
      expect(state.totalPages, 604);
      expect(state.surahStartPages, isEmpty);
    });

    test('loadPage ignores out-of-range pages', () async {
      await container.read(quranProvider.notifier).loadPage(0);
      expect(container.read(quranProvider).currentPage, 1);

      await container.read(quranProvider.notifier).loadPage(605);
      expect(container.read(quranProvider).currentPage, 1);
    });

    test('setMushaf changes mushaf and clears cache', () {
      container.read(quranProvider.notifier).setMushaf(MushafVersion.v2);
      expect(container.read(quranProvider).mushaf, MushafVersion.v2);
      expect(container.read(quranProvider).surahStartPages, isEmpty);
    });

    test('fontPath returns correct paths', () {
      final notifier = container.read(quranProvider.notifier);
      expect(notifier.fontPath, 'v1');
      notifier.setMushaf(MushafVersion.v4);
      expect(notifier.fontPath, 'v4/colrv1');
    });

    test('apiParam maps mushaf to api version', () {
      final notifier = container.read(quranProvider.notifier);
      expect(notifier.apiParam, 'v1');
      notifier.setMushaf(MushafVersion.v2);
      expect(notifier.apiParam, 'v2');
      notifier.setMushaf(MushafVersion.v4);
      expect(notifier.apiParam, 'v2'); // v4 uses v2 data
    });

    test('getPageLines returns null for uncached page', () {
      final notifier = container.read(quranProvider.notifier);
      expect(notifier.getPageLines(1), isNull);
    });

    test('loadIndex parses surah start pages', () async {
      when(() => mockDio.get(
            '/api/quran/index',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => Response(
            data: {'1': 1, '2': 2, '3': 50},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/quran/index'),
          ));

      await container.read(quranProvider.notifier).loadIndex();
      final state = container.read(quranProvider);
      expect(state.surahStartPages[1], 1);
      expect(state.surahStartPages[2], 2);
      expect(state.surahStartPages[3], 50);
    });
  });
}
