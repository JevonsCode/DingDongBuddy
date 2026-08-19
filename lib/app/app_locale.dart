import 'dart:ui' show PlatformDispatcher;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/widgets.dart';

/// Returns the explicit locale selected by the user, or `null` when Flutter
/// should follow the operating system locale.
Locale? configuredAppLocale(AppLanguagePreference preference) =>
    switch (preference) {
      AppLanguagePreference.system => null,
      AppLanguagePreference.english => const Locale('en'),
      AppLanguagePreference.chinese => const Locale('zh'),
      AppLanguagePreference.spanish => const Locale('es'),
    };

/// Resolves a supported locale for code that runs outside a widget tree, such
/// as native tray menus, window titles, and setup prompts.
Locale resolveAppLocale(
  AppLanguagePreference preference, {
  Locale? systemLocale,
}) {
  final Locale? configured = configuredAppLocale(preference);
  if (configured != null) return configured;

  final Locale requested = systemLocale ?? PlatformDispatcher.instance.locale;
  for (final Locale supported in DingDongLocalizations.supportedLocales) {
    if (supported.languageCode == requested.languageCode) return supported;
  }
  return const Locale('en');
}

DingDongLocalizations appLocalizationsFor(
  AppLanguagePreference preference, {
  Locale? systemLocale,
}) => lookupDingDongLocalizations(
  resolveAppLocale(preference, systemLocale: systemLocale),
);
