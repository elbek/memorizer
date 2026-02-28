import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/auth/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {
  @override
  BaseOptions get options => BaseOptions();
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows login form by default', (tester) async {
      final mockApi = MockApiClient();
      when(() => mockApi.dio).thenReturn(MockDio());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      expect(find.text('Quran Memorizer'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Name'), findsNothing);
    });

    testWidgets('toggles to register mode', (tester) async {
      final mockApi = MockApiClient();
      when(() => mockApi.dio).thenReturn(MockDio());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pump();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
    });

    testWidgets('toggles back to login mode', (tester) async {
      final mockApi = MockApiClient();
      when(() => mockApi.dio).thenReturn(MockDio());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      final toggleBack = find.text('Already have an account? Sign in');
      await tester.ensureVisible(toggleBack);
      await tester.tap(toggleBack);
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
