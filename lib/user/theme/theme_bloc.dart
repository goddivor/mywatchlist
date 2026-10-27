import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/theme/system_bars.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

/// App-wide theme: accent (preset, custom or Material You), mode, font and home background.
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences prefs;

  /// Reads the system accent; replaced in tests.
  final Future<Color?> Function() readDynamicAccent;

  /// Applies the status and navigation bar style; off in tests that do not need it.
  final bool syncSystemBars;

  static const String keySeedColor = 'seed_color';
  static const String keyDynamicColor = 'dynamic_color_v1';
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

    emit(ThemeState.fromPreferences(
      seedColor: seedColorValue != null ? Color(seedColorValue) : AppThemes.defaultSeedColor,
      useDynamicColor: prefs.getBool(keyDynamicColor) ?? false,
      customColors: custom,
      fontFamily: prefs.getString(keyFontFamily) ?? AppThemes.defaultFontFamily,
      themeModeName: prefs.getString(keyThemeModeName) ?? 'auto',
      backgroundImagePath: prefs.getString(keyBgImagePath),
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
    emit(state.copyWith(seedColor: event.seedColor, useDynamicColor: false));
  }

  void _onDynamicColorChanged(ThemeDynamicColorChanged event, Emitter<ThemeState> emit) {
    prefs.setBool(keyDynamicColor, event.enabled);
    emit(state.copyWith(useDynamicColor: event.enabled));
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
    emit(state.copyWith(seedColor: color, useDynamicColor: false, customColors: custom));
  }

  void _onCustomColorRemoved(ThemeCustomColorRemoved event, Emitter<ThemeState> emit) {
    final argb = event.color.toARGB32();
    final custom = state.customColors.where((c) => c.toARGB32() != argb).toList();
    _saveCustom(custom);
    final wasSelected = state.seedColor.toARGB32() == argb;
    if (wasSelected) prefs.setInt(keySeedColor, AppThemes.defaultSeedColor.toARGB32());
    emit(state.copyWith(
      customColors: custom,
      seedColor: wasSelected ? AppThemes.defaultSeedColor : null,
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
      backgroundImagePath: event.backgroundImagePath,
      clearBackgroundImage: event.backgroundImagePath == null,
      customBgImagePath: customPath,
      clearCustomBgImage: customPath == null,
      showBackground: event.showBackground,
    ));
  }
}
