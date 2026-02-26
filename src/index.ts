import { Hono } from "hono";
import { auth } from "./routes/auth";
import { authMiddleware } from "./auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Public routes
app.route("/api/auth", auth);

// Protected API routes (will be added in later tasks)
const api = new Hono<{ Bindings: Bindings; Variables: Variables }>();
api.use("*", authMiddleware);
app.route("/api", api);

// Frontend placeholder
app.get("/", (c) => c.text("Quran Memorizer"));

export default app;
