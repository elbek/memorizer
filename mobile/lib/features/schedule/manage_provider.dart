import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memorizer/core/api_client.dart';
import 'package:memorizer/features/auth/auth_provider.dart';
import 'package:memorizer/features/schedule/schedule_provider.dart';

// --- Data Models ---

class ScheduleSummary {
  ScheduleSummary({
    required this.id,
    required this.poolId,
    required this.poolName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.cycleDays,
    required this.status,
    required this.createdAt,
    required this.itemsTotal,
    required this.itemsDone,
    required this.itemsPending,
    required this.itemsPartial,
    required this.itemsMissed,
  });
  final int id, poolId, totalDays, itemsTotal, itemsDone, itemsPending, itemsPartial, itemsMissed;
  final int? cycleDays;
  final String poolName, status, startDate, endDate, createdAt;

  double get progress => itemsTotal > 0 ? itemsDone / itemsTotal : 0.0;

  factory ScheduleSummary.fromJson(Map<String, dynamic> j) => ScheduleSummary(
    id: j['id'] as int,
    poolId: j['pool_id'] as int,
    poolName: j['pool_name'] as String,
    startDate: j['start_date'] as String,
    endDate: j['end_date'] as String,
    totalDays: j['total_days'] as int,
    cycleDays: j['cycle_days'] as int?,
    status: j['status'] as String,
    createdAt: j['created_at'] as String,
    itemsTotal: j['items_total'] as int,
    itemsDone: j['items_done'] as int,
    itemsPending: j['items_pending'] as int,
    itemsPartial: j['items_partial'] as int,
    itemsMissed: j['items_missed'] as int? ?? 0,
  );
}

class PreviewChunk {
  PreviewChunk({required this.surahNumber, required this.surahName, required this.startPage, required this.endPage, required this.pages});
  final int surahNumber;
  final String surahName;
  final double startPage, endPage, pages;

  factory PreviewChunk.fromJson(Map<String, dynamic> j) => PreviewChunk(
    surahNumber: j['surah_number'] as int,
    surahName: j['surah_name'] as String,
    startPage: (j['start_page'] as num).toDouble(),
    endPage: (j['end_page'] as num).toDouble(),
    pages: (j['pages'] as num).toDouble(),
  );
}

class PreviewDay {
  PreviewDay({required this.dayNumber, required this.date, required this.cycle, required this.chunks});
  final int dayNumber, cycle;
  final String date;
  final List<PreviewChunk> chunks;

  factory PreviewDay.fromJson(Map<String, dynamic> j) => PreviewDay(
    dayNumber: j['day_number'] as int,
    date: j['date'] as String,
    cycle: j['cycle'] as int,
    chunks: (j['chunks'] as List).map((e) => PreviewChunk.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class SchedulePreview {
  SchedulePreview({required this.days, required this.totalPages, required this.pagesPerDay, required this.cycles});
  final List<PreviewDay> days;
  final double totalPages, pagesPerDay;
  final int cycles;
}

class SurahReport {
  SurahReport({required this.surahNumber, required this.name, required this.arabic,
    required this.timesRecited, required this.avgQuality, required this.minQuality,
    required this.maxQuality, required this.lastRecited});
  final int surahNumber, timesRecited, minQuality, maxQuality;
  final String name, arabic, lastRecited;
  final double avgQuality;

  factory SurahReport.fromJson(Map<String, dynamic> j) => SurahReport(
    surahNumber: j['surah_number'] as int,
    name: j['name'] as String,
    arabic: j['arabic'] as String,
    timesRecited: j['times_recited'] as int,
    avgQuality: (j['avg_quality'] as num).toDouble(),
    minQuality: j['min_quality'] as int,
    maxQuality: j['max_quality'] as int,
    lastRecited: j['last_recited'] as String,
  );
}

enum DayStatus { done, partial, missed, upcoming, empty }

// --- State ---

class ManageState {
  const ManageState({
    this.schedules = const [],
    this.schedulesLoading = false,
    this.reports = const [],
    this.reportsLoading = false,
  });
  final List<ScheduleSummary> schedules;
  final bool schedulesLoading;
  final List<SurahReport> reports;
  final bool reportsLoading;

  ManageState copyWith({
    List<ScheduleSummary>? schedules,
    bool? schedulesLoading,
    List<SurahReport>? reports,
    bool? reportsLoading,
  }) => ManageState(
    schedules: schedules ?? this.schedules,
    schedulesLoading: schedulesLoading ?? this.schedulesLoading,
    reports: reports ?? this.reports,
    reportsLoading: reportsLoading ?? this.reportsLoading,
  );
}

// --- Notifier ---

class ManageNotifier extends Notifier<ManageState> {
  @override
  ManageState build() => const ManageState();

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> loadSchedules() async {
    state = state.copyWith(schedulesLoading: true);
    try {
      final res = await _api.dio.get('/api/schedule/list');
      final data = res.data as Map<String, dynamic>;
      final list = (data['schedules'] as List)
          .map((e) => ScheduleSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(schedules: list, schedulesLoading: false);
    } catch (_) {
      state = state.copyWith(schedulesLoading: false);
    }
  }

  Future<void> deleteSchedule(int scheduleId) async {
    await _api.dio.delete('/api/schedule/$scheduleId/delete');
    await loadSchedules();
  }

  Future<bool> endSchedule(int scheduleId) async {
    try {
      await _api.dio.post('/api/schedule/$scheduleId/end');
      await loadSchedules();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> loadScheduleHistory(int scheduleId) async {
    try {
      final res = await _api.dio.get('/api/schedule/$scheduleId/history');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<SchedulePreview?> previewSchedule({
    required int poolId,
    required int totalDays,
    int? totalRangeDays,
    required String startDate,
    bool shuffle = false,
  }) async {
    try {
      final res = await _api.dio.post('/api/schedule/generate', data: {
        'pool_id': poolId,
        'total_days': totalDays,
        if (totalRangeDays != null) 'total_range_days': totalRangeDays,
        'start_date': startDate,
        'shuffle': shuffle,
      });
      final d = res.data as Map<String, dynamic>;
      return SchedulePreview(
        days: (d['days'] as List).map((e) => PreviewDay.fromJson(e as Map<String, dynamic>)).toList(),
        totalPages: (d['total_pages'] as num).toDouble(),
        pagesPerDay: (d['pages_per_day'] as num).toDouble(),
        cycles: d['cycles'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> activateSchedule({
    required int poolId,
    required int totalDays,
    int? totalRangeDays,
    required String startDate,
    bool shuffle = false,
  }) async {
    try {
      await _api.dio.post('/api/schedule/activate', data: {
        'pool_id': poolId,
        'total_days': totalDays,
        if (totalRangeDays != null) 'total_range_days': totalRangeDays,
        'start_date': startDate,
        'shuffle': shuffle,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<TodayPool>> loadDay(String date) async {
    try {
      final res = await _api.dio.get('/api/today', queryParameters: {'date': date});
      final data = res.data as Map<String, dynamic>;
      return (data['pools'] as List)
          .map((e) => TodayPool.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> loadReports() async {
    state = state.copyWith(reportsLoading: true);
    try {
      final res = await _api.dio.get('/api/reports/');
      final data = res.data as Map<String, dynamic>;
      final list = (data['stats'] as List)
          .map((e) => SurahReport.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(reports: list, reportsLoading: false);
    } catch (_) {
      state = state.copyWith(reportsLoading: false);
    }
  }
}

final manageProvider = NotifierProvider<ManageNotifier, ManageState>(ManageNotifier.new);
