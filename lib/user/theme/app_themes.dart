import 'package:flutter/material.dart';

class AppThemes {
  /// Predefined seed colors for the color picker grid
  static const List<Color> predefinedColors = [
    Color(0xFFFF4545), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF673AB7), // Deep Purple
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF03A9F4), // Light Blue
    Color(0xFF2196F3), // Blue
    Color(0xFF00BCD4), // Cyan
    Color(0xFF009688), // Teal
    Color(0xFF4CAF50), // Green
    Color(0xFF8BC34A), // Light Green
    Color(0xFFCDDC39), // Lime
    Color(0xFFFFEB3B), // Yellow
    Color(0xFFFFC107), // Amber
    Color(0xFFFF9800), // Orange
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
    Color(0xFF263238), // Dark
  ];

  /// Available background images
  static const List<String> backgroundImages = [
    'assets/images/fall.jpg',
    'assets/images/summer.jpg',
    'assets/images/spring.jpg',
    'assets/images/winter.jpg',
    'assets/images/anime-collage.jpg',
  ];

  /// Available font families
  static const List<String> availableFonts = [
    'Poppins',
    'Roboto',
    'OpenSans',
    'Montserrat',
    'Nunito',
    'Quicksand',
  ];

  /// Display names for fonts (for UI)
  static const Map<String, String> fontDisplayNames = {
    'Poppins': 'Poppins',
    'Roboto': 'Roboto',
    'OpenSans': 'Open Sans',
    'Montserrat': 'Montserrat',
    'Nunito': 'Nunito',
    'Quicksand': 'Quicksand',
  };

  /// Default seed color
  static const Color defaultSeedColor = Color(0xFF607D8B);

  /// Default font family
  static const String defaultFontFamily = 'Poppins';

  /// Generate a ThemeData from a seed color, font family and brightness
  static ThemeData generateThemeData({
    required Color seedColor,
    required String fontFamily,
    required Brightness brightness,
    bool isBlack = false,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final effectiveColorScheme = isBlack
        ? colorScheme.copyWith(
            surface: Colors.black,
            onSurface: Colors.white,
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: const Color(0xFF0A0A0A),
            surfaceContainer: const Color(0xFF121212),
            surfaceContainerHigh: const Color(0xFF1A1A1A),
            surfaceContainerHighest: const Color(0xFF222222),
          )
        : colorScheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: effectiveColorScheme,
      fontFamily: fontFamily,
      brightness: brightness,
      scaffoldBackgroundColor: effectiveColorScheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: effectiveColorScheme.surface,
        foregroundColor: effectiveColorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
