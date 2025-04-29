import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

class ThemeState extends Equatable {
  final String themeName;
  final ThemeData themeData;
  final bool isDarkMode;

  const ThemeState({
    required this.themeName,
    required this.themeData,
    required this.isDarkMode,
  });

  factory ThemeState.initial() {
    return ThemeState(
      themeName: AppThemes.springTheme.name,
      themeData: AppThemes.springTheme.darkTheme,
      isDarkMode: true,
    );
  }

  ThemeState copyWith({
    String? themeName,
    ThemeData? themeData,
    bool? isDarkMode,
  }) {
    return ThemeState(
      themeName: themeName ?? this.themeName,
      themeData: themeData ?? this.themeData,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  @override
  List<Object> get props => [themeName, themeData, isDarkMode];
}