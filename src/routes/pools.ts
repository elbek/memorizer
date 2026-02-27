import { Hono } from "hono";
import { SURAHS, getSurahsByJuz } from "../data/surahs";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

export const pools = new Hono<{ Bindings: Bindings; Variables: Variables }>();

/**
 * GET / — List all pools for the authenticated user
 */
pools.get("/", async (c) => {
  const userId = c.get("userId");
  const result = await c.env.DB.prepare(
    "SELECT id, name, is_system, created_at FROM pools WHERE user_id = ? ORDER BY is_system DESC, name"
  )
    .bind(userId)
    .all<{ id: number; name: string; is_system: number; created_at: string }>();

  return c.json({ pools: result.results });
});

/**
 * POST / — Create a custom pool
 * Body: { name }
 */
pools.post("/", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json<{ name?: string }>();
  const { name } = body;

  if (!name || name.trim().length === 0) {
    return c.json({ error: "Pool name is required" }, 400);
  }

  try {
    const result = await c.env.DB.prepare(
      "INSERT INTO pools (user_id, name, is_system) VALUES (?, ?, 0)"
    )
      .bind(userId, name.trim())
      .run();

    return c.json({ ok: true, id: result.meta.last_row_id });
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      err.message.includes("UNIQUE constraint failed")
    ) {
      return c.json({ error: "Pool name already exists" }, 409);
    }
    throw err;
  }
});

/**
 * DELETE /:poolId — Delete a custom pool
 */
pools.delete("/:poolId", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));

  const pool = await c.env.DB.prepare(
    "SELECT id, is_system FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number; is_system: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  if (pool.is_system === 1) {
    return c.json({ error: "Cannot delete system pool" }, 400);
  }

  // Clean up related data before deleting the pool
  // Get schedules for this pool to delete their items
  const schedules = await c.env.DB.prepare(
    "SELECT id FROM schedules WHERE pool_id = ?"
  ).bind(poolId).all<{ id: number }>();

  const stmts: D1PreparedStatement[] = [];
  for (const sched of schedules.results) {
    stmts.push(c.env.DB.prepare("DELETE FROM schedule_items WHERE schedule_id = ?").bind(sched.id));
  }
  stmts.push(c.env.DB.prepare("DELETE FROM schedules WHERE pool_id = ?").bind(poolId));
  stmts.push(c.env.DB.prepare("DELETE FROM surah_pool WHERE pool_id = ?").bind(poolId));
  stmts.push(c.env.DB.prepare("DELETE FROM pools WHERE id = ?").bind(poolId));

  await c.env.DB.batch(stmts);

  return c.json({ ok: true });
});

/**
 * GET /:poolId/surahs — List surahs in a pool, enriched with metadata
 */
pools.get("/:poolId/surahs", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));

  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  const result = await c.env.DB.prepare(
    "SELECT id, surah_number, added_at FROM surah_pool WHERE pool_id = ?"
  )
    .bind(poolId)
    .all<{ id: number; surah_number: number; added_at: string }>();

  const surahs = result.results.map((entry) => {
    const surah = SURAHS.find((s) => s.number === entry.surah_number);
    return {
      id: entry.id,
      surah_number: entry.surah_number,
      name: surah?.name ?? "",
      arabic: surah?.arabic ?? "",
      pages: surah?.pages ?? 0,
      added_at: entry.added_at,
    };
  });

  return c.json({ surahs });
});

/**
 * POST /:poolId/surahs — Add a surah to a pool
 * Body: { surah_number }
 */
pools.post("/:poolId/surahs", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));
  const body = await c.req.json<{ surah_number?: number }>();
  const { surah_number } = body;

  // Validate surah number
  if (
    surah_number === undefined ||
    surah_number === null ||
    surah_number < 1 ||
    surah_number > 114
  ) {
    return c.json({ error: "Invalid surah number (must be 1-114)" }, 400);
  }

  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  try {
    await c.env.DB.prepare(
      "INSERT INTO surah_pool (pool_id, surah_number) VALUES (?, ?)"
    )
      .bind(poolId, surah_number)
      .run();

    return c.json({ ok: true });
  } catch (err: unknown) {
    if (
      err instanceof Error &&
      err.message.includes("Surah already in another pool")
    ) {
      return c.json({ error: "Surah already in another pool" }, 409);
    }
    throw err;
  }
});

/**
 * DELETE /:poolId/surahs/:surahNumber — Remove a surah from a pool
 */
pools.delete("/:poolId/surahs/:surahNumber", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));
  const surahNumber = Number(c.req.param("surahNumber"));

  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  await c.env.DB.prepare(
    "DELETE FROM surah_pool WHERE pool_id = ? AND surah_number = ?"
  )
    .bind(poolId, surahNumber)
    .run();

  return c.json({ ok: true });
});

/**
 * POST /:poolId/juz — Add all surahs from a juz to a pool
 * Body: { juz_number: number } (1-30)
 * Skips surahs already in another pool (partial success).
 */
pools.post("/:poolId/juz", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));
  const body = await c.req.json<{ juz_number?: number }>();
  const { juz_number } = body;

  if (!juz_number || juz_number < 1 || juz_number > 30) {
    return c.json({ error: "Invalid juz number (must be 1-30)" }, 400);
  }

  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  const surahs = getSurahsByJuz(juz_number);
  let added = 0;
  const skippedSurahs: string[] = [];

  for (const surah of surahs) {
    try {
      await c.env.DB.prepare(
        "INSERT INTO surah_pool (pool_id, surah_number) VALUES (?, ?)"
      )
        .bind(poolId, surah.number)
        .run();
      added++;
    } catch (err: unknown) {
      if (
        err instanceof Error &&
        err.message.includes("Surah already in another pool")
      ) {
        skippedSurahs.push(surah.name);
      } else {
        throw err;
      }
    }
  }

  return c.json({
    ok: true,
    added,
    skipped: skippedSurahs.length,
    skipped_surahs: skippedSurahs,
  });
});

/**
 * POST /:poolId/surahs/:surahNumber/move — Move a surah to this pool
 */
pools.post("/:poolId/surahs/:surahNumber/move", async (c) => {
  const userId = c.get("userId");
  const poolId = Number(c.req.param("poolId"));
  const surahNumber = Number(c.req.param("surahNumber"));

  // Verify target pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number }>();

  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  // Delete from all user's pools, then insert into the target pool
  // Get all pool IDs for this user
  const userPools = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE user_id = ?"
  )
    .bind(userId)
    .all<{ id: number }>();

  const poolIds = userPools.results.map((p) => p.id);

  // Delete surah from all user's pools
  for (const pid of poolIds) {
    await c.env.DB.prepare(
      "DELETE FROM surah_pool WHERE pool_id = ? AND surah_number = ?"
    )
      .bind(pid, surahNumber)
      .run();
  }

  // Insert into target pool
  await c.env.DB.prepare(
    "INSERT INTO surah_pool (pool_id, surah_number) VALUES (?, ?)"
  )
    .bind(poolId, surahNumber)
    .run();

  return c.json({ ok: true });
});
