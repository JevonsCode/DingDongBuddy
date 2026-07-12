import 'dart:io';

import 'package:flutter/material.dart';

/// Restrained desktop theme with compact controls and platform-neutral colors.
final class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    surface: const Color(0xFFF7F7F5),
    seed: const Color(0xFF526A78),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    surface: const Color(0xFF1D2022),
    seed: const Color(0xFF8BA0AB),
  );

  static ThemeData desktopPanelLight() => _desktopPanel(light());

  static ThemeData desktopPanelDark() => _desktopPanel(dark());

  static ThemeData _desktopPanel(ThemeData base) {
    final TextTheme text = base.textTheme;
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 22),
        titleLarge: text.titleLarge?.copyWith(fontSize: 16),
        titleMedium: text.titleMedium?.copyWith(fontSize: 14),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 13),
        bodySmall: text.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color surface,
    required Color seed,
  }) {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return ThemeData(
      brightness: brightness,
      fontFamily: Platform.isMacOS ? '.AppleSystemUIFont' : 'Segoe UI',
      colorScheme: colors,
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: colors.onSurface.withValues(alpha: 0.035),
      scaffoldBackgroundColor: surface,
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        isDense: true,
        border: inputBorder,
        enabledBorder: inputBorder,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        indicatorColor: colors.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        useIndicator: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      switchTheme: const SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
