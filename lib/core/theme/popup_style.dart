import 'package:flutter/material.dart';

/// Visual tokens carried over from the original DingDong callout surface.
abstract final class PopupStyle {
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
