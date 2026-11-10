import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/theme/system_bars.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

/// App-wide theme: accent ("Auto (season)", preset, custom or Material You), mode, font and
/// home background.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences prefs;

  /// Reads the system accent; replaced in tests.
  final Future<Color?> Function() readDynamicAccent;

  /// Applies the status and navigation bar style; off in tests that do not need it.
  final bool syncSystemBars;

  static const String keySeedColor = 'seed_color';
  static const String keyDynamicColor = 'dynamic_color_v1';

  /// "Auto (season)" on or off. Absent (installs before theme-seasons, new installs): on unless
  /// an accent was picked explicitly (`seed_color` saved or Material You on), so an existing
  /// explicit choice is kept and only the never-chosen default moves to the season's accent.
  static const String keyAccentSeason = 'accent_season_v1';
  static const String keyCustomColors = 'custom_seed_colors_v1';
  static const String keyFontFamily = 'font_family';
  static const String keyThemeModeName = 'theme_mode_name';
  static const String keyBgImagePath = 'bg_image_path';
  static const String keyCustomBgImagePath = 'custom_bg_image_path';
  static const String keyShowBg = 'show_bg';
  static const String _keyBgMigrated = 'bg_migrated_v1';

  ThemeBloc({
    required this.prefs,
    Future<Color?> Function()? readDynamicAccent,
    this.syncSystemBars = true,
  })  : readDynamicAccent = readDynamicAccent ?? _platformAccent,
        super(ThemeState.initial()) {
    on<ThemeLoadStarted>(_onThemeLoadStarted);
    on<ThemeSeedColorChanged>(_onSeedColorChanged);
    on<ThemeSeasonAccentSelected>(_onSeasonAccentSelected);
    on<ThemeDynamicColorChanged>(_onDynamicColorChanged);
    on<ThemeDynamicAccentLoaded>(_onDynamicAccentLoaded);
    on<ThemeCustomColorAdded>(_onCustomColorAdded);
    on<ThemeCustomColorRemoved>(_onCustomColorRemoved);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<ThemeFontChanged>(_onFontChanged);
    on<ThemeBackgroundChanged>(_onBackgroundChanged);
  }

  static Future<Color?> _platformAccent() async {
    try {
      return await DynamicColorPlugin.getAccentColor();
    } catch (_) {
      return null; // Not Android 12+, or no plugin (tests, desktop).
    }
  }

  @override
  void onChange(Change<ThemeState> change) {
    super.onChange(change);
    if (syncSystemBars) SystemBars.instance.follow(change.nextState);
  }

  void _onThemeLoadStarted(ThemeLoadStarted event, Emitter<ThemeState> emit) {
    final int? seedColorValue = prefs.getInt(keySeedColor);
    // Migrate: old show_bg=false was never functional, reset to true once
    if (!prefs.containsKey(_keyBgMigrated)) {
      prefs.setBool(keyShowBg, true);
      prefs.setBool(_keyBgMigrated, true);
    }
    final custom = (prefs.getStringList(keyCustomColors) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .map(Color.new)
        .toList();
    final useDynamic = prefs.getBool(keyDynamicColor) ?? false;
    final followSeason =
        prefs.getBool(keyAccentSeason) ?? (!useDynamic && seedColorValue == null);

    emit(ThemeState.fromPreferences(
      seedColor: seedColorValue != null ? Color(seedColorValue) : AppThemes.defaultSeedColor,
      useDynamicColor: useDynamic,
      followSeason: followSeason,
      customColors: custom,
      fontFamily: prefs.getString(keyFontFamily) ?? AppThemes.defaultFontFamily,
      themeModeName: prefs.getString(keyThemeModeName) ?? 'auto',
      // Nothing saved: DailyAL's default Fall picture (the home used to show spring or fall
      // depending on the mode).
      backgroundImagePath: prefs.getString(keyBgImagePath) ?? AppThemes.defaultBackground,
      customBgImagePath: prefs.getString(keyCustomBgImagePath),
      showBackground: prefs.getBool(keyShowBg) ?? true,
    ));
    if (syncSystemBars) SystemBars.instance.follow(state);
    unawaited(readDynamicAccent().then((accent) {
      if (!isClosed) add(ThemeDynamicAccentLoaded(accent));
    }));
  }

  void _onSeedColorChanged(ThemeSeedColorChanged event, Emitter<ThemeState> emit) {
    prefs.setInt(keySeedColor, event.seedColor.toARGB32());
    prefs.setBool(keyDynamicColor, false);
    prefs.setBool(keyAccentSeason, false);
    emit(state.copyWith(
      seedColor: event.seedColor,
      useDynamicColor: false,
      followSeason: false,
    ));
  }

  void _onSeasonAccentSelected(ThemeSeasonAccentSelected event, Emitter<ThemeState> emit) {
    prefs.setBool(keyAccentSeason, true);
    prefs.setBool(keyDynamicColor, false);
    emit(state.copyWith(followSeason: true, useDynamicColor: false));
  }

  void _onDynamicColorChanged(ThemeDynamicColorChanged event, Emitter<ThemeState> emit) {
    prefs.setBool(keyDynamicColor, event.enabled);
    if (event.enabled) prefs.setBool(keyAccentSeason, false);
    emit(state.copyWith(
      useDynamicColor: event.enabled,
      followSeason: event.enabled ? false : null,
    ));
  }

  void _onDynamicAccentLoaded(ThemeDynamicAccentLoaded event, Emitter<ThemeState> emit) {
    final accent = event.accent;
    emit(accent == null
        ? state.copyWith(clearDynamicAccent: true)
        : state.copyWith(dynamicAccent: accent));
  }

  void _onCustomColorAdded(ThemeCustomColorAdded event, Emitter<ThemeState> emit) {
    final color = Color(event.color.toARGB32() | 0xFF000000);
    final argb = color.toARGB32();
    final known = AppThemes.predefinedColors.any((c) => c.toARGB32() == argb) ||
        state.customColors.any((c) => c.toARGB32() == argb);
    final custom = known ? state.customColors : [...state.customColors, color];
    _saveCustom(custom);
    prefs.setInt(keySeedColor, argb);
    prefs.setBool(keyDynamicColor, false);
    prefs.setBool(keyAccentSeason, false);
    emit(state.copyWith(
      seedColor: color,
      useDynamicColor: false,
      followSeason: false,
      customColors: custom,
    ));
  }

  void _onCustomColorRemoved(ThemeCustomColorRemoved event, Emitter<ThemeState> emit) {
    final argb = event.color.toARGB32();
    final custom = state.customColors.where((c) => c.toARGB32() != argb).toList();
    _saveCustom(custom);
    final wasSelected = state.seedColor.toARGB32() == argb;
    // The removed colour was the accent: back to the default, "Auto (season)".
    final wasAccent = wasSelected && !state.followSeason && !state.useDynamicColor;
    if (wasSelected) prefs.setInt(keySeedColor, AppThemes.defaultSeedColor.toARGB32());
    if (wasAccent) prefs.setBool(keyAccentSeason, true);
    emit(state.copyWith(
      customColors: custom,
      seedColor: wasSelected ? AppThemes.defaultSeedColor : null,
      followSeason: wasAccent ? true : null,
    ));
  }

  void _saveCustom(List<Color> colors) {
    prefs.setStringList(
      keyCustomColors,
      colors.map((c) => c.toARGB32().toString()).toList(),
    );
  }

  void _onThemeModeChanged(ThemeModeChanged event, Emitter<ThemeState> emit) {
    prefs.setString(keyThemeModeName, event.themeModeName);
    emit(state.copyWith(themeModeName: event.themeModeName));
  }

  void _onFontChanged(ThemeFontChanged event, Emitter<ThemeState> emit) {
    prefs.setString(keyFontFamily, event.fontFamily);
    emit(state.copyWith(fontFamily: event.fontFamily));
  }

  void _onBackgroundChanged(ThemeBackgroundChanged event, Emitter<ThemeState> emit) {
    if (event.backgroundImagePath != null) {
      prefs.setString(keyBgImagePath, event.backgroundImagePath!);
    } else {
      prefs.remove(keyBgImagePath);
    }
    prefs.setBool(keyShowBg, event.showBackground);

    // Handle custom image path separately
    String? customPath = state.customBgImagePath;
    if (event.customBgImagePath != null) {
      customPath = event.customBgImagePath;
      prefs.setString(keyCustomBgImagePath, customPath!);
    } else if (event.clearCustomImage == true) {
      customPath = null;
      prefs.remove(keyCustomBgImagePath);
    }

    emit(state.copyWith(
      // No picture saved means the default one (as on load).
      backgroundImagePath: event.backgroundImagePath ?? AppThemes.defaultBackground,
      customBgImagePath: customPath,
      clearCustomBgImage: customPath == null,
      showBackground: event.showBackground,
    ));
  }
}
