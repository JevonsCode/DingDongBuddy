import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';

/// Import metadata collected before opening the native directory chooser.
final class LibraryImportOptions {
  const LibraryImportOptions({required this.type});

  final ResourceType type;
}

/// Focused import dialog that keeps the native directory chooser uncluttered.
final class LibraryImportDialog extends StatefulWidget {
  const LibraryImportDialog({super.key});

  @override
  State<LibraryImportDialog> createState() => _LibraryImportDialogState();
}

final class _LibraryImportDialogState extends State<LibraryImportDialog> {
  ResourceType _type = ResourceType.skill;

  @override
  Widget build(BuildContext context) {
    return DesktopAlertDialog(
      maxWidth: 520,
      title: const Text('Import a resource folder'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'DingDong scans only the selected folder’s direct children and previews the result through the library.',
            ),
            const SizedBox(height: 18),
            DesktopSelectField<ResourceType>(
              key: const Key('library-import-type'),
              value: _type,
              items: ResourceType.values
                  .where(
                    (ResourceType type) => type.isConfigurableAgentResource,
                  )
                  .map(
                    (ResourceType type) => DesktopSelectItem<ResourceType>(
                      value: type,
                      label: type.defaultGroup,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ResourceType value) => setState(() => _type = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('library-import-choose-folder'),
          onPressed: () =>
              Navigator.pop(context, LibraryImportOptions(type: _type)),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Choose folder'),
        ),
      ],
    );
  }
}
