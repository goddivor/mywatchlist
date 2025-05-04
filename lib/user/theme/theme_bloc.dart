// import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final SharedPreferences prefs;

  ThemeBloc({required this.prefs}) : super(ThemeState.initial()) {
    on<ThemeLoadStarted>(_onThemeLoadStarted);
    on<ThemeChanged>(_onThemeChanged);
  }

  void _onThemeLoadStarted(ThemeLoadStarted event, Emitter<ThemeState> emit) {
    final String? themeName = prefs.getString('app_theme');
    final bool isDarkMode = prefs.getBool('is_dark_mode') ?? true; // Default to dark mode

    // Find the theme based on stored name or use spring as default
    final AppTheme selectedTheme = AppThemes.availableThemes
        .firstWhere(
          (theme) => theme.name == themeName,
          orElse: () => AppThemes.springTheme,
        );

    emit(state.copyWith(
      themeName: selectedTheme.name,
      themeData: isDarkMode ? selectedTheme.darkTheme : selectedTheme.lightTheme,
      isDarkMode: isDarkMode,
    ));
  }

  void _onThemeChanged(ThemeChanged event, Emitter<ThemeState> emit) async {
    final AppTheme selectedTheme = AppThemes.availableThemes
        .firstWhere(
          (theme) => theme.name == event.themeName,
          orElse: () => AppThemes.springTheme,
        );

    await prefs.setString('app_theme', selectedTheme.name);
    await prefs.setBool('is_dark_mode', event.isDarkMode);

    emit(state.copyWith(
      themeName: selectedTheme.name,
      themeData: event.isDarkMode ? selectedTheme.darkTheme : selectedTheme.lightTheme,
      isDarkMode: event.isDarkMode,
    ));
  }
}