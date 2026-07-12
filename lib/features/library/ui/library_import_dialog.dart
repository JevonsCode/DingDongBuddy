import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';

/// Import metadata collected before opening the native directory chooser.
final class LibraryImportOptions {
  const LibraryImportOptions({
    required this.type,
    this.group,
    this.tags = const <String>[],
  });

  final ResourceType type;
  final String? group;
  final List<String> tags;
}

/// Focused import dialog that keeps the native directory chooser uncluttered.
final class LibraryImportDialog extends StatefulWidget {
  const LibraryImportDialog({super.key});

  @override
  State<LibraryImportDialog> createState() => _LibraryImportDialogState();
}

final class _LibraryImportDialogState extends State<LibraryImportDialog> {
  final TextEditingController _group = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  ResourceType _type = ResourceType.knowledge;

  @override
  void dispose() {
    _group.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
                  .where((ResourceType type) => type.isLibraryResource)
                  .map(
                    (ResourceType type) => DesktopSelectItem<ResourceType>(
                      value: type,
                      label: type.defaultGroup,
                    ),
                  )
                  .toList(growable: false),
              onChanged: (ResourceType value) => setState(() => _type = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _group,
              decoration: const InputDecoration(labelText: 'Group (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags (optional)',
                hintText: 'team, release',
              ),
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
          onPressed: () => Navigator.pop(
            context,
            LibraryImportOptions(
              type: _type,
              group: _emptyAsNull(_group.text),
              tags: _tags.text
                  .split(',')
                  .map((String value) => value.trim())
                  .where((String value) => value.isNotEmpty)
                  .toList(growable: false),
            ),
          ),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Choose folder'),
        ),
      ],
    );
  }
}

String? _emptyAsNull(String value) {
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
