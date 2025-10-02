import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static const String _themeKey = 'selected_theme';

  static final List<ColorTheme> colorThemes = [
    ColorTheme(
      name: "Blue Ocean",
      primary: const Color(0xFF2196F3),
      gradientStart: const Color(0xFF90CAF9),
      gradientEnd: const Color(0xFFBAE0FF),
      containerColor: Colors.white70,
    ),
    ColorTheme(
      name: "Green Nature",
      primary: const Color(0xFF4CAF50),
      gradientStart: const Color(0xFFA5D6A7),
      gradientEnd: const Color(0xFFE8F5E8),
      containerColor: const Color(0xFFF1F8E9),
    ),
    ColorTheme(
      name: "Purple Dream",
      primary: const Color(0xFF9C27B0),
      gradientStart: const Color(0xFFCE93D8),
      gradientEnd: const Color(0xFFF3E5F5),
      containerColor: const Color(0xFFE1BEE7),
    ),
    ColorTheme(
      name: "Orange Sunset",
      primary: const Color(0xFFFF9800),
      gradientStart: const Color(0xFFFFB74D),
      gradientEnd: const Color(0xFFFFF3E0),
      containerColor: const Color(0xFFFFE0B2),
    ),
    ColorTheme(
      name: "Deep Blue",
      primary: const Color(0xFF1976D2),
      gradientStart: const Color(0xFF64B5F6),
      gradientEnd: const Color(0xFFBBDEFB),
      containerColor: const Color(0xFF90CAF9),
    ),
    ColorTheme(
      name: "Pink Blossom",
      primary: const Color(0xFFE91E63),
      gradientStart: const Color(0xFFF8BBD0),
      gradientEnd: const Color(0xFFFCE4EC),
      containerColor: const Color(0xFFF48FB1),
    ),
    ColorTheme(
      name: "Teal Breeze",
      primary: const Color(0xFF009688),
      gradientStart: const Color(0xFF80CBC4),
      gradientEnd: const Color(0xFFE0F2F1),
      containerColor: const Color(0xFFB2DFDB),
    ),
    ColorTheme(
      name: "Golden Glow",
      primary: const Color(0xFFFFC107),
      gradientStart: const Color(0xFFFFE082),
      gradientEnd: const Color(0xFFFFF8E1),
      containerColor: const Color(0xFFFFF59D),
    ),
    ColorTheme(
      name: "Red Passion",
      primary: const Color(0xFFF44336),
      gradientStart: const Color(0xFFEF9A9A),
      gradientEnd: const Color(0xFFFFEBEE),
      containerColor: const Color(0xFFE57373),
    ),
    ColorTheme(
      name: "Sky Morning",
      primary: const Color(0xFF64B5F6),
      gradientStart: const Color(0xFFFFF176),
      gradientEnd: const Color(0xFFFFFDE7),
      containerColor: const Color(0xFFE3F2FD),
    ),
  ];

  static Future<void> saveSelectedTheme(int themeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, themeIndex);
  }

  static Future<int> getSelectedThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey) ?? 0;
  }

  static ColorTheme getCurrentTheme(int index) {
    if (index >= 0 && index < colorThemes.length) {
      return colorThemes[index];
    }
    return colorThemes[0];
  }
}

class ColorTheme {
  final String name;
  final Color primary;
  final Color gradientStart;
  final Color gradientEnd;
  final Color containerColor;

  const ColorTheme({
    required this.name,
    required this.primary,
    required this.gradientStart,
    required this.gradientEnd,
    required this.containerColor,
  });
}
