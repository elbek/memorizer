# Quran Memorizer App - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a mobile-first Quran memorization tracker deployed on Cloudflare Workers with D1 database.

**Architecture:** Single Cloudflare Worker serving both API (Hono) and frontend (single HTML file with Tailwind + vanilla JS). D1 SQLite for storage. JWT auth with httpOnly cookies.

**Tech Stack:** Cloudflare Workers, Hono, D1 (SQLite), Tailwind CSS (CDN), vanilla JavaScript, Vitest + Miniflare for testing.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `package.json`
- Create: `wrangler.jsonc`
- Create: `tsconfig.json`
- Create: `src/index.ts`
- Create: `vitest.config.ts`

**Step 1: Initialize the project**

```bash
cd /Users/elbekkamol/work/memorize-app
npm init -y
npm install hono
npm install -D wrangler typescript @cloudflare/workers-types vitest @cloudflare/vitest-pool-workers
```

**Step 2: Create wrangler.jsonc**

```jsonc
{
  "name": "quran-memorizer",
  "main": "src/index.ts",
  "compatibility_date": "2024-12-01",
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "quran-memorizer-db",
      "database_id": "local"
    }
  ],
  "vars": {
    "JWT_SECRET": "change-me-in-production"
  }
}
```

**Step 3: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "lib": ["ESNext"],
    "types": ["@cloudflare/workers-types", "@cloudflare/vitest-pool-workers"],
    "jsx": "react-jsx",
    "jsxImportSource": "hono/jsx",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*", "tests/**/*"]
}
```

**Step 4: Create vitest.config.ts**

```ts
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.jsonc" },
        miniflare: {
          d1Databases: ["DB"],
        },
      },
    },
  },
});
```

**Step 5: Create minimal src/index.ts**

```ts
import { Hono } from "hono";

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.get("/", (c) => c.text("Quran Memorizer"));

export default app;
```

**Step 6: Add scripts to package.json**

Add to `scripts`:
```json
{
  "dev": "wrangler dev",
  "deploy": "wrangler deploy",
  "test": "vitest run",
  "test:watch": "vitest"
}
```

**Step 7: Verify dev server starts**

```bash
npx wrangler dev
```
Expected: Server starts on localhost, returns "Quran Memorizer" at `/`.

**Step 8: Commit**

```bash
git init
git add -A
git commit -m "feat: project scaffolding with Hono, D1, Vitest"
```

---

### Task 2: Database Schema & Migrations

**Files:**
- Create: `migrations/0001_init.sql`
- Create: `src/db/schema.ts`

**Step 1: Create migration file**

`migrations/0001_init.sql`:
```sql
-- Users table
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE NOT NULL,
  pin_hash TEXT NOT NULL,
  pin_salt TEXT NOT NULL,
  created_at TEXT DEFAULT (datetime('now'))
);

-- Pools (Sabak & Manzil are system pools, users can create custom ones)
CREATE TABLE IF NOT EXISTS pools (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  is_system INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id),
  UNIQUE(user_id, name)
);

-- Surah pool entries (unique per user across ALL pools)
CREATE TABLE IF NOT EXISTS surah_pool (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pool_id INTEGER NOT NULL,
  surah_number INTEGER NOT NULL CHECK(surah_number >= 1 AND surah_number <= 114),
  added_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (pool_id) REFERENCES pools(id) ON DELETE CASCADE
);

-- Trigger to enforce surah uniqueness per user across all pools
CREATE TRIGGER IF NOT EXISTS enforce_surah_unique_per_user
BEFORE INSERT ON surah_pool
BEGIN
  SELECT RAISE(ABORT, 'Surah already in another pool')
  WHERE EXISTS (
    SELECT 1 FROM surah_pool sp
    JOIN pools p ON sp.pool_id = p.id
    JOIN pools p2 ON p2.id = NEW.pool_id
    WHERE sp.surah_number = NEW.surah_number
    AND p.user_id = p2.user_id
  );
END;

-- Schedules
CREATE TABLE IF NOT EXISTS schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pool_id INTEGER NOT NULL,
  start_date TEXT NOT NULL,
  total_days INTEGER NOT NULL,
  status TEXT DEFAULT 'active' CHECK(status IN ('active', 'completed', 'cancelled')),
  created_at TEXT DEFAULT (datetime('now')),
  FOREIGN KEY (pool_id) REFERENCES pools(id)
);

-- Schedule items (daily assignments)
CREATE TABLE IF NOT EXISTS schedule_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  schedule_id INTEGER NOT NULL,
  day_number INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  start_page REAL NOT NULL,
  end_page REAL NOT NULL,
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'partial', 'done')),
  completed_at TEXT,
  quality INTEGER CHECK(quality IS NULL OR (quality >= 1 AND quality <= 20)),
  FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- Recitation log (historical record)
CREATE TABLE IF NOT EXISTS recitation_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  surah_number INTEGER NOT NULL,
  start_page REAL NOT NULL,
  end_page REAL NOT NULL,
  quality INTEGER NOT NULL CHECK(quality >= 1 AND quality <= 20),
  recited_at TEXT DEFAULT (datetime('now')),
  schedule_item_id INTEGER,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (schedule_item_id) REFERENCES schedule_items(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pools_user ON pools(user_id);
CREATE INDEX IF NOT EXISTS idx_surah_pool_pool ON surah_pool(pool_id);
CREATE INDEX IF NOT EXISTS idx_schedules_pool ON schedules(pool_id);
CREATE INDEX IF NOT EXISTS idx_schedule_items_schedule ON schedule_items(schedule_id, day_number);
CREATE INDEX IF NOT EXISTS idx_recitation_log_user ON recitation_log(user_id, surah_number);
```

**Step 2: Create schema types**

`src/db/schema.ts`:
```ts
export interface User {
  id: number;
  name: string;
  pin_hash: string;
  pin_salt: string;
  created_at: string;
}

export interface Pool {
  id: number;
  user_id: number;
  name: string;
  is_system: number; // 1 for Sabak/Manzil, 0 for custom
  created_at: string;
}

export interface SurahPoolEntry {
  id: number;
  pool_id: number;
  surah_number: number;
  added_at: string;
}

export interface Schedule {
  id: number;
  pool_id: number;
  start_date: string;
  total_days: number;
  status: "active" | "completed" | "cancelled";
  created_at: string;
}

export interface ScheduleItem {
  id: number;
  schedule_id: number;
  day_number: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  status: "pending" | "partial" | "done";
  completed_at: string | null;
  quality: number | null;
}

export interface RecitationLog {
  id: number;
  user_id: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  quality: number;
  recited_at: string;
  schedule_item_id: number | null;
}
```

**Step 3: Apply migration locally**

```bash
npx wrangler d1 migrations apply quran-memorizer-db --local
```
Expected: Migration applied successfully.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: database schema and migrations"
```

---

### Task 3: Surah Metadata

**Files:**
- Create: `src/data/surahs.ts`
- Create: `tests/surahs.test.ts`

**Step 1: Write test for surah data integrity**

`tests/surahs.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { SURAHS } from "../src/data/surahs";

describe("Surah metadata", () => {
  it("has exactly 114 surahs", () => {
    expect(SURAHS).toHaveLength(114);
  });

  it("each surah has required fields", () => {
    for (const s of SURAHS) {
      expect(s.number).toBeGreaterThanOrEqual(1);
      expect(s.number).toBeLessThanOrEqual(114);
      expect(s.name).toBeTruthy();
      expect(s.arabic).toBeTruthy();
      expect(s.pages).toBeGreaterThan(0);
    }
  });

  it("surah numbers are sequential 1-114", () => {
    SURAHS.forEach((s, i) => expect(s.number).toBe(i + 1));
  });

  it("total pages sum to approximately 604", () => {
    const total = SURAHS.reduce((sum, s) => sum + s.pages, 0);
    expect(total).toBeGreaterThanOrEqual(600);
    expect(total).toBeLessThanOrEqual(610);
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run tests/surahs.test.ts
```
Expected: FAIL - module not found.

**Step 3: Create surah metadata**

`src/data/surahs.ts`:
```ts
export interface Surah {
  number: number;
  name: string;
  arabic: string;
  pages: number; // page count in 15-line mushaf
}

// Pages in 15-line Madinah mushaf (approximate, rounded to nearest 0.5)
export const SURAHS: Surah[] = [
  { number: 1, name: "Al-Fatihah", arabic: "الفاتحة", pages: 0.5 },
  { number: 2, name: "Al-Baqarah", arabic: "البقرة", pages: 48 },
  { number: 3, name: "Aal-Imran", arabic: "آل عمران", pages: 29 },
  { number: 4, name: "An-Nisa", arabic: "النساء", pages: 28 },
  { number: 5, name: "Al-Ma'idah", arabic: "المائدة", pages: 22 },
  { number: 6, name: "Al-An'am", arabic: "الأنعام", pages: 23 },
  { number: 7, name: "Al-A'raf", arabic: "الأعراف", pages: 26 },
  { number: 8, name: "Al-Anfal", arabic: "الأنفال", pages: 10 },
  { number: 9, name: "At-Tawbah", arabic: "التوبة", pages: 21 },
  { number: 10, name: "Yunus", arabic: "يونس", pages: 16 },
  { number: 11, name: "Hud", arabic: "هود", pages: 16 },
  { number: 12, name: "Yusuf", arabic: "يوسف", pages: 15 },
  { number: 13, name: "Ar-Ra'd", arabic: "الرعد", pages: 7 },
  { number: 14, name: "Ibrahim", arabic: "إبراهيم", pages: 7 },
  { number: 15, name: "Al-Hijr", arabic: "الحجر", pages: 6 },
  { number: 16, name: "An-Nahl", arabic: "النحل", pages: 16 },
  { number: 17, name: "Al-Isra", arabic: "الإسراء", pages: 13 },
  { number: 18, name: "Al-Kahf", arabic: "الكهف", pages: 13 },
  { number: 19, name: "Maryam", arabic: "مريم", pages: 8 },
  { number: 20, name: "Taha", arabic: "طه", pages: 9 },
  { number: 21, name: "Al-Anbiya", arabic: "الأنبياء", pages: 10 },
  { number: 22, name: "Al-Hajj", arabic: "الحج", pages: 10 },
  { number: 23, name: "Al-Mu'minun", arabic: "المؤمنون", pages: 9 },
  { number: 24, name: "An-Nur", arabic: "النور", pages: 10 },
  { number: 25, name: "Al-Furqan", arabic: "الفرقان", pages: 7 },
  { number: 26, name: "Ash-Shu'ara", arabic: "الشعراء", pages: 11 },
  { number: 27, name: "An-Naml", arabic: "النمل", pages: 9 },
  { number: 28, name: "Al-Qasas", arabic: "القصص", pages: 12 },
  { number: 29, name: "Al-Ankabut", arabic: "العنكبوت", pages: 9 },
  { number: 30, name: "Ar-Rum", arabic: "الروم", pages: 7 },
  { number: 31, name: "Luqman", arabic: "لقمان", pages: 4 },
  { number: 32, name: "As-Sajdah", arabic: "السجدة", pages: 3 },
  { number: 33, name: "Al-Ahzab", arabic: "الأحزاب", pages: 13 },
  { number: 34, name: "Saba", arabic: "سبأ", pages: 7 },
  { number: 35, name: "Fatir", arabic: "فاطر", pages: 6 },
  { number: 36, name: "Ya-Sin", arabic: "يس", pages: 6 },
  { number: 37, name: "As-Saffat", arabic: "الصافات", pages: 9 },
  { number: 38, name: "Sad", arabic: "ص", pages: 6 },
  { number: 39, name: "Az-Zumar", arabic: "الزمر", pages: 10 },
  { number: 40, name: "Ghafir", arabic: "غافر", pages: 12 },
  { number: 41, name: "Fussilat", arabic: "فصلت", pages: 7 },
  { number: 42, name: "Ash-Shura", arabic: "الشورى", pages: 7 },
  { number: 43, name: "Az-Zukhruf", arabic: "الزخرف", pages: 8 },
  { number: 44, name: "Ad-Dukhan", arabic: "الدخان", pages: 4 },
  { number: 45, name: "Al-Jathiyah", arabic: "الجاثية", pages: 5 },
  { number: 46, name: "Al-Ahqaf", arabic: "الأحقاف", pages: 5 },
  { number: 47, name: "Muhammad", arabic: "محمد", pages: 5 },
  { number: 48, name: "Al-Fath", arabic: "الفتح", pages: 5 },
  { number: 49, name: "Al-Hujurat", arabic: "الحجرات", pages: 3 },
  { number: 50, name: "Qaf", arabic: "ق", pages: 3 },
  { number: 51, name: "Adh-Dhariyat", arabic: "الذاريات", pages: 3 },
  { number: 52, name: "At-Tur", arabic: "الطور", pages: 3 },
  { number: 53, name: "An-Najm", arabic: "النجم", pages: 3 },
  { number: 54, name: "Al-Qamar", arabic: "القمر", pages: 3 },
  { number: 55, name: "Ar-Rahman", arabic: "الرحمن", pages: 4 },
  { number: 56, name: "Al-Waqi'ah", arabic: "الواقعة", pages: 4 },
  { number: 57, name: "Al-Hadid", arabic: "الحديد", pages: 5 },
  { number: 58, name: "Al-Mujadilah", arabic: "المجادلة", pages: 4 },
  { number: 59, name: "Al-Hashr", arabic: "الحشر", pages: 4 },
  { number: 60, name: "Al-Mumtahanah", arabic: "الممتحنة", pages: 3 },
  { number: 61, name: "As-Saff", arabic: "الصف", pages: 2 },
  { number: 62, name: "Al-Jumu'ah", arabic: "الجمعة", pages: 1.5 },
  { number: 63, name: "Al-Munafiqun", arabic: "المنافقون", pages: 1.5 },
  { number: 64, name: "At-Taghabun", arabic: "التغابن", pages: 2 },
  { number: 65, name: "At-Talaq", arabic: "الطلاق", pages: 2.5 },
  { number: 66, name: "At-Tahrim", arabic: "التحريم", pages: 2.5 },
  { number: 67, name: "Al-Mulk", arabic: "الملك", pages: 3 },
  { number: 68, name: "Al-Qalam", arabic: "القلم", pages: 3 },
  { number: 69, name: "Al-Haqqah", arabic: "الحاقة", pages: 2.5 },
  { number: 70, name: "Al-Ma'arij", arabic: "المعارج", pages: 2 },
  { number: 71, name: "Nuh", arabic: "نوح", pages: 2 },
  { number: 72, name: "Al-Jinn", arabic: "الجن", pages: 2 },
  { number: 73, name: "Al-Muzzammil", arabic: "المزمل", pages: 2 },
  { number: 74, name: "Al-Muddaththir", arabic: "المدثر", pages: 2.5 },
  { number: 75, name: "Al-Qiyamah", arabic: "القيامة", pages: 1.5 },
  { number: 76, name: "Al-Insan", arabic: "الإنسان", pages: 2 },
  { number: 77, name: "Al-Mursalat", arabic: "المرسلات", pages: 2 },
  { number: 78, name: "An-Naba", arabic: "النبأ", pages: 2 },
  { number: 79, name: "An-Nazi'at", arabic: "النازعات", pages: 2 },
  { number: 80, name: "Abasa", arabic: "عبس", pages: 1.5 },
  { number: 81, name: "At-Takwir", arabic: "التكوير", pages: 1 },
  { number: 82, name: "Al-Infitar", arabic: "الانفطار", pages: 1 },
  { number: 83, name: "Al-Mutaffifin", arabic: "المطففين", pages: 2 },
  { number: 84, name: "Al-Inshiqaq", arabic: "الانشقاق", pages: 1 },
  { number: 85, name: "Al-Buruj", arabic: "البروج", pages: 1 },
  { number: 86, name: "At-Tariq", arabic: "الطارق", pages: 0.5 },
  { number: 87, name: "Al-A'la", arabic: "الأعلى", pages: 0.5 },
  { number: 88, name: "Al-Ghashiyah", arabic: "الغاشية", pages: 1 },
  { number: 89, name: "Al-Fajr", arabic: "الفجر", pages: 1.5 },
  { number: 90, name: "Al-Balad", arabic: "البلد", pages: 1 },
  { number: 91, name: "Ash-Shams", arabic: "الشمس", pages: 0.5 },
  { number: 92, name: "Al-Layl", arabic: "الليل", pages: 1 },
  { number: 93, name: "Ad-Duha", arabic: "الضحى", pages: 0.5 },
  { number: 94, name: "Ash-Sharh", arabic: "الشرح", pages: 0.5 },
  { number: 95, name: "At-Tin", arabic: "التين", pages: 0.5 },
  { number: 96, name: "Al-Alaq", arabic: "العلق", pages: 0.5 },
  { number: 97, name: "Al-Qadr", arabic: "القدر", pages: 0.5 },
  { number: 98, name: "Al-Bayyinah", arabic: "البينة", pages: 1 },
  { number: 99, name: "Az-Zalzalah", arabic: "الزلزلة", pages: 0.5 },
  { number: 100, name: "Al-Adiyat", arabic: "العاديات", pages: 0.5 },
  { number: 101, name: "Al-Qari'ah", arabic: "القارعة", pages: 0.5 },
  { number: 102, name: "At-Takathur", arabic: "التكاثر", pages: 0.5 },
  { number: 103, name: "Al-Asr", arabic: "العصر", pages: 0.5 },
  { number: 104, name: "Al-Humazah", arabic: "الهمزة", pages: 0.5 },
  { number: 105, name: "Al-Fil", arabic: "الفيل", pages: 0.5 },
  { number: 106, name: "Quraysh", arabic: "قريش", pages: 0.5 },
  { number: 107, name: "Al-Ma'un", arabic: "الماعون", pages: 0.5 },
  { number: 108, name: "Al-Kawthar", arabic: "الكوثر", pages: 0.5 },
  { number: 109, name: "Al-Kafirun", arabic: "الكافرون", pages: 0.5 },
  { number: 110, name: "An-Nasr", arabic: "النصر", pages: 0.5 },
  { number: 111, name: "Al-Masad", arabic: "المسد", pages: 0.5 },
  { number: 112, name: "Al-Ikhlas", arabic: "الإخلاص", pages: 0.5 },
  { number: 113, name: "Al-Falaq", arabic: "الفلق", pages: 0.5 },
  { number: 114, name: "An-Nas", arabic: "الناس", pages: 0.5 },
];

export function getSurah(number: number): Surah | undefined {
  return SURAHS.find((s) => s.number === number);
}

export function getSurahPages(number: number): number {
  return getSurah(number)?.pages ?? 0;
}
```

**Step 4: Run tests**

```bash
npx vitest run tests/surahs.test.ts
```
Expected: All PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: surah metadata with page counts for 15-line mushaf"
```

---

### Task 4: Auth (Register & Login)

**Files:**
- Create: `src/auth.ts`
- Create: `src/routes/auth.ts`
- Create: `tests/auth.test.ts`

**Step 1: Write auth utility**

`src/auth.ts`:
```ts
export async function hashPin(pin: string, salt: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(pin + salt);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function generateSalt(): string {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);
  return Array.from(array)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function createToken(
  userId: number,
  secret: string
): Promise<string> {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({ sub: userId, exp: Date.now() + 30 * 24 * 60 * 60 * 1000 })
  );
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${header}.${payload}`)
  );
  const signature = btoa(String.fromCharCode(...new Uint8Array(sig)));
  return `${header}.${payload}.${signature}`;
}

export async function verifyToken(
  token: string,
  secret: string
): Promise<{ sub: number } | null> {
  try {
    const [header, payload, signature] = token.split(".");
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      "raw",
      encoder.encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );
    const sigBytes = Uint8Array.from(atob(signature), (c) => c.charCodeAt(0));
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes,
      encoder.encode(`${header}.${payload}`)
    );
    if (!valid) return null;
    const data = JSON.parse(atob(payload));
    if (data.exp < Date.now()) return null;
    return { sub: data.sub };
  } catch {
    return null;
  }
}
```

**Step 2: Write auth routes**

`src/routes/auth.ts`:
```ts
import { Hono } from "hono";
import { setCookie } from "hono/cookie";
import { hashPin, generateSalt, createToken } from "../auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };

const auth = new Hono<{ Bindings: Bindings }>();

auth.post("/register", async (c) => {
  const { name, pin } = await c.req.json();
  if (!name || !pin || pin.length !== 5 || !/^\d{5}$/.test(pin)) {
    return c.json({ error: "Name and 5-digit PIN required" }, 400);
  }
  const salt = generateSalt();
  const pinHash = await hashPin(pin, salt);
  try {
    const result = await c.env.DB.prepare(
      "INSERT INTO users (name, pin_hash, pin_salt) VALUES (?, ?, ?)"
    )
      .bind(name.trim(), pinHash, salt)
      .run();
    const userId = result.meta.last_row_id as number;

    // Auto-create system pools (Sabak & Manzil)
    await c.env.DB.batch([
      c.env.DB.prepare("INSERT INTO pools (user_id, name, is_system) VALUES (?, 'Sabak', 1)").bind(userId),
      c.env.DB.prepare("INSERT INTO pools (user_id, name, is_system) VALUES (?, 'Manzil', 1)").bind(userId),
    ]);

    const token = await createToken(userId, c.env.JWT_SECRET);
    setCookie(c, "token", token, {
      httpOnly: true,
      secure: true,
      sameSite: "Strict",
      maxAge: 30 * 24 * 60 * 60,
      path: "/",
    });
    return c.json({ ok: true, name: name.trim() });
  } catch (e: any) {
    if (e.message?.includes("UNIQUE")) {
      return c.json({ error: "Name already taken" }, 409);
    }
    throw e;
  }
});

auth.post("/login", async (c) => {
  const { name, pin } = await c.req.json();
  if (!name || !pin) {
    return c.json({ error: "Name and PIN required" }, 400);
  }
  const user = await c.env.DB.prepare(
    "SELECT id, pin_hash, pin_salt FROM users WHERE name = ?"
  )
    .bind(name.trim())
    .first();
  if (!user) {
    return c.json({ error: "Invalid credentials" }, 401);
  }
  const pinHash = await hashPin(pin, user.pin_salt as string);
  if (pinHash !== user.pin_hash) {
    return c.json({ error: "Invalid credentials" }, 401);
  }
  const token = await createToken(user.id as number, c.env.JWT_SECRET);
  setCookie(c, "token", token, {
    httpOnly: true,
    secure: true,
    sameSite: "Strict",
    maxAge: 30 * 24 * 60 * 60,
    path: "/",
  });
  return c.json({ ok: true, name: name.trim() });
});

export { auth };
```

**Step 3: Create auth middleware**

Add to `src/auth.ts`:
```ts
import { Context, Next } from "hono";
import { getCookie } from "hono/cookie";

export async function authMiddleware(c: Context, next: Next) {
  const token = getCookie(c, "token");
  if (!token) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  const payload = await verifyToken(token, c.env.JWT_SECRET);
  if (!payload) {
    return c.json({ error: "Unauthorized" }, 401);
  }
  c.set("userId", payload.sub);
  await next();
}
```

**Step 4: Wire up routes in index.ts**

Update `src/index.ts`:
```ts
import { Hono } from "hono";
import { auth } from "./routes/auth";
import { authMiddleware } from "./auth";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Public routes
app.route("/api/auth", auth);

// Protected routes (added in later tasks)
const api = new Hono<{ Bindings: Bindings; Variables: Variables }>();
api.use("*", authMiddleware);
app.route("/api", api);

// Frontend (added in Task 10)
app.get("/", (c) => c.text("Quran Memorizer"));

export default app;
```

**Step 5: Write auth integration test**

`tests/auth.test.ts`:
```ts
import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF } from "cloudflare:test";

async function applyMigrations(db: D1Database) {
  // Read and apply migration inline for tests
  await db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    );
  `);
}

describe("Auth API", () => {
  beforeAll(async () => {
    await applyMigrations(env.DB);
  });

  it("registers a new user", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "TestUser", pin: "12345" }),
    });
    expect(res.status).toBe(200);
    const data = await res.json();
    expect(data.ok).toBe(true);
    expect(res.headers.get("set-cookie")).toContain("token=");
  });

  it("rejects duplicate name", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "TestUser", pin: "54321" }),
    });
    expect(res.status).toBe(409);
  });

  it("rejects invalid PIN", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "User2", pin: "123" }),
    });
    expect(res.status).toBe(400);
  });

  it("logs in with correct credentials", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "TestUser", pin: "12345" }),
    });
    expect(res.status).toBe(200);
    expect(res.headers.get("set-cookie")).toContain("token=");
  });

  it("rejects wrong PIN", async () => {
    const res = await SELF.fetch("http://localhost/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "TestUser", pin: "99999" }),
    });
    expect(res.status).toBe(401);
  });
});
```

**Step 6: Run tests**

```bash
npx vitest run tests/auth.test.ts
```
Expected: All PASS.

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: auth with register, login, JWT middleware"
```

---

### Task 5: Pool Management API

**Files:**
- Create: `src/routes/pools.ts`
- Create: `tests/pools.test.ts`

**Step 1: Write pool routes**

`src/routes/pools.ts`:
```ts
import { Hono } from "hono";
import { SURAHS } from "../data/surahs";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const pools = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// List all pools for user
pools.get("/", async (c) => {
  const userId = c.get("userId");
  const result = await c.env.DB.prepare(
    "SELECT id, name, is_system, created_at FROM pools WHERE user_id = ? ORDER BY is_system DESC, name"
  ).bind(userId).all();
  return c.json({ pools: result.results });
});

// Create custom pool
pools.post("/", async (c) => {
  const userId = c.get("userId");
  const { name } = await c.req.json();
  if (!name || !name.trim()) {
    return c.json({ error: "Pool name required" }, 400);
  }
  try {
    const result = await c.env.DB.prepare(
      "INSERT INTO pools (user_id, name, is_system) VALUES (?, ?, 0)"
    ).bind(userId, name.trim()).run();
    return c.json({ ok: true, id: result.meta.last_row_id });
  } catch (e: any) {
    if (e.message?.includes("UNIQUE")) {
      return c.json({ error: "Pool name already exists" }, 409);
    }
    throw e;
  }
});

// Delete custom pool (system pools cannot be deleted)
pools.delete("/:poolId", async (c) => {
  const userId = c.get("userId");
  const poolId = parseInt(c.req.param("poolId"));
  const pool = await c.env.DB.prepare(
    "SELECT id, is_system FROM pools WHERE id = ? AND user_id = ?"
  ).bind(poolId, userId).first();
  if (!pool) return c.json({ error: "Pool not found" }, 404);
  if (pool.is_system) return c.json({ error: "Cannot delete system pool" }, 400);
  await c.env.DB.prepare("DELETE FROM pools WHERE id = ?").bind(poolId).run();
  return c.json({ ok: true });
});

// List surahs in a pool
pools.get("/:poolId/surahs", async (c) => {
  const userId = c.get("userId");
  const poolId = parseInt(c.req.param("poolId"));
  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  ).bind(poolId, userId).first();
  if (!pool) return c.json({ error: "Pool not found" }, 404);

  const items = await c.env.DB.prepare(
    "SELECT id, surah_number, added_at FROM surah_pool WHERE pool_id = ? ORDER BY surah_number"
  ).bind(poolId).all();
  const enriched = items.results.map((item: any) => {
    const surah = SURAHS.find((s) => s.number === item.surah_number);
    return { ...item, name: surah?.name, arabic: surah?.arabic, pages: surah?.pages };
  });
  return c.json({ surahs: enriched });
});

// Add surah to pool
pools.post("/:poolId/surahs", async (c) => {
  const userId = c.get("userId");
  const poolId = parseInt(c.req.param("poolId"));
  const { surah_number } = await c.req.json();
  if (!surah_number || surah_number < 1 || surah_number > 114) {
    return c.json({ error: "Valid surah_number (1-114) required" }, 400);
  }
  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  ).bind(poolId, userId).first();
  if (!pool) return c.json({ error: "Pool not found" }, 404);

  try {
    await c.env.DB.prepare(
      "INSERT INTO surah_pool (pool_id, surah_number) VALUES (?, ?)"
    ).bind(poolId, surah_number).run();
    return c.json({ ok: true });
  } catch (e: any) {
    if (e.message?.includes("already in another pool")) {
      return c.json({ error: "Surah is already in another pool. Remove it first." }, 409);
    }
    throw e;
  }
});

// Remove surah from pool
pools.delete("/:poolId/surahs/:surahNumber", async (c) => {
  const userId = c.get("userId");
  const poolId = parseInt(c.req.param("poolId"));
  const surahNumber = parseInt(c.req.param("surahNumber"));
  // Verify pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  ).bind(poolId, userId).first();
  if (!pool) return c.json({ error: "Pool not found" }, 404);

  await c.env.DB.prepare(
    "DELETE FROM surah_pool WHERE pool_id = ? AND surah_number = ?"
  ).bind(poolId, surahNumber).run();
  return c.json({ ok: true });
});

// Move surah between pools
pools.post("/:poolId/surahs/:surahNumber/move", async (c) => {
  const userId = c.get("userId");
  const targetPoolId = parseInt(c.req.param("poolId"));
  const surahNumber = parseInt(c.req.param("surahNumber"));
  // Verify target pool belongs to user
  const pool = await c.env.DB.prepare(
    "SELECT id FROM pools WHERE id = ? AND user_id = ?"
  ).bind(targetPoolId, userId).first();
  if (!pool) return c.json({ error: "Pool not found" }, 404);

  // Find current pool entry and delete, then insert into new pool
  await c.env.DB.prepare(`
    DELETE FROM surah_pool WHERE surah_number = ? AND pool_id IN (
      SELECT id FROM pools WHERE user_id = ?
    )
  `).bind(surahNumber, userId).run();

  await c.env.DB.prepare(
    "INSERT INTO surah_pool (pool_id, surah_number) VALUES (?, ?)"
  ).bind(targetPoolId, surahNumber).run();

  return c.json({ ok: true });
});

export { pools };
```

**Step 2: Wire into index.ts**

Add to the protected `api` router:
```ts
import { pools } from "./routes/pools";
api.route("/pools", pools);
```

**Step 3: Write tests for pools**

`tests/pools.test.ts` — test: create custom pool, list pools, add surah, unique constraint across pools, move surah between pools, delete custom pool, cannot delete system pool.

**Step 4: Run tests, commit**

```bash
git add -A
git commit -m "feat: pool management API with custom pools support"
```

---

### Task 6: Scheduling Algorithm

**Files:**
- Create: `src/scheduler.ts`
- Create: `tests/scheduler.test.ts`

**Step 1: Write comprehensive scheduler tests**

`tests/scheduler.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { generateSchedule, ScheduleChunk } from "../src/scheduler";

describe("generateSchedule", () => {
  it("distributes pages evenly across days", () => {
    // 3 surahs totaling 10 pages, over 5 days = 2 pages/day
    const surahs = [
      { number: 1, pages: 3 },
      { number: 2, pages: 4 },
      { number: 3, pages: 3 },
    ];
    const result = generateSchedule(surahs, 5);
    expect(result).toHaveLength(5);
    const pagesPerDay = result.map((day) =>
      day.reduce((sum, chunk) => sum + (chunk.endPage - chunk.startPage), 0)
    );
    // Each day should be close to 2 pages
    pagesPerDay.forEach((p) => {
      expect(p).toBeGreaterThanOrEqual(1.5);
      expect(p).toBeLessThanOrEqual(2.5);
    });
  });

  it("covers all pages from all surahs", () => {
    const surahs = [
      { number: 36, pages: 6 },
      { number: 67, pages: 3 },
    ];
    const result = generateSchedule(surahs, 3);
    const allChunks = result.flat();
    // Total pages should equal 9
    const totalPages = allChunks.reduce(
      (sum, chunk) => sum + (chunk.endPage - chunk.startPage),
      0
    );
    expect(totalPages).toBe(9);
  });

  it("handles single day", () => {
    const surahs = [{ number: 1, pages: 2 }];
    const result = generateSchedule(surahs, 1);
    expect(result).toHaveLength(1);
    expect(result[0]).toHaveLength(1);
    expect(result[0][0].endPage - result[0][0].startPage).toBe(2);
  });

  it("handles more days than pages", () => {
    const surahs = [{ number: 112, pages: 0.5 }];
    const result = generateSchedule(surahs, 5);
    // Should still produce a valid schedule (some days may be empty)
    const nonEmpty = result.filter((day) => day.length > 0);
    expect(nonEmpty.length).toBeGreaterThanOrEqual(1);
  });
});
```

**Step 2: Run tests to verify failure**

```bash
npx vitest run tests/scheduler.test.ts
```
Expected: FAIL.

**Step 3: Implement scheduler**

`src/scheduler.ts`:
```ts
export interface ScheduleChunk {
  surahNumber: number;
  startPage: number; // offset from surah start (0-based)
  endPage: number; // exclusive
}

interface SurahInput {
  number: number;
  pages: number;
}

export function generateSchedule(
  surahs: SurahInput[],
  totalDays: number
): ScheduleChunk[][] {
  // Build a flat list of page units across all surahs
  const totalPages = surahs.reduce((sum, s) => sum + s.pages, 0);
  const targetPerDay = totalPages / totalDays;

  const days: ScheduleChunk[][] = Array.from({ length: totalDays }, () => []);

  let currentDay = 0;
  let currentDayPages = 0;

  for (const surah of surahs) {
    let remaining = surah.pages;
    let pageOffset = 0;

    while (remaining > 0 && currentDay < totalDays) {
      const spaceLeft = targetPerDay - currentDayPages;
      const isLastDay = currentDay === totalDays - 1;

      let take: number;
      if (isLastDay) {
        // Last day takes everything remaining
        take = remaining;
      } else if (remaining <= spaceLeft + 0.25) {
        // If remaining fits (with small tolerance), put it all in current day
        take = remaining;
      } else {
        // Take what fits in the current day
        take = Math.max(0.5, Math.round(spaceLeft * 2) / 2); // round to nearest 0.5
        if (take > remaining) take = remaining;
      }

      days[currentDay].push({
        surahNumber: surah.number,
        startPage: pageOffset,
        endPage: pageOffset + take,
      });

      pageOffset += take;
      remaining -= take;
      currentDayPages += take;

      // Move to next day if current is full enough
      if (currentDayPages >= targetPerDay - 0.25 && currentDay < totalDays - 1) {
        currentDay++;
        currentDayPages = 0;
      }
    }
  }

  return days;
}
```

**Step 4: Run tests**

```bash
npx vitest run tests/scheduler.test.ts
```
Expected: All PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: scheduling algorithm with even page distribution"
```

---

### Task 7: Schedule API Routes

**Files:**
- Create: `src/routes/schedule.ts`
- Create: `tests/schedule.test.ts`

**Step 1: Write schedule routes**

`src/routes/schedule.ts` — endpoints for:
- `POST /schedule/generate` — preview schedule from a pool_id (returns day-by-day breakdown, does not save)
- `POST /schedule/activate` — saves schedule + items to DB, cancels existing active schedule for that pool
- `GET /schedule/:poolId` — get current active schedule for a pool with all items
- `GET /today` — get today's items across ALL pools with active schedules

**Step 2: Write today endpoint**

The `/today` endpoint:
1. Finds ALL active schedules for user (across all pools)
2. Calculates which day_number today falls on for each schedule (based on start_date)
3. Returns schedule_items for that day_number, grouped by pool name
4. Enriches with surah name, arabic name, page info, pool name

**Step 3: Write tests, run, commit**

```bash
git add -A
git commit -m "feat: schedule generation, activation, and today endpoints"
```

---

### Task 8: Completion & Quality Tracking API

**Files:**
- Create: `src/routes/items.ts`
- Create: `tests/items.test.ts`

**Step 1: Write item update route**

`src/routes/items.ts`:
```ts
import { Hono } from "hono";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const items = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Mark item as done with quality rating
items.patch("/:id/done", async (c) => {
  const userId = c.get("userId");
  const id = parseInt(c.req.param("id"));
  const { quality } = await c.req.json();

  if (!quality || quality < 1 || quality > 20) {
    return c.json({ error: "Quality rating 1-20 required" }, 400);
  }

  // Verify item belongs to user (through schedule → pool → user)
  const item = await c.env.DB.prepare(`
    SELECT si.* FROM schedule_items si
    JOIN schedules s ON si.schedule_id = s.id
    JOIN pools p ON s.pool_id = p.id
    WHERE si.id = ? AND p.user_id = ?
  `).bind(id, userId).first();

  if (!item) return c.json({ error: "Item not found" }, 404);

  // Update item
  await c.env.DB.prepare(
    "UPDATE schedule_items SET status = 'done', quality = ?, completed_at = datetime('now') WHERE id = ?"
  ).bind(quality, id).run();

  // Log recitation
  await c.env.DB.prepare(`
    INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality, schedule_item_id)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(userId, item.surah_number, item.start_page, item.end_page, quality, id).run();

  return c.json({ ok: true });
});

// Mark item as partial — splits remaining into next day
items.patch("/:id/partial", async (c) => {
  const userId = c.get("userId");
  const id = parseInt(c.req.param("id"));
  const { stopped_at_page, quality } = await c.req.json();

  if (!quality || quality < 1 || quality > 20) {
    return c.json({ error: "Quality rating 1-20 required" }, 400);
  }

  const item: any = await c.env.DB.prepare(`
    SELECT si.*, s.total_days FROM schedule_items si
    JOIN schedules s ON si.schedule_id = s.id
    JOIN pools p ON s.pool_id = p.id
    WHERE si.id = ? AND p.user_id = ?
  `).bind(id, userId).first();

  if (!item) return c.json({ error: "Item not found" }, 404);

  if (stopped_at_page <= item.start_page || stopped_at_page >= item.end_page) {
    return c.json({ error: "stopped_at_page must be between start and end" }, 400);
  }

  // Update original item to partial (up to stopped_at_page)
  await c.env.DB.prepare(
    "UPDATE schedule_items SET status = 'partial', end_page = ?, quality = ?, completed_at = datetime('now') WHERE id = ?"
  ).bind(stopped_at_page, quality, id).run();

  // Log recitation for completed portion
  await c.env.DB.prepare(`
    INSERT INTO recitation_log (user_id, surah_number, start_page, end_page, quality, schedule_item_id)
    VALUES (?, ?, ?, ?, ?, ?)
  `).bind(userId, item.surah_number, item.start_page, stopped_at_page, quality, id).run();

  // Create new item for remaining portion, pushed to next day
  const nextDay = item.day_number + 1;
  await c.env.DB.prepare(`
    INSERT INTO schedule_items (schedule_id, day_number, surah_number, start_page, end_page, status)
    VALUES (?, ?, ?, ?, ?, 'pending')
  `).bind(item.schedule_id, nextDay, item.surah_number, stopped_at_page, item.end_page).run();

  return c.json({ ok: true });
});

export { items };
```

**Step 2: Wire into index.ts**

```ts
import { items } from "./routes/items";
api.route("/item", items);
```

**Step 3: Write tests, run, commit**

```bash
git add -A
git commit -m "feat: completion tracking with quality rating and carry-forward"
```

---

### Task 9: Reports & Backup API

**Files:**
- Create: `src/routes/reports.ts`
- Create: `tests/reports.test.ts`

**Step 1: Write reports route**

`src/routes/reports.ts`:
```ts
import { Hono } from "hono";
import { SURAHS } from "../data/surahs";

type Bindings = { DB: D1Database; JWT_SECRET: string };
type Variables = { userId: number };

const reports = new Hono<{ Bindings: Bindings; Variables: Variables }>();

// Per-surah quality stats
reports.get("/", async (c) => {
  const userId = c.get("userId");
  const stats = await c.env.DB.prepare(`
    SELECT
      surah_number,
      COUNT(*) as times_recited,
      AVG(quality) as avg_quality,
      MIN(quality) as min_quality,
      MAX(quality) as max_quality,
      MAX(recited_at) as last_recited
    FROM recitation_log
    WHERE user_id = ?
    GROUP BY surah_number
    ORDER BY surah_number
  `).bind(userId).all();

  const enriched = stats.results.map((row: any) => {
    const surah = SURAHS.find((s) => s.number === row.surah_number);
    return {
      ...row,
      avg_quality: Math.round(row.avg_quality * 10) / 10,
      name: surah?.name,
      arabic: surah?.arabic,
    };
  });

  return c.json({ stats: enriched });
});

// Full data backup
reports.get("/backup", async (c) => {
  const userId = c.get("userId");

  const [userPools, surahEntries, schedules, scheduleItems, logs] = await Promise.all([
    c.env.DB.prepare("SELECT * FROM pools WHERE user_id = ?").bind(userId).all(),
    c.env.DB.prepare(`
      SELECT sp.* FROM surah_pool sp
      JOIN pools p ON sp.pool_id = p.id
      WHERE p.user_id = ?
    `).bind(userId).all(),
    c.env.DB.prepare(`
      SELECT s.* FROM schedules s
      JOIN pools p ON s.pool_id = p.id
      WHERE p.user_id = ?
    `).bind(userId).all(),
    c.env.DB.prepare(`
      SELECT si.* FROM schedule_items si
      JOIN schedules s ON si.schedule_id = s.id
      JOIN pools p ON s.pool_id = p.id
      WHERE p.user_id = ?
    `).bind(userId).all(),
    c.env.DB.prepare("SELECT * FROM recitation_log WHERE user_id = ?").bind(userId).all(),
  ]);

  return c.json({
    exported_at: new Date().toISOString(),
    pools: userPools.results,
    surah_entries: surahEntries.results,
    schedules: schedules.results,
    schedule_items: scheduleItems.results,
    recitation_logs: logs.results,
  });
});

export { reports };
```

**Step 2: Wire into index.ts, test, commit**

```bash
git add -A
git commit -m "feat: reports with per-surah quality stats and backup export"
```

---

### Task 10: Frontend — HTML Shell & Login

**Files:**
- Create: `src/frontend/index.html`
- Modify: `src/index.ts` — serve HTML at `/`

**Step 1: Create the HTML shell**

Single HTML file with:
- Tailwind CSS via CDN
- Bottom nav bar (Home | Pools | Calendar | Reports)
- View container that swaps between screens
- Login/register form as the initial screen
- Mobile-first responsive layout
- Dark/light color scheme (warm, modern feel)

**Step 2: Serve from worker**

In `src/index.ts`, import the HTML as a string and serve at `/`:
```ts
import html from "./frontend/index.html";
app.get("/", (c) => c.html(html));
```

In `wrangler.jsonc`, add rules for HTML import:
```jsonc
"rules": [{ "type": "Text", "globs": ["**/*.html"] }]
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: frontend HTML shell with login screen"
```

---

### Task 11: Frontend — Dashboard (Home Screen)

**Files:**
- Modify: `src/frontend/index.html`

**Step 1: Build home screen**

- Shows today's date and greeting
- Sabak section: list of today's chunks with surah name, page range
- Manzil section: same
- Each item has: "Done" button, "Partial" button
- Done shows quality slider (1-20) before confirming
- Partial asks for page stopped at + quality slider
- Progress bar: "Day X of Y — Z pages today"
- Fetches from `GET /api/today`

**Step 2: Test on mobile viewport, commit**

```bash
git add -A
git commit -m "feat: dashboard with today's assignments and completion flow"
```

---

### Task 12: Frontend — Pool Management

**Files:**
- Modify: `src/frontend/index.html`

**Step 1: Build pool screen**

- Two tabs: Sabak / Manzil
- Searchable list of 114 surahs (search by name or number)
- Each surah row shows: number, name, Arabic name, page count
- Green check if in current pool, grey if in other pool (with label)
- Tap to add/remove
- Bottom summary: "X surahs, Y total pages"
- "Generate Schedule" button at bottom

**Step 2: Schedule setup modal**

- Number of days input
- Start date picker (defaults to tomorrow)
- "Preview" button → shows day-by-day breakdown
- "Activate" button → saves schedule

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: pool management and schedule setup UI"
```

---

### Task 13: Frontend — Calendar View

**Files:**
- Modify: `src/frontend/index.html`

**Step 1: Build calendar**

- Monthly grid view
- Each cell shows: day number, page count badge
- Color coding: green=done, yellow=partial, grey=upcoming, red=missed
- Toggle: Sabak / Manzil / Both
- Month navigation arrows
- Tap a day → slide-up detail panel showing each chunk

**Step 2: Day detail panel**

- List of chunks for that day
- Each chunk: surah name, page range, status, quality (if completed)

**Step 3: Commit**

```bash
git add -A
git commit -m "feat: calendar view with day drill-down"
```

---

### Task 14: Frontend — Reports

**Files:**
- Modify: `src/frontend/index.html`

**Step 1: Build reports screen**

- Table: surah name, times recited, avg quality, min, max, last recited
- Sortable columns (tap to sort)
- Quality color coding: green (15-20), yellow (8-14), red (1-7)
- Summary stats at top: total recitations, overall avg quality
- "Download Backup" button at bottom → triggers `/api/backup` download

**Step 2: Commit**

```bash
git add -A
git commit -m "feat: reports screen with quality stats and backup download"
```

---

### Task 15: Polish & Deploy

**Files:**
- Modify: various

**Step 1: Final testing**

- Test full flow: register → add surahs → generate schedule → complete items → check reports
- Test on mobile viewport
- Test carry-forward (partial completion)
- Test calendar view navigation

**Step 2: Create D1 database on Cloudflare**

```bash
npx wrangler d1 create quran-memorizer-db
```
Update `wrangler.jsonc` with the real database_id.

**Step 3: Apply migrations to production**

```bash
npx wrangler d1 migrations apply quran-memorizer-db --remote
```

**Step 4: Set production secret**

```bash
npx wrangler secret put JWT_SECRET
```

**Step 5: Deploy**

```bash
npx wrangler deploy
```

**Step 6: Commit final state**

```bash
git add -A
git commit -m "chore: production config and deployment"
```
