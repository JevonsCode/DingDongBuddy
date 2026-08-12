import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A restrained desktop switch with a fixed 36×20 footprint and no ink splash.
class CompactSwitch extends StatefulWidget {
  const CompactSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<CompactSwitch> createState() => _CompactSwitchState();
}

class _CompactSwitchState extends State<CompactSwitch> {
  bool _hovered = false;
  bool _focused = false;

  void _toggle() {
    if (widget.onChanged != null) widget.onChanged!(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = widget.onChanged != null;
    return Semantics(
      button: false,
      enabled: enabled,
      toggled: widget.value,
      onTap: enabled ? _toggle : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          enabled: enabled,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggle : null,
            child: SizedBox(
              width: 36,
              height: 20,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.value
                      ? colors.primary
                      : _hovered || _focused
                      ? colors.surfaceContainerHighest
                      : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    width: _focused ? 1.5 : 1,
                    color: _focused
                        ? colors.primary
                        : widget.value
                        ? colors.primary
                        : colors.outline,
                  ),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  alignment: widget.value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.value
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text-and-control row matching desktop settings and editor layouts.
class CompactSwitchListTile extends StatelessWidget {
  const CompactSwitchListTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.contentPadding = EdgeInsets.zero,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: contentPadding.add(const EdgeInsets.symmetric(vertical: 9)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.bodyMedium,
                      child: title,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CompactSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
