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
    surface: const Color(0xFF182126),
    seed: const Color(0xFF7EB5CF),
  );

  static ThemeData desktopPanelLight() => _desktopPanel(light());

  static ThemeData desktopPanelDark() => _desktopPanel(dark());

  static ThemeData _desktopPanel(ThemeData base) {
    final bool isDark = base.brightness == Brightness.dark;
    final ColorScheme colors = base.colorScheme.copyWith(
      primary: isDark ? const Color(0xFF8CB9CF) : const Color(0xFF2F6F8F),
      onPrimary: isDark ? const Color(0xFF10242D) : Colors.white,
      surface: isDark ? const Color(0xFF182126) : Colors.white,
      surfaceDim: isDark ? const Color(0xFF182126) : const Color(0xFFF7F7F5),
      surfaceBright: isDark ? const Color(0xFF243038) : Colors.white,
      surfaceContainerLowest: isDark
          ? const Color(0xFF1B252B)
          : const Color(0xFFF7F7F5),
      surfaceContainerLow: isDark
          ? const Color(0xFF202B32)
          : const Color(0xFFF4F4F2),
      surfaceContainer: isDark
          ? const Color(0xFF253139)
          : const Color(0xFFF1F1EF),
      surfaceContainerHigh: isDark
          ? const Color(0xFF2B3942)
          : const Color(0xFFEDEDEB),
      surfaceContainerHighest: isDark
          ? const Color(0xFF32424C)
          : const Color(0xFFE6E6E3),
      onSurface: isDark ? const Color(0xFFEDF2F4) : const Color(0xFF37352F),
      onSurfaceVariant: isDark
          ? const Color(0xFFABB8BE)
          : const Color(0xFF787774),
      outline: isDark ? const Color(0xFF52626B) : const Color(0xFFD0D0CC),
      outlineVariant: isDark
          ? const Color(0xFF34434C)
          : const Color(0xFFE9E9E7),
      secondaryContainer: isDark
          ? const Color(0xFF2B3942)
          : const Color(0xFFEDEDEB),
      onSecondaryContainer: isDark
          ? const Color(0xFFEDF2F4)
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
      hoverColor: Colors.transparent,
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          shape: controlShape,
          textStyle: text.labelLarge?.copyWith(fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
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
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final TextTheme baseText = ThemeData(brightness: brightness).textTheme;
    return ThemeData(
      brightness: brightness,
      fontFamily: Platform.isMacOS ? '.AppleSystemUIFont' : 'Segoe UI',
      colorScheme: colors,
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
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
      dialogTheme: DesktopDialogStyle.theme(colors, baseText),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: controlShape,
          textStyle: baseText.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: controlShape,
          textStyle: baseText.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          side: BorderSide(color: colors.outlineVariant),
          shape: controlShape,
          textStyle: baseText.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
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
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(32),
          maximumSize: const Size.square(36),
          padding: const EdgeInsets.all(7),
          shape: controlShape,
          splashFactory: NoSplash.splashFactory,
          overlayColor: Colors.transparent,
        ),
      ),
      sliderTheme: SliderThemeData(
        overlayShape: SliderComponentShape.noOverlay,
        trackHeight: 3,
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.surfaceContainerHighest,
        thumbColor: colors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: baseText.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: BorderSide(color: colors.outlineVariant),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 5),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: baseText.labelSmall?.copyWith(
          color: colors.onInverseSurface,
          fontSize: 11,
        ),
      ),
      checkboxTheme: const CheckboxThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      radioTheme: const RadioThemeData(
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      switchTheme: const SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
    );
  }
}
