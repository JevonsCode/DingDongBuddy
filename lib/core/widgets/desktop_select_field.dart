import 'package:flutter/material.dart';

/// One value displayed by [DesktopSelectField].
final class DesktopSelectItem<T> {
  const DesktopSelectItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final Widget? icon;
}

/// Compact desktop selection field with a restrained anchored menu.
class DesktopSelectField<T> extends StatelessWidget {
  const DesktopSelectField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final T value;
  final List<DesktopSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final DesktopSelectItem<T> selected = items.firstWhere(
      (DesktopSelectItem<T> item) => item.value == value,
      orElse: () => items.first,
    );
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      child: MenuAnchor(
        alignmentOffset: const Offset(0, 5),
        menuChildren: items
            .map(
              (DesktopSelectItem<T> item) => MenuItemButton(
                onPressed: enabled ? () => onChanged(item.value) : null,
                leadingIcon: item.icon,
                trailingIcon: item.value == value
                    ? Icon(Icons.check_rounded, size: 16, color: colors.primary)
                    : const SizedBox(width: 16),
                style: MenuItemButton.styleFrom(
                  minimumSize: const Size(180, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: enabled
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: enabled
                        ? colors.surfaceContainerLow
                        : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: <Widget>[
                      if (selected.icon != null) ...<Widget>[
                        selected.icon!,
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          selected.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: enabled
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        controller.isOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }
}
