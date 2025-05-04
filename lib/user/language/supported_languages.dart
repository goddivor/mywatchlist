class SupportedLanguage {
  final String code;
  final String name;
  final String flag;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });
}

class SupportedLanguages {
  static const List<SupportedLanguage> languages = [
    SupportedLanguage(
      code: 'en',
      name: 'English',
      flag: '🇺🇸',
    ),
    SupportedLanguage(
      code: 'fr',
      name: 'Français',
      flag: '🇫🇷',
    ),
    SupportedLanguage(
      code: 'es',
      name: 'Español',
      flag: '🇪🇸',
    ),
    SupportedLanguage(
      code: 'ja',
      name: '日本語',
      flag: '🇯🇵',
    ),
    SupportedLanguage(
      code: 'de',
      name: 'Deutsch',
      flag: '🇩🇪',
    ),
    SupportedLanguage(
      code: 'it',
      name: 'Italiano',
      flag: '🇮🇹',
    ),
    SupportedLanguage(
      code: 'zh',
      name: '中文',
      flag: '🇨🇳',
    ),
    SupportedLanguage(
      code: 'ko',
      name: '한국어',
      flag: '🇰🇷',
    ),
    SupportedLanguage(
      code: 'ru',
      name: 'Русский',
      flag: '🇷🇺',
    ),
    SupportedLanguage(
      code: 'pt',
      name: 'Português',
      flag: '🇵🇹',
    ),
  ];

  static SupportedLanguage getLanguageByCode(String code) {
    return languages.firstWhere(
      (language) => language.code == code,
      orElse: () => languages[0], // Default to English
    );
  }

  static List<String> getLanguageCodes() {
    return languages.map((lang) => lang.code).toList();
  }
}