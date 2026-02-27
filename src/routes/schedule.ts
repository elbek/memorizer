import { Hono } from "hono";
import type { Context } from "hono";
import { SURAHS } from "../data/surahs";
import { generateSchedule } from "../scheduler";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };
type Env = { Bindings: Bindings; Variables: Variables };

export const schedule = new Hono<Env>();

/**
 * Helper: verify a pool belongs to the authenticated user.
 * Returns the pool row or null.
 */
async function verifyPoolOwnership(
  c: Context<Env>,
  poolId: number
): Promise<{ id: number; name: string } | null> {
  const userId = c.get("userId");
  return c.env.DB.prepare(
    "SELECT id, name FROM pools WHERE id = ? AND user_id = ?"
  )
    .bind(poolId, userId)
    .first<{ id: number; name: string }>();
}

/**
 * Helper: fetch surahs for a pool, enriched with page counts from SURAHS constant.
 */
async function getPoolSurahs(
  c: Context<Env>,
  poolId: number
): Promise<{ number: number; pages: number }[]> {
  const result = await c.env.DB.prepare(
    "SELECT surah_number FROM surah_pool WHERE pool_id = ? ORDER BY surah_number"
  )
    .bind(poolId)
    .all<{ surah_number: number }>();

  return result.results.map((entry) => {
    const surah = SURAHS.find((s) => s.number === entry.surah_number);
    return {
      number: entry.surah_number,
      pages: surah?.pages ?? 0,
    };
  });
}

/**
 * Helper: add a date string by N days, returning YYYY-MM-DD.
 */
function addDays(dateStr: string, days: number): string {
  const d = new Date(dateStr + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().split("T")[0];
}

/**
 * Build a cycling schedule: one cycle = total_days, repeat to fill total_range_days.
 * If total_range_days > total_days, the cycle repeats (last cycle may be partial).
 */
function buildCyclingSchedule(
  surahs: { number: number; pages: number }[],
  cycleDays: number,
  totalRangeDays: number,
  shuffle: boolean,
  startDate: string
) {
  const allDays: Array<{
    day_number: number;
    date: string;
    cycle: number;
    chunks: Array<{
      surah_number: number;
      surah_name: string;
      start_page: number;
      end_page: number;
      pages: number;
    }>;
  }> = [];

  let dayOffset = 0;
  let cycle = 1;
  while (dayOffset < totalRangeDays) {
    const remainingDays = totalRangeDays - dayOffset;
    const daysThisCycle = Math.min(cycleDays, remainingDays);
    const dayChunks = generateSchedule(surahs, daysThisCycle, { shuffle });

    for (let i = 0; i < dayChunks.length; i++) {
      allDays.push({
        day_number: dayOffset + i + 1,
        date: addDays(startDate, dayOffset + i),
        cycle,
        chunks: dayChunks[i].map((chunk) => {
          const surah = SURAHS.find((s) => s.number === chunk.surahNumber);
          return {
            surah_number: chunk.surahNumber,
            surah_name: surah?.name ?? "",
            start_page: chunk.startPage,
            end_page: chunk.endPage,
            pages: chunk.endPage - chunk.startPage,
          };
        }),
      });
    }
    dayOffset += daysThisCycle;
    cycle++;
  }
  return allDays;
}

/**
 * POST /generate — Preview schedule (does NOT save to DB)
 */
schedule.post("/generate", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json<{
    pool_id?: number;
    total_days?: number;
    total_range_days?: number;
    start_date?: string;
    shuffle?: boolean;
  }>();
  const { pool_id, total_days, start_date, shuffle } = body;
  const total_range_days = body.total_range_days || total_days;

  if (!pool_id || !total_days || !start_date) {
    return c.json({ error: "pool_id, total_days, and start_date are required" }, 400);
  }

  const pool = await verifyPoolOwnership(c, pool_id);
  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  const surahs = await getPoolSurahs(c, pool_id);
  if (surahs.length === 0) {
    return c.json({ error: "Pool has no surahs" }, 400);
  }

  const totalPages = surahs.reduce((sum, s) => sum + s.pages, 0);
  const pagesPerDay = totalPages / total_days;
  const days = buildCyclingSchedule(surahs, total_days!, total_range_days!, !!shuffle, start_date);

  return c.json({ days, total_pages: totalPages, pages_per_day: pagesPerDay, cycles: Math.ceil(total_range_days! / total_days!) });
});

/**
 * POST /activate — Save schedule to DB
 * Cancels old schedule and DELETES its pending items (replace, not append).
 */
schedule.post("/activate", async (c) => {
  const userId = c.get("userId");
  const body = await c.req.json<{
    pool_id?: number;
    total_days?: number;
    total_range_days?: number;
    start_date?: string;
    shuffle?: boolean;
  }>();
  const { pool_id, total_days, start_date, shuffle } = body;
  const total_range_days = body.total_range_days || total_days;

  if (!pool_id || !total_days || !start_date) {
    return c.json({ error: "pool_id, total_days, and start_date are required" }, 400);
  }

  const pool = await verifyPoolOwnership(c, pool_id);
  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  const surahs = await getPoolSurahs(c, pool_id);
  if (surahs.length === 0) {
    return c.json({ error: "Pool has no surahs" }, 400);
  }

  // Cancel old active schedule and delete its pending items (clean replace)
  const oldSchedule = await c.env.DB.prepare(
    "SELECT id FROM schedules WHERE pool_id = ? AND status = 'active'"
  ).bind(pool_id).first<{ id: number }>();

  if (oldSchedule) {
    await c.env.DB.batch([
      c.env.DB.prepare(
        "DELETE FROM schedule_items WHERE schedule_id = ? AND status = 'pending'"
      ).bind(oldSchedule.id),
      c.env.DB.prepare(
        "UPDATE schedules SET status = 'cancelled' WHERE id = ?"
      ).bind(oldSchedule.id),
    ]);
  }

  // Generate the cycling schedule
  const days = buildCyclingSchedule(surahs, total_days!, total_range_days!, !!shuffle, start_date);

  // Insert the schedule
  const scheduleResult = await c.env.DB.prepare(
    "INSERT INTO schedules (pool_id, start_date, total_days) VALUES (?, ?, ?)"
  )
    .bind(pool_id, start_date, total_range_days)
    .run();

  const scheduleId = scheduleResult.meta.last_row_id as number;

  // Insert all schedule_items
  const stmts = [];
  for (const day of days) {
    for (const chunk of day.chunks) {
      stmts.push(
        c.env.DB.prepare(
          "INSERT INTO schedule_items (schedule_id, day_number, surah_number, start_page, end_page) VALUES (?, ?, ?, ?, ?)"
        ).bind(scheduleId, day.day_number, chunk.surah_number, chunk.start_page, chunk.end_page)
      );
    }
  }

  if (stmts.length > 0) {
    await c.env.DB.batch(stmts);
  }

  return c.json({ ok: true, schedule_id: scheduleId });
});

/**
 * GET /:poolId — Get current active schedule for a pool
 */
schedule.get("/:poolId", async (c) => {
  const poolId = Number(c.req.param("poolId"));

  const pool = await verifyPoolOwnership(c, poolId);
  if (!pool) {
    return c.json({ error: "Pool not found" }, 404);
  }

  const sched = await c.env.DB.prepare(
    "SELECT * FROM schedules WHERE pool_id = ? AND status = 'active' ORDER BY created_at DESC LIMIT 1"
  )
    .bind(poolId)
    .first<{
      id: number;
      pool_id: number;
      start_date: string;
      total_days: number;
      status: string;
      created_at: string;
    }>();

  if (!sched) {
    return c.json({ error: "No active schedule found" }, 404);
  }

  const itemsResult = await c.env.DB.prepare(
    "SELECT * FROM schedule_items WHERE schedule_id = ? ORDER BY day_number, id"
  )
    .bind(sched.id)
    .all<{
      id: number;
      schedule_id: number;
      day_number: number;
      surah_number: number;
      start_page: number;
      end_page: number;
      status: string;
      completed_at: string | null;
      quality: number | null;
    }>();

  const items = itemsResult.results.map((item) => {
    const surah = SURAHS.find((s) => s.number === item.surah_number);
    return {
      ...item,
      surah_name: surah?.name ?? "",
      arabic: surah?.arabic ?? "",
      pages: item.end_page - item.start_page,
    };
  });

  return c.json({ schedule: sched, items });
});

/**
 * GET /list — List all schedules for the user (active, cancelled, completed)
 */
schedule.get("/list", async (c) => {
  const userId = c.get("userId");

  const result = await c.env.DB.prepare(
    `SELECT s.id, s.pool_id, s.start_date, s.total_days, s.status, s.created_at, p.name as pool_name
     FROM schedules s
     JOIN pools p ON p.id = s.pool_id
     WHERE p.user_id = ?
     ORDER BY s.created_at DESC`
  )
    .bind(userId)
    .all<{
      id: number;
      pool_id: number;
      start_date: string;
      total_days: number;
      status: string;
      created_at: string;
      pool_name: string;
    }>();

  // For each schedule, get completion stats
  const schedules = [];
  for (const sched of result.results) {
    const stats = await c.env.DB.prepare(
      `SELECT
         COUNT(*) as total,
         SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) as done,
         SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
         SUM(CASE WHEN status = 'partial' THEN 1 ELSE 0 END) as partial
       FROM schedule_items WHERE schedule_id = ?`
    )
      .bind(sched.id)
      .first<{ total: number; done: number; pending: number; partial: number }>();

    const endDate = addDays(sched.start_date, sched.total_days - 1);

    schedules.push({
      ...sched,
      end_date: endDate,
      items_total: stats?.total ?? 0,
      items_done: stats?.done ?? 0,
      items_pending: stats?.pending ?? 0,
      items_partial: stats?.partial ?? 0,
    });
  }

  return c.json({ schedules });
});

/**
 * DELETE /:scheduleId/delete — Delete a schedule (only if not completed)
 */
schedule.delete("/:scheduleId/delete", async (c) => {
  const userId = c.get("userId");
  const scheduleId = Number(c.req.param("scheduleId"));

  // Verify schedule belongs to user via pool ownership
  const sched = await c.env.DB.prepare(
    `SELECT s.id, s.status FROM schedules s
     JOIN pools p ON p.id = s.pool_id
     WHERE s.id = ? AND p.user_id = ?`
  )
    .bind(scheduleId, userId)
    .first<{ id: number; status: string }>();

  if (!sched) {
    return c.json({ error: "Schedule not found" }, 404);
  }

  if (sched.status === "completed") {
    return c.json({ error: "Cannot delete a completed schedule" }, 400);
  }

  await c.env.DB.batch([
    c.env.DB.prepare("DELETE FROM schedule_items WHERE schedule_id = ?").bind(scheduleId),
    c.env.DB.prepare("DELETE FROM schedules WHERE id = ?").bind(scheduleId),
  ]);

  return c.json({ ok: true });
});

/**
 * Today handler — Get today's assignments across ALL pools.
 * Exported separately so it can be mounted at /api/today.
 */
export async function todayHandler(c: Context<Env>) {
  const userId = c.get("userId");

  // Find all pools for the user
  const poolsResult = await c.env.DB.prepare(
    "SELECT id, name FROM pools WHERE user_id = ?"
  )
    .bind(userId)
    .all<{ id: number; name: string }>();

  const today = new Date();
  const todayStr =
    today.getUTCFullYear() +
    "-" +
    String(today.getUTCMonth() + 1).padStart(2, "0") +
    "-" +
    String(today.getUTCDate()).padStart(2, "0");

  const pools: Array<{
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
  }> = [];

  const upcoming: Array<{ pool_name: string; start_date: string }> = [];

  for (const pool of poolsResult.results) {
    // Find active schedule for this pool
    const sched = await c.env.DB.prepare(
      "SELECT * FROM schedules WHERE pool_id = ? AND status = 'active' ORDER BY created_at DESC LIMIT 1"
    )
      .bind(pool.id)
      .first<{
        id: number;
        pool_id: number;
        start_date: string;
        total_days: number;
        status: string;
        created_at: string;
      }>();

    if (!sched) continue;

    // Calculate today's day number
    const startDate = new Date(sched.start_date + "T00:00:00Z");
    const todayDate = new Date(todayStr + "T00:00:00Z");
    const diffMs = todayDate.getTime() - startDate.getTime();
    const dayNumber = Math.floor(diffMs / (1000 * 60 * 60 * 24)) + 1;

    if (dayNumber < 1 || dayNumber > sched.total_days) {
      // Track upcoming schedules (starts in the future)
      if (dayNumber < 1) {
        upcoming.push({
          pool_name: pool.name,
          start_date: sched.start_date,
        });
      }
      continue;
    }

    // Fetch schedule items for this day
    const itemsResult = await c.env.DB.prepare(
      "SELECT * FROM schedule_items WHERE schedule_id = ? AND day_number = ? ORDER BY id"
    )
      .bind(sched.id, dayNumber)
      .all<{
        id: number;
        schedule_id: number;
        day_number: number;
        surah_number: number;
        start_page: number;
        end_page: number;
        status: string;
        completed_at: string | null;
        quality: number | null;
      }>();

    const items = itemsResult.results.map((item) => {
      const surah = SURAHS.find((s) => s.number === item.surah_number);
      return {
        id: item.id,
        surah_number: item.surah_number,
        surah_name: surah?.name ?? "",
        arabic: surah?.arabic ?? "",
        start_page: item.start_page,
        end_page: item.end_page,
        pages: item.end_page - item.start_page,
        status: item.status,
        quality: item.quality,
      };
    });

    pools.push({
      pool_id: pool.id,
      pool_name: pool.name,
      day_number: dayNumber,
      total_days: sched.total_days,
      items,
    });
  }

  // Sort upcoming by start date (earliest first)
  upcoming.sort((a, b) => a.start_date.localeCompare(b.start_date));

  return c.json({ pools, upcoming });
}
