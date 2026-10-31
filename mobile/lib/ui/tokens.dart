import 'package:flutter/material.dart';

/// Design tokens copied from the PWA (docs/app/styles.css `:root`) so the
/// native companion and the web app read as one product. The PWA has no dark
/// theme; the dark palette keeps the same hue relationships.
@immutable
class DingTokens extends ThemeExtension<DingTokens> {
  const DingTokens({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.field,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.success,
    required this.successSoft,
    required this.attention,
    required this.attentionSoft,
    required this.attentionText,
    required this.unseenBorder,
    required this.danger,
    required this.offlineDot,
    required this.shadow,
  });

  static const DingTokens light = DingTokens(
    background: Color(0xFFF4F3EF),
    surface: Color(0xFFFFFEFC),
    surfaceSoft: Color(0xFFF8F7F4),
    field: Color(0xFFF0EFEC),
    border: Color(0xFFDEDDD8),
    text: Color(0xFF222629),
    textSecondary: Color(0xFF73797D),
    accent: Color(0xFF2B5877),
    accentSoft: Color(0xFFE7F0F5),
    accentBorder: Color(0x3D2B5877),
    success: Color(0xFF238558),
    successSoft: Color(0xFFEFF8F3),
    attention: Color(0xFF9B5D26),
    attentionSoft: Color(0xFFFFF4E8),
    attentionText: Color(0xFF6F421B),
    unseenBorder: Color(0x57F7973E),
    danger: Color(0xFFB54845),
    offlineDot: Color(0xFFAFB4B6),
    shadow: Color(0x1A1F262B),
  );

  static const DingTokens dark = DingTokens(
    background: Color(0xFF15181B),
    surface: Color(0xFF1D2125),
    surfaceSoft: Color(0xFF23282C),
    field: Color(0xFF2A3035),
    border: Color(0xFF353C42),
    text: Color(0xFFE8EAEB),
    textSecondary: Color(0xFF9AA2A7),
    accent: Color(0xFF7FB0D0),
    accentSoft: Color(0xFF1F3442),
    accentBorder: Color(0x527FB0D0),
    success: Color(0xFF4CC28C),
    successSoft: Color(0xFF1A2C24),
    attention: Color(0xFFE0A066),
    attentionSoft: Color(0xFF33261A),
    attentionText: Color(0xFFF0C394),
    unseenBorder: Color(0x66F7973E),
    danger: Color(0xFFE0716D),
    offlineDot: Color(0xFF6B7378),
    shadow: Color(0x66000000),
  );

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color field;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color accent;
  final Color accentSoft;
  final Color accentBorder;
  final Color success;
  final Color successSoft;
  final Color attention;
  final Color attentionSoft;
  final Color attentionText;
  final Color unseenBorder;
  final Color danger;
  final Color offlineDot;
  final Color shadow;

  /// Text on accent-filled buttons: white on the light accent, near-black on
  /// the lighter dark-mode accent so contrast stays above 4.5:1.
  Color get onAccent =>
      accent.computeLuminance() > 0.35 ? const Color(0xFF10181E) : Colors.white;

  static DingTokens of(BuildContext context) =>
      Theme.of(context).extension<DingTokens>()!;

  @override
  DingTokens copyWith() => this;

  @override
  DingTokens lerp(DingTokens? other, double t) =>
      t < 0.5 ? this : other ?? this;
}

/// Radii from styles.css.
abstract final class DingRadius {
  static const double button = 10;
  static const double input = 11;
  static const double banner = 12;
  static const double card = 13;
  static const double mascot = 13;
  static const double sheet = 17;
  static const double tab = 9;
}

ThemeData dingTheme(Brightness brightness) {
  final DingTokens tokens = brightness == Brightness.dark
      ? DingTokens.dark
      : DingTokens.light;
  final ThemeData base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.accent,
      brightness: brightness,
      primary: tokens.accent,
      surface: tokens.surface,
    ),
    scaffoldBackgroundColor: tokens.surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[tokens],
    textTheme: base.textTheme.apply(
      bodyColor: tokens.text,
      displayColor: tokens.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.accent,
      selectionColor: tokens.accent.withValues(alpha: 0.25),
      selectionHandleColor: tokens.accent,
    ),
  );
}
