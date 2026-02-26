import { Hono } from "hono";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };
type Env = { Bindings: Bindings; Variables: Variables };

export const items = new Hono<Env>();

/**
 * Helper: verify a schedule item belongs to the authenticated user
 * by walking the ownership chain: schedule_items -> schedules -> pools.
 * Returns the item row or null.
 */
async function verifyItemOwnership(
  db: D1Database,
  itemId: number,
  userId: number
): Promise<{
  id: number;
  schedule_id: number;
  day_number: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  status: string;
  quality: number | null;
} | null> {
  return db
    .prepare(
      `SELECT si.id, si.schedule_id, si.day_number, si.surah_number,
              si.start_page, si.end_page, si.status, si.quality
       FROM schedule_items si
       JOIN schedules s ON si.schedule_id = s.id
       JOIN pools p ON s.pool_id = p.id
       WHERE si.id = ? AND p.user_id = ?`
    )
    .bind(itemId, userId)
    .first<{
      id: number;
      schedule_id: number;
      day_number: number;
      surah_number: number;
      start_page: number;
      end_page: number;
      status: string;
      quality: number | null;
    }>();
}

/**
 * PATCH /:id/done — Mark a schedule item as fully completed.
 * Body: { quality } (integer 1-20, required)
 */
items.patch("/:id/done", async (c) => {
  const userId = c.get("userId");
  const itemId = Number(c.req.param("id"));
  const body = await c.req.json<{ quality?: number }>();
  const { quality } = body;

  // Validate quality
  if (
    quality === undefined ||
    quality === null ||
    !Number.isInteger(quality) ||
    quality < 1 ||
    quality > 20
  ) {
    return c.json({ error: "quality is required and must be an integer 1-20" }, 400);
  }

  // Verify ownership
  const item = await verifyItemOwnership(c.env.DB, itemId, userId);
  if (!item) {
    return c.json({ error: "Item not found" }, 404);
  }

  // Update item status
  await c.env.DB.prepare(
    `UPDATE schedule_items
     SET status = 'done', quality = ?, completed_at = datetime('now')
     WHERE id = ?`
  )
    .bind(quality, itemId)
    .run();

  // Insert recitation log
  await c.env.DB.prepare(
    `INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality, schedule_item_id)
     VALUES (?, ?, ?, ?, ?, ?)`
  )
    .bind(userId, item.surah_number, item.start_page, item.end_page, quality, itemId)
    .run();

  return c.json({ ok: true });
});

/**
 * PATCH /:id/partial — Mark a schedule item as partially completed,
 * creating a carry-forward item for the remaining portion on the next day.
 * Body: { stopped_at_page, quality } (both required, quality 1-20)
 */
items.patch("/:id/partial", async (c) => {
  const userId = c.get("userId");
  const itemId = Number(c.req.param("id"));
  const body = await c.req.json<{ stopped_at_page?: number; quality?: number }>();
  const { stopped_at_page, quality } = body;

  // Validate quality
  if (
    quality === undefined ||
    quality === null ||
    !Number.isInteger(quality) ||
    quality < 1 ||
    quality > 20
  ) {
    return c.json({ error: "quality is required and must be an integer 1-20" }, 400);
  }

  // Validate stopped_at_page is provided
  if (stopped_at_page === undefined || stopped_at_page === null) {
    return c.json({ error: "stopped_at_page is required" }, 400);
  }

  // Verify ownership
  const item = await verifyItemOwnership(c.env.DB, itemId, userId);
  if (!item) {
    return c.json({ error: "Item not found" }, 404);
  }

  // Validate stopped_at_page is between start_page (inclusive) and end_page (exclusive)
  if (stopped_at_page <= item.start_page || stopped_at_page >= item.end_page) {
    return c.json(
      { error: "stopped_at_page must be between start_page (exclusive) and end_page (exclusive)" },
      400
    );
  }

  // Update original item: mark as partial, end_page = stopped_at_page
  await c.env.DB.prepare(
    `UPDATE schedule_items
     SET status = 'partial', end_page = ?, quality = ?, completed_at = datetime('now')
     WHERE id = ?`
  )
    .bind(stopped_at_page, quality, itemId)
    .run();

  // Insert recitation log for the completed portion
  await c.env.DB.prepare(
    `INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality, schedule_item_id)
     VALUES (?, ?, ?, ?, ?, ?)`
  )
    .bind(userId, item.surah_number, item.start_page, stopped_at_page, quality, itemId)
    .run();

  // Create new schedule_item for the remaining portion pushed to next day
  await c.env.DB.prepare(
    `INSERT INTO schedule_items (schedule_id, day_number, surah_number, start_page, end_page, status)
     VALUES (?, ?, ?, ?, ?, 'pending')`
  )
    .bind(
      item.schedule_id,
      item.day_number + 1,
      item.surah_number,
      stopped_at_page,
      item.end_page,
      )
    .run();

  return c.json({ ok: true });
});
