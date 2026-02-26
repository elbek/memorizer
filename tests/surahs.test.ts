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
