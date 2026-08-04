import 'package:flutter/material.dart';

/// A compact icon action with a rectangular focus/hover surface.
///
/// This deliberately keeps the system tooltip and keyboard semantics while
/// preventing each feature from inventing a different icon-button footprint.
class DesktopIconButton extends StatelessWidget {
  const DesktopIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.size = 32,
    this.iconSize = 18,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.style,
    this.padding,
    this.constraints,
    this.visualDensity,
    this.tapTargetSize,
    this.alignment = Alignment.center,
    this.focusNode,
    this.autofocus = false,
    this.onLongPress,
    this.mouseCursor,
    this.splashRadius,
    this.isSelected,
    this.selectedIcon,
    this.iconAlignment,
    super.key,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final VisualDensity? visualDensity;
  final MaterialTapTargetSize? tapTargetSize;
  final AlignmentGeometry alignment;
  final FocusNode? focusNode;
  final bool autofocus;
  final VoidCallback? onLongPress;
  final MouseCursor? mouseCursor;
  final double? splashRadius;
  final bool? isSelected;
  final Widget? selectedIcon;
  final IconAlignment? iconAlignment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    final Color foreground =
        foregroundColor ??
        (selected ? colors.primary : colors.onSurfaceVariant);
    final Color background =
        backgroundColor ??
        (selected ? colors.primary.withValues(alpha: 0.1) : Colors.transparent);
    final ButtonStyle defaultStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size.square(size)),
      maximumSize: WidgetStatePropertyAll<Size>(Size.square(size)),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        padding ?? EdgeInsets.zero,
      ),
      tapTargetSize: tapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!),
        ),
      ),
      foregroundColor: WidgetStatePropertyAll<Color>(
        enabled ? foreground : foreground.withValues(alpha: 0.4),
      ),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (!enabled) return background.withValues(alpha: 0.35);
        if (states.contains(WidgetState.pressed)) {
          return colors.primary.withValues(alpha: selected ? 0.18 : 0.1);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colors.surfaceContainerHigh;
        }
        return background;
      }),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      mouseCursor: WidgetStatePropertyAll<MouseCursor>(
        mouseCursor ??
            (enabled ? SystemMouseCursors.click : SystemMouseCursors.basic),
      ),
    );
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      onLongPress: onLongPress,
      iconSize: iconSize,
      padding: padding ?? EdgeInsets.zero,
      constraints:
          constraints ?? BoxConstraints.tightFor(width: size, height: size),
      visualDensity: visualDensity,
      alignment: alignment,
      focusNode: focusNode,
      autofocus: autofocus,
      splashRadius: splashRadius,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      // Keep feature-level geometry/colors authoritative when supplied.
      style: style?.merge(defaultStyle) ?? defaultStyle,
      icon: icon,
    );
  }
}
