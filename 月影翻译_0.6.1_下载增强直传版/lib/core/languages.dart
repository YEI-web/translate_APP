class LanguageOption {
  const LanguageOption(this.code, this.label);

  final String code;
  final String label;
}

const sourceLanguages = <LanguageOption>[
  LanguageOption('auto', '自动检测'),
  ...targetLanguages,
];

const targetLanguages = <LanguageOption>[
  LanguageOption('zh-Hans', '简体中文'),
  LanguageOption('zh-Hant', '繁體中文'),
  LanguageOption('en', 'English'),
  LanguageOption('ja', '日本語'),
  LanguageOption('ko', '한국어'),
  LanguageOption('de', 'Deutsch'),
  LanguageOption('fr', 'Français'),
  LanguageOption('es', 'Español'),
  LanguageOption('it', 'Italiano'),
  LanguageOption('pt', 'Português'),
  LanguageOption('ru', 'Русский'),
  LanguageOption('ar', 'العربية'),
];

String languageLabel(String code) {
  for (final language in sourceLanguages) {
    if (language.code == code) return language.label;
  }
  return code;
}
