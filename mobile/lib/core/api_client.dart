import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

const _tokenKey = 'auth_token';

class ApiClient {
  ApiClient({
    Dio? dio,
    SharedPreferences? prefs,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _prefs = prefs {
    _dio.options.baseUrl = baseUrl ?? apiBaseUrl;
    _dio.interceptors.add(LogInterceptor(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (o) => print(o),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _prefs?.getString(_tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio _dio;
  SharedPreferences? _prefs;

  Dio get dio => _dio;

  void setPrefs(SharedPreferences prefs) => _prefs = prefs;

  Future<void> saveToken(String token) async =>
      _prefs?.setString(_tokenKey, token);

  String? getToken() => _prefs?.getString(_tokenKey);

  Future<void> clearToken() async => _prefs?.remove(_tokenKey);
}
