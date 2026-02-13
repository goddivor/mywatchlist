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
  static const String _keyShowBg = 'show_bg';

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
    final bool showBg = prefs.getBool(_keyShowBg) ?? false;

    emit(ThemeState.fromPreferences(
      seedColor: seedColorValue != null
          ? Color(seedColorValue)
          : AppThemes.defaultSeedColor,
      fontFamily: fontFamily ?? AppThemes.defaultFontFamily,
      themeModeName: themeModeName ?? 'auto',
      backgroundImagePath: bgImagePath,
      showBackground: showBg,
    ));
  }

  void _onSeedColorChanged(
      ThemeSeedColorChanged event, Emitter<ThemeState> emit) {
    prefs.setInt(_keySeedColor, event.seedColor.value);

    emit(ThemeState.fromPreferences(
      seedColor: event.seedColor,
      fontFamily: state.fontFamily,
      themeModeName: state.themeModeName,
      backgroundImagePath: state.backgroundImagePath,
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

    emit(ThemeState.fromPreferences(
      seedColor: state.seedColor,
      fontFamily: state.fontFamily,
      themeModeName: state.themeModeName,
      backgroundImagePath: event.backgroundImagePath,
      showBackground: event.showBackground,
    ));
  }
}
