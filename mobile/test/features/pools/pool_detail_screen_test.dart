import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/pools/pool_detail_screen.dart';
import 'package:memorizer/features/pools/pools_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;

  setUp(() {
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
  });

  final testPool = Pool(id: 1, name: 'Daily', isSystem: true, createdAt: '2024-01-01');

  group('PoolDetailScreen', () {
    testWidgets('shows pool name and surah count', (tester) async {
      when(() => mockDio.get('/api/pools/1/surahs',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: {
                  'surahs': [
                    {
                      'id': 1,
                      'surah_number': 36,
                      'name': 'Ya-Sin',
                      'arabic': 'يس',
                      'pages': 5.5,
                    }
                  ]
                },
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/pools/1/surahs'),
              ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: PoolDetailScreen(pool: testPool),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('1 surahs'), findsOneWidget);
      expect(find.text('Ya-Sin'), findsOneWidget);
    });

    testWidgets('shows empty state when no surahs', (tester) async {
      when(() => mockDio.get('/api/pools/1/surahs',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                data: {'surahs': []},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/pools/1/surahs'),
              ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
          child: MaterialApp(
            home: PoolDetailScreen(pool: testPool),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No surahs yet'), findsOneWidget);
    });
  });
}
