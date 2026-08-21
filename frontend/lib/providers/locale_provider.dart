import 'package:flutter/material.dart';

import '../core/l10n/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  AppLocalizations? _localizations;

  AppLocalizations tr(BuildContext context) {
    _localizations ??= AppLocalizations.of(context);
    return _localizations!;
  }

  void setLocale(Locale locale) {
    if (!AppLocalizations.supportedLocales.contains(locale)) return;
    _locale = locale;
    _localizations = null;
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('ny'));
    } else {
      setLocale(const Locale('en'));
    }
  }

  String get languageName => _locale.languageCode == 'en' ? 'English' : 'Chichewa';
}
