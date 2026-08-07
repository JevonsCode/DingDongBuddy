import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:flutter/material.dart';

/// User input collected before fetching a remote library bundle.
final class LibraryLinkImportOptions {
  const LibraryLinkImportOptions({required this.url});

  final String url;
}

/// Compact link-entry dialog for shared JSON bundles.
final class LibraryLinkImportDialog extends StatefulWidget {
  const LibraryLinkImportDialog({super.key});

  @override
  State<LibraryLinkImportDialog> createState() =>
      _LibraryLinkImportDialogState();
}

final class _LibraryLinkImportDialogState
    extends State<LibraryLinkImportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String url = _controller.text.trim();
    if (url.isEmpty) {
      return;
    }
    Navigator.pop(context, LibraryLinkImportOptions(url: url));
  }

  @override
  Widget build(BuildContext context) {
    final String url = _controller.text.trim();
    return DesktopAlertDialog(
      maxWidth: 620,
      title: Text(context.localized('Import from link', '从链接导入')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.localized(
                'Paste a JSON bundle link. DingDong will fetch it, resolve its online resources, and show the sources for review before importing.',
                '粘贴 JSON 资源包链接。DingDong 会先请求文件、解析其中的在线资源，并在导入前展示来源供你检查。',
              ),
            ),
            const SizedBox(height: 16),
            DesktopTextField(
              key: const Key('library-import-link-field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                hintText: context.localized(
                  'https://example.com/dingdong-resources.json',
                  'https://example.com/dingdong-resources.json',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          onPressed: () => Navigator.pop(context),
          label: context.localized('Cancel', '取消'),
          compact: true,
        ),
        DesktopActionButton(
          key: const Key('library-import-link-submit'),
          onPressed: url.isEmpty ? null : _submit,
          icon: const Icon(Icons.cloud_download_outlined, size: 17),
          label: context.localized('Fetch and review', '请求并检查'),
          tone: DesktopActionTone.primary,
        ),
      ],
    );
  }
}
