import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/core/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.name,
    this.error,
  });

  final AuthStatus status;
  final String? name;
  final String? error;

  AuthState copyWith({AuthStatus? status, String? name, String? error}) =>
      AuthState(
        status: status ?? this.status,
        name: name ?? this.name,
        error: error,
      );
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> checkAuth() async {
    final token = _api.getToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await _api.dio.get('/api/today');
      if (res.statusCode == 200) {
        state = const AuthState(status: AuthStatus.authenticated);
      } else {
        await _api.clearToken();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } on DioException {
      await _api.clearToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final res = await _api.dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      await _api.saveToken(data['token'] as String);
      state = AuthState(
        status: AuthStatus.authenticated,
        name: data['name'] as String?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map<String, dynamic>?)?['error']
              as String? ??
          'Login failed';
      state = state.copyWith(error: msg);
    }
  }

  Future<void> register(String email, String name, String password) async {
    try {
      final res = await _api.dio.post('/api/auth/register', data: {
        'email': email,
        'name': name,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      await _api.saveToken(data['token'] as String);
      state = AuthState(
        status: AuthStatus.authenticated,
        name: data['name'] as String?,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map<String, dynamic>?)?['error']
              as String? ??
          'Registration failed';
      state = state.copyWith(error: msg);
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
