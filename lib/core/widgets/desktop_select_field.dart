import 'package:dingdong/core/widgets/desktop_action_button.dart';
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
    this.semanticLabel,
    this.displayLabel,
    this.menuWidth,
    this.highlighted = false,
    super.key,
  });

  final T value;
  final List<DesktopSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final String? semanticLabel;
  final String? displayLabel;
  final double? menuWidth;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double? menuWidth = this.menuWidth;
    const menuPadding = 4.0;
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
        crossAxisUnconstrained: menuWidth == null,
        style: menuWidth == null
            ? null
            : MenuStyle(
                alignment: AlignmentDirectional.bottomStart,
                minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                maximumSize: WidgetStatePropertyAll(Size(menuWidth, 324)),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.all(menuPadding),
                ),
                backgroundColor: WidgetStatePropertyAll(colors.surface),
                surfaceTintColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
                elevation: const WidgetStatePropertyAll(3),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
        menuChildren: items
            .map(
              (DesktopSelectItem<T> item) => MenuItemButton(
                onPressed: enabled ? () => onChanged(item.value) : null,
                leadingIcon: item.icon,
                trailingIcon: item.value == value
                    ? Icon(Icons.check_rounded, size: 16, color: colors.primary)
                    : const SizedBox(width: 16),
                style: MenuItemButton.styleFrom(
                  minimumSize: menuWidth == null
                      ? const Size(180, 34)
                      : Size(menuWidth - 2 * menuPadding, 32),
                  visualDensity: menuWidth == null
                      ? null
                      : VisualDensity.standard,
                  backgroundColor: menuWidth != null && item.value == value
                      ? colors.primary.withValues(alpha: 0.09)
                      : null,
                  foregroundColor: menuWidth != null && item.value == value
                      ? colors.primary
                      : null,
                  textStyle: menuWidth == null
                      ? null
                      : theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: item.value == value
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
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
              return Semantics(
                button: true,
                enabled: enabled,
                expanded: controller.isOpen,
                label: semanticLabel,
                value: selected.label,
                child: ExcludeSemantics(
                  child: DesktopActionButton(
                    onPressed: enabled
                        ? () => controller.isOpen
                              ? controller.close()
                              : controller.open()
                        : null,
                    height: 38,
                    style:
                        DesktopActionButton.styleFrom(
                          foregroundColor: enabled
                              ? (highlighted
                                    ? colors.primary
                                    : colors.onSurface)
                              : colors.onSurfaceVariant,
                          backgroundColor: enabled
                              ? (highlighted
                                    ? colors.primary.withValues(alpha: 0.09)
                                    : colors.surfaceContainerLow)
                              : colors.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ).copyWith(
                          side: highlighted && enabled
                              ? WidgetStateProperty.resolveWith((states) {
                                  final focused = states.contains(
                                    WidgetState.focused,
                                  );
                                  return BorderSide(
                                    color: focused
                                        ? colors.primary
                                        : colors.primary.withValues(
                                            alpha: 0.35,
                                          ),
                                    width: focused ? 1.5 : 1,
                                  );
                                })
                              : null,
                        ),
                    child: Row(
                      children: <Widget>[
                        if (selected.icon != null) ...<Widget>[
                          selected.icon!,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            displayLabel ?? selected.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
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
                ),
              );
            },
      ),
    );
  }
}
