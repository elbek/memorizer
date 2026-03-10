export interface ScheduleChunk {
  surahNumber: number;
  startPage: number; // offset from surah start (0-based)
  endPage: number; // exclusive
}

interface SurahInput {
  number: number;
  pages: number;
}

/**
 * Fisher-Yates shuffle (returns new array, does not mutate input)
 */
function shuffleArray<T>(arr: T[]): T[] {
  const result = [...arr];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

/**
 * Distributes surah pages across a given number of days as evenly as possible.
 *
 * Algorithm:
 * 1. Calculate totalPages and targetPerDay
 * 2. Walk through surahs sequentially, filling each day up to the target
 * 3. Surahs are NEVER split — the whole surah is assigned to one day,
 *    even if it means going over the daily target
 * 4. Some imbalance between days is acceptable (e.g., 15 vs 17 pages)
 * 5. Last day gets everything remaining
 * 6. If there are more days than surahs, some days will be empty
 */
export function generateSchedule(
  surahs: SurahInput[],
  totalDays: number,
  options?: { shuffle?: boolean }
): ScheduleChunk[][] {
  const orderedSurahs = options?.shuffle ? shuffleArray(surahs) : surahs;
  const totalPages = orderedSurahs.reduce((sum, s) => sum + s.pages, 0);
  const targetPerDay = totalPages / totalDays;

  // Initialize days array
  const days: ScheduleChunk[][] = [];
  for (let i = 0; i < totalDays; i++) {
    days.push([]);
  }

  let currentDay = 0;
  let currentDayPages = 0;

  for (const surah of orderedSurahs) {
    // Clamp to last day if needed
    if (currentDay >= totalDays) {
      currentDay = totalDays - 1;
    }

    const isLastDay = currentDay === totalDays - 1;

    // Move to next day if current day is at/over target (unless last day)
    if (!isLastDay && currentDayPages >= targetPerDay) {
      currentDay++;
      currentDayPages = 0;
    }

    // Clamp again after advancing
    if (currentDay >= totalDays) {
      currentDay = totalDays - 1;
    }

    // Assign the whole surah to the current day — never split
    days[currentDay].push({
      surahNumber: surah.number,
      startPage: 0,
      endPage: surah.pages,
    });
    currentDayPages += surah.pages;

    // If adding this surah put us at or over target, move to next day
    if (currentDay < totalDays - 1 && currentDayPages >= targetPerDay) {
      currentDay++;
      currentDayPages = 0;
    }
  }

  return days;
}
