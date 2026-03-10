-- Add 'missed' to schedule_items status CHECK constraint
-- SQLite doesn't support ALTER CHECK, so we recreate the table

PRAGMA foreign_keys = OFF;

CREATE TABLE schedule_items_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  schedule_id INTEGER NOT NULL,
  day_number INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  start_page REAL NOT NULL,
  end_page REAL NOT NULL,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'partial', 'done', 'missed')),
  completed_at TEXT,
  quality INTEGER CHECK(quality IS NULL OR (quality >= 1 AND quality <= 20)),
  FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

INSERT INTO schedule_items_new SELECT * FROM schedule_items;

DROP TABLE schedule_items;

ALTER TABLE schedule_items_new RENAME TO schedule_items;

CREATE INDEX IF NOT EXISTS idx_schedule_items_schedule ON schedule_items(schedule_id, day_number);

PRAGMA foreign_keys = ON;
