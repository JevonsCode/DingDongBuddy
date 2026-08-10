import 'package:flutter/material.dart';

/// Visual tokens carried over from the original DingDong callout surface.
abstract final class PopupStyle {
  /// Legacy light tokens kept for light-only auxiliary surfaces and callers
  /// that have not yet opted into the context-aware palette.
  static const Color background = Color(0xFFF5F5F2);
  static const Color surface = Color(0xFFFFFEFC);
  static const Color surfaceSoft = Color(0xFFF8F7F4);
  static const Color field = Color(0xFFF0EFEC);
  static const Color border = Color(0xFFDCDDDC);
  static const Color textPrimary = Color(0xFF1B242C);
  static const Color textSecondary = Color(0xFF6D7274);
  static const Color textTertiary = Color(0xFFA09F9A);
  static const Color accent = Color(0xFF2B5877);
  static const Color accentSoft = Color(0xFFE7F0F5);
  static const Color success = Color(0xFF739477);

  /// The single canonical MCP hue used by every MCP surface in the app.
  static const Color mcp = Color(0xFF2F7651);
  static const Color development = Color(0xFFD65332);
  static const Color developmentSoft = Color(0xFFFBE9E3);
  static const Color activityUnread = Color(0xFFD88B4A);
  static const Color warmSurface = Color(0xFFFBF7ED);
  static const Color skillSurface = Color(0xFFF2F5FB);
  static const double radius = 16;

  static const PopupPalette light = PopupPalette(
    background: background,
    surface: surface,
    surfaceSoft: surfaceSoft,
    field: field,
    border: border,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    textTertiary: textTertiary,
    accent: accent,
    accentSoft: accentSoft,
    success: success,
    development: development,
    developmentSoft: developmentSoft,
    activityUnread: activityUnread,
    warmSurface: warmSurface,
    warmTagSurface: Color(0xFFF0EBDD),
    warmAccent: Color(0xFFA97822),
    skillSurface: skillSurface,
    skillTagSurface: Color(0xFFE9EBF7),
    skillAccent: Color(0xFF4C63A1),
  );

  static const PopupPalette dark = PopupPalette(
    background: Color(0xFF182126),
    surface: Color(0xFF222D34),
    surfaceSoft: Color(0xFF1E2930),
    field: Color(0xFF2A363E),
    border: Color(0xFF3B4A53),
    textPrimary: Color(0xFFEDF2F4),
    textSecondary: Color(0xFFABB8BE),
    textTertiary: Color(0xFF74848C),
    accent: Color(0xFF7EB5CF),
    accentSoft: Color(0xFF243E4C),
    success: Color(0xFF91B898),
    development: Color(0xFFFF977B),
    developmentSoft: Color(0xFF4A2A24),
    activityUnread: Color(0xFFE3A36C),
    warmSurface: Color(0xFF302B20),
    warmTagSurface: Color(0xFF3A3324),
    warmAccent: Color(0xFFD8A64A),
    skillSurface: Color(0xFF282E3A),
    skillTagSurface: Color(0xFF30384A),
    skillAccent: Color(0xFF91A8E8),
  );

  static PopupPalette of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);

  static PopupPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static Color mcpAccent(Brightness brightness) => brightness == Brightness.dark
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.44), mcp)
      : mcp;

  static Color mcpSurface(Brightness brightness, {double opacity = 0.10}) =>
      mcpAccent(brightness).withValues(alpha: opacity);

  static Color mcpBorder(Brightness brightness) =>
      mcpAccent(brightness).withValues(alpha: 0.22);

  static BoxDecoration card({Color? color, double radius = 10}) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }
}

/// Theme-aware colors for the compact popup shell.
@immutable
final class PopupPalette {
  const PopupPalette({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.field,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.development,
    required this.developmentSoft,
    required this.activityUnread,
    required this.warmSurface,
    required this.warmTagSurface,
    required this.warmAccent,
    required this.skillSurface,
    required this.skillTagSurface,
    required this.skillAccent,
  });

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color field;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color development;
  final Color developmentSoft;
  final Color activityUnread;
  final Color warmSurface;
  final Color warmTagSurface;
  final Color warmAccent;
  final Color skillSurface;
  final Color skillTagSurface;
  final Color skillAccent;

  BoxDecoration card({Color? color, double radius = 10}) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }
}
