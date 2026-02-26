import { Hono } from "hono";
import { SURAHS } from "../data/surahs";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };
type Env = { Bindings: Bindings; Variables: Variables };

export const reports = new Hono<Env>();

/**
 * GET / — Per-surah quality stats
 * Groups recitation_log by surah_number and returns aggregate stats.
 */
reports.get("/", async (c) => {
  const userId = c.get("userId");

  const result = await c.env.DB.prepare(
    `SELECT
      surah_number,
      COUNT(*) as times_recited,
      AVG(quality) as avg_quality,
      MIN(quality) as min_quality,
      MAX(quality) as max_quality,
      MAX(recited_at) as last_recited
    FROM recitation_log
    WHERE user_id = ?
    GROUP BY surah_number
    ORDER BY surah_number`
  )
    .bind(userId)
    .all<{
      surah_number: number;
      times_recited: number;
      avg_quality: number;
      min_quality: number;
      max_quality: number;
      last_recited: string;
    }>();

  const stats = result.results.map((row) => {
    const surah = SURAHS.find((s) => s.number === row.surah_number);
    return {
      surah_number: row.surah_number,
      name: surah?.name ?? "",
      arabic: surah?.arabic ?? "",
      times_recited: row.times_recited,
      avg_quality: Math.round(row.avg_quality * 10) / 10,
      min_quality: row.min_quality,
      max_quality: row.max_quality,
      last_recited: row.last_recited,
    };
  });

  return c.json({ stats });
});

/**
 * GET /backup — Full data export as JSON
 * Fetches all user data in parallel and returns it.
 */
reports.get("/backup", async (c) => {
  const userId = c.get("userId");
  const db = c.env.DB;

  // Fetch all user data in parallel
  const [poolsResult, recitationLogsResult] = await Promise.all([
    db
      .prepare("SELECT * FROM pools WHERE user_id = ? ORDER BY id")
      .bind(userId)
      .all(),
    db
      .prepare(
        "SELECT * FROM recitation_log WHERE user_id = ? ORDER BY id"
      )
      .bind(userId)
      .all(),
  ]);

  const pools = poolsResult.results;
  const poolIds = pools.map((p: Record<string, unknown>) => p.id as number);

  // If user has no pools, return empty data
  if (poolIds.length === 0) {
    return c.json({
      exported_at: new Date().toISOString(),
      pools: [],
      surah_entries: [],
      schedules: [],
      schedule_items: [],
      recitation_logs: recitationLogsResult.results,
    });
  }

  // Build placeholders for IN clause
  const placeholders = poolIds.map(() => "?").join(",");

  // Fetch surah entries and schedules in parallel (depend on pool IDs)
  const [surahEntriesResult, schedulesResult] = await Promise.all([
    db
      .prepare(
        `SELECT * FROM surah_pool WHERE pool_id IN (${placeholders}) ORDER BY id`
      )
      .bind(...poolIds)
      .all(),
    db
      .prepare(
        `SELECT * FROM schedules WHERE pool_id IN (${placeholders}) ORDER BY id`
      )
      .bind(...poolIds)
      .all(),
  ]);

  const schedules = schedulesResult.results;
  const scheduleIds = schedules.map(
    (s: Record<string, unknown>) => s.id as number
  );

  // Fetch schedule items (depend on schedule IDs)
  let scheduleItems: Record<string, unknown>[] = [];
  if (scheduleIds.length > 0) {
    const siPlaceholders = scheduleIds.map(() => "?").join(",");
    const scheduleItemsResult = await db
      .prepare(
        `SELECT * FROM schedule_items WHERE schedule_id IN (${siPlaceholders}) ORDER BY id`
      )
      .bind(...scheduleIds)
      .all();
    scheduleItems = scheduleItemsResult.results;
  }

  return c.json({
    exported_at: new Date().toISOString(),
    pools,
    surah_entries: surahEntriesResult.results,
    schedules,
    schedule_items: scheduleItems,
    recitation_logs: recitationLogsResult.results,
  });
});
