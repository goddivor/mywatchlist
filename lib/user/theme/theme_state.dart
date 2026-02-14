import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

class ThemeState extends Equatable {
  final Color seedColor;
  final String fontFamily;
  final String themeModeName; // 'auto', 'light', 'dark', 'black'
  final String? backgroundImagePath;
  final String? customBgImagePath;
  final bool showBackground;
  final ThemeData lightThemeData;
  final ThemeData darkThemeData;
  final ThemeMode themeMode;

  const ThemeState({
    required this.seedColor,
    required this.fontFamily,
    required this.themeModeName,
    required this.backgroundImagePath,
    this.customBgImagePath,
    required this.showBackground,
    required this.lightThemeData,
    required this.darkThemeData,
    required this.themeMode,
  });

  factory ThemeState.initial() {
    return ThemeState(
      seedColor: AppThemes.defaultSeedColor,
      fontFamily: AppThemes.defaultFontFamily,
      themeModeName: 'auto',
      backgroundImagePath: null,
      customBgImagePath: null,
      showBackground: true,
      lightThemeData: AppThemes.generateThemeData(
        seedColor: AppThemes.defaultSeedColor,
        fontFamily: AppThemes.defaultFontFamily,
        brightness: Brightness.light,
      ),
      darkThemeData: AppThemes.generateThemeData(
        seedColor: AppThemes.defaultSeedColor,
        fontFamily: AppThemes.defaultFontFamily,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
    );
  }

  factory ThemeState.fromPreferences({
    required Color seedColor,
    required String fontFamily,
    required String themeModeName,
    String? backgroundImagePath,
    String? customBgImagePath,
    bool showBackground = true,
  }) {
    final isBlack = themeModeName == 'black';

    return ThemeState(
      seedColor: seedColor,
      fontFamily: fontFamily,
      themeModeName: themeModeName,
      backgroundImagePath: backgroundImagePath,
      customBgImagePath: customBgImagePath,
      showBackground: showBackground,
      lightThemeData: AppThemes.generateThemeData(
        seedColor: seedColor,
        fontFamily: fontFamily,
        brightness: Brightness.light,
      ),
      darkThemeData: AppThemes.generateThemeData(
        seedColor: seedColor,
        fontFamily: fontFamily,
        brightness: Brightness.dark,
        isBlack: isBlack,
      ),
      themeMode: _resolveThemeMode(themeModeName),
    );
  }

  static ThemeMode _resolveThemeMode(String modeName) {
    switch (modeName) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
      case 'black':
        return ThemeMode.dark;
      case 'auto':
      default:
        return ThemeMode.system;
    }
  }

  @override
  List<Object?> get props => [
        seedColor,
        fontFamily,
        themeModeName,
        backgroundImagePath,
        customBgImagePath,
        showBackground,
        lightThemeData,
        darkThemeData,
        themeMode,
      ];
}
