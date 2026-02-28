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
 * Round a value to the nearest 0.5
 */
function roundToHalf(value: number): number {
  return Math.round(value * 2) / 2;
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
 * 3. Short surahs (pages <= targetPerDay) are NEVER split — the whole surah
 *    is assigned to one day, even if it means going over the daily target
 * 4. Large surahs (pages > targetPerDay) are split across days, with splits
 *    rounded to nearest 0.5 page
 * 5. Last day gets everything remaining
 * 6. If there are more days than pages, some days will be empty
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
    // If we've gone past the last day, put everything on the last day
    if (currentDay >= totalDays) {
      currentDay = totalDays - 1;
    }

    const isSmallSurah = surah.pages <= targetPerDay;

    if (isSmallSurah) {
      // NEVER split small surahs — assign the whole surah to one day
      const isLastDay = currentDay === totalDays - 1;

      if (!isLastDay && currentDayPages >= targetPerDay) {
        // Current day is already at/over target, move to next day
        currentDay++;
        currentDayPages = 0;
      }

      // Clamp to last day if needed
      if (currentDay >= totalDays) {
        currentDay = totalDays - 1;
      }

      days[currentDay].push({
        surahNumber: surah.number,
        startPage: 0,
        endPage: surah.pages,
      });
      currentDayPages += surah.pages;

      // If adding this surah put us at or over target, move to next day
      // (unless we're on the last day)
      if (currentDay < totalDays - 1 && currentDayPages >= targetPerDay) {
        currentDay++;
        currentDayPages = 0;
      }
    } else {
      // Large surah: must be split across days
      let surahRemaining = surah.pages;
      let surahOffset = 0;

      while (surahRemaining > 0) {
        if (currentDay >= totalDays) {
          currentDay = totalDays - 1;
        }

        const isLastDay = currentDay === totalDays - 1;

        if (isLastDay) {
          days[currentDay].push({
            surahNumber: surah.number,
            startPage: surahOffset,
            endPage: surahOffset + surahRemaining,
          });
          surahOffset += surahRemaining;
          surahRemaining = 0;
        } else {
          const spaceInDay = targetPerDay - currentDayPages;
          const roundedSpace = roundToHalf(spaceInDay);

          if (roundedSpace <= 0) {
            currentDay++;
            currentDayPages = 0;
            continue;
          }

          if (surahRemaining <= roundedSpace) {
            // Rest of surah fits in this day
            days[currentDay].push({
              surahNumber: surah.number,
              startPage: surahOffset,
              endPage: surahOffset + surahRemaining,
            });
            currentDayPages += surahRemaining;
            surahOffset += surahRemaining;
            surahRemaining = 0;
          } else {
            let chunkSize = roundToHalf(spaceInDay);
            if (chunkSize < 0.5) {
              chunkSize = 0.5;
            }
            if (chunkSize > surahRemaining) {
              chunkSize = surahRemaining;
            }

            days[currentDay].push({
              surahNumber: surah.number,
              startPage: surahOffset,
              endPage: surahOffset + chunkSize,
            });
            currentDayPages += chunkSize;
            surahOffset += chunkSize;
            surahRemaining -= chunkSize;

            currentDay++;
            currentDayPages = 0;
          }
        }
      }
    }
  }

  return days;
}
