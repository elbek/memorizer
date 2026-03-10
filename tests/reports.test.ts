import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF } from "cloudflare:test";

let cookie: string;
let poolId: number;
let scheduleId: number;
let scheduleItems: Array<{
  id: number;
  schedule_id: number;
  day_number: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  status: string;
}>;

async function registerAndGetCookie(
  name: string
): Promise<string> {
  const res = await SELF.fetch("http://localhost/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: `${name}@test.com`, name, password: "testpass1" }),
  });
  const setCookie = res.headers.get("set-cookie")!;
  return setCookie.split(";")[0]; // "token=xxx"
}

beforeAll(async () => {
  // Apply migration
  await env.DB.batch([
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS pools (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      is_system INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id),
      UNIQUE(user_id, name)
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS surah_pool (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pool_id INTEGER NOT NULL,
      surah_number INTEGER NOT NULL CHECK(surah_number >= 1 AND surah_number <= 114),
      added_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS schedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pool_id INTEGER NOT NULL,
      start_date TEXT NOT NULL,
      total_days INTEGER NOT NULL,
      cycle_days INTEGER,
      status TEXT DEFAULT 'active' CHECK(status IN ('active', 'completed', 'cancelled')),
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (pool_id) REFERENCES pools(id)
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS schedule_items (
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
    )`),
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS recitation_log (
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
    )`),
    env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_pools_user ON pools(user_id)`
    ),
    env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_surah_pool_pool ON surah_pool(pool_id)`
    ),
    env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_schedules_pool ON schedules(pool_id)`
    ),
    env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_schedule_items_schedule ON schedule_items(schedule_id, day_number)`
    ),
    env.DB.prepare(
      `CREATE INDEX IF NOT EXISTS idx_recitation_log_user ON recitation_log(user_id, surah_number)`
    ),
  ]);

  // Create trigger separately
  await env.DB.prepare(
    `CREATE TRIGGER IF NOT EXISTS enforce_surah_unique_per_user
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
    END`
  ).run();

  // Register user and get auth cookie
  cookie = await registerAndGetCookie("reportsuser");

  // Get the Sabak pool
  const listRes = await SELF.fetch("http://localhost/api/pools", {
    headers: { Cookie: cookie },
  });
  const listBody = (await listRes.json()) as {
    pools: { id: number; name: string }[];
  };
  const sabak = listBody.pools.find((p) => p.name === "Sabak")!;
  poolId = sabak.id;

  // Add surah 1 (Al-Fatihah, 0.5 pages) and surah 112 (Al-Ikhlas, 0.5 pages) to Sabak pool
  await SELF.fetch(`http://localhost/api/pools/${poolId}/surahs`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Cookie: cookie },
    body: JSON.stringify({ surah_number: 1 }),
  });
  await SELF.fetch(`http://localhost/api/pools/${poolId}/surahs`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Cookie: cookie },
    body: JSON.stringify({ surah_number: 112 }),
  });

  // Activate a schedule
  const activateRes = await SELF.fetch(
    "http://localhost/api/schedule/activate",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 1,
        start_date: "2026-02-26",
      }),
    }
  );
  const activateBody = (await activateRes.json()) as {
    ok: boolean;
    schedule_id: number;
  };
  scheduleId = activateBody.schedule_id;

  // Fetch the generated schedule items
  const itemsResult = await env.DB.prepare(
    "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
  )
    .bind(scheduleId)
    .all<{
      id: number;
      schedule_id: number;
      day_number: number;
      surah_number: number;
      start_page: number;
      end_page: number;
      status: string;
    }>();

  scheduleItems = itemsResult.results;
});

describe("Reports API", () => {
  it("returns empty stats when no recitations", async () => {
    const res = await SELF.fetch("http://localhost/api/reports", {
      headers: { Cookie: cookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { stats: unknown[] };
    expect(body.stats).toEqual([]);
  });

  it("returns correct stats after marking items done", async () => {
    // Mark the first item as done with quality 10
    const item1 = scheduleItems[0];
    await SELF.fetch(`http://localhost/api/item/${item1.id}/done`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ quality: 10 }),
    });

    // Mark the second item as done with quality 16
    const item2 = scheduleItems[1];
    await SELF.fetch(`http://localhost/api/item/${item2.id}/done`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ quality: 16 }),
    });

    // Now manually add another recitation_log entry for surah 1 to test aggregation
    // (item1 was surah 1; we add another log entry for the same surah with quality 14)
    await env.DB.prepare(
      `INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality)
       VALUES (?, ?, ?, ?, ?)`
    )
      .bind(
        1, // user id
        item1.surah_number,
        item1.start_page,
        item1.end_page,
        14
      )
      .run();

    const res = await SELF.fetch("http://localhost/api/reports", {
      headers: { Cookie: cookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      stats: Array<{
        surah_number: number;
        name: string;
        arabic: string;
        times_recited: number;
        avg_quality: number;
        min_quality: number;
        max_quality: number;
        last_recited: string;
      }>;
    };

    expect(body.stats.length).toBeGreaterThanOrEqual(1);

    // Find stats for surah 1 (Al-Fatihah) - should have 2 recitations (quality 10, 14)
    const surah1Stats = body.stats.find((s) => s.surah_number === item1.surah_number);
    expect(surah1Stats).toBeDefined();
    expect(surah1Stats!.times_recited).toBe(2);
    expect(surah1Stats!.avg_quality).toBe(12.0); // (10+14)/2 = 12.0
    expect(surah1Stats!.min_quality).toBe(10);
    expect(surah1Stats!.max_quality).toBe(14);
    expect(surah1Stats!.name).toBeTruthy();
    expect(surah1Stats!.arabic).toBeTruthy();
    expect(surah1Stats!.last_recited).toBeTruthy();

    // Find stats for surah 112 (Al-Ikhlas) - should have 1 recitation (quality 16)
    const surah112Stats = body.stats.find((s) => s.surah_number === item2.surah_number);
    expect(surah112Stats).toBeDefined();
    expect(surah112Stats!.times_recited).toBe(1);
    expect(surah112Stats!.avg_quality).toBe(16.0);
    expect(surah112Stats!.min_quality).toBe(16);
    expect(surah112Stats!.max_quality).toBe(16);
  });

  it("backup includes all data tables", async () => {
    // Ensure recitation logs exist by inserting directly
    // (The previous test may have created some via the API, but we ensure at least one here)
    const userId = 1; // first registered user
    await env.DB.prepare(
      `INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality)
       VALUES (?, ?, ?, ?, ?)`
    )
      .bind(userId, 1, 0, 0.5, 15)
      .run();

    const res = await SELF.fetch("http://localhost/api/reports/backup", {
      headers: { Cookie: cookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      exported_at: string;
      pools: unknown[];
      surah_entries: unknown[];
      schedules: unknown[];
      schedule_items: unknown[];
      recitation_logs: unknown[];
    };

    expect(body.exported_at).toBeTruthy();
    expect(body.pools.length).toBeGreaterThan(0);
    expect(body.surah_entries.length).toBeGreaterThan(0);
    expect(body.schedules.length).toBeGreaterThan(0);
    expect(body.schedule_items.length).toBeGreaterThan(0);
    expect(body.recitation_logs.length).toBeGreaterThan(0);
  });

  it("backup only includes current user's data", async () => {
    // Register a second user
    const otherCookie = await registerAndGetCookie("reportsother");

    // Get the other user's Sabak pool
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: otherCookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const otherSabak = listBody.pools.find((p) => p.name === "Sabak")!;

    // Add a surah to other user's pool
    await SELF.fetch(`http://localhost/api/pools/${otherSabak.id}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: otherCookie },
      body: JSON.stringify({ surah_number: 114 }),
    });

    // Activate a schedule for other user
    await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: otherCookie },
      body: JSON.stringify({
        pool_id: otherSabak.id,
        total_days: 1,
        start_date: "2026-02-26",
      }),
    });

    // Get backup for the OTHER user
    const otherBackupRes = await SELF.fetch(
      "http://localhost/api/reports/backup",
      {
        headers: { Cookie: otherCookie },
      }
    );
    const otherBackup = (await otherBackupRes.json()) as {
      exported_at: string;
      pools: Array<{ id: number; user_id: number }>;
      surah_entries: Array<{ pool_id: number }>;
      schedules: Array<{ pool_id: number }>;
      schedule_items: unknown[];
      recitation_logs: unknown[];
    };

    // Verify other user's backup only contains their pools
    const otherPoolIds = otherBackup.pools.map((p) => p.id);
    expect(otherPoolIds).toContain(otherSabak.id);
    expect(otherPoolIds).not.toContain(poolId); // Should NOT contain first user's pool

    // Verify surah_entries only belong to other user's pools
    for (const entry of otherBackup.surah_entries) {
      expect(otherPoolIds).toContain(entry.pool_id);
    }

    // Verify schedules only belong to other user's pools
    for (const sched of otherBackup.schedules) {
      expect(otherPoolIds).toContain(sched.pool_id);
    }

    // Other user has no recitation logs
    expect(otherBackup.recitation_logs).toEqual([]);

    // Now get backup for original user and verify it does NOT include other user's data
    const originalBackupRes = await SELF.fetch(
      "http://localhost/api/reports/backup",
      {
        headers: { Cookie: cookie },
      }
    );
    const originalBackup = (await originalBackupRes.json()) as {
      pools: Array<{ id: number }>;
      recitation_logs: unknown[];
    };

    const originalPoolIds = originalBackup.pools.map((p) => p.id);
    expect(originalPoolIds).toContain(poolId);
    expect(originalPoolIds).not.toContain(otherSabak.id);
  });
});
