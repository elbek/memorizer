import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/schedule/schedule_provider.dart';

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
    container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(mockApi)]);
  });
  tearDown(() => container.dispose());

  group('ScheduleNotifier', () {
    test('initial state is empty and not loading', () {
      final state = container.read(scheduleProvider);
      expect(state.pools, isEmpty);
      expect(state.loading, false);
    });

    test('loadToday fetches data', () async {
      when(() => mockDio.get('/api/today', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
        data: {'pools': [
          {
            'pool_id': 1, 'pool_name': 'Sabak', 'day_number': 3, 'total_days': 30,
            'items': [
              {'id': 10, 'surah_number': 36, 'surah_name': 'Ya-Sin', 'arabic': 'يس',
               'start_page': 440, 'end_page': 445, 'pages': 5, 'status': 'pending', 'quality': null}
            ]
          }
        ], 'upcoming': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/today'),
      ));

      await container.read(scheduleProvider.notifier).loadToday();
      final state = container.read(scheduleProvider);

      expect(state.pools, hasLength(1));
      expect(state.pools.first.poolName, 'Sabak');
      expect(state.pools.first.items, hasLength(1));
      expect(state.pools.first.items.first.surahName, 'Ya-Sin');
      expect(state.loading, false);
    });

    test('loadToday with date param passes it', () async {
      when(() => mockDio.get('/api/today', queryParameters: {'date': '2024-06-15'}))
          .thenAnswer((_) async => Response(
        data: {'pools': [], 'upcoming': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/today'),
      ));

      await container.read(scheduleProvider.notifier).loadToday(date: '2024-06-15');
      verify(() => mockDio.get('/api/today', queryParameters: {'date': '2024-06-15'})).called(1);
    });

    test('loadToday sets error on failure', () async {
      when(() => mockDio.get('/api/today', queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        message: 'Timeout',
        requestOptions: RequestOptions(path: '/api/today'),
      ));

      await container.read(scheduleProvider.notifier).loadToday();
      expect(container.read(scheduleProvider).error, 'Timeout');
    });

    test('markDone calls API then reloads', () async {
      when(() => mockDio.patch('/api/item/10/done', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
        data: {'ok': true},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/item/10/done'),
      ));
      when(() => mockDio.get('/api/today', queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
        data: {'pools': [], 'upcoming': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/today'),
      ));

      await container.read(scheduleProvider.notifier).markDone(10, 15);
      verify(() => mockDio.patch('/api/item/10/done', data: {'quality': 15})).called(1);
    });

    test('ScheduleItem.fromJson parses correctly', () {
      final item = ScheduleItem.fromJson({
        'id': 1, 'surah_number': 36, 'surah_name': 'Ya-Sin', 'arabic': 'يس',
        'start_page': 440, 'end_page': 445.5, 'pages': 5.5, 'status': 'done', 'quality': 18,
      });
      expect(item.id, 1);
      expect(item.surahName, 'Ya-Sin');
      expect(item.endPage, 445.5);
      expect(item.quality, 18);
    });
  });
}
