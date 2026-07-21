import 'package:flutter/material.dart';

/// Shared modal treatment for DingDong's compact desktop surfaces.
abstract final class DesktopDialogStyle {
  static const double radius = 14;
  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 24,
  );

  static RoundedRectangleBorder shape(ColorScheme colors) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: colors.outlineVariant),
    );
  }

  static DialogThemeData theme(ColorScheme colors, TextTheme textTheme) {
    return DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      barrierColor: Colors.black.withValues(alpha: 0.32),
      shape: shape(colors),
      insetPadding: insetPadding,
      clipBehavior: Clip.antiAlias,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colors.onSurface,
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 13,
        height: 1.45,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    );
  }

  static ThemeData scopedTheme(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return theme.copyWith(
      dialogTheme: DesktopDialogStyle.theme(colors, theme.textTheme),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: controlShape,
          side: BorderSide(color: colors.outline),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ButtonStyle destructiveButtonStyle(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: colors.error,
      foregroundColor: colors.onError,
    );
  }
}

/// Compact AlertDialog with disciplined desktop spacing and width.
final class DesktopAlertDialog extends StatelessWidget {
  const DesktopAlertDialog({
    this.title,
    this.content,
    this.actions,
    this.maxWidth = 460,
    this.scrollable = false,
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final DialogThemeData dialogTheme = DesktopDialogStyle.theme(
      colors,
      theme.textTheme,
    );
    final bool hasTitle = title != null;
    final bool hasActions = actions?.isNotEmpty ?? false;
    return DesktopDialogTheme(
      child: AlertDialog(
        title: title,
        content: content,
        actions: actions,
        scrollable: scrollable,
        constraints: BoxConstraints(maxWidth: maxWidth),
        insetPadding: DesktopDialogStyle.insetPadding,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        shape: DesktopDialogStyle.shape(colors),
        clipBehavior: Clip.antiAlias,
        titleTextStyle: dialogTheme.titleTextStyle,
        contentTextStyle: dialogTheme.contentTextStyle,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: EdgeInsets.fromLTRB(
          20,
          hasTitle ? 10 : 18,
          20,
          hasActions ? 4 : 18,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
        buttonPadding: const EdgeInsets.only(left: 6),
        actionsOverflowButtonSpacing: 8,
      ),
    );
  }
}

/// Limits dialog control styling to the modal subtree.
final class DesktopDialogTheme extends StatelessWidget {
  const DesktopDialogTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DesktopDialogStyle.scopedTheme(Theme.of(context)),
      child: child,
    );
  }
}
