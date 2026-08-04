import 'package:flutter/material.dart';

/// Visual emphasis used by DingDong's compact desktop action buttons.
enum DesktopActionTone { primary, soft, neutral, danger }

/// A compact, rectangular desktop button with no Material splash or halo.
///
/// Keeping the treatment here prevents secondary windows and feature surfaces
/// from falling back to Material's pill-shaped defaults.
class DesktopActionButton extends StatelessWidget {
  const DesktopActionButton({
    required this.onPressed,
    this.label,
    this.child,
    this.icon,
    this.tone = DesktopActionTone.neutral,
    this.compact = false,
    this.minWidth = 0,
    this.height,
    this.style,
    this.filled,
    Key? key,
  }) : _buttonKey = key,
       assert(label != null || child != null),
       super(key: null);

  final Key? _buttonKey;

  final Object? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final Object? icon;
  final DesktopActionTone tone;
  final bool compact;
  final double minWidth;
  final double? height;
  final ButtonStyle? style;
  final bool? filled;

  /// Style helper for custom flat selector rows that still use the shared
  /// button surface and no-halo interaction contract.
  static ButtonStyle styleFrom({
    Size? minimumSize,
    Color? foregroundColor,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    BorderSide? side,
    OutlinedBorder? shape,
  }) {
    return ButtonStyle(
      minimumSize: minimumSize == null
          ? null
          : WidgetStatePropertyAll<Size>(minimumSize),
      foregroundColor: foregroundColor == null
          ? null
          : WidgetStatePropertyAll<Color>(foregroundColor),
      backgroundColor: backgroundColor == null
          ? null
          : WidgetStatePropertyAll<Color>(backgroundColor),
      padding: padding == null
          ? null
          : WidgetStatePropertyAll<EdgeInsetsGeometry>(padding),
      side: side == null ? null : WidgetStatePropertyAll<BorderSide>(side),
      shape: shape == null
          ? null
          : WidgetStatePropertyAll<OutlinedBorder>(shape),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _DesktopActionPalette palette = _palette(colors, tone);
    final bool enabled = onPressed != null;
    final ButtonStyle baseStyle = ButtonStyle(
      animationDuration: Duration.zero,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      elevation: const WidgetStatePropertyAll<double>(0),
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(minWidth, height ?? (compact ? 32 : 36)),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(
          color: enabled
              ? palette.border
              : palette.border.withValues(alpha: 0.4),
        ),
      ),
      foregroundColor: WidgetStatePropertyAll<Color>(
        enabled ? palette.foreground : palette.disabledForeground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (!enabled) return palette.disabledBackground;
        if (states.contains(WidgetState.pressed)) return palette.pressed;
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return palette.hovered;
        }
        return palette.background;
      }),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1),
      ),
      mouseCursor: WidgetStatePropertyAll<MouseCursor>(
        enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      ),
    );
    final Widget labelWidget = switch (label) {
      final String value => Text(value),
      final Widget value => value,
      _ => const SizedBox.shrink(),
    };
    final Widget buttonChild = child == null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                switch (icon) {
                  final IconData value => Icon(value, size: compact ? 14 : 15),
                  final Widget value => IconTheme.merge(
                    data: IconThemeData(size: compact ? 14 : 15),
                    child: value,
                  ),
                  _ => const SizedBox.shrink(),
                },
                const SizedBox(width: 6),
              ],
              labelWidget,
            ],
          )
        : icon == null
        ? child!
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              switch (icon) {
                final IconData value => Icon(value, size: compact ? 14 : 15),
                final Widget value => IconTheme.merge(
                  data: IconThemeData(size: compact ? 14 : 15),
                  child: value,
                ),
                _ => const SizedBox.shrink(),
              },
              const SizedBox(width: 6),
              child!,
            ],
          );
    // ButtonStyle.merge keeps the receiver's non-null values. The caller's
    // style must therefore be the receiver, otherwise custom tab/selector
    // surfaces silently lose their foreground, background, border and size.
    final ButtonStyle resolvedStyle = style?.merge(baseStyle) ?? baseStyle;
    final bool useFilled =
        filled ??
        (tone == DesktopActionTone.primary || tone == DesktopActionTone.danger);
    return useFilled
        ? FilledButton(
            key: _buttonKey,
            onPressed: onPressed,
            style: resolvedStyle,
            child: buttonChild,
          )
        : OutlinedButton(
            key: _buttonKey,
            onPressed: onPressed,
            style: resolvedStyle,
            child: buttonChild,
          );
  }
}

_DesktopActionPalette _palette(ColorScheme colors, DesktopActionTone tone) {
  final Color disabledForeground = colors.onSurfaceVariant.withValues(
    alpha: 0.42,
  );
  final Color disabledBackground = colors.surfaceContainerHigh.withValues(
    alpha: 0.5,
  );
  return switch (tone) {
    DesktopActionTone.primary => _DesktopActionPalette(
      foreground: colors.onPrimary,
      background: colors.primary,
      hovered: Color.alphaBlend(
        colors.onPrimary.withValues(alpha: 0.08),
        colors.primary,
      ),
      pressed: Color.alphaBlend(
        colors.onPrimary.withValues(alpha: 0.14),
        colors.primary,
      ),
      border: colors.primary,
      disabledForeground: disabledForeground,
      disabledBackground: disabledBackground,
    ),
    DesktopActionTone.soft => _DesktopActionPalette(
      foreground: colors.primary,
      background: colors.primary.withValues(alpha: 0.1),
      hovered: colors.primary.withValues(alpha: 0.15),
      pressed: colors.primary.withValues(alpha: 0.2),
      border: colors.primary.withValues(alpha: 0.24),
      disabledForeground: disabledForeground,
      disabledBackground: disabledBackground,
    ),
    DesktopActionTone.neutral => _DesktopActionPalette(
      foreground: colors.onSurfaceVariant,
      background: colors.surfaceContainerLow,
      hovered: colors.surfaceContainerHigh,
      pressed: colors.surfaceContainerHighest,
      border: colors.outlineVariant,
      disabledForeground: disabledForeground,
      disabledBackground: disabledBackground,
    ),
    DesktopActionTone.danger => _DesktopActionPalette(
      foreground: colors.onError,
      background: colors.error,
      hovered: Color.alphaBlend(
        colors.onError.withValues(alpha: 0.08),
        colors.error,
      ),
      pressed: Color.alphaBlend(
        colors.onError.withValues(alpha: 0.14),
        colors.error,
      ),
      border: colors.error,
      disabledForeground: disabledForeground,
      disabledBackground: disabledBackground,
    ),
  };
}

final class _DesktopActionPalette {
  const _DesktopActionPalette({
    required this.foreground,
    required this.background,
    required this.hovered,
    required this.pressed,
    required this.border,
    required this.disabledForeground,
    required this.disabledBackground,
  });

  final Color foreground;
  final Color background;
  final Color hovered;
  final Color pressed;
  final Color border;
  final Color disabledForeground;
  final Color disabledBackground;
}
