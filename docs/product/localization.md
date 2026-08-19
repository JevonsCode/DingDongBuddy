# DingDong localization

DingDong uses Flutter's standard ARB and `gen-l10n` pipeline for application
copy. English is the template and fallback locale. Simplified Chinese and
Spanish ship as complete locale catalogs; future languages should be added to
the same catalog instead of introducing language-condition branches in feature
code.

## Source of truth

- `lib/l10n/app_en.arb` defines every message, placeholder, and developer
  description.
- `lib/l10n/app_zh.arb` and `lib/l10n/app_es.arb` contain locale-specific copy
  with the same keys and placeholder metadata.
- `l10n.yaml` owns generation settings. Generated files live under
  `lib/l10n/generated/` and must not be edited by hand.
- `lib/app/app_locale.dart` resolves saved and system locale preferences and
  provides the deliberate English fallback for headless app services.
- `lib/app/app_localizations.dart` exports the generated API and the
  `context.l10n` convenience accessor.

Run generation after editing an ARB file:

```bash
flutter gen-l10n
dart format lib/l10n/generated
```

Use typed generated getters in Dart UI and controllers. Do not add
`isChinese`, `localized(en, zh)`, maps embedded in widgets, or concatenated
sentences. Dynamic values belong in ARB placeholders. Counts that change the
sentence should use ICU plural/select syntax so new languages can choose their
own grammar.

## Adding a language

1. Add the locale to `AppLanguagePreference` and its label to every ARB file.
2. Copy `app_en.arb` to `app_<locale>.arb`, translate every message, and preserve
   all keys and placeholders exactly.
3. Add the locale to `configuredAppLocale` in `lib/app/app_locale.dart`.
4. Add native macOS `.strings` files under
   `macos/Runner/<locale>.lproj/`, then register the locale and variant groups in
   the Xcode project and `CFBundleLocalizations`.
5. Add localized release notes when the update metadata supports that locale.
6. Run generation, localization contract tests, the full Flutter test suite,
   static analysis, and a native build. Manually inspect the language picker,
   compact popup, secondary windows, native context menus, tray menu,
   notifications, update notes, and macOS permission dialogs.

## Platform-native copy

macOS-owned dialogs and menus use localized `.strings` tables because those
surfaces can exist before Flutter has initialized. They are the only deliberate
second catalog. The localization contract test checks that English, Simplified
Chinese, and Spanish native tables expose identical key sets.

## Quality gates

`test/l10n/localization_contract_test.dart` prevents locale key drift,
placeholder drift, silent Spanish-to-English fallback, and the return of legacy
two-language selectors. Machine-assisted translations are a starting point,
not approval: product terminology, grammar, truncation, accessibility labels,
and tone still require a native-speaker review before a release is considered
fully copyedited.
