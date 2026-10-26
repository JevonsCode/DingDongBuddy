import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';

/// An anchored multi-select matching the shared desktop single-select field.
class DesktopMultiSelectField<T> extends StatelessWidget {
  const DesktopMultiSelectField({
    required this.items,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final List<DesktopSelectItem<T>> items;
  final Set<T>? selected;
  final String label;
  final ValueChanged<Set<T>?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget option(String text, bool checked, VoidCallback action) => Semantics(
      checked: checked,
      child: MenuItemButton(
        closeOnActivate: false,
        onPressed: enabled ? action : null,
        leadingIcon: Icon(
          checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
          size: 17,
          color: checked ? colors.primary : colors.onSurfaceVariant,
        ),
        style: MenuItemButton.styleFrom(minimumSize: const Size(180, 34)),
        child: Text(text),
      ),
    );
    final selectionLabel = selected == null
        ? label
        : '$label · ${selected!.length}';
    return MenuAnchor(
      alignmentOffset: const Offset(0, 5),
      menuChildren: [
        option(context.l10n.all, selected == null, () => onChanged(null)),
        if (items.isNotEmpty) const Divider(height: 1),
        for (final item in items)
          option(
            item.label,
            selected == null || selected!.contains(item.value),
            () {
              final next = {
                ...?selected,
                if (selected == null) ...items.map((e) => e.value),
              };
              if (next.contains(item.value)) {
                next.remove(item.value);
              } else {
                next.add(item.value);
              }
              onChanged(next.length == items.length ? null : next);
            },
          ),
      ],
      builder: (context, controller, _) => DesktopActionButton(
        height: 38,
        semanticLabel: selectionLabel,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        style: DesktopActionButton.styleFrom(
          backgroundColor: colors.surfaceContainerLow,
          foregroundColor: colors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectionLabel,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              controller.isOpen ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
