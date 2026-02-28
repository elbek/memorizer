import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';

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
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('AuthNotifier', () {
    test('initial state is unknown', () {
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unknown);
      expect(state.name, isNull);
      expect(state.error, isNull);
    });

    test('login sets authenticated on success', () async {
      when(() => mockDio.post('/api/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'ok': true, 'name': 'Test User', 'token': 'jwt123'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/auth/login'),
              ));
      when(() => mockApi.saveToken('jwt123')).thenAnswer((_) async {});

      await container.read(authProvider.notifier).login('test@test.com', 'password1');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.name, 'Test User');
      expect(state.error, isNull);
      verify(() => mockApi.saveToken('jwt123')).called(1);
    });

    test('login sets error on failure', () async {
      when(() => mockDio.post('/api/auth/login', data: any(named: 'data')))
          .thenThrow(DioException(
        response: Response(
          data: {'error': 'Invalid credentials'},
          statusCode: 401,
          requestOptions: RequestOptions(path: '/api/auth/login'),
        ),
        requestOptions: RequestOptions(path: '/api/auth/login'),
      ));

      await container.read(authProvider.notifier).login('test@test.com', 'wrong');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unknown);
      expect(state.error, 'Invalid credentials');
    });

    test('register sets authenticated on success', () async {
      when(() => mockDio.post('/api/auth/register', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'ok': true, 'name': 'New User', 'token': 'jwt456'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/auth/register'),
              ));
      when(() => mockApi.saveToken('jwt456')).thenAnswer((_) async {});

      await container.read(authProvider.notifier).register('new@test.com', 'New User', 'password1');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.name, 'New User');
      verify(() => mockApi.saveToken('jwt456')).called(1);
    });

    test('register sets error on duplicate email', () async {
      when(() => mockDio.post('/api/auth/register', data: any(named: 'data')))
          .thenThrow(DioException(
        response: Response(
          data: {'error': 'Email already registered'},
          statusCode: 409,
          requestOptions: RequestOptions(path: '/api/auth/register'),
        ),
        requestOptions: RequestOptions(path: '/api/auth/register'),
      ));

      await container.read(authProvider.notifier).register('dup@test.com', 'Dup', 'password1');

      final state = container.read(authProvider);
      expect(state.error, 'Email already registered');
    });

    test('logout clears token and sets unauthenticated', () async {
      // First login
      when(() => mockDio.post('/api/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: {'ok': true, 'name': 'User', 'token': 'jwt'},
                statusCode: 200,
                requestOptions: RequestOptions(path: '/api/auth/login'),
              ));
      when(() => mockApi.saveToken('jwt')).thenAnswer((_) async {});
      when(() => mockApi.clearToken()).thenAnswer((_) async {});

      final notifier = container.read(authProvider.notifier);
      await notifier.login('u@t.com', 'password1');
      expect(container.read(authProvider).status, AuthStatus.authenticated);

      await notifier.logout();

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      verify(() => mockApi.clearToken()).called(1);
    });

    test('checkAuth sets authenticated when token valid', () async {
      when(() => mockApi.getToken()).thenReturn('valid-token');
      when(() => mockDio.get('/api/today')).thenAnswer((_) async => Response(
            data: {'pools': []},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/api/today'),
          ));

      await container.read(authProvider.notifier).checkAuth();

      expect(container.read(authProvider).status, AuthStatus.authenticated);
    });

    test('checkAuth sets unauthenticated when no token', () async {
      when(() => mockApi.getToken()).thenReturn(null);

      await container.read(authProvider.notifier).checkAuth();

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
    });
  });
}
