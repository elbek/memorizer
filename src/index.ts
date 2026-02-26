import { Hono } from "hono";
import { auth } from "./routes/auth";
import { pools } from "./routes/pools";
import { schedule, todayHandler } from "./routes/schedule";
import { items } from "./routes/items";
import { authMiddleware } from "./auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Public routes
app.route("/api/auth", auth);

// Protected API routes
const api = new Hono<{ Bindings: Bindings; Variables: Variables }>();
api.use("*", authMiddleware);
api.route("/pools", pools);
api.route("/schedule", schedule);
api.route("/item", items);
api.get("/today", todayHandler);
app.route("/api", api);

// Frontend placeholder
app.get("/", (c) => c.text("Quran Memorizer"));

export default app;
