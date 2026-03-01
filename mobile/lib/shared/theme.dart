import 'package:flutter/material.dart';

// Islamic-inspired warm palette
const _emerald = Color(0xFF1B6B4A);
const _gold = Color(0xFFC5A55A);
const _cream = Color(0xFFFFFDF7);
const _darkBrown = Color(0xFF3D2B1F);
const _warmGrey = Color(0xFF8C7B6B);

final lightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _emerald,
    brightness: Brightness.light,
    surface: _cream,
    primary: _emerald,
    secondary: _gold,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: _cream,
  appBarTheme: AppBarTheme(
    centerTitle: true,
    backgroundColor: _cream,
    foregroundColor: _darkBrown,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _darkBrown,
      letterSpacing: 0.3,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: _warmGrey.withValues(alpha: 0.12)),
    ),
    color: Colors.white,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 64,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: _emerald.withValues(alpha: 0.12),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _emerald);
      }
      return TextStyle(fontSize: 11, color: _warmGrey);
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: _emerald, size: 22);
      }
      return IconThemeData(color: _warmGrey, size: 22);
    }),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _warmGrey.withValues(alpha: 0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _warmGrey.withValues(alpha: 0.2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _emerald, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _emerald,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: BorderSide.none,
  ),
  dividerTheme: DividerThemeData(color: _warmGrey.withValues(alpha: 0.12)),
);

final darkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: _emerald,
    brightness: Brightness.dark,
    surface: const Color(0xFF141414),
    primary: const Color(0xFF4ADE80),
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFF141414),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Color(0xFF141414),
    elevation: 0,
    scrolledUnderElevation: 0.5,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.3,
    ),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    color: const Color(0xFF1E1E1E),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 64,
    backgroundColor: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    indicatorColor: const Color(0xFF4ADE80).withValues(alpha: 0.15),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E1E1E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF4ADE80), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF4ADE80),
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: BorderSide.none,
  ),
);

const quranPageBg = Color(0xFFF5F0E1);
const quranPageBgDark = Color(0xFF2D2A24);

/// Quran page background color presets: (name, light, dark).
const quranPageColors = <(String, Color, Color)>[
  ('Parchment', Color(0xFFF5F0E1), Color(0xFF2D2A24)),
  ('White', Color(0xFFFFFFFF), Color(0xFF1E1E1E)),
  ('Sepia', Color(0xFFF0E4CC), Color(0xFF302820)),
  ('Olive', Color(0xFFECEDE2), Color(0xFF262A22)),
  ('Sky', Color(0xFFE8EEF4), Color(0xFF1E2530)),
  ('Rose', Color(0xFFF5ECE8), Color(0xFF2D2424)),
  ('Lavender', Color(0xFFEDE8F4), Color(0xFF252030)),
  ('Mint', Color(0xFFE6F0EC), Color(0xFF1E2A26)),
];

Color quranPageBgFor(int index, bool isDark) {
  final i = index.clamp(0, quranPageColors.length - 1);
  return isDark ? quranPageColors[i].$3 : quranPageColors[i].$2;
}
