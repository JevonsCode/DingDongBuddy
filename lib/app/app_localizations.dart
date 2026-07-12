import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Minimal strongly-scoped localization service for DingDong-owned copy.
final class DingDongLocalizations {
  const DingDongLocalizations(this.locale);

  final Locale locale;

  bool get isChinese => locale.languageCode.toLowerCase() == 'zh';

  String text(String english, String chinese) => isChinese ? chinese : english;

  static DingDongLocalizations of(BuildContext context) {
    return Localizations.of<DingDongLocalizations>(
          context,
          DingDongLocalizations,
        ) ??
        DingDongLocalizations(
          Localizations.maybeLocaleOf(context) ?? const Locale('en'),
        );
  }

  static const LocalizationsDelegate<DingDongLocalizations> delegate =
      _DingDongLocalizationsDelegate();
}

final class _DingDongLocalizationsDelegate
    extends LocalizationsDelegate<DingDongLocalizations> {
  const _DingDongLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>{'en', 'zh'}.contains(locale.languageCode);

  @override
  Future<DingDongLocalizations> load(Locale locale) {
    return SynchronousFuture<DingDongLocalizations>(
      DingDongLocalizations(locale),
    );
  }

  @override
  bool shouldReload(_DingDongLocalizationsDelegate old) => false;
}

extension DingDongLocalizedBuildContext on BuildContext {
  String localized(String english, String chinese) =>
      DingDongLocalizations.of(this).text(english, chinese);
}
