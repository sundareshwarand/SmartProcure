import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const supportedLocales = [Locale('en'), Locale('hi'), Locale('ta')];

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'welcome': 'Welcome to SmartProcure',
      'get_started': 'Get Started',
      'already_registered': 'Already Registered',
    },
    'hi': {
      'welcome': 'SmartProcure में आपका स्वागत है',
      'get_started': 'शुरू करें',
      'already_registered': 'पहले से पंजीकृत',
    },
    'ta': {
      'welcome': 'SmartProcureக்கு வரவேற்கிறோம்',
      'get_started': 'தொடக்கம்',
      'already_registered': 'ஏற்கனவே பதிவு செய்துள்ளீர்கள்',
    }
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']![key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
