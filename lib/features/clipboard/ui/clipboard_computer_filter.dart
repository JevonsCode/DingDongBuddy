import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

class ClipboardComputerFilter extends StatelessWidget {
  const ClipboardComputerFilter({required this.viewModel, super.key});

  final ClipboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.clipboardSourceComputer;
    final selected = viewModel.selectedComputerId;
    const computer = Icon(Icons.computer_rounded, size: 16);
    const width = 196.0;
    return SizedBox(
      width: width,
      height: 32,
      child: DesktopSelectField<String?>(
        key: const Key('clipboard-computer-filter'),
        value: selected,
        semanticLabel: label,
        menuWidth: width,
        highlighted: selected != null,
        displayLabel: selected == null ? label : null,
        items: [
          DesktopSelectItem(
            value: null,
            label: context.l10n.allSources,
            icon: const Icon(Icons.devices_outlined, size: 16),
          ),
          for (final option in viewModel.computerSourceOptions)
            DesktopSelectItem(
              value: option.id,
              label: option.label,
              icon: computer,
            ),
        ],
        onChanged: viewModel.setComputerSource,
      ),
    );
  }
}
