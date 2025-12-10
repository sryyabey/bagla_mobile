import 'package:flutter/material.dart';

/// Lightweight localization stub to replace generated flutter_gen output.
/// Provides Turkish and English strings for the app keys currently in use.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('tr'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(Localizations.localeOf(context));
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'loginTitle': 'Login',
      'emailLabel': 'Email',
      'passwordLabel': 'Password',
      'facebookLogin': 'Continue with Facebook',
      'googleLogin': 'Continue with Google',
      'onboardTitle1': 'Build your bio link & share',
      'onboardDesc1':
          'Launch a single bio link, add socials and share it everywhere with QR or one tap.',
      'onboardTitle2': 'Appointments + SMS alerts',
      'onboardDesc2':
          'Book appointments, send confirmations by SMS, and keep the whole schedule in one place.',
      'onboardTitle3': 'Bio link is free to start',
      'onboardDesc3':
          'Begin free, publish your bio link instantly, upgrade only when you need extras.',
      'menuTitle': 'Menu',
      'myLinks': 'My Links',
      'themes': 'Themes',
      'profile': 'Profile',
      'support': 'Support',
      'exit': 'Logout',
      'loginButton': 'Login',
    },
    'tr': {
      'loginTitle': 'Giriş Yap',
      'emailLabel': 'E-posta',
      'passwordLabel': 'Şifre',
      'facebookLogin': 'Facebook ile devam et',
      'googleLogin': 'Google ile devam et',
      'onboardTitle1': 'Biyolinkini hazırla ve paylaş',
      'onboardDesc1':
          'Tüm sosyal linklerini tek biyolinkte topla, QR ile paylaş ve her yerde görün.',
      'onboardTitle2': 'Randevu + SMS ile takip et',
      'onboardDesc2':
          'Randevu al, otomatik SMS gönder; takvimini ve bildirimleri tek ekrandan yönet.',
      'onboardTitle3': 'Biyolink ücretsiz başlar',
      'onboardDesc3':
          'Ücretsiz başla, biyolinkini anında yayınla; ihtiyaç oldukça paketleri aç.',
      'menuTitle': 'Menü',
      'myLinks': 'Linklerim',
      'themes': 'Temalar',
      'profile': 'Profil',
      'support': 'Destek',
      'exit': 'Çıkış',
      'loginButton': 'Giriş',
    },
  };

  String _text(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['tr']![key] ?? key;
  }

  String get loginTitle => _text('loginTitle');
  String get emailLabel => _text('emailLabel');
  String get passwordLabel => _text('passwordLabel');
  String get facebookLogin => _text('facebookLogin');
  String get googleLogin => _text('googleLogin');
  String get onboardTitle1 => _text('onboardTitle1');
  String get onboardDesc1 => _text('onboardDesc1');
  String get onboardTitle2 => _text('onboardTitle2');
  String get onboardDesc2 => _text('onboardDesc2');
  String get onboardTitle3 => _text('onboardTitle3');
  String get onboardDesc3 => _text('onboardDesc3');
  String get menuTitle => _text('menuTitle');
  String get profile => _text('profile');
  String get myLinks => _text('myLinks');
  String get themes => _text('themes');
  String get support => _text('support');
  String get exit => _text('exit');
  String get loginButton => _text('loginButton');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'tr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
