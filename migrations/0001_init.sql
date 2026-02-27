-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Pools (Sabak & Manzil are system pools, users can create custom ones)
CREATE TABLE IF NOT EXISTS pools (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  is_system INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE(user_id, name)
);

-- Surah pool entries (unique per user across ALL pools)
CREATE TABLE IF NOT EXISTS surah_pool (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pool_id INTEGER NOT NULL,
  surah_number INTEGER NOT NULL CHECK(surah_number >= 1 AND surah_number <= 114),
  added_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE
);

-- Trigger to enforce surah uniqueness per user across all pools
CREATE TRIGGER IF NOT EXISTS enforce_surah_unique_per_user
BEFORE INSERT ON surah_pool
BEGIN
  SELECT RAISE(ABORT, 'Surah already in another pool')
  WHERE EXISTS (
    SELECT 1 FROM surah_pool sp
    JOIN pools p ON sp.pool_id = p.id
    JOIN pools p2 ON p2.id = NEW.pool_id
    WHERE sp.surah_number = NEW.surah_number
    AND p.user_id = p2.user_id
  );
END;

-- Schedules
CREATE TABLE IF NOT EXISTS schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pool_id INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  total_days INTEGER NOT NULL,
  cycle_days INTEGER,
  status TEXT DEFAULT 'active' CHECK(status IN ('active', 'completed', 'cancelled')),
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (pool_id) REFERENCES pools(id)
);

-- Schedule items (daily assignments)
CREATE TABLE IF NOT EXISTS schedule_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  schedule_id INTEGER NOT NULL,
  day_number INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  start_page REAL NOT NULL,
  end_page REAL NOT NULL,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'partial', 'done')),
  completed_at TEXT,
  quality INTEGER CHECK(quality IS NULL OR (quality >= 1 AND quality <= 20)),
  FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- Recitation log (historical record)
CREATE TABLE IF NOT EXISTS recitation_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  start_page REAL NOT NULL,
  end_page REAL NOT NULL,
  quality INTEGER NOT NULL CHECK(quality >= 1 AND quality <= 20),
  recited_at TEXT DEFAULT (datetime('now')),
  schedule_item_id INTEGER,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (schedule_item_id) REFERENCES schedule_items(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pools_user ON pools(user_id);
CREATE INDEX IF NOT EXISTS idx_surah_pool_pool ON surah_pool(pool_id);
CREATE INDEX IF NOT EXISTS idx_schedules_pool ON schedules(pool_id);
CREATE INDEX IF NOT EXISTS idx_schedule_items_schedule ON schedule_items(schedule_id, day_number);
CREATE INDEX IF NOT EXISTS idx_recitation_log_user ON recitation_log(user_id, surah_number);
