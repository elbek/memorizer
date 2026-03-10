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
  cookie = await registerAndGetCookie("itemsuser");

  // Get the Sabak pool
  const listRes = await SELF.fetch("http://localhost/api/pools", {
    headers: { Cookie: cookie },
  });
  const listBody = (await listRes.json()) as {
    pools: { id: number; name: string }[];
  };
  const sabak = listBody.pools.find((p) => p.name === "Sabak")!;
  poolId = sabak.id;

  // Add surahs 78, 79, 80 (An-Naba 1.5pg, An-Nazi'at 1.5pg, Abasa 1pg) to Sabak pool
  for (const surahNum of [78, 79, 80]) {
    await SELF.fetch(`http://localhost/api/pools/${poolId}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ surah_number: surahNum }),
    });
  }

  // Activate a schedule: 3 surahs over 3 days = 1 surah/day
  const activateRes = await SELF.fetch(
    "http://localhost/api/schedule/activate",
    {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({
        pool_id: poolId,
        total_days: 3,
        start_date: "2026-01-01",
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

describe("Items API", () => {
  it("marks item as done with quality rating", async () => {
    const item = scheduleItems[0];
    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ quality: 15 }),
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);

    // Verify item is now done in DB
    const updated = await env.DB.prepare(
      "SELECT status, quality, completed_at FROM schedule_items WHERE id = ?"
    )
      .bind(item.id)
      .first<{ status: string; quality: number; completed_at: string }>();

    expect(updated!.status).toBe("done");
    expect(updated!.quality).toBe(15);
    expect(updated!.completed_at).toBeTruthy();
  });

  it("rejects quality of 0", async () => {
    const item = scheduleItems[1];
    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ quality: 0 }),
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("quality");
  });

  it("rejects quality of 21", async () => {
    const item = scheduleItems[1];
    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ quality: 21 }),
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("quality");
  });

  it("rejects missing quality", async () => {
    const item = scheduleItems[1];
    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({}),
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("quality");
  });

  it("creates a recitation log entry on done", async () => {
    const item = scheduleItems[2];

    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ quality: 18 }),
      }
    );
    expect(res.status).toBe(200);

    const log = await env.DB.prepare(
      "SELECT * FROM recitation_log WHERE schedule_item_id = ?"
    )
      .bind(item.id)
      .first<{
        user_id: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        quality: number;
        schedule_item_id: number;
      }>();

    expect(log).not.toBeNull();
    expect(log!.surah_number).toBe(item.surah_number);
    expect(log!.start_page).toBe(item.start_page);
    expect(log!.end_page).toBe(item.end_page);
    expect(log!.quality).toBe(18);
    expect(log!.schedule_item_id).toBe(item.id);
  });

  it("returns 404 for item belonging to another user", async () => {
    const otherCookie = await registerAndGetCookie("otheruser");
    const item = scheduleItems[1];

    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/done`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: otherCookie },
        body: JSON.stringify({ quality: 10 }),
      }
    );

    expect(res.status).toBe(404);
  });

  it("marks item as partial and creates carry-forward item with recitation log", async () => {
    // First, create a new schedule so we have fresh pending items
    const activateRes = await SELF.fetch(
      "http://localhost/api/schedule/activate",
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({
          pool_id: poolId,
          total_days: 3,
          start_date: "2026-06-01",
        }),
      }
    );
    const activateBody = (await activateRes.json()) as {
      ok: boolean;
      schedule_id: number;
    };
    const newScheduleId = activateBody.schedule_id;

    // Fetch the new schedule items
    const newItemsResult = await env.DB.prepare(
      "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
    )
      .bind(newScheduleId)
      .all<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
      }>();

    const newItems = newItemsResult.results;
    const item = newItems[0]; // Use first item
    // stopped_at_page must be strictly between start_page and end_page
    const stoppedAt = item.start_page + (item.end_page - item.start_page) / 2;

    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/partial`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ stopped_at_page: stoppedAt, quality: 12 }),
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);

    // Verify original item is now partial with end_page = stoppedAt
    const updated = await env.DB.prepare(
      "SELECT status, end_page, quality, completed_at FROM schedule_items WHERE id = ?"
    )
      .bind(item.id)
      .first<{
        status: string;
        end_page: number;
        quality: number;
        completed_at: string;
      }>();

    expect(updated!.status).toBe("partial");
    expect(updated!.end_page).toBe(stoppedAt);
    expect(updated!.quality).toBe(12);
    expect(updated!.completed_at).toBeTruthy();

    // Verify carry-forward item was created on next day
    const carryForward = await env.DB.prepare(
      `SELECT * FROM schedule_items
       WHERE schedule_id = ? AND day_number = ? AND start_page = ? AND status = 'pending'
       ORDER BY id DESC LIMIT 1`
    )
      .bind(item.schedule_id, item.day_number + 1, stoppedAt)
      .first<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
      }>();

    expect(carryForward).not.toBeNull();
    expect(carryForward!.surah_number).toBe(item.surah_number);
    expect(carryForward!.start_page).toBe(stoppedAt);
    expect(carryForward!.end_page).toBe(item.end_page);
    expect(carryForward!.day_number).toBe(item.day_number + 1);
    expect(carryForward!.status).toBe("pending");

    // Verify recitation log records only the completed portion
    const log = await env.DB.prepare(
      "SELECT * FROM recitation_log WHERE schedule_item_id = ?"
    )
      .bind(item.id)
      .first<{
        user_id: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        quality: number;
        schedule_item_id: number;
      }>();

    expect(log).not.toBeNull();
    expect(log!.surah_number).toBe(item.surah_number);
    expect(log!.start_page).toBe(item.start_page);
    expect(log!.end_page).toBe(stoppedAt); // Only up to stopped_at_page
    expect(log!.quality).toBe(12);
  });

  it("rejects stopped_at_page at or before start_page", async () => {
    // Use the original scheduleItems which still have items
    // Create another fresh schedule for partial validation tests
    const activateRes = await SELF.fetch(
      "http://localhost/api/schedule/activate",
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({
          pool_id: poolId,
          total_days: 3,
          start_date: "2026-07-01",
        }),
      }
    );
    const activateBody = (await activateRes.json()) as {
      ok: boolean;
      schedule_id: number;
    };

    const newItemsResult = await env.DB.prepare(
      "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
    )
      .bind(activateBody.schedule_id)
      .all<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
      }>();

    const item = newItemsResult.results[0];

    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/partial`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({
          stopped_at_page: item.start_page,
          quality: 10,
        }),
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("stopped_at_page");
  });

  it("rejects stopped_at_page at or after end_page", async () => {
    // Use the latest schedule's items
    const latestSchedule = await env.DB.prepare(
      "SELECT id FROM schedules WHERE pool_id = ? AND status = 'active' ORDER BY id DESC LIMIT 1"
    )
      .bind(poolId)
      .first<{ id: number }>();

    const newItemsResult = await env.DB.prepare(
      "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
    )
      .bind(latestSchedule!.id)
      .all<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
      }>();

    const item = newItemsResult.results[0];

    const res = await SELF.fetch(
      `http://localhost/api/item/${item.id}/partial`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({
          stopped_at_page: item.end_page,
          quality: 10,
        }),
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("stopped_at_page");
  });
});
