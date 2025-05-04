import 'package:equatable/equatable.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object> get props => [];
}

class ThemeLoadStarted extends ThemeEvent {}

class ThemeChanged extends ThemeEvent {
  final String themeName;
  final bool isDarkMode;

  const ThemeChanged({
    required this.themeName,
    required this.isDarkMode,
  });

  @override
  List<Object> get props => [themeName, isDarkMode];
}