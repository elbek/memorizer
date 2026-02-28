import { Hono } from "hono";
import { setCookie } from "hono/cookie";
import { hashPassword, generateSalt, createToken } from "../auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

export const auth = new Hono<{ Bindings: Bindings; Variables: Variables }>();

/**
 * POST /register
 * Body: { email: string, name: string, password: string }
 * Creates user, auto-creates Sabak, Manzil, and Daily pools, returns JWT cookie.
 */
auth.post("/register", async (c) => {
  const body = await c.req.json<{ email?: string; name?: string; password?: string }>();
  const { email, name, password } = body;

  // Validate email
  if (!email || !email.includes("@") || !email.includes(".")) {
    return c.json({ error: "Valid email is required" }, 400);
  }

  // Validate name
  if (!name || name.trim().length === 0) {
    return c.json({ error: "Name is required" }, 400);
  }

  // Validate password: minimum 8 chars, at least 1 letter and 1 number
  if (!password || password.length < 8 || !/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
    return c.json({ error: "Password must be at least 8 characters with at least 1 letter and 1 number" }, 400);
  }

  const salt = generateSalt();
  const passwordHash = await hashPassword(password, salt);

  try {
    // Insert user
    const result = await c.env.DB.prepare(
      "INSERT INTO users (email, name, password_hash, password_salt) VALUES (?, ?, ?, ?)"
    )
      .bind(email.trim().toLowerCase(), name.trim(), passwordHash, salt)
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

    return c.json({ ok: true, name: name.trim(), token });
  } catch (err: unknown) {
    // Handle UNIQUE constraint violation (duplicate email)
    if (
      err instanceof Error &&
      err.message.includes("UNIQUE constraint failed")
    ) {
      return c.json({ error: "Email already registered" }, 409);
    }
    throw err;
  }
});

/**
 * POST /login
 * Body: { email: string, password: string }
 * Verifies credentials, returns JWT cookie.
 */
auth.post("/login", async (c) => {
  const body = await c.req.json<{ email?: string; password?: string }>();
  const { email, password } = body;

  if (!email || !password) {
    return c.json({ error: "Email and password are required" }, 400);
  }

  // Look up user by email
  const user = await c.env.DB.prepare(
    "SELECT id, name, password_hash, password_salt FROM users WHERE email = ?"
  )
    .bind(email.trim().toLowerCase())
    .first<{ id: number; name: string; password_hash: string; password_salt: string }>();

  if (!user) {
    return c.json({ error: "Invalid credentials" }, 401);
  }

  // Hash provided password with stored salt and compare
  const hashedPassword = await hashPassword(password, user.password_salt);
  if (hashedPassword !== user.password_hash) {
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

  return c.json({ ok: true, name: user.name, token });
});
