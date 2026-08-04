import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopSegment<T> {
  const DesktopSegment({required this.value, required this.label});

  final T value;
  final Widget label;
}

/// Restrained segmented choice with a stable, ink-free desktop surface.
///
/// Selection changes are intentionally not animated. This prevents the brief
/// Material ink/transition flash that is especially noticeable when changing
/// appearance settings such as the theme.
class DesktopSegmentedControl<T> extends StatelessWidget {
  const DesktopSegmentedControl({
    required this.value,
    required this.segments,
    required this.onChanged,
    this.minimumSegmentWidth = 40,
    super.key,
  });

  final T value;
  final List<DesktopSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final double minimumSegmentWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments
            .map(
              (DesktopSegment<T> segment) => _DesktopSegmentButton<T>(
                selected: segment.value == value,
                minimumWidth: minimumSegmentWidth,
                onPressed: () {
                  if (segment.value != value) onChanged(segment.value);
                },
                child: segment.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DesktopSegmentButton<T> extends StatefulWidget {
  const _DesktopSegmentButton({
    required this.selected,
    required this.minimumWidth,
    required this.onPressed,
    required this.child,
  });

  final bool selected;
  final double minimumWidth;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_DesktopSegmentButton<T>> createState() =>
      _DesktopSegmentButtonState<T>();
}

class _DesktopSegmentButtonState<T> extends State<_DesktopSegmentButton<T>> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() {
    if (!widget.selected) widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color background = widget.selected
        ? colors.surfaceContainerLowest
        : _hovered || _focused
        ? colors.onSurface.withValues(alpha: 0.045)
        : Colors.transparent;
    final Color border = widget.selected
        ? colors.outlineVariant
        : _focused
        ? colors.primary.withValues(alpha: 0.46)
        : Colors.transparent;
    return Semantics(
      button: true,
      selected: widget.selected,
      onTap: _activate,
      child: MouseRegion(
        cursor: widget.selected
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          mouseCursor: widget.selected
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
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
            onTap: _activate,
            child: Container(
              constraints: BoxConstraints(minWidth: widget.minimumWidth),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border),
              ),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.labelMedium?.copyWith(
                  color: widget.selected
                      ? colors.onSurface
                      : colors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
