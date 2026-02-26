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
 * Distributes surah pages across a given number of days as evenly as possible.
 *
 * Algorithm:
 * 1. Calculate totalPages and targetPerDay
 * 2. Walk through surahs sequentially, filling each day up to the target
 * 3. When a surah doesn't fit entirely in the current day, split it
 * 4. Round splits to nearest 0.5 page (minimum chunk size)
 * 5. Last day gets everything remaining
 * 6. If there are more days than pages, some days will be empty
 */
export function generateSchedule(
  surahs: SurahInput[],
  totalDays: number
): ScheduleChunk[][] {
  const totalPages = surahs.reduce((sum, s) => sum + s.pages, 0);
  const targetPerDay = totalPages / totalDays;

  // Initialize days array
  const days: ScheduleChunk[][] = [];
  for (let i = 0; i < totalDays; i++) {
    days.push([]);
  }

  let currentDay = 0;
  let currentDayPages = 0;

  for (const surah of surahs) {
    let surahRemaining = surah.pages;
    let surahOffset = 0; // how far into this surah we've scheduled

    while (surahRemaining > 0) {
      // If we've gone past the last day, put everything on the last day
      if (currentDay >= totalDays) {
        currentDay = totalDays - 1;
      }

      const isLastDay = currentDay === totalDays - 1;

      if (isLastDay) {
        // Last day gets everything remaining
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
          // Current day is full, move to next day
          currentDay++;
          currentDayPages = 0;
          continue;
        }

        if (surahRemaining <= roundedSpace) {
          // Entire remaining surah fits in this day
          days[currentDay].push({
            surahNumber: surah.number,
            startPage: surahOffset,
            endPage: surahOffset + surahRemaining,
          });
          currentDayPages += surahRemaining;
          surahOffset += surahRemaining;
          surahRemaining = 0;
        } else {
          // Need to split: put what fits, carry the rest
          let chunkSize = roundToHalf(spaceInDay);

          // Ensure minimum chunk size of 0.5
          if (chunkSize < 0.5) {
            chunkSize = 0.5;
          }

          // Don't take more than what's remaining
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

          // Move to next day
          currentDay++;
          currentDayPages = 0;
        }
      }
    }
  }

  return days;
}
