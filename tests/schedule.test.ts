import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF } from "cloudflare:test";

let cookie: string;
let poolId: number;

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
  cookie = await registerAndGetCookie("scheduleuser");

  // Get the Sabak pool
  const listRes = await SELF.fetch("http://localhost/api/pools", {
    headers: { Cookie: cookie },
  });
  const listBody = (await listRes.json()) as {
    pools: { id: number; name: string }[];
  };
  const sabak = listBody.pools.find((p) => p.name === "Sabak")!;
  poolId = sabak.id;

  // Add surahs 112, 113, 114 to the Sabak pool
  for (const surahNum of [112, 113, 114]) {
    await SELF.fetch(`http://localhost/api/pools/${poolId}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ surah_number: surahNum }),
    });
  }
});

describe("Schedule API", () => {
  it("generates a preview with correct day structure", async () => {
    const res = await SELF.fetch("http://localhost/api/schedule/generate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: "2026-01-01",
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      days: Array<{
        day_number: number;
        date: string;
        chunks: Array<{
          surah_number: number;
          surah_name: string;
          start_page: number;
          end_page: number;
          pages: number;
        }>;
      }>;
      total_pages: number;
      pages_per_day: number;
    };

    // 3 surahs x 0.5 pages = 1.5 total pages
    expect(body.total_pages).toBe(1.5);
    expect(body.pages_per_day).toBe(0.5);
    expect(body.days).toHaveLength(3);

    // Verify day numbers and dates
    expect(body.days[0].day_number).toBe(1);
    expect(body.days[0].date).toBe("2026-01-01");
    expect(body.days[1].day_number).toBe(2);
    expect(body.days[1].date).toBe("2026-01-02");
    expect(body.days[2].day_number).toBe(3);
    expect(body.days[2].date).toBe("2026-01-03");

    // Each day should have 1 chunk of 0.5 pages (one surah per day)
    for (const day of body.days) {
      expect(day.chunks.length).toBeGreaterThanOrEqual(1);
    }

    // Verify surah names are enriched
    const allChunks = body.days.flatMap((d) => d.chunks);
    const surahNumbers = allChunks.map((c) => c.surah_number);
    expect(surahNumbers).toContain(112);
    expect(surahNumbers).toContain(113);
    expect(surahNumbers).toContain(114);
  });

  it("activates a schedule, creating schedule and items in DB", async () => {
    const res = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: "2026-01-01",
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; schedule_id: number };
    expect(body.ok).toBe(true);
    expect(body.schedule_id).toBeGreaterThan(0);

    // Verify schedule exists in DB
    const sched = await env.DB.prepare(
      "SELECT * FROM schedules WHERE id = ?"
    )
      .bind(body.schedule_id)
      .first<{
        id: number;
        pool_id: number;
        start_date: string;
        total_days: number;
        status: string;
      }>();

    expect(sched).not.toBeNull();
    expect(sched!.pool_id).toBe(poolId);
    expect(sched!.start_date).toBe("2026-01-01");
    expect(sched!.total_days).toBe(3);
    expect(sched!.status).toBe("active");

    // Verify schedule_items exist
    const items = await env.DB.prepare(
      "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
    )
      .bind(body.schedule_id)
      .all<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
      }>();

    // We have 3 surahs of 0.5 pages across 3 days = 3 items
    expect(items.results.length).toBe(3);

    // All items should be pending
    for (const item of items.results) {
      expect(item.status).toBe("pending");
    }
  });

  it("activating new schedule marks previous as completed with missed items", async () => {
    // First activation
    const res1 = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: "2026-02-01",
      }),
    });
    const body1 = (await res1.json()) as { ok: boolean; schedule_id: number };
    const firstScheduleId = body1.schedule_id;

    // Second activation
    const res2 = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: "2026-03-01",
      }),
    });
    const body2 = (await res2.json()) as { ok: boolean; schedule_id: number };
    const secondScheduleId = body2.schedule_id;

    expect(secondScheduleId).not.toBe(firstScheduleId);

    // First schedule should be completed (not deleted)
    const firstSched = await env.DB.prepare(
      "SELECT status FROM schedules WHERE id = ?"
    )
      .bind(firstScheduleId)
      .first<{ status: string }>();
    expect(firstSched).not.toBeNull();
    expect(firstSched!.status).toBe("completed");

    // First schedule's pending items should be marked as missed
    const missedItems = await env.DB.prepare(
      "SELECT COUNT(*) as count FROM schedule_items WHERE schedule_id = ? AND status = 'missed'"
    ).bind(firstScheduleId).first<{ count: number }>();
    expect(missedItems!.count).toBeGreaterThan(0);

    // No pending items should remain
    const pendingItems = await env.DB.prepare(
      "SELECT COUNT(*) as count FROM schedule_items WHERE schedule_id = ? AND status = 'pending'"
    ).bind(firstScheduleId).first<{ count: number }>();
    expect(pendingItems!.count).toBe(0);

    // Second schedule should be active
    const secondSched = await env.DB.prepare(
      "SELECT status FROM schedules WHERE id = ?"
    )
      .bind(secondScheduleId)
      .first<{ status: string }>();
    expect(secondSched!.status).toBe("active");
  });

  it("GET /:poolId returns schedule with enriched items", async () => {
    // Ensure there is an active schedule for this pool
    const activateRes = await SELF.fetch(
      "http://localhost/api/schedule/activate",
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({
          pool_id: poolId,
          total_days: 3,
          start_date: "2026-04-01",
        }),
      }
    );
    expect(activateRes.status).toBe(200);

    const res = await SELF.fetch(
      `http://localhost/api/schedule/${poolId}`,
      {
        headers: { Cookie: cookie },
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      schedule: {
        id: number;
        pool_id: number;
        start_date: string;
        total_days: number;
        status: string;
      };
      items: Array<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        surah_name: string;
        arabic: string;
        start_page: number;
        end_page: number;
        pages: number;
        status: string;
      }>;
    };

    expect(body.schedule).toBeDefined();
    expect(body.schedule.pool_id).toBe(poolId);
    expect(body.schedule.status).toBe("active");

    // Items should be enriched with surah metadata
    expect(body.items.length).toBeGreaterThan(0);
    for (const item of body.items) {
      expect(item.surah_name).toBeTruthy();
      expect(item.arabic).toBeTruthy();
      expect(typeof item.pages).toBe("number");
    }

    // Check surah numbers
    const surahNumbers = [...new Set(body.items.map((i) => i.surah_number))];
    expect(surahNumbers).toContain(112);
    expect(surahNumbers).toContain(113);
    expect(surahNumbers).toContain(114);
  });

  it("GET /today returns today's assignments grouped by pool", async () => {
    // Create a schedule that starts today
    const today = new Date();
    const todayStr =
      today.getUTCFullYear() +
      "-" +
      String(today.getUTCMonth() + 1).padStart(2, "0") +
      "-" +
      String(today.getUTCDate()).padStart(2, "0");

    // Activate a schedule starting today
    await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: todayStr,
      }),
    });

    const res = await SELF.fetch("http://localhost/api/today", {
      headers: { Cookie: cookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      pools: Array<{
        pool_id: number;
        pool_name: string;
        day_number: number;
        total_days: number;
        items: Array<{
          id: number;
          surah_number: number;
          surah_name: string;
          arabic: string;
          start_page: number;
          end_page: number;
          pages: number;
          status: string;
          quality: number | null;
        }>;
      }>;
    };

    expect(body.pools.length).toBeGreaterThanOrEqual(1);

    const poolEntry = body.pools.find((p) => p.pool_id === poolId);
    expect(poolEntry).toBeDefined();
    expect(poolEntry!.pool_name).toBe("Sabak");
    expect(poolEntry!.day_number).toBe(1);
    expect(poolEntry!.total_days).toBe(3);
    expect(poolEntry!.items.length).toBeGreaterThanOrEqual(1);

    // Items should have enriched metadata
    for (const item of poolEntry!.items) {
      expect(item.surah_name).toBeTruthy();
      expect(item.arabic).toBeTruthy();
      expect(item.status).toBe("pending");
    }
  });

  it("POST /:scheduleId/end marks schedule completed and items missed", async () => {
    // Activate a schedule
    const activateRes = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 5,
        start_date: "2026-05-01",
      }),
    });
    const { schedule_id: schedId } = (await activateRes.json()) as { schedule_id: number };

    // End the schedule
    const endRes = await SELF.fetch(`http://localhost/api/schedule/${schedId}/end`, {
      method: "POST",
      headers: { Cookie: cookie },
    });
    expect(endRes.status).toBe(200);

    // Schedule should be completed
    const sched = await env.DB.prepare("SELECT status FROM schedules WHERE id = ?")
      .bind(schedId).first<{ status: string }>();
    expect(sched!.status).toBe("completed");

    // Pending items should be marked missed
    const pending = await env.DB.prepare(
      "SELECT COUNT(*) as c FROM schedule_items WHERE schedule_id = ? AND status = 'pending'"
    ).bind(schedId).first<{ c: number }>();
    expect(pending!.c).toBe(0);

    const missed = await env.DB.prepare(
      "SELECT COUNT(*) as c FROM schedule_items WHERE schedule_id = ? AND status = 'missed'"
    ).bind(schedId).first<{ c: number }>();
    expect(missed!.c).toBeGreaterThan(0);
  });

  it("POST /:scheduleId/end rejects non-active schedule", async () => {
    // Create and end a schedule first
    const activateRes = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ pool_id: poolId, total_days: 3, start_date: "2026-06-01" }),
    });
    const { schedule_id: schedId } = (await activateRes.json()) as { schedule_id: number };
    await SELF.fetch(`http://localhost/api/schedule/${schedId}/end`, {
      method: "POST",
      headers: { Cookie: cookie },
    });

    // Try to end again — should fail
    const endRes = await SELF.fetch(`http://localhost/api/schedule/${schedId}/end`, {
      method: "POST",
      headers: { Cookie: cookie },
    });
    expect(endRes.status).toBe(400);
  });

  it("GET /:scheduleId/history returns items with stats", async () => {
    // Activate a schedule
    const activateRes = await SELF.fetch("http://localhost/api/schedule/activate", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ pool_id: poolId, total_days: 3, start_date: "2026-07-01" }),
    });
    const { schedule_id: schedId } = (await activateRes.json()) as { schedule_id: number };

    // Mark one item as done
    const items = await env.DB.prepare(
      "SELECT id FROM schedule_items WHERE schedule_id = ? LIMIT 1"
    ).bind(schedId).first<{ id: number }>();

    await SELF.fetch(`http://localhost/api/item/${items!.id}/done`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ quality: 15 }),
    });

    // Fetch history
    const histRes = await SELF.fetch(`http://localhost/api/schedule/${schedId}/history`, {
      headers: { Cookie: cookie },
    });
    expect(histRes.status).toBe(200);

    const body = (await histRes.json()) as {
      schedule: { id: number; pool_name: string; status: string; end_date: string };
      items: Array<{ surah_name: string; status: string; quality: number | null; date: string }>;
      stats: { total: number; done: number; partial: number; pending: number; missed: number; avg_quality: number };
    };

    expect(body.schedule.id).toBe(schedId);
    expect(body.schedule.end_date).toBeTruthy();
    expect(body.items.length).toBeGreaterThan(0);
    expect(body.stats.done).toBe(1);
    expect(body.stats.avg_quality).toBe(15);

    // Items should have date field
    for (const item of body.items) {
      expect(item.date).toBeTruthy();
      expect(item.surah_name).toBeTruthy();
    }
  });

  it("GET /today auto-completes expired schedules and returns expired array", async () => {
    // Insert a schedule that ended in the past directly in DB
    const pastStart = "2025-01-01";
    const result = await env.DB.prepare(
      "INSERT INTO schedules (pool_id, start_date, total_days, status) VALUES (?, ?, ?, 'active')"
    ).bind(poolId, pastStart, 3).run();
    const expiredSchedId = result.meta.last_row_id as number;

    // Insert some items
    await env.DB.prepare(
      "INSERT INTO schedule_items (schedule_id, day_number, surah_number, start_page, end_page) VALUES (?, 1, 112, 0, 0.5)"
    ).bind(expiredSchedId).run();

    const res = await SELF.fetch("http://localhost/api/today?date=2025-02-01", {
      headers: { Cookie: cookie },
    });
    expect(res.status).toBe(200);

    const body = (await res.json()) as {
      pools: Array<Record<string, unknown>>;
      expired: Array<{ pool_id: number; pool_name: string; end_date: string }>;
    };

    // Should have expired entry
    expect(body.expired.length).toBeGreaterThanOrEqual(1);
    const exp = body.expired.find((e) => e.pool_id === poolId);
    expect(exp).toBeDefined();
    expect(exp!.end_date).toBe("2025-01-03");

    // Schedule should now be completed in DB
    const sched = await env.DB.prepare("SELECT status FROM schedules WHERE id = ?")
      .bind(expiredSchedId).first<{ status: string }>();
    expect(sched!.status).toBe("completed");

    // Pending items should be marked missed
    const pending = await env.DB.prepare(
      "SELECT COUNT(*) as c FROM schedule_items WHERE schedule_id = ? AND status = 'pending'"
    ).bind(expiredSchedId).first<{ c: number }>();
    expect(pending!.c).toBe(0);
  });

  it("GET /schedule/list auto-completes expired schedules", async () => {
    // Insert an expired active schedule directly
    const result = await env.DB.prepare(
      "INSERT INTO schedules (pool_id, start_date, total_days, status) VALUES (?, '2024-01-01', 2, 'active')"
    ).bind(poolId).run();
    const schedId = result.meta.last_row_id as number;
    await env.DB.prepare(
      "INSERT INTO schedule_items (schedule_id, day_number, surah_number, start_page, end_page) VALUES (?, 1, 113, 0, 0.5)"
    ).bind(schedId).run();

    const res = await SELF.fetch("http://localhost/api/schedule/list", {
      headers: { Cookie: cookie },
    });
    expect(res.status).toBe(200);

    const body = (await res.json()) as {
      schedules: Array<{ id: number; status: string; items_missed: number }>;
    };

    const found = body.schedules.find((s) => s.id === schedId);
    expect(found).toBeDefined();
    expect(found!.status).toBe("completed");
    expect(found!.items_missed).toBeGreaterThanOrEqual(1);
  });

  it("GET /today returns empty when no active schedules", async () => {
    // Register a fresh user with no schedules
    const freshCookie = await registerAndGetCookie("noscheduser");

    const res = await SELF.fetch("http://localhost/api/today", {
      headers: { Cookie: freshCookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      pools: Array<Record<string, unknown>>;
    };
    expect(body.pools).toHaveLength(0);
  });
});
