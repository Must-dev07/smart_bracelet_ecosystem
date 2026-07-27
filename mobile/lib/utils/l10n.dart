/// Minimal i18n scaffolding (English + French) without codegen, so the map is
/// easy to extend. Access via L10n.of(context).t('key').
import 'package:flutter/material.dart';

class L10n {
  final Locale locale;
  L10n(this.locale);

  static L10n of(BuildContext context) =>
      Localizations.of<L10n>(context, L10n) ?? L10n(const Locale('en'));

  static const delegate = _L10nDelegate();

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app_title': 'Bracelet Monitor',
      'login': 'Sign in',
      'register': 'Create account',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot password?',
      'home': 'Home',
      'live': 'Live',
      'alerts': 'Alerts',
      'history': 'History',
      'graphs': 'Graphs',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'heart_rate': 'Heart rate',
      'temperature': 'Temperature',
      'spo2': 'SpO₂',
      'battery': 'Battery',
      'movement': 'Movement',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'reconnecting': 'Reconnecting…',
      'scanning': 'Scanning…',
      'pair_bracelet': 'Pair a bracelet',
      'acknowledge': 'Acknowledge',
      'dark_mode': 'Dark mode',
      'language': 'Language',
      'logout': 'Sign out',
      'disclaimer_title': 'Important',
    },
    'fr': {
      'app_title': 'Bracelet Monitor',
      'login': 'Se connecter',
      'register': 'Créer un compte',
      'email': 'E-mail',
      'password': 'Mot de passe',
      'forgot_password': 'Mot de passe oublié ?',
      'home': 'Accueil',
      'live': 'Direct',
      'alerts': 'Alertes',
      'history': 'Historique',
      'graphs': 'Graphiques',
      'settings': 'Réglages',
      'notifications': 'Notifications',
      'heart_rate': 'Fréquence cardiaque',
      'temperature': 'Température',
      'spo2': 'SpO₂',
      'battery': 'Batterie',
      'movement': 'Mouvement',
      'connected': 'Connecté',
      'disconnected': 'Déconnecté',
      'reconnecting': 'Reconnexion…',
      'scanning': 'Recherche…',
      'pair_bracelet': 'Associer un bracelet',
      'acknowledge': 'Accuser réception',
      'dark_mode': 'Mode sombre',
      'language': 'Langue',
      'logout': 'Se déconnecter',
      'disclaimer_title': 'Important',
    },
  };

  String t(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);
  @override
  Future<L10n> load(Locale locale) async => L10n(locale);
  @override
  bool shouldReload(_L10nDelegate old) => false;
}
