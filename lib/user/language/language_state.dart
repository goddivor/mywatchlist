import 'package:equatable/equatable.dart';

class LanguageState extends Equatable {
  final String languageCode;
  final bool useSystemLanguage;

  const LanguageState({
    required this.languageCode,
    required this.useSystemLanguage,
  });

  const LanguageState.initial()
      : languageCode = 'en',
        useSystemLanguage = false;

  LanguageState copyWith({
    String? languageCode,
    bool? useSystemLanguage,
  }) {
    return LanguageState(
      languageCode: languageCode ?? this.languageCode,
      useSystemLanguage: useSystemLanguage ?? this.useSystemLanguage,
    );
  }

  @override
  List<Object> get props => [languageCode, useSystemLanguage];
}