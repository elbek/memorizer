import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';

class ScheduleItem {
  ScheduleItem({required this.id, required this.surahNumber, required this.surahName, required this.arabic,
    required this.startPage, required this.endPage, required this.pages, required this.status, this.quality});
  final int id;
  final int surahNumber;
  final String surahName;
  final String arabic;
  final double startPage;
  final double endPage;
  final double pages;
  final String status;
  final int? quality;

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    id: json['id'] as int,
    surahNumber: json['surah_number'] as int,
    surahName: json['surah_name'] as String,
    arabic: json['arabic'] as String,
    startPage: (json['start_page'] as num).toDouble(),
    endPage: (json['end_page'] as num).toDouble(),
    pages: (json['pages'] as num).toDouble(),
    status: json['status'] as String,
    quality: json['quality'] as int?,
  );
}

class TodayPool {
  TodayPool({required this.poolId, required this.poolName, required this.dayNumber, required this.totalDays, required this.items});
  final int poolId;
  final String poolName;
  final int dayNumber;
  final int totalDays;
  final List<ScheduleItem> items;

  factory TodayPool.fromJson(Map<String, dynamic> json) => TodayPool(
    poolId: json['pool_id'] as int,
    poolName: json['pool_name'] as String,
    dayNumber: json['day_number'] as int,
    totalDays: json['total_days'] as int,
    items: (json['items'] as List).map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class TodayState {
  const TodayState({this.pools = const [], this.loading = false, this.error});
  final List<TodayPool> pools;
  final bool loading;
  final String? error;
  TodayState copyWith({List<TodayPool>? pools, bool? loading, String? error}) =>
      TodayState(pools: pools ?? this.pools, loading: loading ?? this.loading, error: error);
}

class ScheduleNotifier extends Notifier<TodayState> {
  @override
  TodayState build() => const TodayState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadToday({String? date}) async {
    state = state.copyWith(loading: true);
    try {
      final params = <String, dynamic>{};
      if (date != null) params['date'] = date;
      final res = await _api.dio.get('/api/today', queryParameters: params);
      final data = res.data as Map<String, dynamic>;
      final pools = (data['pools'] as List).map((e) => TodayPool.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(pools: pools, loading: false);
    } on DioException catch (e) {
      state = state.copyWith(error: e.message ?? 'Failed to load today', loading: false);
    }
  }

  Future<void> markDone(int itemId, int quality) async {
    await _api.dio.patch('/api/item/$itemId/done', data: {'quality': quality});
    await loadToday();
  }

  Future<void> markPartial(int itemId, double stoppedAtPage, int quality) async {
    await _api.dio.patch('/api/item/$itemId/partial', data: {
      'stopped_at_page': stoppedAtPage,
      'quality': quality,
    });
    await loadToday();
  }
}

final scheduleProvider = NotifierProvider<ScheduleNotifier, TodayState>(ScheduleNotifier.new);
