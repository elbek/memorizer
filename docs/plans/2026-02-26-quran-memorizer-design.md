# Quran Memorizer App - Design Document

## Overview

A mobile-first web app for tracking Quran memorization progress. Deployed as a Cloudflare Worker with D1 database. Users register with name + 5-digit PIN, manage surah pools, generate balanced daily schedules, track completion, and rate memorization quality.

## Architecture

- **Runtime:** Cloudflare Worker (ES modules)
- **Routing:** Hono (~14kb, built for workers)
- **Database:** Cloudflare D1 (SQLite)
- **Auth:** JWT in httpOnly cookie, PIN hashed with SHA-256 + salt
- **Frontend:** Single HTML file, Tailwind CSS via CDN, vanilla JS
- **No external dependencies** beyond Hono and D1

## Data Model

### Tables

**users**
- `id` INTEGER PRIMARY KEY
- `name` TEXT UNIQUE NOT NULL
- `pin_hash` TEXT NOT NULL
- `pin_salt` TEXT NOT NULL
- `created_at` TEXT DEFAULT CURRENT_TIMESTAMP

**pools**
- `id` INTEGER PRIMARY KEY
- `user_id` INTEGER NOT NULL (FK → users)
- `name` TEXT NOT NULL (e.g., "Sabak", "Manzil", or custom name)
- `is_system` INTEGER DEFAULT 0 (1 for Sabak/Manzil, auto-created on registration)
- `created_at` TEXT DEFAULT CURRENT_TIMESTAMP
- UNIQUE(user_id, name)

**surah_pool**
- `id` INTEGER PRIMARY KEY
- `pool_id` INTEGER NOT NULL (FK → pools)
- `surah_number` INTEGER NOT NULL (1-114)
- `added_at` TEXT DEFAULT CURRENT_TIMESTAMP
- UNIQUE(pool_id → user_id, surah_number) — enforces surah belongs to only one pool per user

**schedules**
- `id` INTEGER PRIMARY KEY
- `pool_id` INTEGER NOT NULL (FK → pools)
- `start_date` TEXT NOT NULL
- `total_days` INTEGER NOT NULL
- `status` TEXT DEFAULT 'active'
- `created_at` TEXT DEFAULT CURRENT_TIMESTAMP

**schedule_items**
- `id` INTEGER PRIMARY KEY
- `schedule_id` INTEGER NOT NULL (FK → schedules)
- `day_number` INTEGER NOT NULL
- `surah_number` INTEGER NOT NULL
- `start_page` REAL NOT NULL
- `end_page` REAL NOT NULL
- `status` TEXT DEFAULT 'pending' ('pending' | 'partial' | 'done')
- `completed_at` TEXT
- `quality` INTEGER (1-20, NULL until rated)

**recitation_log**
- `id` INTEGER PRIMARY KEY
- `user_id` INTEGER NOT NULL (FK → users)
- `surah_number` INTEGER NOT NULL
- `start_page` REAL NOT NULL
- `end_page` REAL NOT NULL
- `quality` INTEGER NOT NULL (1-20)
- `recited_at` TEXT DEFAULT CURRENT_TIMESTAMP
- `schedule_item_id` INTEGER (FK → schedule_items)

### Static Data

Surah metadata (name, Arabic name, page count in 15-line mushaf) embedded as a JS constant. 114 entries, no DB needed.

## Scheduling Algorithm

1. Collect all surahs in the selected pool
2. Expand each surah to its page range (e.g., Al-Baqarah = 48 pages)
3. Calculate `target_per_day = total_pages / num_days`
4. Walk through pages sequentially, filling each day up to the target
5. Split surahs at page boundaries when needed
6. Minimum chunk size: 0.5 pages (avoid tiny fragments)
7. Prefer slightly over-filling current day vs. starting a tiny chunk on next day

### Carry-Forward on Partial Completion

- User marks item as "partial" → app asks which page they stopped at
- Remaining pages become a new item pushed to the next day
- Future days are NOT reshuffled — incomplete work stacks on the next day
- This ensures no surah/page is ever skipped

## Screens & Navigation

Bottom tab bar: **Home | Pools | Calendar | Reports**

### Screen 1: Login/Register
- Name + 5-digit PIN form
- New name → register; existing name + correct PIN → login

### Screen 2: Home (Dashboard)
- Grouped by pool: shows each pool's assignments for today
- Sabak and Manzil shown first (system pools), then custom pools
- For each item: Mark Done / Mark Partial buttons
- Quality slider (1-20) appears on completion
- Progress summary per pool: "Day 3 of 10 — 6 pages today"

### Screen 3: Pool Management
- Shows all pools as cards/tabs (Sabak, Manzil, + any custom pools)
- "Create Pool" button to add custom pools
- For each pool: searchable list of 114 surahs with page counts
- Tap to add/remove from pool
- Surah already in another pool shown as greyed out with pool name label
- Total pages per pool displayed
- "Generate Schedule" button per pool → schedule setup flow
  - Set number of days + start date
  - Preview day-by-day breakdown
  - Confirm to activate

### Screen 4: Calendar View
- Monthly calendar grid
- Each day shows page count badge
- Color coding: green (done), yellow (partial), grey (upcoming), red (missed)
- Tap day → drill into detail: each chunk with surah name, page range, status, quality
- Filter by pool (All / Sabak / Manzil / custom pools)
- Navigate between months

### Screen 5: Reports
- Per-surah stats table: times recited, avg/min/max quality, last recited
- Overall progress summary
- Export/backup: download all data as JSON

## API Endpoints

| Method | Route | Purpose |
|--------|-------|---------|
| POST | `/api/auth/register` | Create user |
| POST | `/api/auth/login` | Login, set JWT cookie |
| GET | `/api/today` | Today's assignments |
| GET | `/api/pools` | List user's pools |
| POST | `/api/pools` | Create custom pool |
| DELETE | `/api/pools/:id` | Delete custom pool |
| GET | `/api/pools/:id/surahs` | List surahs in a pool |
| POST | `/api/pools/:id/surahs` | Add surah to pool |
| DELETE | `/api/pools/:id/surahs/:surahNum` | Remove surah from pool |
| POST | `/api/schedule/generate` | Preview schedule for a pool |
| POST | `/api/schedule/activate` | Save & activate |
| GET | `/api/schedule/:poolId` | View current schedule for pool |
| PATCH | `/api/item/:id` | Mark done/partial + quality |
| GET | `/api/reports` | Per-surah stats |
| GET | `/api/backup` | Full JSON export |

## Backup Strategy

- GET `/api/backup` returns complete JSON of all user data
- User can download on demand from Reports screen
- Includes: pool config, schedules, all recitation logs with quality ratings

## Key Constraints

- Mobile-first responsive design
- Surah belongs to exactly one pool (unique constraint on user_id + surah_number)
- Quality rating 1-20 required on completion
- Page sizes based on 15-line mushaf standard
- PIN hashed with SHA-256 + per-user salt (Web Crypto API)
