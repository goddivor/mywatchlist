import 'package:equatable/equatable.dart';

abstract class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object> get props => [];
}

/// Re-reads the saved language and applies it (the bloc already starts from the saved value).
class LanguageLoadStarted extends LanguageEvent {}

class LanguageChanged extends LanguageEvent {
  /// ARB tag of the picked language; legacy short codes (`fr`) are normalized.
  final String languageCode;
  final bool useSystemLanguage;

  const LanguageChanged({
    required this.languageCode,
    required this.useSystemLanguage,
  });

  @override
  List<Object> get props => [languageCode, useSystemLanguage];
}
