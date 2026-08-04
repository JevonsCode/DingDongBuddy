import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flat, rectangular choice chip for filters and compact selectors.
///
/// Unlike [FilterChip], this component has no pill, elevation, Material ink
/// halo, or selection animation. The stable surface keeps dense filter rows
/// from flashing when their selected state changes.
class DesktopChoiceChip extends StatefulWidget {
  const DesktopChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.leading,
    this.enabled = true,
    this.foregroundColor,
    this.selectedForegroundColor,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.borderColor,
    this.selectedBorderColor,
    this.height = 30,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.borderRadius = 8,
    this.textStyle,
    super.key,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Widget? leading;
  final bool enabled;
  final Color? foregroundColor;
  final Color? selectedForegroundColor;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final Color? borderColor;
  final Color? selectedBorderColor;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final TextStyle? textStyle;

  @override
  State<DesktopChoiceChip> createState() => _DesktopChoiceChipState();
}

class _DesktopChoiceChipState extends State<DesktopChoiceChip> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() {
    if (widget.enabled) widget.onSelected(!widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool active = widget.enabled && widget.selected;
    final Color foreground = active
        ? widget.selectedForegroundColor ?? colors.primary
        : widget.foregroundColor ?? colors.onSurfaceVariant;
    final Color baseFill = active
        ? widget.selectedBackgroundColor ??
              colors.primary.withValues(alpha: 0.1)
        : widget.backgroundColor ?? Colors.transparent;
    final Color fill = !active && (_hovered || _focused)
        ? Color.alphaBlend(colors.onSurface.withValues(alpha: 0.04), baseFill)
        : baseFill;
    final Color baseBorder = active
        ? widget.selectedBorderColor ?? colors.primary.withValues(alpha: 0.36)
        : widget.borderColor ?? colors.outlineVariant;
    final Color border = _focused
        ? colors.primary.withValues(alpha: 0.52)
        : baseBorder;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: widget.enabled,
      onTap: widget.enabled ? _activate : null,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          enabled: widget.enabled,
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _activate : null,
            child: Container(
              height: widget.height,
              padding: widget.padding,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (widget.leading != null) ...<Widget>[
                    IconTheme.merge(
                      data: IconThemeData(color: foreground, size: 14),
                      child: widget.leading!,
                    ),
                    const SizedBox(width: 5),
                  ],
                  DefaultTextStyle.merge(
                    style:
                        (widget.textStyle ??
                                Theme.of(context).textTheme.labelMedium)
                            ?.copyWith(
                              color: widget.enabled
                                  ? foreground
                                  : colors.onSurfaceVariant.withValues(
                                      alpha: 0.42,
                                    ),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                    child: widget.label,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
