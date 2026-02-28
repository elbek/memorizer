import { describe, it, expect } from "vitest";
import { generateSchedule } from "../src/scheduler";

describe("generateSchedule", () => {
  it("distributes pages evenly across days", () => {
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
    // Each day should be close to 2 pages (10 total / 5 days)
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
    const nonEmpty = result.filter((day) => day.length > 0);
    expect(nonEmpty.length).toBeGreaterThanOrEqual(1);
    // Total pages still correct
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(0.5);
  });

  it("splits large surah across multiple days", () => {
    const surahs = [{ number: 2, pages: 48 }];
    const result = generateSchedule(surahs, 10);
    expect(result).toHaveLength(10);
    // Each day should have ~4.8 pages
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(48);
    // Verify chunks are contiguous
    const chunks = result.flat();
    for (let i = 1; i < chunks.length; i++) {
      expect(chunks[i].startPage).toBe(chunks[i - 1].endPage);
    }
  });

  it("handles mixed large and small surahs", () => {
    const surahs = [
      { number: 2, pages: 48 },
      { number: 112, pages: 0.5 },
      { number: 113, pages: 0.5 },
      { number: 114, pages: 0.5 },
    ];
    const result = generateSchedule(surahs, 10);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBeCloseTo(49.5);
  });

  it("never splits short surahs across days", () => {
    // Simulate Juz Amma-like surahs with fractional page counts
    // Target ~2 pages/day, but surahs like An-Naba (1.5 pages) should not be split
    const surahs = [
      { number: 78, pages: 1.5 }, // An-Naba
      { number: 79, pages: 1.5 }, // An-Nazi'at
      { number: 80, pages: 1 },   // Abasa
      { number: 81, pages: 0.5 }, // At-Takwir
      { number: 82, pages: 0.5 }, // Al-Infitar
      { number: 83, pages: 1.5 }, // Al-Mutaffifin
      { number: 84, pages: 0.5 }, // Al-Inshiqaq
      { number: 85, pages: 1 },   // Al-Buruj
    ];
    // Total: 8 pages across 4 days = 2 pages/day target
    const result = generateSchedule(surahs, 4);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(8);

    // Key assertion: each surah should appear in exactly one day (no splitting)
    for (const surah of surahs) {
      const daysContainingSurah = result.filter((day) =>
        day.some((chunk) => chunk.surahNumber === surah.number)
      );
      expect(
        daysContainingSurah.length,
        `Surah ${surah.number} (${surah.pages} pages) should appear in exactly 1 day but appeared in ${daysContainingSurah.length}`
      ).toBe(1);

      // Each surah chunk should cover the full surah (startPage=0, endPage=pages)
      const chunks = result.flat().filter((c) => c.surahNumber === surah.number);
      expect(chunks).toHaveLength(1);
      expect(chunks[0].startPage).toBe(0);
      expect(chunks[0].endPage).toBe(surah.pages);
    }
  });
});
