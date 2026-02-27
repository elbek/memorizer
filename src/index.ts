import { Hono } from "hono";
import { auth } from "./routes/auth";
import { pools } from "./routes/pools";
import { schedule, todayHandler } from "./routes/schedule";
import { items } from "./routes/items";
import { reports } from "./routes/reports";
import { quran } from "./routes/quran";
import { authMiddleware } from "./auth";
import html from "./frontend/index.html";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Public routes
app.route("/api/auth", auth);
app.route("/api/quran", quran);

// Protected API routes
const api = new Hono<{ Bindings: Bindings; Variables: Variables }>();
api.use("*", authMiddleware);
api.route("/pools", pools);
api.route("/schedule", schedule);
api.route("/item", items);
api.route("/reports", reports);
api.get("/today", todayHandler);
app.route("/api", api);

// PWA manifest
app.get("/manifest.json", (c) => {
  c.header("Content-Type", "application/manifest+json");
  c.header("Cache-Control", "public, max-age=86400");
  return c.body(
    JSON.stringify({
      name: "Quran Memorizer",
      short_name: "Memorizer",
      start_url: "/",
      display: "standalone",
      background_color: "#ffffff",
      theme_color: "#059669",
      icons: [
        {
          src: "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><rect width='512' height='512' rx='80' fill='%23059669'/><text x='256' y='256' dominant-baseline='central' text-anchor='middle' font-size='300'>📖</text></svg>",
          sizes: "512x512",
          type: "image/svg+xml",
          purpose: "any maskable",
        },
      ],
    })
  );
});

// Service worker for PWA install
app.get("/sw.js", (c) => {
  c.header("Content-Type", "application/javascript");
  c.header("Cache-Control", "no-cache");
  return c.body("self.addEventListener('fetch', function() {});");
});

// Frontend
app.get("/", (c) => c.html(html));

export default app;
