import 'dart:io';

import 'package:dingdong/core/widgets/desktop_dialog.dart';
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
    final bool isDark = base.brightness == Brightness.dark;
    final ColorScheme colors = base.colorScheme.copyWith(
      primary: isDark ? const Color(0xFF8CB9CF) : const Color(0xFF2F6F8F),
      onPrimary: isDark ? const Color(0xFF10242D) : Colors.white,
      surface: isDark ? const Color(0xFF191919) : Colors.white,
      surfaceDim: isDark ? const Color(0xFF191919) : const Color(0xFFF7F7F5),
      surfaceBright: isDark ? const Color(0xFF252525) : Colors.white,
      surfaceContainerLowest: isDark
          ? const Color(0xFF202020)
          : const Color(0xFFF7F7F5),
      surfaceContainerLow: isDark
          ? const Color(0xFF242424)
          : const Color(0xFFF4F4F2),
      surfaceContainer: isDark
          ? const Color(0xFF292929)
          : const Color(0xFFF1F1EF),
      surfaceContainerHigh: isDark
          ? const Color(0xFF303030)
          : const Color(0xFFEDEDEB),
      surfaceContainerHighest: isDark
          ? const Color(0xFF373737)
          : const Color(0xFFE6E6E3),
      onSurface: isDark ? const Color(0xFFE8E8E6) : const Color(0xFF37352F),
      onSurfaceVariant: isDark
          ? const Color(0xFFA9A9A5)
          : const Color(0xFF787774),
      outline: isDark ? const Color(0xFF565656) : const Color(0xFFD0D0CC),
      outlineVariant: isDark
          ? const Color(0xFF343434)
          : const Color(0xFFE9E9E7),
      secondaryContainer: isDark
          ? const Color(0xFF303030)
          : const Color(0xFFEDEDEB),
      onSecondaryContainer: isDark
          ? const Color(0xFFE8E8E6)
          : const Color(0xFF37352F),
      surfaceTint: Colors.transparent,
    );
    final TextTheme text = base.textTheme;
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(5),
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      dividerColor: colors.outlineVariant,
      dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 1),
      hoverColor: colors.onSurface.withValues(alpha: 0.045),
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontSize: 22),
        titleLarge: text.titleLarge?.copyWith(fontSize: 17),
        titleMedium: text.titleMedium?.copyWith(fontSize: 14),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 13),
        bodySmall: text.bodySmall?.copyWith(fontSize: 11),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: colors.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.35),
        ),
        hintStyle: text.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          side: BorderSide(color: colors.outline),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(32),
          maximumSize: const Size.square(34),
          padding: const EdgeInsets.all(6),
          shape: controlShape,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide.none,
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surfaceContainerHigh;
        }),
        checkColor: WidgetStatePropertyAll<Color>(colors.onPrimary),
      ),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      dialogTheme: DesktopDialogStyle.theme(colors, text),
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
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 1.25),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
      ),
      dialogTheme: DesktopDialogStyle.theme(
        colors,
        ThemeData(brightness: brightness).textTheme,
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
