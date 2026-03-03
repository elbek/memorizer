# Mobile Schedule, Calendar & Reports Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add schedule generator, schedule list, calendar month view, and reports to the mobile Flutter app — matching web UI functionality.

**Architecture:** Extend existing Riverpod provider pattern. New `ManageNotifier` provider handles schedule CRUD, calendar data, and reports via existing `ApiClient`. Five new screens slot into the existing `ReciteScreen` tab container (expanded from 2 → 5 tabs). Schedule generator launches as a bottom sheet from `PoolDetailScreen`.

**Tech Stack:** Flutter, Riverpod, Dio, go_router (existing stack — no new dependencies)

---

## Task 1: Create manage_provider.dart — Data Models & API Methods

**Files:**
- Create: `mobile/lib/features/schedule/manage_provider.dart`

**Step 1: Create the provider file with all data models and API methods**

```dart
import 'package:dio/dio.dart';
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
  });
  final int id, poolId, totalDays, itemsTotal, itemsDone, itemsPending, itemsPartial;
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

// --- Calendar day status computed from /api/today responses ---

enum DayStatus { done, partial, missed, upcoming, empty }

class CalendarDay {
  CalendarDay({required this.date, required this.status, required this.pools});
  final String date;
  final DayStatus status;
  final List<TodayPool> pools;
}

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

  // Schedule list
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

  // Schedule generator
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

  // Calendar — fetch a single day
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

  // Reports
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
```

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/schedule/manage_provider.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add manage provider with schedule, calendar, and reports API
```

---

## Task 2: Create schedule_list_screen.dart

**Files:**
- Create: `mobile/lib/features/schedule/schedule_list_screen.dart`

**Step 1: Create the schedule list screen**

This is a simple list showing all schedules with progress bars. Each card shows:
- Pool name, date range, status badge
- Progress bar (done/total)
- Delete button for non-completed schedules

Follow the existing card patterns from `today_screen.dart`:
- Use `Card` + `InkWell` with `BorderRadius.circular(16)`
- Use `cs.primary.withValues(alpha: ...)` for tinted backgrounds
- Use `LinearProgressIndicator` for progress
- Pull-to-refresh with `RefreshIndicator`
- Load data in `initState` via `Future.microtask`
- Accept `embedded: true` parameter (no Scaffold when embedded in tabs)
- Delete confirmation dialog matching existing pattern (`AlertDialog` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))`)

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/schedule/schedule_list_screen.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add schedule list screen with progress and delete
```

---

## Task 3: Create schedule_generator_sheet.dart

**Files:**
- Create: `mobile/lib/features/schedule/schedule_generator_sheet.dart`

**Step 1: Create the schedule generator bottom sheet**

A `StatefulWidget` shown via `showModalBottomSheet` from `PoolDetailScreen`. Contains:

**Form fields (Column in a scrollable sheet):**
- Cycle length (days): `TextField` with `keyboardType: TextInputType.number`, default "7"
- Total range (days): `TextField` number, default same as cycle
- Start date: row with date text + `IconButton` opening `showDatePicker`
- Shuffle: `SwitchListTile`

**Two action buttons:**
- "Preview" → calls `manageProvider.previewSchedule(...)`, shows result below
- "Activate" → calls `manageProvider.activateSchedule(...)`, on success pops sheet + shows snackbar

**Preview section (when preview data available):**
- Summary: "X pages over Y days (Z pages/day)"
- Scrollable list of days with chunks: "Day N (date): Surah Name pp. X–Y"

**Widget structure:**
```
DraggableScrollableSheet
  Column
    handleBar
    title "Generate Schedule"
    form fields
    Row [Preview button] [Activate button]
    if preview != null: preview list
```

Match existing bottom sheet patterns from `pool_detail_screen.dart`:
- `DraggableScrollableSheet` with `initialChildSize: 0.7`
- Handle bar: 36×4 rounded container
- Use `FilledButton` for primary actions, `OutlinedButton` for secondary

Constructor: `ScheduleGeneratorSheet({required int poolId, required String poolName})`

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/schedule/schedule_generator_sheet.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add schedule generator bottom sheet with preview and activate
```

---

## Task 4: Create calendar_screen.dart

**Files:**
- Create: `mobile/lib/features/schedule/calendar_screen.dart`

**Step 1: Create the calendar month view screen**

A `ConsumerStatefulWidget` that shows a month grid calendar.

**State:**
- `_year`, `_month` — current view month (initialized to now)
- `Map<String, DayStatus> _dayStatuses` — date string → status for the visible month
- `bool _loading`

**Data fetching strategy:**
Use `GET /api/schedule/list` to get all schedules with their items. Then compute per-day status from `schedule_items` by fetching each active schedule's items via `GET /api/schedule/:poolId`. This is complex — simpler approach: fetch the current month's days one request per day in parallel. But that's 30 requests.

**Better approach:** Use `GET /api/schedule/list` for the schedule metadata (start_date, end_date, items_done, items_total, items_pending, items_partial). Then for each schedule that overlaps with the visible month, fetch its full items via `GET /api/schedule/:poolId`. From the items (which have `day_number` and `status`), compute the calendar day colors by mapping `day_number` → `start_date + day_number - 1`.

**Actually simplest correct approach:** The backend doesn't have a "fetch month" endpoint. Use the schedule list + individual schedule item data:

1. `loadSchedules()` to get all schedules with date ranges
2. For schedules overlapping visible month, their `items_done/total/pending/partial` gives overall status
3. For day-level detail, compute from schedule start_date + total_days which days have items
4. When user taps a day, fetch that specific day via `loadDay(date)` to show details

For the grid coloring, use a simplified approach:
- For each schedule, days from `start_date` to `start_date + total_days - 1` have items
- Color all schedule days as "upcoming" (gray) by default
- Past days with items = "missed" (red) unless items are done
- Since we can't know per-day status from the list endpoint alone, fetch active schedule items once on load

**Implementation:**

```
_loadMonth() async:
  1. Get schedule list from manageProvider
  2. For each active schedule overlapping this month:
     fetch /api/schedule/:poolId → get all items
  3. Group items by day_number → date
  4. For each date: if all done → green, if any partial → yellow,
     if past + any pending → red, if future → gray
  5. setState with _dayStatuses map
```

**Layout:**
```
Column
  Row [← month year →] navigation
  GridView.count(crossAxisCount: 7)
    dayOfWeek headers (S M T W T F S)
    day cells with colored dots
```

**Day cell widget:**
- Number text
- Small colored circle (6px) below the number
- InkWell → tap opens bottom sheet with that day's items (fetched via `loadDay`)

Accept `embedded: true` parameter. Load data on `initState`.

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/schedule/calendar_screen.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add calendar month view with color-coded schedule days
```

---

## Task 5: Create reports_screen.dart

**Files:**
- Create: `mobile/lib/features/schedule/reports_screen.dart`

**Step 1: Create the reports screen**

A `ConsumerStatefulWidget` showing per-surah recitation statistics.

**Layout:**
```
Column
  summary card (total recitations, avg quality)
  sort dropdown
  Expanded ListView of surah report cards
```

**Summary card:**
- Total recitations: sum of all `timesRecited`
- Average quality: weighted average of `avgQuality` by `timesRecited`

**Sort options (dropdown or segmented button):**
- Surah number (default)
- Times recited (descending)
- Average quality (descending)
- Last recited (most recent first)

**Each surah card:**
- Surah number + name + arabic
- Times recited badge
- Average quality with color indicator (≥15 green, ≥10 yellow, <10 red)
- Last recited date (formatted)

Accept `embedded: true` parameter. Load from `manageProvider.loadReports()` on `initState`. Pull-to-refresh.

Match existing card/list patterns from the app.

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/schedule/reports_screen.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add reports screen with per-surah recitation stats
```

---

## Task 6: Expand ReciteScreen to 5 tabs

**Files:**
- Modify: `mobile/lib/features/recite/recite_screen.dart`

**Step 1: Update ReciteScreen from 2 tabs to 5 tabs**

Changes:
- `DefaultTabController(length: 5)`
- `TabBar` with `isScrollable: true` and `tabAlignment: TabAlignment.start`
- Tabs: Today, Schedules, Calendar, Reports, Pools
- `TabBarView` children: `TodayScreen`, `ScheduleListScreen`, `CalendarScreen`, `ReportsScreen`, `PoolsScreen` (all with `embedded: true`)

Add imports for the new screens.

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/recite/recite_screen.dart`
Expected: No errors

**Step 3: Commit**

```
feat: expand recite screen to 5 tabs with schedules, calendar, reports
```

---

## Task 7: Add "Generate Schedule" button to PoolDetailScreen

**Files:**
- Modify: `mobile/lib/features/pools/pool_detail_screen.dart`

**Step 1: Add generate schedule button**

In `PoolDetailScreen.build()`, add a button in the summary bar area (below the surah/page counts) or as a second FAB / action in the AppBar.

**Cleanest approach:** Add an `IconButton` in the `AppBar` actions:

```dart
AppBar(
  title: Text(widget.pool.name),
  actions: [
    IconButton(
      icon: const Icon(Icons.event_note_rounded, size: 22),
      tooltip: 'Generate Schedule',
      onPressed: () => _showScheduleGenerator(context),
    ),
  ],
),
```

Add method:
```dart
void _showScheduleGenerator(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => ScheduleGeneratorSheet(
        poolId: widget.pool.id,
        poolName: widget.pool.name,
        scrollController: scrollCtrl,
      ),
    ),
  );
}
```

Add import for `schedule_generator_sheet.dart`.

**Step 2: Verify**

Run: `cd mobile && flutter analyze lib/features/pools/pool_detail_screen.dart`
Expected: No errors

**Step 3: Commit**

```
feat: add generate schedule button to pool detail screen
```

---

## Task 8: Final integration verification

**Step 1:** Run full analysis:
```
cd mobile && flutter analyze lib/
```
Expected: No new errors from our changes

**Step 2:** Build the app:
```
cd mobile && flutter build apk --debug 2>&1 | tail -5
```
Expected: BUILD SUCCESSFUL

**Step 3: Commit all remaining changes**

```
feat: mobile schedule management, calendar, and reports
```
