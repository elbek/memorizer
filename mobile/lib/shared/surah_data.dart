class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.name,
    required this.arabic,
    required this.ayahCount,
    required this.pages,
    required this.juz,
  });

  final int number;
  final String name;
  final String arabic;
  final int ayahCount;
  final double pages;
  final int juz;
}

const List<SurahInfo> surahs = [
  SurahInfo(number: 1, name: "Al-Fatihah", arabic: "الفاتحة", ayahCount: 7, pages: 1, juz: 1),
  SurahInfo(number: 2, name: "Al-Baqarah", arabic: "البقرة", ayahCount: 286, pages: 48, juz: 1),
  SurahInfo(number: 3, name: "Aal-'Imran", arabic: "آل عمران", ayahCount: 200, pages: 27, juz: 3),
  SurahInfo(number: 4, name: "An-Nisa'", arabic: "النساء", ayahCount: 176, pages: 29.5, juz: 4),
  SurahInfo(number: 5, name: "Al-Ma'idah", arabic: "المائدة", ayahCount: 120, pages: 21.5, juz: 6),
  SurahInfo(number: 6, name: "Al-An'am", arabic: "الأنعام", ayahCount: 165, pages: 23, juz: 7),
  SurahInfo(number: 7, name: "Al-A'raf", arabic: "الأعراف", ayahCount: 206, pages: 26, juz: 8),
  SurahInfo(number: 8, name: "Al-Anfal", arabic: "الأنفال", ayahCount: 75, pages: 10, juz: 9),
  SurahInfo(number: 9, name: "At-Tawbah", arabic: "التوبة", ayahCount: 129, pages: 21, juz: 10),
  SurahInfo(number: 10, name: "Yunus", arabic: "يونس", ayahCount: 109, pages: 13.5, juz: 11),
  SurahInfo(number: 11, name: "Hud", arabic: "هود", ayahCount: 123, pages: 14, juz: 11),
  SurahInfo(number: 12, name: "Yusuf", arabic: "يوسف", ayahCount: 111, pages: 13.5, juz: 12),
  SurahInfo(number: 13, name: "Ar-Ra'd", arabic: "الرعد", ayahCount: 43, pages: 6.5, juz: 13),
  SurahInfo(number: 14, name: "Ibrahim", arabic: "إبراهيم", ayahCount: 52, pages: 6.5, juz: 13),
  SurahInfo(number: 15, name: "Al-Hijr", arabic: "الحجر", ayahCount: 99, pages: 5.5, juz: 14),
  SurahInfo(number: 16, name: "An-Nahl", arabic: "النحل", ayahCount: 128, pages: 14.5, juz: 14),
  SurahInfo(number: 17, name: "Al-Isra'", arabic: "الإسراء", ayahCount: 111, pages: 11.5, juz: 15),
  SurahInfo(number: 18, name: "Al-Kahf", arabic: "الكهف", ayahCount: 110, pages: 11.5, juz: 15),
  SurahInfo(number: 19, name: "Maryam", arabic: "مريم", ayahCount: 98, pages: 7.5, juz: 16),
  SurahInfo(number: 20, name: "Taha", arabic: "طه", ayahCount: 135, pages: 9.5, juz: 16),
  SurahInfo(number: 21, name: "Al-Anbiya'", arabic: "الأنبياء", ayahCount: 112, pages: 10, juz: 17),
  SurahInfo(number: 22, name: "Al-Hajj", arabic: "الحج", ayahCount: 78, pages: 10, juz: 17),
  SurahInfo(number: 23, name: "Al-Mu'minun", arabic: "المؤمنون", ayahCount: 118, pages: 8, juz: 18),
  SurahInfo(number: 24, name: "An-Nur", arabic: "النور", ayahCount: 64, pages: 9.5, juz: 18),
  SurahInfo(number: 25, name: "Al-Furqan", arabic: "الفرقان", ayahCount: 77, pages: 7.5, juz: 18),
  SurahInfo(number: 26, name: "Ash-Shu'ara", arabic: "الشعراء", ayahCount: 227, pages: 10, juz: 19),
  SurahInfo(number: 27, name: "An-Naml", arabic: "النمل", ayahCount: 93, pages: 8.5, juz: 19),
  SurahInfo(number: 28, name: "Al-Qasas", arabic: "القصص", ayahCount: 88, pages: 11, juz: 20),
  SurahInfo(number: 29, name: "Al-Ankabut", arabic: "العنكبوت", ayahCount: 69, pages: 8, juz: 20),
  SurahInfo(number: 30, name: "Ar-Rum", arabic: "الروم", ayahCount: 60, pages: 6.5, juz: 21),
  SurahInfo(number: 31, name: "Luqman", arabic: "لقمان", ayahCount: 34, pages: 4, juz: 21),
  SurahInfo(number: 32, name: "As-Sajdah", arabic: "السجدة", ayahCount: 30, pages: 3, juz: 21),
  SurahInfo(number: 33, name: "Al-Ahzab", arabic: "الأحزاب", ayahCount: 73, pages: 10, juz: 21),
  SurahInfo(number: 34, name: "Saba'", arabic: "سبأ", ayahCount: 54, pages: 6.5, juz: 22),
  SurahInfo(number: 35, name: "Fatir", arabic: "فاطر", ayahCount: 45, pages: 6, juz: 22),
  SurahInfo(number: 36, name: "Ya-Sin", arabic: "يس", ayahCount: 83, pages: 5.5, juz: 22),
  SurahInfo(number: 37, name: "As-Saffat", arabic: "الصافات", ayahCount: 182, pages: 7, juz: 23),
  SurahInfo(number: 38, name: "Sad", arabic: "ص", ayahCount: 88, pages: 5.5, juz: 23),
  SurahInfo(number: 39, name: "Az-Zumar", arabic: "الزمر", ayahCount: 75, pages: 9, juz: 23),
  SurahInfo(number: 40, name: "Ghafir", arabic: "غافر", ayahCount: 85, pages: 9.5, juz: 24),
  SurahInfo(number: 41, name: "Fussilat", arabic: "فصلت", ayahCount: 54, pages: 6, juz: 24),
  SurahInfo(number: 42, name: "Ash-Shura", arabic: "الشورى", ayahCount: 53, pages: 6.5, juz: 25),
  SurahInfo(number: 43, name: "Az-Zukhruf", arabic: "الزخرف", ayahCount: 89, pages: 6.5, juz: 25),
  SurahInfo(number: 44, name: "Ad-Dukhan", arabic: "الدخان", ayahCount: 59, pages: 3, juz: 25),
  SurahInfo(number: 45, name: "Al-Jathiyah", arabic: "الجاثية", ayahCount: 37, pages: 3.5, juz: 25),
  SurahInfo(number: 46, name: "Al-Ahqaf", arabic: "الأحقاف", ayahCount: 35, pages: 4.5, juz: 26),
  SurahInfo(number: 47, name: "Muhammad", arabic: "محمد", ayahCount: 38, pages: 4, juz: 26),
  SurahInfo(number: 48, name: "Al-Fath", arabic: "الفتح", ayahCount: 29, pages: 4.5, juz: 26),
  SurahInfo(number: 49, name: "Al-Hujurat", arabic: "الحجرات", ayahCount: 18, pages: 2.5, juz: 26),
  SurahInfo(number: 50, name: "Qaf", arabic: "ق", ayahCount: 45, pages: 2.5, juz: 26),
  SurahInfo(number: 51, name: "Adh-Dhariyat", arabic: "الذاريات", ayahCount: 60, pages: 3, juz: 26),
  SurahInfo(number: 52, name: "At-Tur", arabic: "الطور", ayahCount: 49, pages: 2.5, juz: 27),
  SurahInfo(number: 53, name: "An-Najm", arabic: "النجم", ayahCount: 62, pages: 2.5, juz: 27),
  SurahInfo(number: 54, name: "Al-Qamar", arabic: "القمر", ayahCount: 55, pages: 3, juz: 27),
  SurahInfo(number: 55, name: "Ar-Rahman", arabic: "الرحمن", ayahCount: 78, pages: 3, juz: 27),
  SurahInfo(number: 56, name: "Al-Waqi'ah", arabic: "الواقعة", ayahCount: 96, pages: 3, juz: 27),
  SurahInfo(number: 57, name: "Al-Hadid", arabic: "الحديد", ayahCount: 29, pages: 4.5, juz: 27),
  SurahInfo(number: 58, name: "Al-Mujadilah", arabic: "المجادلة", ayahCount: 22, pages: 3.5, juz: 28),
  SurahInfo(number: 59, name: "Al-Hashr", arabic: "الحشر", ayahCount: 24, pages: 3.5, juz: 28),
  SurahInfo(number: 60, name: "Al-Mumtahanah", arabic: "الممتحنة", ayahCount: 13, pages: 2.5, juz: 28),
  SurahInfo(number: 61, name: "As-Saff", arabic: "الصف", ayahCount: 14, pages: 1.5, juz: 28),
  SurahInfo(number: 62, name: "Al-Jumu'ah", arabic: "الجمعة", ayahCount: 11, pages: 1.5, juz: 28),
  SurahInfo(number: 63, name: "Al-Munafiqun", arabic: "المنافقون", ayahCount: 11, pages: 1.5, juz: 28),
  SurahInfo(number: 64, name: "At-Taghabun", arabic: "التغابن", ayahCount: 18, pages: 2, juz: 28),
  SurahInfo(number: 65, name: "At-Talaq", arabic: "الطلاق", ayahCount: 12, pages: 2, juz: 28),
  SurahInfo(number: 66, name: "At-Tahrim", arabic: "التحريم", ayahCount: 12, pages: 2, juz: 28),
  SurahInfo(number: 67, name: "Al-Mulk", arabic: "الملك", ayahCount: 30, pages: 2.5, juz: 29),
  SurahInfo(number: 68, name: "Al-Qalam", arabic: "القلم", ayahCount: 52, pages: 2, juz: 29),
  SurahInfo(number: 69, name: "Al-Haqqah", arabic: "الحاقة", ayahCount: 52, pages: 2, juz: 29),
  SurahInfo(number: 70, name: "Al-Ma'arij", arabic: "المعارج", ayahCount: 44, pages: 2, juz: 29),
  SurahInfo(number: 71, name: "Nuh", arabic: "نوح", ayahCount: 28, pages: 1.5, juz: 29),
  SurahInfo(number: 72, name: "Al-Jinn", arabic: "الجن", ayahCount: 28, pages: 2, juz: 29),
  SurahInfo(number: 73, name: "Al-Muzzammil", arabic: "المزمل", ayahCount: 20, pages: 1.5, juz: 29),
  SurahInfo(number: 74, name: "Al-Muddaththir", arabic: "المدثر", ayahCount: 56, pages: 2, juz: 29),
  SurahInfo(number: 75, name: "Al-Qiyamah", arabic: "القيامة", ayahCount: 40, pages: 1, juz: 29),
  SurahInfo(number: 76, name: "Al-Insan", arabic: "الإنسان", ayahCount: 31, pages: 2, juz: 29),
  SurahInfo(number: 77, name: "Al-Mursalat", arabic: "المرسلات", ayahCount: 50, pages: 1.5, juz: 29),
  SurahInfo(number: 78, name: "An-Naba", arabic: "النبأ", ayahCount: 40, pages: 1.5, juz: 30),
  SurahInfo(number: 79, name: "An-Nazi'at", arabic: "النازعات", ayahCount: 46, pages: 1.5, juz: 30),
  SurahInfo(number: 80, name: "'Abasa", arabic: "عبس", ayahCount: 42, pages: 1, juz: 30),
  SurahInfo(number: 81, name: "At-Takwir", arabic: "التكوير", ayahCount: 29, pages: 1, juz: 30),
  SurahInfo(number: 82, name: "Al-Infitar", arabic: "الانفطار", ayahCount: 19, pages: 0.5, juz: 30),
  SurahInfo(number: 83, name: "Al-Mutaffifin", arabic: "المطففين", ayahCount: 36, pages: 2, juz: 30),
  SurahInfo(number: 84, name: "Al-Inshiqaq", arabic: "الانشقاق", ayahCount: 25, pages: 0.5, juz: 30),
  SurahInfo(number: 85, name: "Al-Buruj", arabic: "البروج", ayahCount: 22, pages: 1, juz: 30),
  SurahInfo(number: 86, name: "At-Tariq", arabic: "الطارق", ayahCount: 17, pages: 0.5, juz: 30),
  SurahInfo(number: 87, name: "Al-A'la", arabic: "الأعلى", ayahCount: 19, pages: 1, juz: 30),
  SurahInfo(number: 88, name: "Al-Ghashiyah", arabic: "الغاشية", ayahCount: 26, pages: 0.5, juz: 30),
  SurahInfo(number: 89, name: "Al-Fajr", arabic: "الفجر", ayahCount: 30, pages: 1.5, juz: 30),
  SurahInfo(number: 90, name: "Al-Balad", arabic: "البلد", ayahCount: 20, pages: 0.5, juz: 30),
  SurahInfo(number: 91, name: "Ash-Shams", arabic: "الشمس", ayahCount: 15, pages: 0.5, juz: 30),
  SurahInfo(number: 92, name: "Al-Layl", arabic: "الليل", ayahCount: 21, pages: 0.5, juz: 30),
  SurahInfo(number: 93, name: "Ad-Duha", arabic: "الضحى", ayahCount: 11, pages: 0.5, juz: 30),
  SurahInfo(number: 94, name: "Ash-Sharh", arabic: "الشرح", ayahCount: 8, pages: 0.5, juz: 30),
  SurahInfo(number: 95, name: "At-Tin", arabic: "التين", ayahCount: 8, pages: 0.5, juz: 30),
  SurahInfo(number: 96, name: "Al-'Alaq", arabic: "العلق", ayahCount: 19, pages: 0.5, juz: 30),
  SurahInfo(number: 97, name: "Al-Qadr", arabic: "القدر", ayahCount: 5, pages: 0.5, juz: 30),
  SurahInfo(number: 98, name: "Al-Bayyinah", arabic: "البينة", ayahCount: 8, pages: 0.5, juz: 30),
  SurahInfo(number: 99, name: "Az-Zalzalah", arabic: "الزلزلة", ayahCount: 8, pages: 0.5, juz: 30),
  SurahInfo(number: 100, name: "Al-'Adiyat", arabic: "العاديات", ayahCount: 11, pages: 0.5, juz: 30),
  SurahInfo(number: 101, name: "Al-Qari'ah", arabic: "القارعة", ayahCount: 11, pages: 0.5, juz: 30),
  SurahInfo(number: 102, name: "At-Takathur", arabic: "التكاثر", ayahCount: 8, pages: 0.5, juz: 30),
  SurahInfo(number: 103, name: "Al-'Asr", arabic: "العصر", ayahCount: 3, pages: 0.5, juz: 30),
  SurahInfo(number: 104, name: "Al-Humazah", arabic: "الهمزة", ayahCount: 9, pages: 0.5, juz: 30),
  SurahInfo(number: 105, name: "Al-Fil", arabic: "الفيل", ayahCount: 5, pages: 0.5, juz: 30),
  SurahInfo(number: 106, name: "Quraysh", arabic: "قريش", ayahCount: 4, pages: 0.5, juz: 30),
  SurahInfo(number: 107, name: "Al-Ma'un", arabic: "الماعون", ayahCount: 7, pages: 0.5, juz: 30),
  SurahInfo(number: 108, name: "Al-Kawthar", arabic: "الكوثر", ayahCount: 3, pages: 0.5, juz: 30),
  SurahInfo(number: 109, name: "Al-Kafirun", arabic: "الكافرون", ayahCount: 6, pages: 0.5, juz: 30),
  SurahInfo(number: 110, name: "An-Nasr", arabic: "النصر", ayahCount: 3, pages: 0.5, juz: 30),
  SurahInfo(number: 111, name: "Al-Masad", arabic: "المسد", ayahCount: 5, pages: 0.5, juz: 30),
  SurahInfo(number: 112, name: "Al-Ikhlas", arabic: "الإخلاص", ayahCount: 4, pages: 0.5, juz: 30),
  SurahInfo(number: 113, name: "Al-Falaq", arabic: "الفلق", ayahCount: 5, pages: 0.5, juz: 30),
  SurahInfo(number: 114, name: "An-Nas", arabic: "الناس", ayahCount: 6, pages: 0.5, juz: 30),
];

/// Mushaf start page for each surah (1-indexed, matching surah number).
const List<int> surahStartPages = [
  1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267,
  282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411,
  415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502,
  507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551,
  553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578,
  580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595,
  595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602,
  602, 602, 603, 603, 603, 604, 604, 604,
];

SurahInfo? getSurah(int number) {
  if (number < 1 || number > 114) return null;
  return surahs[number - 1];
}

/// Returns the mushaf start page for the given surah number (1–114).
int startPageForSurah(int surahNumber) {
  if (surahNumber < 1 || surahNumber > 114) return 1;
  return surahStartPages[surahNumber - 1];
}

/// Returns the surah that contains the given mushaf page (1–604).
SurahInfo surahForPage(int page) {
  int matched = 0;
  for (int i = 1; i < surahStartPages.length; i++) {
    if (surahStartPages[i] <= page) {
      matched = i;
    } else {
      break;
    }
  }
  return surahs[matched];
}

List<SurahInfo> getSurahsByJuz(int juzNumber) =>
    surahs.where((s) => s.juz == juzNumber).toList();
