import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:memorizer/features/settings/settings_provider.dart';

enum AudioPlaybackStatus { idle, loading, playing, paused }

class AudioState {
  const AudioState({
    this.status = AudioPlaybackStatus.idle,
    this.currentPage = 0,
    this.currentAyahIndex = 0,
    this.ayahKeys = const [],
    this.currentAyahKey,
  });

  final AudioPlaybackStatus status;
  final int currentPage;
  final int currentAyahIndex;
  final List<String> ayahKeys;
  final String? currentAyahKey;

  bool get isActive => status != AudioPlaybackStatus.idle;

  AudioState copyWith({
    AudioPlaybackStatus? status,
    int? currentPage,
    int? currentAyahIndex,
    List<String>? ayahKeys,
    String? currentAyahKey,
  }) =>
      AudioState(
        status: status ?? this.status,
        currentPage: currentPage ?? this.currentPage,
        currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
        ayahKeys: ayahKeys ?? this.ayahKeys,
        currentAyahKey: currentAyahKey,
      );
}

class AudioNotifier extends Notifier<AudioState> {
  final _player = AudioPlayer();
  final _dio = Dio(BaseOptions(baseUrl: 'https://api.quran.com/api/v4'));
  final _urlCache = <String, List<_AyahAudio>>{}; // "reciterId:page" -> urls
  void Function()? onPageComplete;

  @override
  AudioState build() {
    ref.onDispose(() {
      _player.dispose();
    });
    _player.playerStateStream.listen(_onPlayerState);
    return const AudioState();
  }

  void _onPlayerState(PlayerState ps) {
    if (ps.processingState == ProcessingState.completed) {
      _playNextAyah();
    }
  }

  Future<void> playPage(int page, {String? fromAyahKey}) async {
    state = state.copyWith(status: AudioPlaybackStatus.loading, currentPage: page);

    try {
      final reciterId = ref.read(settingsProvider).reciterId;
      final audios = await _fetchAudioUrls(reciterId, page);
      if (audios.isEmpty) {
        state = const AudioState();
        return;
      }

      final keys = audios.map((a) => a.verseKey).toList();
      var startIndex = 0;
      if (fromAyahKey != null) {
        final idx = keys.indexOf(fromAyahKey);
        if (idx >= 0) startIndex = idx;
      }

      state = state.copyWith(
        status: AudioPlaybackStatus.playing,
        ayahKeys: keys,
        currentAyahIndex: startIndex,
        currentAyahKey: keys[startIndex],
      );
      await _player.setUrl(audios[startIndex].url);
      _player.play();
    } catch (_) {
      state = const AudioState();
    }
  }

  void _playNextAyah() {
    final next = state.currentAyahIndex + 1;
    if (next >= state.ayahKeys.length) {
      // Page finished
      state = const AudioState();
      onPageComplete?.call();
      return;
    }

    final reciterId = ref.read(settingsProvider).reciterId;
    final cacheKey = '$reciterId:${state.currentPage}';
    final audios = _urlCache[cacheKey];
    if (audios == null || next >= audios.length) {
      state = const AudioState();
      return;
    }

    state = state.copyWith(
      currentAyahIndex: next,
      currentAyahKey: state.ayahKeys[next],
    );
    _player.setUrl(audios[next].url).then((_) => _player.play());
  }

  void togglePlayPause() {
    if (state.status == AudioPlaybackStatus.playing) {
      _player.pause();
      state = state.copyWith(status: AudioPlaybackStatus.paused, currentAyahKey: state.currentAyahKey);
    } else if (state.status == AudioPlaybackStatus.paused) {
      _player.play();
      state = state.copyWith(status: AudioPlaybackStatus.playing, currentAyahKey: state.currentAyahKey);
    }
  }

  void skipNext() {
    if (!state.isActive) return;
    _player.stop();
    _playNextAyah();
  }

  void skipPrevious() {
    if (!state.isActive || state.currentAyahIndex <= 0) return;
    final prev = state.currentAyahIndex - 1;
    final reciterId = ref.read(settingsProvider).reciterId;
    final cacheKey = '$reciterId:${state.currentPage}';
    final audios = _urlCache[cacheKey];
    if (audios == null || prev >= audios.length) return;

    _player.stop();
    state = state.copyWith(
      currentAyahIndex: prev,
      currentAyahKey: state.ayahKeys[prev],
    );
    _player.setUrl(audios[prev].url).then((_) => _player.play());
  }

  void stop() {
    _player.stop();
    state = const AudioState();
  }

  Future<List<_AyahAudio>> _fetchAudioUrls(int reciterId, int page) async {
    final cacheKey = '$reciterId:$page';
    if (_urlCache.containsKey(cacheKey)) return _urlCache[cacheKey]!;

    final res = await _dio.get(
      '/recitations/$reciterId/by_page/$page',
      queryParameters: {'per_page': 50, 'fields': 'url'},
    );
    final data = res.data as Map<String, dynamic>;
    final files = (data['audio_files'] as List<dynamic>?) ?? [];

    final audios = files.map((f) {
      var url = f['url'] as String? ?? '';
      if (url.isNotEmpty && !url.startsWith('http')) {
        url = 'https://verses.quran.com/$url';
      }
      return _AyahAudio(verseKey: f['verse_key'] as String? ?? '', url: url);
    }).where((a) => a.url.isNotEmpty).toList();

    _urlCache[cacheKey] = audios;
    return audios;
  }
}

class _AyahAudio {
  const _AyahAudio({required this.verseKey, required this.url});
  final String verseKey;
  final String url;
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
