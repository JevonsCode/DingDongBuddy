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
      title: Text(context.l10n.importFromLink),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context
                  .l10n
                  .pasteAJSONBundleLinkDingDongWillFetchItResolveItsOnline_cb404168,
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
                hintText: context.l10n.httpsExampleComDingdongResourcesJson,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          onPressed: () => Navigator.pop(context),
          label: context.l10n.cancel,
          compact: true,
        ),
        DesktopActionButton(
          key: const Key('library-import-link-submit'),
          onPressed: url.isEmpty ? null : _submit,
          icon: const Icon(Icons.cloud_download_outlined, size: 17),
          label: context.l10n.fetchAndReview,
          tone: DesktopActionTone.primary,
        ),
      ],
    );
  }
}
