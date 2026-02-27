import { Hono } from "hono";
import { setCookie } from "hono/cookie";
import { hashPin, generateSalt, createToken } from "../auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

export const auth = new Hono<{ Bindings: Bindings; Variables: Variables }>();

/**
 * POST /register
 * Body: { name: string, pin: string }
 * Creates user, auto-creates Sabak and Manzil pools, returns JWT cookie.
 */
auth.post("/register", async (c) => {
  const body = await c.req.json<{ name?: string; pin?: string }>();
  const { name, pin } = body;

  // Validate name
  if (!name || name.trim().length === 0) {
    return c.json({ error: "Name is required" }, 400);
  }

  // Validate pin: must be exactly 5 digits
  if (!pin || !/^\d{5}$/.test(pin)) {
    return c.json({ error: "PIN must be exactly 5 digits" }, 400);
  }

  const salt = generateSalt();
  const pinHash = await hashPin(pin, salt);

  try {
    // Insert user
    const result = await c.env.DB.prepare(
      "INSERT INTO users (name, pin_hash, pin_salt) VALUES (?, ?, ?)"
    )
      .bind(name.trim(), pinHash, salt)
      .run();

    const userId = result.meta.last_row_id as number;

    // Auto-create system pools: Sabak, Manzil, and Daily
    await c.env.DB.batch([
      c.env.DB.prepare(
        "INSERT INTO pools (user_id, name, is_system) VALUES (?, ?, 1)"
      ).bind(userId, "Sabak"),
      c.env.DB.prepare(
        "INSERT INTO pools (user_id, name, is_system) VALUES (?, ?, 1)"
      ).bind(userId, "Manzil"),
      c.env.DB.prepare(
        "INSERT INTO pools (user_id, name, is_system) VALUES (?, ?, 1)"
      ).bind(userId, "Daily"),
    ]);

    // Create JWT and set cookie
    const token = await createToken(userId, c.env.JWT_SECRET);
    setCookie(c, "token", token, {
      httpOnly: true,
      secure: true,
      sameSite: "Lax",
      path: "/",
      maxAge: 30 * 24 * 60 * 60, // 30 days
    });

    return c.json({ ok: true, name: name.trim() });
  } catch (err: unknown) {
    // Handle UNIQUE constraint violation (duplicate name)
    if (
      err instanceof Error &&
      err.message.includes("UNIQUE constraint failed")
    ) {
      return c.json({ error: "Name already taken" }, 409);
    }
    throw err;
  }
});

/**
 * POST /login
 * Body: { name: string, pin: string }
 * Verifies credentials, returns JWT cookie.
 */
auth.post("/login", async (c) => {
  const body = await c.req.json<{ name?: string; pin?: string }>();
  const { name, pin } = body;

  if (!name || !pin) {
    return c.json({ error: "Name and PIN are required" }, 400);
  }

  // Look up user by name
  const user = await c.env.DB.prepare(
    "SELECT id, name, pin_hash, pin_salt FROM users WHERE name = ?"
  )
    .bind(name.trim())
    .first<{ id: number; name: string; pin_hash: string; pin_salt: string }>();

  if (!user) {
    return c.json({ error: "Invalid credentials" }, 401);
  }

  // Hash provided pin with stored salt and compare
  const hashedPin = await hashPin(pin, user.pin_salt);
  if (hashedPin !== user.pin_hash) {
    return c.json({ error: "Invalid credentials" }, 401);
  }

  // Create JWT and set cookie
  const token = await createToken(user.id, c.env.JWT_SECRET);
  setCookie(c, "token", token, {
    httpOnly: true,
    secure: true,
    sameSite: "Lax",
    path: "/",
    maxAge: 30 * 24 * 60 * 60, // 30 days
  });

  return c.json({ ok: true, name: user.name });
});
