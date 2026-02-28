import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';

class Pool {
  Pool({required this.id, required this.name, required this.isSystem, required this.createdAt});
  final int id;
  final String name;
  final bool isSystem;
  final String createdAt;

  factory Pool.fromJson(Map<String, dynamic> json) => Pool(
    id: json['id'] as int,
    name: json['name'] as String,
    isSystem: (json['is_system'] as int) == 1,
    createdAt: json['created_at'] as String,
  );
}

class PoolSurah {
  PoolSurah({required this.id, required this.surahNumber, required this.name, required this.arabic, required this.pages});
  final int id;
  final int surahNumber;
  final String name;
  final String arabic;
  final double pages;

  factory PoolSurah.fromJson(Map<String, dynamic> json) => PoolSurah(
    id: json['id'] as int,
    surahNumber: json['surah_number'] as int,
    name: json['name'] as String,
    arabic: json['arabic'] as String,
    pages: (json['pages'] as num).toDouble(),
  );
}

class PoolsState {
  const PoolsState({this.pools = const [], this.loading = false, this.error});
  final List<Pool> pools;
  final bool loading;
  final String? error;
  PoolsState copyWith({List<Pool>? pools, bool? loading, String? error}) =>
      PoolsState(pools: pools ?? this.pools, loading: loading ?? this.loading, error: error);
}

class PoolsNotifier extends Notifier<PoolsState> {
  @override
  PoolsState build() => const PoolsState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadPools() async {
    state = state.copyWith(loading: true);
    try {
      final res = await _api.dio.get('/api/pools');
      final data = res.data as Map<String, dynamic>;
      final list = (data['pools'] as List).map((e) => Pool.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(pools: list, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(error: e.message ?? 'Failed to load pools', loading: false);
    }
  }

  Future<void> createPool(String name) async {
    try {
      await _api.dio.post('/api/pools', data: {'name': name});
      await loadPools();
    } on DioException catch (e) {
      final msg = (e.response?.data as Map<String, dynamic>?)?['error'] as String? ?? 'Failed to create pool';
      state = state.copyWith(error: msg);
    }
  }

  Future<void> deletePool(int poolId) async {
    try {
      await _api.dio.delete('/api/pools/$poolId');
      await loadPools();
    } on DioException catch (e) {
      final msg = (e.response?.data as Map<String, dynamic>?)?['error'] as String? ?? 'Failed to delete pool';
      state = state.copyWith(error: msg);
    }
  }

  Future<List<PoolSurah>> loadPoolSurahs(int poolId) async {
    final res = await _api.dio.get('/api/pools/$poolId/surahs');
    final data = res.data as Map<String, dynamic>;
    return (data['surahs'] as List).map((e) => PoolSurah.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addSurah(int poolId, int surahNumber) async {
    await _api.dio.post('/api/pools/$poolId/surahs', data: {'surah_number': surahNumber});
  }

  Future<void> removeSurah(int poolId, int surahNumber) async {
    await _api.dio.delete('/api/pools/$poolId/surahs/$surahNumber');
  }

  /// Returns a map of surahNumber → poolName for all surahs across all pools.
  Future<Map<int, String>> loadAllSurahAssignments() async {
    final pools = state.pools;
    final map = <int, String>{};
    for (final pool in pools) {
      final surahs = await loadPoolSurahs(pool.id);
      for (final s in surahs) {
        map[s.surahNumber] = pool.name;
      }
    }
    return map;
  }

  Future<({int added, int skipped})> addJuz(int poolId, int juzNumber) async {
    final res = await _api.dio.post('/api/pools/$poolId/juz', data: {'juz_number': juzNumber});
    final data = res.data as Map<String, dynamic>;
    return (added: data['added'] as int? ?? 0, skipped: data['skipped'] as int? ?? 0);
  }
}

final poolsProvider = NotifierProvider<PoolsNotifier, PoolsState>(PoolsNotifier.new);
