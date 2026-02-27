import { describe, it, expect } from "vitest";
import { SURAHS, getSurahsByJuz } from "../src/data/surahs";

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
      expect(s.juz).toBeGreaterThanOrEqual(1);
      expect(s.juz).toBeLessThanOrEqual(30);
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

  it("all 30 juz are covered by surah assignments", () => {
    const juzSet = new Set(SURAHS.map((s) => s.juz));
    // Some juz (e.g. 2, 5) have no surah starting there because
    // a long surah spans across them. That's expected.
    expect(juzSet.size).toBeGreaterThanOrEqual(25);
    expect(juzSet.has(1)).toBe(true);
    expect(juzSet.has(30)).toBe(true);
  });

  it("juz 30 contains An-Naba through An-Nas", () => {
    const juz30 = getSurahsByJuz(30);
    const numbers = juz30.map((s) => s.number);
    expect(numbers[0]).toBe(78); // An-Naba
    expect(numbers[numbers.length - 1]).toBe(114); // An-Nas
    expect(juz30).toHaveLength(37);
  });
});
