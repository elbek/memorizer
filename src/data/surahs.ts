export interface Surah {
  number: number;
  name: string;
  arabic: string;
  pages: number;
  juz: number;
}

/**
 * Complete metadata for all 114 surahs of the Quran.
 * Page counts are based on the 15-line Madinah mushaf (King Fahd Complex),
 * computed from start/end page data and rounded to the nearest 0.5 pages.
 * Total pages: ~604.
 *
 * juz: the juz where the surah starts (primary juz assignment).
 * Some surahs span multiple juz; we assign each to the juz where it begins.
 */
export const SURAHS: Surah[] = [
  { number: 1, name: "Al-Fatihah", arabic: "الفاتحة", pages: 1, juz: 1 },
  { number: 2, name: "Al-Baqarah", arabic: "البقرة", pages: 48, juz: 1 },
  { number: 3, name: "Aal-Imran", arabic: "آل عمران", pages: 27, juz: 3 },
  { number: 4, name: "An-Nisa", arabic: "النساء", pages: 29.5, juz: 4 },
  { number: 5, name: "Al-Ma'idah", arabic: "المائدة", pages: 21.5, juz: 6 },
  { number: 6, name: "Al-An'am", arabic: "الأنعام", pages: 23, juz: 7 },
  { number: 7, name: "Al-A'raf", arabic: "الأعراف", pages: 26, juz: 8 },
  { number: 8, name: "Al-Anfal", arabic: "الأنفال", pages: 10, juz: 9 },
  { number: 9, name: "At-Tawbah", arabic: "التوبة", pages: 21, juz: 10 },
  { number: 10, name: "Yunus", arabic: "يونس", pages: 13.5, juz: 11 },
  { number: 11, name: "Hud", arabic: "هود", pages: 14, juz: 11 },
  { number: 12, name: "Yusuf", arabic: "يوسف", pages: 13.5, juz: 12 },
  { number: 13, name: "Ar-Ra'd", arabic: "الرعد", pages: 6.5, juz: 13 },
  { number: 14, name: "Ibrahim", arabic: "إبراهيم", pages: 6.5, juz: 13 },
  { number: 15, name: "Al-Hijr", arabic: "الحجر", pages: 5.5, juz: 14 },
  { number: 16, name: "An-Nahl", arabic: "النحل", pages: 14.5, juz: 14 },
  { number: 17, name: "Al-Isra", arabic: "الإسراء", pages: 11.5, juz: 15 },
  { number: 18, name: "Al-Kahf", arabic: "الكهف", pages: 11.5, juz: 15 },
  { number: 19, name: "Maryam", arabic: "مريم", pages: 7.5, juz: 16 },
  { number: 20, name: "Taha", arabic: "طه", pages: 9.5, juz: 16 },
  { number: 21, name: "Al-Anbiya", arabic: "الأنبياء", pages: 10, juz: 17 },
  { number: 22, name: "Al-Hajj", arabic: "الحج", pages: 10, juz: 17 },
  { number: 23, name: "Al-Mu'minun", arabic: "المؤمنون", pages: 8, juz: 18 },
  { number: 24, name: "An-Nur", arabic: "النور", pages: 9.5, juz: 18 },
  { number: 25, name: "Al-Furqan", arabic: "الفرقان", pages: 7.5, juz: 18 },
  { number: 26, name: "Ash-Shu'ara", arabic: "الشعراء", pages: 10, juz: 19 },
  { number: 27, name: "An-Naml", arabic: "النمل", pages: 8.5, juz: 19 },
  { number: 28, name: "Al-Qasas", arabic: "القصص", pages: 11, juz: 20 },
  { number: 29, name: "Al-Ankabut", arabic: "العنكبوت", pages: 8, juz: 20 },
  { number: 30, name: "Ar-Rum", arabic: "الروم", pages: 6.5, juz: 21 },
  { number: 31, name: "Luqman", arabic: "لقمان", pages: 4, juz: 21 },
  { number: 32, name: "As-Sajdah", arabic: "السجدة", pages: 3, juz: 21 },
  { number: 33, name: "Al-Ahzab", arabic: "الأحزاب", pages: 10, juz: 21 },
  { number: 34, name: "Saba", arabic: "سبأ", pages: 6.5, juz: 22 },
  { number: 35, name: "Fatir", arabic: "فاطر", pages: 6, juz: 22 },
  { number: 36, name: "Ya-Sin", arabic: "يس", pages: 5.5, juz: 22 },
  { number: 37, name: "As-Saffat", arabic: "الصافات", pages: 7, juz: 23 },
  { number: 38, name: "Sad", arabic: "ص", pages: 5.5, juz: 23 },
  { number: 39, name: "Az-Zumar", arabic: "الزمر", pages: 9, juz: 23 },
  { number: 40, name: "Ghafir", arabic: "غافر", pages: 9.5, juz: 24 },
  { number: 41, name: "Fussilat", arabic: "فصلت", pages: 6, juz: 24 },
  { number: 42, name: "Ash-Shura", arabic: "الشورى", pages: 6.5, juz: 25 },
  { number: 43, name: "Az-Zukhruf", arabic: "الزخرف", pages: 6.5, juz: 25 },
  { number: 44, name: "Ad-Dukhan", arabic: "الدخان", pages: 3, juz: 25 },
  { number: 45, name: "Al-Jathiyah", arabic: "الجاثية", pages: 3.5, juz: 25 },
  { number: 46, name: "Al-Ahqaf", arabic: "الأحقاف", pages: 4.5, juz: 26 },
  { number: 47, name: "Muhammad", arabic: "محمد", pages: 4, juz: 26 },
  { number: 48, name: "Al-Fath", arabic: "الفتح", pages: 4.5, juz: 26 },
  { number: 49, name: "Al-Hujurat", arabic: "الحجرات", pages: 2.5, juz: 26 },
  { number: 50, name: "Qaf", arabic: "ق", pages: 2.5, juz: 26 },
  { number: 51, name: "Adh-Dhariyat", arabic: "الذاريات", pages: 3, juz: 26 },
  { number: 52, name: "At-Tur", arabic: "الطور", pages: 2.5, juz: 27 },
  { number: 53, name: "An-Najm", arabic: "النجم", pages: 2.5, juz: 27 },
  { number: 54, name: "Al-Qamar", arabic: "القمر", pages: 3, juz: 27 },
  { number: 55, name: "Ar-Rahman", arabic: "الرحمن", pages: 3, juz: 27 },
  { number: 56, name: "Al-Waqi'ah", arabic: "الواقعة", pages: 3, juz: 27 },
  { number: 57, name: "Al-Hadid", arabic: "الحديد", pages: 4.5, juz: 27 },
  { number: 58, name: "Al-Mujadilah", arabic: "المجادلة", pages: 3.5, juz: 28 },
  { number: 59, name: "Al-Hashr", arabic: "الحشر", pages: 3.5, juz: 28 },
  { number: 60, name: "Al-Mumtahanah", arabic: "الممتحنة", pages: 2.5, juz: 28 },
  { number: 61, name: "As-Saff", arabic: "الصف", pages: 1.5, juz: 28 },
  { number: 62, name: "Al-Jumu'ah", arabic: "الجمعة", pages: 1.5, juz: 28 },
  { number: 63, name: "Al-Munafiqun", arabic: "المنافقون", pages: 1.5, juz: 28 },
  { number: 64, name: "At-Taghabun", arabic: "التغابن", pages: 2, juz: 28 },
  { number: 65, name: "At-Talaq", arabic: "الطلاق", pages: 2, juz: 28 },
  { number: 66, name: "At-Tahrim", arabic: "التحريم", pages: 2, juz: 28 },
  { number: 67, name: "Al-Mulk", arabic: "الملك", pages: 2.5, juz: 29 },
  { number: 68, name: "Al-Qalam", arabic: "القلم", pages: 2, juz: 29 },
  { number: 69, name: "Al-Haqqah", arabic: "الحاقة", pages: 2, juz: 29 },
  { number: 70, name: "Al-Ma'arij", arabic: "المعارج", pages: 2, juz: 29 },
  { number: 71, name: "Nuh", arabic: "نوح", pages: 1.5, juz: 29 },
  { number: 72, name: "Al-Jinn", arabic: "الجن", pages: 2, juz: 29 },
  { number: 73, name: "Al-Muzzammil", arabic: "المزمل", pages: 1.5, juz: 29 },
  { number: 74, name: "Al-Muddaththir", arabic: "المدثر", pages: 2, juz: 29 },
  { number: 75, name: "Al-Qiyamah", arabic: "القيامة", pages: 1, juz: 29 },
  { number: 76, name: "Al-Insan", arabic: "الإنسان", pages: 2, juz: 29 },
  { number: 77, name: "Al-Mursalat", arabic: "المرسلات", pages: 1.5, juz: 29 },
  { number: 78, name: "An-Naba", arabic: "النبأ", pages: 1.5, juz: 30 },
  { number: 79, name: "An-Nazi'at", arabic: "النازعات", pages: 1.5, juz: 30 },
  { number: 80, name: "Abasa", arabic: "عبس", pages: 1, juz: 30 },
  { number: 81, name: "At-Takwir", arabic: "التكوير", pages: 1, juz: 30 },
  { number: 82, name: "Al-Infitar", arabic: "الانفطار", pages: 0.5, juz: 30 },
  { number: 83, name: "Al-Mutaffifin", arabic: "المطففين", pages: 2, juz: 30 },
  { number: 84, name: "Al-Inshiqaq", arabic: "الانشقاق", pages: 0.5, juz: 30 },
  { number: 85, name: "Al-Buruj", arabic: "البروج", pages: 1, juz: 30 },
  { number: 86, name: "At-Tariq", arabic: "الطارق", pages: 0.5, juz: 30 },
  { number: 87, name: "Al-A'la", arabic: "الأعلى", pages: 1, juz: 30 },
  { number: 88, name: "Al-Ghashiyah", arabic: "الغاشية", pages: 0.5, juz: 30 },
  { number: 89, name: "Al-Fajr", arabic: "الفجر", pages: 1.5, juz: 30 },
  { number: 90, name: "Al-Balad", arabic: "البلد", pages: 0.5, juz: 30 },
  { number: 91, name: "Ash-Shams", arabic: "الشمس", pages: 0.5, juz: 30 },
  { number: 92, name: "Al-Layl", arabic: "الليل", pages: 0.5, juz: 30 },
  { number: 93, name: "Ad-Duha", arabic: "الضحى", pages: 0.5, juz: 30 },
  { number: 94, name: "Ash-Sharh", arabic: "الشرح", pages: 0.5, juz: 30 },
  { number: 95, name: "At-Tin", arabic: "التين", pages: 0.5, juz: 30 },
  { number: 96, name: "Al-Alaq", arabic: "العلق", pages: 0.5, juz: 30 },
  { number: 97, name: "Al-Qadr", arabic: "القدر", pages: 0.5, juz: 30 },
  { number: 98, name: "Al-Bayyinah", arabic: "البينة", pages: 0.5, juz: 30 },
  { number: 99, name: "Az-Zalzalah", arabic: "الزلزلة", pages: 0.5, juz: 30 },
  { number: 100, name: "Al-Adiyat", arabic: "العاديات", pages: 0.5, juz: 30 },
  { number: 101, name: "Al-Qari'ah", arabic: "القارعة", pages: 0.5, juz: 30 },
  { number: 102, name: "At-Takathur", arabic: "التكاثر", pages: 0.5, juz: 30 },
  { number: 103, name: "Al-Asr", arabic: "العصر", pages: 0.5, juz: 30 },
  { number: 104, name: "Al-Humazah", arabic: "الهمزة", pages: 0.5, juz: 30 },
  { number: 105, name: "Al-Fil", arabic: "الفيل", pages: 0.5, juz: 30 },
  { number: 106, name: "Quraysh", arabic: "قريش", pages: 0.5, juz: 30 },
  { number: 107, name: "Al-Ma'un", arabic: "الماعون", pages: 0.5, juz: 30 },
  { number: 108, name: "Al-Kawthar", arabic: "الكوثر", pages: 0.5, juz: 30 },
  { number: 109, name: "Al-Kafirun", arabic: "الكافرون", pages: 0.5, juz: 30 },
  { number: 110, name: "An-Nasr", arabic: "النصر", pages: 0.5, juz: 30 },
  { number: 111, name: "Al-Masad", arabic: "المسد", pages: 0.5, juz: 30 },
  { number: 112, name: "Al-Ikhlas", arabic: "الإخلاص", pages: 0.5, juz: 30 },
  { number: 113, name: "Al-Falaq", arabic: "الفلق", pages: 0.5, juz: 30 },
  { number: 114, name: "An-Nas", arabic: "الناس", pages: 0.5, juz: 30 },
];

export function getSurah(number: number): Surah | undefined {
  return SURAHS.find((s) => s.number === number);
}

export function getSurahPages(number: number): number {
  return getSurah(number)?.pages ?? 0;
}

export function getSurahsByJuz(juzNumber: number): Surah[] {
  return SURAHS.filter((s) => s.juz === juzNumber);
}
