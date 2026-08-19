import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit language preferences resolve through one locale registry', () {
    expect(configuredAppLocale(AppLanguagePreference.system), isNull);
    expect(
      configuredAppLocale(AppLanguagePreference.english),
      const Locale('en'),
    );
    expect(
      configuredAppLocale(AppLanguagePreference.chinese),
      const Locale('zh'),
    );
    expect(
      configuredAppLocale(AppLanguagePreference.spanish),
      const Locale('es'),
    );
  });

  test('system language uses supported locales and falls back to English', () {
    expect(
      resolveAppLocale(
        AppLanguagePreference.system,
        systemLocale: const Locale('es', 'MX'),
      ),
      const Locale('es'),
    );
    expect(
      resolveAppLocale(
        AppLanguagePreference.system,
        systemLocale: const Locale('fr'),
      ),
      const Locale('en'),
    );
  });

  test('headless surfaces receive the same generated translations', () {
    final strings = appLocalizationsFor(AppLanguagePreference.spanish);

    expect(strings.languageSpanish, 'Español');
    expect(
      strings.connectDingDongToCurrentAgent('/tmp/dingdong_mcp'),
      allOf(contains('Conecta'), contains('/tmp/dingdong_mcp')),
    );
    expect(strings.dingDongUnreadCount(3), 'DingDong · 3 sin leer');
  });
}
