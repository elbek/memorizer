import 'dart:async';

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
    this.repeating = false,
    this.rangeStartIndex,
    this.rangeEndIndex,
  });

  final AudioPlaybackStatus status;
  final int currentPage;
  final int currentAyahIndex;
  final List<String> ayahKeys;
  final String? currentAyahKey;
  final bool repeating;
  final int? rangeStartIndex;
  final int? rangeEndIndex;

  bool get isActive => status != AudioPlaybackStatus.idle;
  bool get hasRange => rangeStartIndex != null && rangeEndIndex != null;

  AudioState copyWith({
    AudioPlaybackStatus? status,
    int? currentPage,
    int? currentAyahIndex,
    List<String>? ayahKeys,
    String? currentAyahKey,
    bool? repeating,
    int? rangeStartIndex,
    int? rangeEndIndex,
  }) =>
      AudioState(
        status: status ?? this.status,
        currentPage: currentPage ?? this.currentPage,
        currentAyahIndex: currentAyahIndex ?? this.currentAyahIndex,
        ayahKeys: ayahKeys ?? this.ayahKeys,
        currentAyahKey: currentAyahKey,
        repeating: repeating ?? this.repeating,
        rangeStartIndex: rangeStartIndex ?? this.rangeStartIndex,
        rangeEndIndex: rangeEndIndex ?? this.rangeEndIndex,
      );
}

/// Verse timing from QDC API.
class _VerseTiming {
  const _VerseTiming({required this.verseKey, required this.from, required this.to});
  final String verseKey;
  final int from; // ms
  final int to; // ms
}

/// Cached chapter audio data.
class _ChapterAudio {
  const _ChapterAudio({required this.url, required this.timings});
  final String url;
  final List<_VerseTiming> timings;
}

class AudioNotifier extends Notifier<AudioState> {
  final _player = AudioPlayer();
  final _dio = Dio(BaseOptions(baseUrl: 'https://api.qurancdn.com/api/qdc'));
  final _chapterCache = <String, _ChapterAudio>{}; // "reciterId:chapter" -> audio
  bool _repeating = false;
  StreamSubscription<Duration>? _positionSub;
  int? _currentEndMs; // end timestamp of current verse
  bool _advancing = false; // guard against double-advance
  String? _loadedUrl; // currently loaded audio URL
  void Function()? onPageComplete;

  @override
  AudioState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _player.dispose();
    });
    _player.playerStateStream.listen(_onPlayerState);
    return const AudioState();
  }

  void _onPlayerState(PlayerState ps) {
    if (ps.processingState == ProcessingState.completed) {
      // Chapter audio ended (last verse of chapter)
      _onVerseEnd();
    }
  }

  void _startPositionMonitor() {
    _positionSub?.cancel();
    _positionSub = _player.positionStream.listen((pos) {
      final endMs = _currentEndMs;
      if (endMs == null || _advancing) return;
      if (pos.inMilliseconds >= endMs) {
        _onVerseEnd();
      }
    });
  }

  void _onVerseEnd() {
    if (_advancing) return;
    _advancing = true;

    if (_repeating && !state.hasRange) {
      // Single verse repeat — seek back to start of this verse
      final timing = _findTiming(state.currentAyahKey);
      if (timing != null) {
        _player.seek(Duration(milliseconds: timing.from));
        if (state.status != AudioPlaybackStatus.playing) _player.play();
      }
      _advancing = false;
      return;
    }

    _playNextAyah();
    _advancing = false;
  }

  _VerseTiming? _findTiming(String? verseKey) {
    if (verseKey == null) return null;
    final chapter = verseKey.split(':').first;
    final reciterId = ref.read(settingsProvider).reciterId;
    final cacheKey = '$reciterId:$chapter';
    final audio = _chapterCache[cacheKey];
    if (audio == null) return null;
    return audio.timings.where((t) => t.verseKey == verseKey).firstOrNull;
  }

  /// Start playback with a known list of ayah keys.
  Future<void> playPageWithKeys(int page, List<String> ayahKeys, {String? fromAyahKey, String? toAyahKey}) async {
    _repeating = false;
    _advancing = false;

    var startIndex = 0;
    if (fromAyahKey != null) {
      final idx = ayahKeys.indexOf(fromAyahKey);
      if (idx >= 0) startIndex = idx;
    }
    int? endIndex;
    if (toAyahKey != null) {
      final idx = ayahKeys.indexOf(toAyahKey);
      if (idx >= 0) endIndex = idx;
    }

    state = AudioState(
      status: AudioPlaybackStatus.loading,
      currentPage: page,
      ayahKeys: ayahKeys,
      currentAyahIndex: startIndex,
      currentAyahKey: ayahKeys[startIndex],
      rangeStartIndex: endIndex != null ? startIndex : null,
      rangeEndIndex: endIndex,
    );

    try {
      final reciterId = ref.read(settingsProvider).reciterId;

      // Pre-fetch audio data for all chapters on this page
      final chapters = ayahKeys.map((k) => int.parse(k.split(':').first)).toSet();
      for (final ch in chapters) {
        await _fetchChapterAudio(reciterId, ch);
      }

      state = state.copyWith(status: AudioPlaybackStatus.playing, currentAyahKey: ayahKeys[startIndex]);
      await _seekToVerse(ayahKeys[startIndex]);
      _player.play();
      _startPositionMonitor();
    } catch (_) {
      state = const AudioState();
    }
  }

  Future<void> _seekToVerse(String verseKey) async {
    final chapter = verseKey.split(':').first;
    final reciterId = ref.read(settingsProvider).reciterId;
    final cacheKey = '$reciterId:$chapter';
    final audio = _chapterCache[cacheKey];
    if (audio == null) return;

    final timing = audio.timings.where((t) => t.verseKey == verseKey).firstOrNull;
    if (timing == null) return;

    _currentEndMs = timing.to;

    // Load a different chapter audio if needed
    if (_loadedUrl != audio.url) {
      _loadedUrl = audio.url;
      await _player.setUrl(audio.url);
    }
    await _player.seek(Duration(milliseconds: timing.from));
  }

  void _playNextAyah() {
    final next = state.currentAyahIndex + 1;
    final endIdx = state.rangeEndIndex;

    if (endIdx != null && next > endIdx) {
      if (_repeating) {
        _playIndex(state.rangeStartIndex!);
        return;
      }
      _player.pause();
      state = const AudioState();
      return;
    }

    if (next >= state.ayahKeys.length) {
      if (_repeating && state.rangeStartIndex != null) {
        _playIndex(state.rangeStartIndex!);
        return;
      }
      _player.pause();
      state = const AudioState();
      onPageComplete?.call();
      return;
    }

    _advanceTo(next);
  }

  /// Advance to the next verse without seeking if same chapter (gapless).
  void _advanceTo(int index) {
    if (index >= state.ayahKeys.length) {
      state = const AudioState();
      return;
    }

    final verseKey = state.ayahKeys[index];
    final chapter = verseKey.split(':').first;
    final reciterId = ref.read(settingsProvider).reciterId;
    final cacheKey = '$reciterId:$chapter';
    final audio = _chapterCache[cacheKey];
    if (audio == null) return;

    final timing = audio.timings.where((t) => t.verseKey == verseKey).firstOrNull;
    if (timing == null) return;

    // Same chapter — just update end timestamp, let audio continue naturally
    if (_loadedUrl == audio.url) {
      _currentEndMs = timing.to;
      state = state.copyWith(
        currentAyahIndex: index,
        currentAyahKey: verseKey,
      );
      return;
    }

    // Different chapter — need to load new audio and seek
    _playIndex(index);
  }

  /// Seek to a specific verse (used for skip, repeat, chapter crossings).
  void _playIndex(int index) {
    if (index >= state.ayahKeys.length) {
      state = const AudioState();
      return;
    }

    final verseKey = state.ayahKeys[index];
    state = state.copyWith(
      currentAyahIndex: index,
      currentAyahKey: verseKey,
    );

    _seekToVerse(verseKey).then((_) {
      if (state.status == AudioPlaybackStatus.playing ||
          state.status == AudioPlaybackStatus.loading) {
        _player.play();
      }
    });
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
    _repeating = false;
    _advancing = false;
    final next = state.currentAyahIndex + 1;
    final endIdx = state.rangeEndIndex;
    if (endIdx != null && next > endIdx) {
      _player.pause();
      state = const AudioState();
      return;
    }
    if (next >= state.ayahKeys.length) {
      _player.pause();
      state = const AudioState();
      onPageComplete?.call();
      return;
    }
    _playIndex(next);
  }

  void skipPrevious() {
    if (!state.isActive || state.currentAyahIndex <= 0) return;
    _repeating = false;
    _advancing = false;
    _playIndex(state.currentAyahIndex - 1);
  }

  void repeatAyah() {
    _repeating = true;
    state = state.copyWith(repeating: true, currentAyahKey: state.currentAyahKey);
    if (!state.isActive) return;
    final timing = _findTiming(state.currentAyahKey);
    if (timing != null) {
      _player.seek(Duration(milliseconds: timing.from));
    }
    if (state.status != AudioPlaybackStatus.playing) {
      _player.play();
      state = state.copyWith(status: AudioPlaybackStatus.playing, repeating: true, currentAyahKey: state.currentAyahKey);
    }
  }

  void stop() {
    _repeating = false;
    _advancing = false;
    _currentEndMs = null;
    _loadedUrl = null;
    _positionSub?.cancel();
    _player.pause();
    state = const AudioState();
  }

  Future<_ChapterAudio> _fetchChapterAudio(int reciterId, int chapter) async {
    final cacheKey = '$reciterId:$chapter';
    if (_chapterCache.containsKey(cacheKey)) return _chapterCache[cacheKey]!;

    final res = await _dio.get(
      '/audio/reciters/$reciterId/audio_files',
      queryParameters: {'chapter': chapter, 'segments': true},
    );
    final data = res.data as Map<String, dynamic>;
    final files = (data['audio_files'] as List<dynamic>?) ?? [];
    if (files.isEmpty) {
      final empty = _ChapterAudio(url: '', timings: []);
      _chapterCache[cacheKey] = empty;
      return empty;
    }

    final file = files[0] as Map<String, dynamic>;
    final url = file['audio_url'] as String? ?? '';
    final verseTimings = (file['verse_timings'] as List<dynamic>?) ?? [];

    final timings = verseTimings.map((t) => _VerseTiming(
      verseKey: t['verse_key'] as String,
      from: (t['timestamp_from'] as num).toInt(),
      to: (t['timestamp_to'] as num).toInt(),
    )).toList();

    final audio = _ChapterAudio(url: url, timings: timings);
    _chapterCache[cacheKey] = audio;
    return audio;
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
