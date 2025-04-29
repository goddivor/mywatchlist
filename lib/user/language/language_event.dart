import 'package:equatable/equatable.dart';

abstract class LanguageEvent extends Equatable {
  const LanguageEvent();

  @override
  List<Object> get props => [];
}

class LanguageLoadStarted extends LanguageEvent {}

class LanguageChanged extends LanguageEvent {
  final String languageCode;
  final bool useSystemLanguage;

  const LanguageChanged({
    required this.languageCode,
    required this.useSystemLanguage,
  });

  @override
  List<Object> get props => [languageCode, useSystemLanguage];
}