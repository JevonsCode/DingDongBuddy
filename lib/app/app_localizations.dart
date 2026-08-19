import 'package:dingdong/l10n/generated/dingdong_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:dingdong/l10n/generated/dingdong_localizations.dart';

/// Typed access to DingDong-owned copy generated from the ARB catalogs.
extension DingDongLocalizedBuildContext on BuildContext {
  DingDongLocalizations get l10n {
    final DingDongLocalizations? strings =
        Localizations.of<DingDongLocalizations>(this, DingDongLocalizations);
    if (strings != null) return strings;

    // Component previews and focused widget tests may intentionally omit the
    // application delegate. Keep those isolated surfaces deterministic while
    // production MaterialApps continue to install the generated delegates.
    final Locale requested =
        Localizations.maybeLocaleOf(this) ?? const Locale('en');
    final Locale supported = DingDongLocalizations.supportedLocales.firstWhere(
      (Locale locale) => locale.languageCode == requested.languageCode,
      orElse: () => const Locale('en'),
    );
    return lookupDingDongLocalizations(supported);
  }
}
