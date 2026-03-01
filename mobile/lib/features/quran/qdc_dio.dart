import 'package:dio/dio.dart';

/// Shared Dio instance for Quran Data Community API.
final qdcDio = Dio(BaseOptions(baseUrl: 'https://api.qurancdn.com/api/qdc'));
