import { describe, it, expect } from "vitest";
import { generateSchedule } from "../src/scheduler";

describe("generateSchedule", () => {
  it("distributes whole surahs across days", () => {
    const surahs = [
      { number: 1, pages: 3 },
      { number: 2, pages: 4 },
      { number: 3, pages: 3 },
    ];
    const result = generateSchedule(surahs, 5);
    expect(result).toHaveLength(5);
    // Total pages should be correct
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(10);
    // No surah should be split
    for (const surah of surahs) {
      const chunks = result.flat().filter((c) => c.surahNumber === surah.number);
      expect(chunks).toHaveLength(1);
      expect(chunks[0].startPage).toBe(0);
      expect(chunks[0].endPage).toBe(surah.pages);
    }
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

  it("never splits a surah even if it is large", () => {
    const surahs = [{ number: 2, pages: 48 }];
    const result = generateSchedule(surahs, 10);
    expect(result).toHaveLength(10);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(48);
    // The single surah should appear in exactly one day, not split
    const nonEmpty = result.filter((day) => day.length > 0);
    expect(nonEmpty).toHaveLength(1);
    expect(nonEmpty[0][0].startPage).toBe(0);
    expect(nonEmpty[0][0].endPage).toBe(48);
  });

  it("handles mixed large and small surahs without splitting", () => {
    const surahs = [
      { number: 2, pages: 48 },
      { number: 112, pages: 0.5 },
      { number: 113, pages: 0.5 },
      { number: 114, pages: 0.5 },
    ];
    const result = generateSchedule(surahs, 10);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBeCloseTo(49.5);
    // Each surah should be in exactly one day
    for (const surah of surahs) {
      const chunks = result.flat().filter((c) => c.surahNumber === surah.number);
      expect(chunks).toHaveLength(1);
      expect(chunks[0].startPage).toBe(0);
      expect(chunks[0].endPage).toBe(surah.pages);
    }
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

  it("groups many tiny surahs onto the same day", () => {
    // 10 surahs each 0.5 pages = 5 pages total, 5 days = 1 page/day target
    // Surahs should be grouped ~2 per day, never split
    const surahs = Array.from({ length: 10 }, (_, i) => ({
      number: 105 + i,
      pages: 0.5,
    }));
    const result = generateSchedule(surahs, 5);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(5);
    // Every surah appears exactly once
    for (const surah of surahs) {
      const chunks = result.flat().filter((c) => c.surahNumber === surah.number);
      expect(chunks).toHaveLength(1);
      expect(chunks[0].startPage).toBe(0);
      expect(chunks[0].endPage).toBe(0.5);
    }
    // All 5 days should have content (2 surahs each)
    const nonEmpty = result.filter((day) => day.length > 0);
    expect(nonEmpty).toHaveLength(5);
  });

  it("handles more surahs than days", () => {
    // 6 surahs across 2 days — all must appear, none split
    const surahs = [
      { number: 109, pages: 0.5 },
      { number: 110, pages: 0.5 },
      { number: 111, pages: 0.5 },
      { number: 112, pages: 0.5 },
      { number: 113, pages: 0.5 },
      { number: 114, pages: 0.5 },
    ];
    const result = generateSchedule(surahs, 2);
    expect(result).toHaveLength(2);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(3);
    // All surahs present
    const allNums = result.flat().map((c) => c.surahNumber).sort((a, b) => a - b);
    expect(allNums).toEqual([109, 110, 111, 112, 113, 114]);
  });

  it("keeps surahs under 4 pages together on same day when possible", () => {
    // Two small surahs (1.5 + 1 = 2.5 pages) with 3 days and 4.5 total pages
    // Target is 1.5 pages/day — both small surahs should fit on day 1
    const surahs = [
      { number: 78, pages: 1.5 },
      { number: 80, pages: 1 },
      { number: 36, pages: 2 },
    ];
    const result = generateSchedule(surahs, 3);
    const total = result.flat().reduce((s, c) => s + (c.endPage - c.startPage), 0);
    expect(total).toBe(4.5);
    // No surah split
    for (const surah of surahs) {
      const chunks = result.flat().filter((c) => c.surahNumber === surah.number);
      expect(chunks).toHaveLength(1);
    }
  });

  it("handles single surah across many days", () => {
    // 1 surah, 7 days — surah goes to one day, rest empty
    const surahs = [{ number: 36, pages: 6 }];
    const result = generateSchedule(surahs, 7);
    expect(result).toHaveLength(7);
    const nonEmpty = result.filter((day) => day.length > 0);
    expect(nonEmpty).toHaveLength(1);
    expect(nonEmpty[0][0].surahNumber).toBe(36);
    expect(nonEmpty[0][0].endPage).toBe(6);
  });

  it("preserves surah order in output", () => {
    const surahs = [
      { number: 78, pages: 1 },
      { number: 79, pages: 1 },
      { number: 80, pages: 1 },
      { number: 81, pages: 1 },
    ];
    const result = generateSchedule(surahs, 2);
    const allNums = result.flat().map((c) => c.surahNumber);
    expect(allNums).toEqual([78, 79, 80, 81]);
  });

  it("handles equal distribution perfectly", () => {
    // 4 surahs of 2 pages each, 4 days = exactly 2 pages/day
    const surahs = [
      { number: 1, pages: 2 },
      { number: 2, pages: 2 },
      { number: 3, pages: 2 },
      { number: 4, pages: 2 },
    ];
    const result = generateSchedule(surahs, 4);
    expect(result).toHaveLength(4);
    // Each day should have exactly 1 surah
    for (const day of result) {
      expect(day).toHaveLength(1);
      expect(day[0].endPage - day[0].startPage).toBe(2);
    }
  });
});
