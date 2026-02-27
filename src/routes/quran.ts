import { Hono } from "hono";
import quranPagesV1 from "../data/quran-pages-v1.json";
import quranPagesV2 from "../data/quran-pages-v2.json";
import quranIndexV1 from "../data/quran-index-v1.json";
import quranIndexV2 from "../data/quran-index-v2.json";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const quran = new Hono<{ Bindings: Bindings; Variables: Variables }>();

const pagesData: Record<string, Record<string, unknown>> = {
  v1: quranPagesV1 as Record<string, unknown>,
  v2: quranPagesV2 as Record<string, unknown>,
};

const indexData: Record<string, unknown> = {
  v1: quranIndexV1,
  v2: quranIndexV2,
};

function getMushaf(q: string | undefined): string {
  return q === "v1" ? "v1" : "v2";
}

// Serve surah-to-start-page index
quran.get("/index", (c) => {
  const mushaf = getMushaf(c.req.query("mushaf"));
  c.header("Cache-Control", "public, max-age=31536000, immutable");
  return c.json(indexData[mushaf]);
});

// Serve a single page's word data
quran.get("/page/:page", (c) => {
  const page = parseInt(c.req.param("page"));
  if (isNaN(page) || page < 1 || page > 604) {
    return c.json({ error: "Invalid page number (1-604)" }, 400);
  }
  const mushaf = getMushaf(c.req.query("mushaf"));
  const data = pagesData[mushaf][String(page)];
  if (!data) {
    return c.json({ error: "Page not found" }, 404);
  }
  c.header("Cache-Control", "public, max-age=31536000, immutable");
  return c.json(data);
});

export { quran };
