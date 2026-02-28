import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Stable font family name that encodes mushaf + page, so different mushafs
/// don't collide (e.g. V2 page 1 vs V4 page 1).
String fontFamilyFor(String fontPath, int pageNumber) {
  // Turn "v4/colrv1" → "v4_colrv1" for a safe family name.
  final safe = fontPath.replaceAll('/', '_');
  return 'QCF_${safe}_P$pageNumber';
}

class FontCache {
  FontCache({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Set<String> _loaded = {};

  static const _cdnBase =
      'https://verses.quran.foundation/fonts/quran/hafs';

  String _key(String fontPath, int pageNumber) => '$fontPath/$pageNumber';

  bool isLoaded(String fontPath, int pageNumber) =>
      _loaded.contains(_key(fontPath, pageNumber));

  void markLoaded(String fontPath, int pageNumber) =>
      _loaded.add(_key(fontPath, pageNumber));

  /// Downloads the font from CDN if not already cached on disk, then registers
  /// it with Flutter's engine so it can be used via fontFamily.
  Future<bool> ensureFont(String fontPath, int pageNumber) async {
    if (isLoaded(fontPath, pageNumber)) return true;

    try {
      final dir = await getApplicationSupportDirectory();
      final fontDir = Directory('${dir.path}/fonts/$fontPath');
      if (!fontDir.existsSync()) {
        fontDir.createSync(recursive: true);
      }

      final file = File('${fontDir.path}/p$pageNumber.ttf');

      if (!file.existsSync()) {
        final url = '$_cdnBase/$fontPath/ttf/p$pageNumber.ttf';
        await _dio.download(url, file.path);
      }

      final fontFamily = fontFamilyFor(fontPath, pageNumber);
      final bytes = file.readAsBytesSync();
      await ui.loadFontFromList(Uint8List.fromList(bytes), fontFamily: fontFamily);

      markLoaded(fontPath, pageNumber);
      return true;
    } catch (_) {
      return false;
    }
  }
}
