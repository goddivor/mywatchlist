import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object?> get props => [];
}

class ThemeLoadStarted extends ThemeEvent {}

/// A preset or custom accent was picked (turns Material You and "Auto (season)" off).
class ThemeSeedColorChanged extends ThemeEvent {
  final Color seedColor;

  const ThemeSeedColorChanged(this.seedColor);

  @override
  List<Object?> get props => [seedColor];
}

/// "Auto (season)" picked: the accent follows the background's season (turns Material You off).
class ThemeSeasonAccentSelected extends ThemeEvent {
  const ThemeSeasonAccentSelected();
}

/// Material You: the accent follows the wallpaper (Android 12+) when [enabled].
class ThemeDynamicColorChanged extends ThemeEvent {
  final bool enabled;

  const ThemeDynamicColorChanged(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// The system accent read from the platform (null when the device has none).
class ThemeDynamicAccentLoaded extends ThemeEvent {
  final Color? accent;

  const ThemeDynamicAccentLoaded(this.accent);

  @override
  List<Object?> get props => [accent];
}

/// A colour from the custom picker: saved among the custom swatches and selected.
class ThemeCustomColorAdded extends ThemeEvent {
  final Color color;

  const ThemeCustomColorAdded(this.color);

  @override
  List<Object?> get props => [color];
}

/// Removes a custom swatch; when it was the accent, "Auto (season)" (the default) comes back.
class ThemeCustomColorRemoved extends ThemeEvent {
  final Color color;

  const ThemeCustomColorRemoved(this.color);

  @override
  List<Object?> get props => [color];
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
