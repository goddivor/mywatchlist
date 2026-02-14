import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeLoadStarted extends ThemeEvent {}

class ThemeSeedColorChanged extends ThemeEvent {
  final Color seedColor;

  const ThemeSeedColorChanged(this.seedColor);

  @override
  List<Object?> get props => [seedColor];
}

class ThemeModeChanged extends ThemeEvent {
  final String themeModeName; // 'auto', 'light', 'dark', 'black'

  const ThemeModeChanged(this.themeModeName);

  @override
  List<Object?> get props => [themeModeName];
}

class ThemeFontChanged extends ThemeEvent {
  final String fontFamily;

  const ThemeFontChanged(this.fontFamily);

  @override
  List<Object?> get props => [fontFamily];
}

class ThemeBackgroundChanged extends ThemeEvent {
  final String? backgroundImagePath;
  final String? customBgImagePath;
  final bool? clearCustomImage;
  final bool showBackground;

  const ThemeBackgroundChanged({
    this.backgroundImagePath,
    this.customBgImagePath,
    this.clearCustomImage,
    required this.showBackground,
  });

  @override
  List<Object?> get props =>
      [backgroundImagePath, customBgImagePath, clearCustomImage, showBackground];
}
