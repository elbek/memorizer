import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF } from "cloudflare:test";

beforeAll(async () => {
  // Apply migration statements individually (D1 exec splits on semicolons
  // which breaks the trigger that contains semicolons inside BEGIN...END)
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
    env.DB.prepare(`CREATE INDEX IF NOT EXISTS idx_pools_user ON pools(user_id)`),
    env.DB.prepare(`CREATE INDEX IF NOT EXISTS idx_surah_pool_pool ON surah_pool(pool_id)`),
    env.DB.prepare(`CREATE INDEX IF NOT EXISTS idx_schedules_pool ON schedules(pool_id)`),
    env.DB.prepare(`CREATE INDEX IF NOT EXISTS idx_schedule_items_schedule ON schedule_items(schedule_id, day_number)`),
    env.DB.prepare(`CREATE INDEX IF NOT EXISTS idx_recitation_log_user ON recitation_log(user_id, surah_number)`),
  ]);

  // Create trigger separately using prepare().run() to avoid D1 exec
  // splitting on the semicolon inside the BEGIN...END block
  await env.DB.prepare(`CREATE TRIGGER IF NOT EXISTS enforce_surah_unique_per_user
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
    END`).run();
});

describe("Auth - Register", () => {
  it("registers a new user and returns ok with set-cookie", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "test@example.com", name: "testuser", password: "password1" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; name: string };
    expect(body.ok).toBe(true);
    expect(body.name).toBe("testuser");

    // Should have set-cookie header with token
    const setCookie = res.headers.get("set-cookie");
    expect(setCookie).toBeTruthy();
    expect(setCookie).toContain("token=");
    expect(setCookie).toContain("HttpOnly");
  });

  it("rejects duplicate email with 409", async () => {
    // Register first user
    await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "dup@example.com", name: "duplicate", password: "password1" }),
    });

    // Try to register same email again
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "dup@example.com", name: "duplicate2", password: "password2" }),
    });

    expect(res.status).toBe(409);
  });

  it("rejects invalid password with 400", async () => {
    // Too short
    const res1 = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "bad1@example.com", name: "badpass1", password: "short1" }),
    });
    expect(res1.status).toBe(400);

    // No number
    const res2 = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "bad2@example.com", name: "badpass2", password: "nodigits" }),
    });
    expect(res2.status).toBe(400);

    // No letter
    const res3 = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "bad3@example.com", name: "badpass3", password: "12345678" }),
    });
    expect(res3.status).toBe(400);
  });

  it("rejects invalid email with 400", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "notanemail", name: "bademail", password: "password1" }),
    });
    expect(res.status).toBe(400);
  });

  it("creates system pools (Sabak and Manzil) on registration", async () => {
    // Register a new user
    await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "pooluser@example.com", name: "pooluser", password: "password1" }),
    });

    // Query the DB directly to verify pools were created
    const user = await env.DB.prepare("SELECT id FROM users WHERE email = ?")
      .bind("pooluser@example.com")
      .first<{ id: number }>();

    expect(user).toBeTruthy();

    const pools = await env.DB.prepare(
      "SELECT name, is_system FROM pools WHERE user_id = ? ORDER BY name"
    )
      .bind(user!.id)
      .all<{ name: string; is_system: number }>();

    expect(pools.results).toHaveLength(3);

    const poolNames = pools.results.map((p) => p.name).sort();
    expect(poolNames).toEqual(["Daily", "Manzil", "Sabak"]);

    // All should be system pools
    for (const pool of pools.results) {
      expect(pool.is_system).toBe(1);
    }
  });
});

describe("Auth - Token in response", () => {
  it("register returns token in JSON body", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "tokenreg@example.com", name: "tokenreg", password: "password1" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; token: string };
    expect(body.ok).toBe(true);
    expect(body.token).toBeTruthy();
    expect(typeof body.token).toBe("string");
    expect(body.token.split(".")).toHaveLength(3); // JWT format
  });

  it("login returns token in JSON body", async () => {
    // Register user first (tests may not share DB state)
    await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "tokenlogin@example.com", name: "tokenlogin", password: "password1" }),
    });

    const res = await SELF.fetch("http://localhost/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "tokenlogin@example.com", password: "password1" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; token: string };
    expect(body.ok).toBe(true);
    expect(body.token).toBeTruthy();
    expect(body.token.split(".")).toHaveLength(3);
  });
});

describe("Auth - Bearer token", () => {
  let bearerToken: string;

  beforeAll(async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "bearer@example.com", name: "beareruser", password: "password1" }),
    });
    const body = (await res.json()) as { token: string };
    bearerToken = body.token;
  });

  it("accepts Authorization: Bearer header on protected routes", async () => {
    const res = await SELF.fetch("http://localhost/api/pools", {
      headers: { Authorization: `Bearer ${bearerToken}` },
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { pools: unknown[] };
    expect(body.pools).toBeDefined();
  });

  it("rejects invalid Bearer token with 401", async () => {
    const res = await SELF.fetch("http://localhost/api/pools", {
      headers: { Authorization: "Bearer invalid.token.here" },
    });

    expect(res.status).toBe(401);
  });

  it("rejects missing auth with 401", async () => {
    const res = await SELF.fetch("http://localhost/api/pools");

    expect(res.status).toBe(401);
  });
});

describe("Auth - Login", () => {
  beforeAll(async () => {
    // Register a user for login tests
    await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "login@example.com", name: "loginuser", password: "password1" }),
    });
  });

  it("logs in with correct credentials and returns set-cookie", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "login@example.com", password: "password1" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { ok: boolean; name: string };
    expect(body.ok).toBe(true);
    expect(body.name).toBe("loginuser");

    const setCookie = res.headers.get("set-cookie");
    expect(setCookie).toBeTruthy();
    expect(setCookie).toContain("token=");
  });

  it("rejects wrong password with 401", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: "login@example.com", password: "wrongpass1" }),
    });

    expect(res.status).toBe(401);
  });
});
