import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:flutter/material.dart';

/// Shared row selection action for resource and clipboard lists.
class DesktopSelectionButton extends StatelessWidget {
  const DesktopSelectionButton({
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DesktopIconButton(
    tooltip: selected
        ? context.l10n.removeFromSelection
        : context.l10n.selectItem2,
    selected: selected,
    size: 32,
    onPressed: onPressed,
    icon: SelectionMark(selected: selected),
  );
}
