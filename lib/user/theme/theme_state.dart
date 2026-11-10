import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

class ThemeState extends Equatable {
  /// The chosen preset or custom accent (kept while Material You is on).
  final Color seedColor;

  /// Material You: the accent follows the system accent when one is known.
  final bool useDynamicColor;

  /// The system accent (Android 12+), null when unknown or unsupported.
  final Color? dynamicAccent;

  /// "Auto (season)": the accent follows the season of the background picture
  /// ([AppThemes.seasonAccentFor]); an explicit pick (preset, custom, Material You) turns it off.
  final bool followSeason;

  /// Colours added with the custom picker, shown after the presets.
  final List<Color> customColors;
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
    this.useDynamicColor = false,
    this.dynamicAccent,
    this.followSeason = false,
    this.customColors = const [],
    required this.fontFamily,
    required this.themeModeName,
    required this.backgroundImagePath,
    this.customBgImagePath,
    required this.showBackground,
    required this.lightThemeData,
    required this.darkThemeData,
    required this.themeMode,
  });

  /// The colour the schemes are built from.
  Color get effectiveSeed => resolveSeed(
        seedColor: seedColor,
        useDynamicColor: useDynamicColor,
        dynamicAccent: dynamicAccent,
        followSeason: followSeason,
        backgroundImagePath: backgroundImagePath,
      );

  /// Material You first (when the device has an accent), then "Auto (season)", then the
  /// picked preset or custom colour.
  static Color resolveSeed({
    required Color seedColor,
    required bool useDynamicColor,
    required Color? dynamicAccent,
    required bool followSeason,
    required String? backgroundImagePath,
  }) {
    if (useDynamicColor && dynamicAccent != null) return dynamicAccent;
    if (followSeason) return AppThemes.seasonAccentFor(backgroundImagePath);
    return seedColor;
  }

  /// The "Auto (season)" accent of the current background, shown on its swatch.
  Color get seasonAccent => AppThemes.seasonAccentFor(backgroundImagePath);

  /// Whether the device offers a Material You accent.
  bool get dynamicColorAvailable => dynamicAccent != null;

  /// A new install: DailyAL's default theme (Fall background, its Brown accent through
  /// "Auto (season)").
  factory ThemeState.initial() => ThemeState.fromPreferences(
        seedColor: AppThemes.defaultSeedColor,
        followSeason: true,
        fontFamily: AppThemes.defaultFontFamily,
        themeModeName: 'auto',
        backgroundImagePath: AppThemes.defaultBackground,
      );

  factory ThemeState.fromPreferences({
    required Color seedColor,
    bool useDynamicColor = false,
    Color? dynamicAccent,
    bool followSeason = false,
    List<Color> customColors = const [],
    required String fontFamily,
    required String themeModeName,
    String? backgroundImagePath,
    String? customBgImagePath,
    bool showBackground = true,
  }) {
    final isBlack = themeModeName == 'black';
    final seed = resolveSeed(
      seedColor: seedColor,
      useDynamicColor: useDynamicColor,
      dynamicAccent: dynamicAccent,
      followSeason: followSeason,
      backgroundImagePath: backgroundImagePath,
    );

    return ThemeState(
      seedColor: seedColor,
      useDynamicColor: useDynamicColor,
      dynamicAccent: dynamicAccent,
      followSeason: followSeason,
      customColors: List.unmodifiable(customColors),
      fontFamily: fontFamily,
      themeModeName: themeModeName,
      backgroundImagePath: backgroundImagePath,
      customBgImagePath: customBgImagePath,
      showBackground: showBackground,
      lightThemeData: AppThemes.generateThemeData(
        seedColor: seed,
        fontFamily: fontFamily,
        brightness: Brightness.light,
      ),
      darkThemeData: AppThemes.generateThemeData(
        seedColor: seed,
        fontFamily: fontFamily,
        brightness: Brightness.dark,
        isBlack: isBlack,
      ),
      themeMode: resolveThemeMode(themeModeName),
    );
  }

  /// Copy that rebuilds the theme data only when the effective accent, font or mode changed
  /// (a background change rebuilds it only in "Auto (season)" when the season's accent differs).
  ThemeState copyWith({
    Color? seedColor,
    bool? useDynamicColor,
    Color? dynamicAccent,
    bool clearDynamicAccent = false,
    bool? followSeason,
    List<Color>? customColors,
    String? fontFamily,
    String? themeModeName,
    String? backgroundImagePath,
    bool clearBackgroundImage = false,
    String? customBgImagePath,
    bool clearCustomBgImage = false,
    bool? showBackground,
  }) {
    final next = ThemeState(
      seedColor: seedColor ?? this.seedColor,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      dynamicAccent: clearDynamicAccent ? null : (dynamicAccent ?? this.dynamicAccent),
      followSeason: followSeason ?? this.followSeason,
      customColors:
          customColors == null ? this.customColors : List.unmodifiable(customColors),
      fontFamily: fontFamily ?? this.fontFamily,
      themeModeName: themeModeName ?? this.themeModeName,
      backgroundImagePath:
          clearBackgroundImage ? null : (backgroundImagePath ?? this.backgroundImagePath),
      customBgImagePath:
          clearCustomBgImage ? null : (customBgImagePath ?? this.customBgImagePath),
      showBackground: showBackground ?? this.showBackground,
      lightThemeData: lightThemeData,
      darkThemeData: darkThemeData,
      themeMode: themeMode,
    );
    final themeUnchanged = next.effectiveSeed == effectiveSeed &&
        next.fontFamily == this.fontFamily &&
        next.themeModeName == this.themeModeName;
    if (themeUnchanged) return next;
    return ThemeState.fromPreferences(
      seedColor: next.seedColor,
      useDynamicColor: next.useDynamicColor,
      dynamicAccent: next.dynamicAccent,
      followSeason: next.followSeason,
      customColors: next.customColors,
      fontFamily: next.fontFamily,
      themeModeName: next.themeModeName,
      backgroundImagePath: next.backgroundImagePath,
      customBgImagePath: next.customBgImagePath,
      showBackground: next.showBackground,
    );
  }

  /// The brightness actually shown for [platformBrightness] (the device's, for 'auto').
  Brightness brightnessFor(Brightness platformBrightness) => switch (themeMode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        ThemeMode.system => platformBrightness,
      };

  static ThemeMode resolveThemeMode(String modeName) {
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
        useDynamicColor,
        dynamicAccent,
        followSeason,
        customColors,
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
