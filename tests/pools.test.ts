import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF } from "cloudflare:test";

async function registerAndGetCookie(
  name: string,
  pin: string
): Promise<string> {
  const res = await SELF.fetch("http://localhost/api/auth/register", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, pin }),
  });
  const cookie = res.headers.get("set-cookie")!;
  return cookie.split(";")[0]; // "token=xxx"
}

beforeAll(async () => {
  // Apply migration statements individually
  await env.DB.batch([
    env.DB.prepare(`CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
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
      status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'partial', 'done')),
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
});

describe("Pool Management API", () => {
  it("lists pools returns Sabak and Manzil (auto-created on registration)", async () => {
    const cookie = await registerAndGetCookie("listpools", "12345");

    const res = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      pools: {
        id: number;
        name: string;
        is_system: number;
        created_at: string;
      }[];
    };
    expect(body.pools).toHaveLength(3);

    const names = body.pools.map((p) => p.name);
    expect(names).toContain("Sabak");
    expect(names).toContain("Manzil");
    expect(names).toContain("Daily");

    for (const pool of body.pools) {
      expect(pool.is_system).toBe(1);
    }
  });

  it("creates a custom pool successfully", async () => {
    const cookie = await registerAndGetCookie("createpool", "12345");

    const res = await SELF.fetch("http://localhost/api/pools", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ name: "Review" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; id: number };
    expect(body.ok).toBe(true);
    expect(body.id).toBeGreaterThan(0);
  });

  it("rejects duplicate pool name with 409", async () => {
    const cookie = await registerAndGetCookie("duppool", "12345");

    // Create pool first time
    await SELF.fetch("http://localhost/api/pools", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ name: "Review" }),
    });

    // Try to create same pool name again
    const res = await SELF.fetch("http://localhost/api/pools", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ name: "Review" }),
    });

    expect(res.status).toBe(409);
  });

  it("cannot delete system pool (400)", async () => {
    const cookie = await registerAndGetCookie("delsyspool", "12345");

    // Get pools to find a system pool
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string; is_system: number }[];
    };
    const systemPool = listBody.pools.find((p) => p.is_system === 1)!;

    const res = await SELF.fetch(
      `http://localhost/api/pools/${systemPool.id}`,
      {
        method: "DELETE",
        headers: { Cookie: cookie },
      }
    );

    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe("Cannot delete system pool");
  });

  it("can delete custom pool", async () => {
    const cookie = await registerAndGetCookie("delcustpool", "12345");

    // Create a custom pool
    const createRes = await SELF.fetch("http://localhost/api/pools", {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ name: "ToDelete" }),
    });
    const createBody = (await createRes.json()) as {
      ok: boolean;
      id: number;
    };

    // Delete it
    const res = await SELF.fetch(
      `http://localhost/api/pools/${createBody.id}`,
      {
        method: "DELETE",
        headers: { Cookie: cookie },
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);

    // Verify it no longer appears in the list
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const found = listBody.pools.find((p) => p.id === createBody.id);
    expect(found).toBeUndefined();
  });

  it("adds surah to pool and lists surahs enriched with metadata", async () => {
    const cookie = await registerAndGetCookie("addsurah", "12345");

    // Get the Sabak pool
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const sabak = listBody.pools.find((p) => p.name === "Sabak")!;

    // Add surah 1 to Sabak
    const addRes = await SELF.fetch(
      `http://localhost/api/pools/${sabak.id}/surahs`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ surah_number: 1 }),
      }
    );

    expect(addRes.status).toBe(200);
    const addBody = (await addRes.json()) as { ok: boolean };
    expect(addBody.ok).toBe(true);

    // List surahs in Sabak — should be enriched with metadata
    const surahsRes = await SELF.fetch(
      `http://localhost/api/pools/${sabak.id}/surahs`,
      {
        headers: { Cookie: cookie },
      }
    );

    expect(surahsRes.status).toBe(200);
    const surahsBody = (await surahsRes.json()) as {
      surahs: {
        id: number;
        surah_number: number;
        name: string;
        arabic: string;
        pages: number;
        added_at: string;
      }[];
    };
    expect(surahsBody.surahs).toHaveLength(1);
    expect(surahsBody.surahs[0].surah_number).toBe(1);
    expect(surahsBody.surahs[0].name).toBe("Al-Fatihah");
    expect(surahsBody.surahs[0].arabic).toBeTruthy();
    expect(surahsBody.surahs[0].pages).toBe(1);
    expect(surahsBody.surahs[0].added_at).toBeTruthy();
  });

  it("cannot add same surah to two pools (409)", async () => {
    const cookie = await registerAndGetCookie("dupsurah", "12345");

    // Get pools
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const sabak = listBody.pools.find((p) => p.name === "Sabak")!;
    const manzil = listBody.pools.find((p) => p.name === "Manzil")!;

    // Add surah 1 to Sabak
    await SELF.fetch(`http://localhost/api/pools/${sabak.id}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ surah_number: 1 }),
    });

    // Try to add surah 1 to Manzil — should fail with 409
    const res = await SELF.fetch(
      `http://localhost/api/pools/${manzil.id}/surahs`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", Cookie: cookie },
        body: JSON.stringify({ surah_number: 1 }),
      }
    );

    expect(res.status).toBe(409);
    const body = (await res.json()) as { error: string };
    expect(body.error).toBe("Surah already in another pool");
  });

  it("moves surah between pools", async () => {
    const cookie = await registerAndGetCookie("movesurah", "12345");

    // Get pools
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const sabak = listBody.pools.find((p) => p.name === "Sabak")!;
    const manzil = listBody.pools.find((p) => p.name === "Manzil")!;

    // Add surah 1 to Sabak
    await SELF.fetch(`http://localhost/api/pools/${sabak.id}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ surah_number: 1 }),
    });

    // Move surah 1 to Manzil
    const res = await SELF.fetch(
      `http://localhost/api/pools/${manzil.id}/surahs/1/move`,
      {
        method: "POST",
        headers: { Cookie: cookie },
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);

    // Verify surah is now in Manzil
    const manzilSurahsRes = await SELF.fetch(
      `http://localhost/api/pools/${manzil.id}/surahs`,
      { headers: { Cookie: cookie } }
    );
    const manzilSurahs = (await manzilSurahsRes.json()) as {
      surahs: { surah_number: number }[];
    };
    expect(manzilSurahs.surahs.some((s) => s.surah_number === 1)).toBe(true);

    // Verify surah is no longer in Sabak
    const sabakSurahsRes = await SELF.fetch(
      `http://localhost/api/pools/${sabak.id}/surahs`,
      { headers: { Cookie: cookie } }
    );
    const sabakSurahs = (await sabakSurahsRes.json()) as {
      surahs: { surah_number: number }[];
    };
    expect(sabakSurahs.surahs.some((s) => s.surah_number === 1)).toBe(false);
  });

  it("removes surah from pool", async () => {
    const cookie = await registerAndGetCookie("removesurah", "12345");

    // Get pools
    const listRes = await SELF.fetch("http://localhost/api/pools", {
      headers: { Cookie: cookie },
    });
    const listBody = (await listRes.json()) as {
      pools: { id: number; name: string }[];
    };
    const sabak = listBody.pools.find((p) => p.name === "Sabak")!;

    // Add surah 2 to Sabak
    await SELF.fetch(`http://localhost/api/pools/${sabak.id}/surahs`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookie },
      body: JSON.stringify({ surah_number: 2 }),
    });

    // Remove surah 2 from Sabak
    const res = await SELF.fetch(
      `http://localhost/api/pools/${sabak.id}/surahs/2`,
      {
        method: "DELETE",
        headers: { Cookie: cookie },
      }
    );

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean };
    expect(body.ok).toBe(true);

    // Verify surah is no longer in the pool
    const surahsRes = await SELF.fetch(
      `http://localhost/api/pools/${sabak.id}/surahs`,
      { headers: { Cookie: cookie } }
    );
    const surahsBody = (await surahsRes.json()) as {
      surahs: { surah_number: number }[];
    };
    expect(surahsBody.surahs).toHaveLength(0);
  });
});
