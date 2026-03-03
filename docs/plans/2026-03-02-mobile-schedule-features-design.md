# Mobile Schedule, Calendar & Reports — Design

## Goal
Match the web UI's schedule management features in the mobile Flutter app.

## What Already Exists (mobile)
- TodayScreen: daily assignments per pool, Done/Partial with quality rating
- PoolsScreen + PoolDetailScreen: create/delete pools, add/remove surahs, add juz
- ReciteScreen: 2-tab container (Schedule, Pools)

## New Features

### 1. Schedule Generator (bottom sheet from PoolDetailScreen)
- Button on PoolDetailScreen: "Generate Schedule"
- Bottom sheet fields: cycle days, total range days, start date, shuffle toggle
- Preview → `POST /api/schedule/generate` → scrollable daily breakdown
- Activate → `POST /api/schedule/activate`
- On success: close sheet, show snackbar, refresh pool data

### 2. Schedule List Screen (new tab)
- `GET /api/schedule/list` → list of schedule cards
- Each card: pool name, date range (start–end), progress bar (done/total), status badge
- Delete button for non-completed schedules → `DELETE /api/schedule/:id/delete`
- Pull-to-refresh

### 3. Calendar Month View (new tab)
- Month grid with left/right navigation
- Fetch schedule items for visible month via `GET /api/schedule/list` + `GET /api/schedule/:poolId`
- Color-coded day cells: green (all done), yellow (has partial), red (past + pending), gray (future)
- Tap day → bottom detail showing that day's items via `GET /api/today?date=YYYY-MM-DD`
- Optional pool filter dropdown

### 4. Reports Screen (new tab)
- `GET /api/reports/` → per-surah stats
- Summary row: total recitations, average quality across all surahs
- Scrollable list: surah name, arabic, times recited, avg quality, last recited date
- Sort by: surah number, times recited, avg quality, last recited

## Navigation Change
ReciteScreen tabs: 2 → 5
**Today | Schedules | Calendar | Reports | Pools**

Tabs are scrollable (TabBar with `isScrollable: true`) since 5 tabs won't fit comfortably.

## New Files
- `lib/features/schedule/manage_provider.dart` — schedule list, generate, activate, reports, calendar data
- `lib/features/schedule/schedule_list_screen.dart` — schedule list tab
- `lib/features/schedule/schedule_generator_sheet.dart` — bottom sheet for generating/activating
- `lib/features/schedule/calendar_screen.dart` — month calendar view
- `lib/features/schedule/reports_screen.dart` — per-surah reports

## Modified Files
- `lib/features/recite/recite_screen.dart` — expand to 5 tabs
- `lib/features/pools/pool_detail_screen.dart` — add "Generate Schedule" button

## Data Models (in manage_provider.dart)

```dart
class ScheduleSummary {
  int id, poolId, totalDays, itemsTotal, itemsDone, itemsPending, itemsPartial;
  int? cycleDays;
  String poolName, status, startDate, endDate, createdAt;
}

class SchedulePreviewDay {
  int dayNumber, cycle;
  String date;
  List<SchedulePreviewChunk> chunks;
}

class SchedulePreviewChunk {
  int surahNumber;
  String surahName;
  double startPage, endPage, pages;
}

class SurahReport {
  int surahNumber, timesRecited, minQuality, maxQuality;
  String name, arabic, lastRecited;
  double avgQuality;
}
```

## API Endpoints Used
| Endpoint | Feature |
|----------|---------|
| POST /api/schedule/generate | Schedule generator preview |
| POST /api/schedule/activate | Schedule generator activate |
| GET /api/schedule/list | Schedule list tab |
| DELETE /api/schedule/:id/delete | Schedule list delete |
| GET /api/today?date=YYYY-MM-DD | Calendar day detail |
| GET /api/reports/ | Reports tab |
