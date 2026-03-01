import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorizer/core/api_client.dart';

void main() {
  group('ApiClient', () {
    test('sets base URL on Dio', () {
      final apiClient = ApiClient(baseUrl: 'https://test.example.com');
      expect(apiClient.dio.options.baseUrl, 'https://test.example.com');
    });

    test('saveToken writes to shared preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = ApiClient(prefs: prefs, baseUrl: 'https://test.example.com');

      await apiClient.saveToken('abc123');

      expect(prefs.getString('auth_token'), 'abc123');
    });

    test('getToken reads from shared preferences', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'mytoken'});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = ApiClient(prefs: prefs, baseUrl: 'https://test.example.com');

      final token = apiClient.getToken();

      expect(token, 'mytoken');
    });

    test('getToken returns null when no token stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = ApiClient(prefs: prefs, baseUrl: 'https://test.example.com');

      final token = apiClient.getToken();

      expect(token, isNull);
    });

    test('clearToken removes from shared preferences', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'old'});
      final prefs = await SharedPreferences.getInstance();
      final apiClient = ApiClient(prefs: prefs, baseUrl: 'https://test.example.com');

      await apiClient.clearToken();

      expect(prefs.getString('auth_token'), isNull);
    });

    test('interceptor adds Bearer header when token exists', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'test-jwt-token'});
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio();
      ApiClient(dio: dio, prefs: prefs, baseUrl: 'https://test.example.com');

      final options = RequestOptions(path: '/api/test');
      final interceptor = dio.interceptors.whereType<InterceptorsWrapper>().first;

      interceptor.onRequest.call(options, RequestInterceptorHandler());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(options.headers['Authorization'], 'Bearer test-jwt-token');
    });

    test('interceptor skips Bearer header when no token', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio();
      ApiClient(dio: dio, prefs: prefs, baseUrl: 'https://test.example.com');

      final options = RequestOptions(path: '/api/test');
      final interceptor = dio.interceptors.whereType<InterceptorsWrapper>().first;

      interceptor.onRequest.call(options, RequestInterceptorHandler());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(options.headers['Authorization'], isNull);
    });
  });
}
