import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences prefs;

  static const String _keySeedColor = 'seed_color';
  static const String _keyFontFamily = 'font_family';
  static const String _keyThemeModeName = 'theme_mode_name';
  static const String _keyBgImagePath = 'bg_image_path';
  static const String _keyCustomBgImagePath = 'custom_bg_image_path';
  static const String _keyShowBg = 'show_bg';
  static const String _keyBgMigrated = 'bg_migrated_v1';

  ThemeBloc({required this.prefs}) : super(ThemeState.initial()) {
    on<ThemeLoadStarted>(_onThemeLoadStarted);
    on<ThemeSeedColorChanged>(_onSeedColorChanged);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<ThemeFontChanged>(_onFontChanged);
    on<ThemeBackgroundChanged>(_onBackgroundChanged);
  }

  void _onThemeLoadStarted(ThemeLoadStarted event, Emitter<ThemeState> emit) {
    final int? seedColorValue = prefs.getInt(_keySeedColor);
    final String? fontFamily = prefs.getString(_keyFontFamily);
    final String? themeModeName = prefs.getString(_keyThemeModeName);
    final String? bgImagePath = prefs.getString(_keyBgImagePath);
    final String? customBgImagePath = prefs.getString(_keyCustomBgImagePath);
    // Migrate: old show_bg=false was never functional, reset to true once
    if (!prefs.containsKey(_keyBgMigrated)) {
      prefs.setBool(_keyShowBg, true);
      prefs.setBool(_keyBgMigrated, true);
    }
    final bool showBg = prefs.getBool(_keyShowBg) ?? true;

    emit(ThemeState.fromPreferences(
      seedColor: seedColorValue != null
          ? Color(seedColorValue)
          : AppThemes.defaultSeedColor,
      fontFamily: fontFamily ?? AppThemes.defaultFontFamily,
      themeModeName: themeModeName ?? 'auto',
      backgroundImagePath: bgImagePath,
      customBgImagePath: customBgImagePath,
      showBackground: showBg,
    ));
  }

  void _onSeedColorChanged(
      ThemeSeedColorChanged event, Emitter<ThemeState> emit) {
    prefs.setInt(_keySeedColor, event.seedColor.toARGB32());

    emit(ThemeState.fromPreferences(
      seedColor: event.seedColor,
      fontFamily: state.fontFamily,
      themeModeName: state.themeModeName,
      backgroundImagePath: state.backgroundImagePath,
      customBgImagePath: state.customBgImagePath,
      showBackground: state.showBackground,
    ));
  }

  void _onThemeModeChanged(
      ThemeModeChanged event, Emitter<ThemeState> emit) {
    prefs.setString(_keyThemeModeName, event.themeModeName);

    emit(ThemeState.fromPreferences(
      seedColor: state.seedColor,
      fontFamily: state.fontFamily,
      themeModeName: event.themeModeName,
      backgroundImagePath: state.backgroundImagePath,
      customBgImagePath: state.customBgImagePath,
      showBackground: state.showBackground,
    ));
  }

  void _onFontChanged(ThemeFontChanged event, Emitter<ThemeState> emit) {
    prefs.setString(_keyFontFamily, event.fontFamily);

    emit(ThemeState.fromPreferences(
      seedColor: state.seedColor,
      fontFamily: event.fontFamily,
      themeModeName: state.themeModeName,
      backgroundImagePath: state.backgroundImagePath,
      customBgImagePath: state.customBgImagePath,
      showBackground: state.showBackground,
    ));
  }

  void _onBackgroundChanged(
      ThemeBackgroundChanged event, Emitter<ThemeState> emit) {
    if (event.backgroundImagePath != null) {
      prefs.setString(_keyBgImagePath, event.backgroundImagePath!);
    } else {
      prefs.remove(_keyBgImagePath);
    }
    prefs.setBool(_keyShowBg, event.showBackground);

    // Handle custom image path separately
    String? customPath = state.customBgImagePath;
    if (event.customBgImagePath != null) {
      customPath = event.customBgImagePath;
      prefs.setString(_keyCustomBgImagePath, customPath!);
    } else if (event.clearCustomImage == true) {
      customPath = null;
      prefs.remove(_keyCustomBgImagePath);
    }

    emit(ThemeState.fromPreferences(
      seedColor: state.seedColor,
      fontFamily: state.fontFamily,
      themeModeName: state.themeModeName,
      backgroundImagePath: event.backgroundImagePath,
      customBgImagePath: customPath,
      showBackground: event.showBackground,
    ));
  }
}
