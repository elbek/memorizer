import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/pools/pools_provider.dart';

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

  group('PoolsNotifier', () {
    test('initial state is empty', () {
      final state = container.read(poolsProvider);
      expect(state.pools, isEmpty);
      expect(state.loading, false);
    });

    test('loadPools fetches and populates state', () async {
      when(() => mockDio.get('/api/pools')).thenAnswer((_) async => Response(
        data: {'pools': [
          {'id': 1, 'name': 'Sabak', 'is_system': 1, 'created_at': '2024-01-01'},
          {'id': 2, 'name': 'Manzil', 'is_system': 1, 'created_at': '2024-01-01'},
        ]},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/pools'),
      ));

      await container.read(poolsProvider.notifier).loadPools();
      final state = container.read(poolsProvider);

      expect(state.pools, hasLength(2));
      expect(state.pools[0].name, 'Sabak');
      expect(state.pools[0].isSystem, true);
      expect(state.loading, false);
    });

    test('loadPools sets error on failure', () async {
      when(() => mockDio.get('/api/pools')).thenThrow(DioException(
        message: 'Network error',
        requestOptions: RequestOptions(path: '/api/pools'),
      ));

      await container.read(poolsProvider.notifier).loadPools();
      final state = container.read(poolsProvider);

      expect(state.error, 'Network error');
      expect(state.loading, false);
    });

    test('createPool calls API and reloads', () async {
      when(() => mockDio.post('/api/pools', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
            data: {'ok': true, 'id': 3},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/pools'),
          ));
      when(() => mockDio.get('/api/pools')).thenAnswer((_) async => Response(
        data: {'pools': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/pools'),
      ));

      await container.read(poolsProvider.notifier).createPool('Custom');
      verify(() => mockDio.post('/api/pools', data: {'name': 'Custom'})).called(1);
    });

    test('deletePool calls API and reloads', () async {
      when(() => mockDio.delete('/api/pools/3')).thenAnswer((_) async => Response(
        data: {'ok': true},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/pools/3'),
      ));
      when(() => mockDio.get('/api/pools')).thenAnswer((_) async => Response(
        data: {'pools': []},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/pools'),
      ));

      await container.read(poolsProvider.notifier).deletePool(3);
      verify(() => mockDio.delete('/api/pools/3')).called(1);
    });

    test('Pool.fromJson parses correctly', () {
      final pool = Pool.fromJson({
        'id': 1, 'name': 'Test', 'is_system': 0, 'created_at': '2024-01-01'
      });
      expect(pool.id, 1);
      expect(pool.name, 'Test');
      expect(pool.isSystem, false);
    });
  });
}
