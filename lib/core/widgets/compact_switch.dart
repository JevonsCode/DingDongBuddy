import 'package:flutter/material.dart';

/// A restrained desktop switch with a fixed 36×20 footprint and no ink splash.
class CompactSwitch extends StatelessWidget {
  const CompactSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = onChanged != null;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 36,
          height: 20,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value ? colors.primary : colors.outline,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: value ? colors.onPrimary : colors.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 12),
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
    return GestureDetector(
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
    );
  }
}
