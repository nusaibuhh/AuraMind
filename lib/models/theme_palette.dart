import 'package:flutter/material.dart';

import 'question.dart';

class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.name,
    required this.category,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onBackground,
    required this.thumbnailGradient,
  });

  final String id;
  final String name;
  final MentalHealthCategory category;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color onBackground;
  final List<Color> thumbnailGradient;

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: onPrimary,
        onSurface: onBackground,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onBackground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: onBackground.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

const List<ThemePalette> allThemePalettes = [
  // Anxiety themes
  ThemePalette(
    id: 'ocean_calm',
    name: 'Ocean Calm',
    category: MentalHealthCategory.anxiety,
    primary: Color(0xFF4A90D9),
    secondary: Color(0xFFE8F4FD),
    accent: Color(0xFF87CEEB),
    background: Color(0xFFF5FAFF),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1A3A5C),
    thumbnailGradient: [Color(0xFF87CEEB), Color(0xFF4A90D9), Color(0xFFE8F4FD)],
  ),
  ThemePalette(
    id: 'sage_forest',
    name: 'Sage Forest',
    category: MentalHealthCategory.anxiety,
    primary: Color(0xFF6B8F71),
    secondary: Color(0xFFF5F0E8),
    accent: Color(0xFF9CAF88),
    background: Color(0xFFF8FAF5),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2D4A32),
    thumbnailGradient: [Color(0xFF9CAF88), Color(0xFF6B8F71), Color(0xFFF5F0E8)],
  ),
  ThemePalette(
    id: 'lavender_air',
    name: 'Lavender Air',
    category: MentalHealthCategory.anxiety,
    primary: Color(0xFF9B8EC4),
    secondary: Color(0xFFE8E4EF),
    accent: Color(0xFFB8A9D9),
    background: Color(0xFFF9F7FC),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF3D3555),
    thumbnailGradient: [Color(0xFFB8A9D9), Color(0xFF9B8EC4), Color(0xFFE8E4EF)],
  ),
  // Depression themes
  ThemePalette(
    id: 'sunrise',
    name: 'Sunrise',
    category: MentalHealthCategory.depression,
    primary: Color(0xFFE8A838),
    secondary: Color(0xFFFDF6E8),
    accent: Color(0xFFF5C563),
    background: Color(0xFFFFFBF5),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF5C4A1A),
    thumbnailGradient: [Color(0xFFF5C563), Color(0xFFE8A838), Color(0xFFFDF6E8)],
  ),
  ThemePalette(
    id: 'peach_light',
    name: 'Peach Light',
    category: MentalHealthCategory.depression,
    primary: Color(0xFFE8A090),
    secondary: Color(0xFFF5EDE8),
    accent: Color(0xFFF0C4B8),
    background: Color(0xFFFFFAF8),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF5C3D35),
    thumbnailGradient: [Color(0xFFF0C4B8), Color(0xFFE8A090), Color(0xFFF5EDE8)],
  ),
  ThemePalette(
    id: 'coral_soft',
    name: 'Coral Soft',
    category: MentalHealthCategory.depression,
    primary: Color(0xFFE8786A),
    secondary: Color(0xFFFFFFFF),
    accent: Color(0xFFF0A090),
    background: Color(0xFFFFF8F7),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF5C2D28),
    thumbnailGradient: [Color(0xFFF0A090), Color(0xFFE8786A), Color(0xFFFFFFFF)],
  ),
  // Stress themes
  ThemePalette(
    id: 'mint_breeze',
    name: 'Mint Breeze',
    category: MentalHealthCategory.stress,
    primary: Color(0xFF5CB8A8),
    secondary: Color(0xFFFFFFFF),
    accent: Color(0xFF8DD4C8),
    background: Color(0xFFF5FFFC),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1A4A42),
    thumbnailGradient: [Color(0xFF8DD4C8), Color(0xFF5CB8A8), Color(0xFFFFFFFF)],
  ),
  ThemePalette(
    id: 'aqua',
    name: 'Aqua',
    category: MentalHealthCategory.stress,
    primary: Color(0xFF4ABFBF),
    secondary: Color(0xFFE0E8E8),
    accent: Color(0xFF7DD4D4),
    background: Color(0xFFF5FAFA),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF1A4545),
    thumbnailGradient: [Color(0xFF7DD4D4), Color(0xFF4ABFBF), Color(0xFFE0E8E8)],
  ),
  ThemePalette(
    id: 'soft_green',
    name: 'Soft Green',
    category: MentalHealthCategory.stress,
    primary: Color(0xFF6BAF7A),
    secondary: Color(0xFFF5F0E8),
    accent: Color(0xFF9DD4A8),
    background: Color(0xFFF8FAF5),
    surface: Color(0xFFFFFFFF),
    onPrimary: Color(0xFFFFFFFF),
    onBackground: Color(0xFF2D4A35),
    thumbnailGradient: [Color(0xFF9DD4A8), Color(0xFF6BAF7A), Color(0xFFF5F0E8)],
  ),
];

List<ThemePalette> themesForCategory(MentalHealthCategory category) {
  if (category == MentalHealthCategory.normal) {
    return List<ThemePalette>.from(allThemePalettes)..shuffle();
  }
  return allThemePalettes
      .where((theme) => theme.category == category)
      .toList();
}

ThemePalette? paletteById(String id) {
  for (final palette in allThemePalettes) {
    if (palette.id == id) return palette;
  }
  return null;
}
