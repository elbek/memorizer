import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/recite/recite_screen.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockApi;
  late MockDio mockDio;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockApi = MockApiClient();
    mockDio = MockDio();
    when(() => mockApi.dio).thenReturn(mockDio);
  });

  Widget buildApp() {
    when(() => mockDio.get(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async => Response(
              data: {'pools': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: ReciteScreen()),
    );
  }

  group('ReciteScreen', () {
    testWidgets('shows Schedule and Pools tabs', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      expect(find.text('Recite'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Pools'), findsOneWidget);
    });

    testWidgets('can switch to Pools tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      await tester.tap(find.text('Pools'));
      await tester.pumpAndSettle();

      expect(find.text('No pools yet'), findsOneWidget);
    });
  });
}
