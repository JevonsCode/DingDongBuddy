import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Root widget for the side preview window used by single-click clipboard rows.
class ClipboardPreviewApp extends StatefulWidget {
  const ClipboardPreviewApp({
    required this.initialRecord,
    required this.windowController,
    required this.clipboardGateway,
    required this.shareGateway,
    super.key,
  });

  final ClipboardRecord initialRecord;
  final WindowController windowController;
  final ClipboardGateway clipboardGateway;
  final ClipboardShareGateway shareGateway;

  @override
  State<ClipboardPreviewApp> createState() => _ClipboardPreviewAppState();
}

class _ClipboardPreviewAppState extends State<ClipboardPreviewApp> {
  late ClipboardRecord _record;

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
    widget.windowController.setWindowMethodHandler((call) async {
      if (call.method != 'update_record') return;
      final Map<Object?, Object?> values =
          call.arguments as Map<Object?, Object?>;
      final Map<Object?, Object?> record =
          values['record']! as Map<Object?, Object?>;
      if (mounted) {
        setState(() => _record = clipboardRecordFromWindowJson(record));
      }
      await windowManager.setPosition(
        Offset(values['x']! as double, values['y']! as double),
      );
    });
  }

  Future<void> _copy() async {
    if (_record.tags.contains('file-url')) {
      final List<String> files = _record.content
          .split('\n')
          .map((String path) => path.trim())
          .where((String path) => path.isNotEmpty)
          .toList(growable: false);
      if (files.isNotEmpty) {
        await widget.clipboardGateway.writeFiles(files);
        return;
      }
    }
    await widget.clipboardGateway.writeText(_record.content);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _ClipboardPreviewCard(
          record: _record,
          onCopy: _copy,
          onShare: () => widget.shareGateway.share(_record),
          onClose: widget.windowController.hide,
        ),
      ),
    );
  }
}

class _ClipboardPreviewCard extends StatelessWidget {
  const _ClipboardPreviewCard({
    required this.record,
    required this.onCopy,
    required this.onShare,
    required this.onClose,
  });

  final ClipboardRecord record;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final File image = File(record.content);
    final bool hasImage =
        record.kind == ClipboardKind.image && image.existsSync();
    return Material(
      color: PopupStyle.background.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PopupStyle.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _PreviewKindIcon(record.kind),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PopupStyle.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TimeOfDay.fromDateTime(
                          record.updatedAt.toLocal(),
                        ).format(context),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: PopupStyle.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasImage) ...<Widget>[
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: PopupStyle.card(radius: 9),
                  child: Image.file(image, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasImage)
              SizedBox(height: 72, child: _PreviewContent(record: record))
            else
              Expanded(child: _PreviewContent(record: record)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined, size: 15),
                  label: const Text('分享'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.record});

  final ClipboardRecord record;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: PopupStyle.field,
      borderRadius: BorderRadius.circular(9),
    ),
    child: SingleChildScrollView(
      child: SelectableText(
        record.sensitive ? '敏感内容已隐藏' : record.content,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          color: PopupStyle.textSecondary,
        ),
      ),
    ),
  );
}

class _PreviewKindIcon extends StatelessWidget {
  const _PreviewKindIcon(this.kind);

  final ClipboardKind kind;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: PopupStyle.field,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      switch (kind) {
        ClipboardKind.image => Icons.image_outlined,
        ClipboardKind.file => Icons.description_outlined,
        ClipboardKind.command => Icons.terminal_rounded,
        ClipboardKind.url => Icons.link_rounded,
        ClipboardKind.code || ClipboardKind.json => Icons.code_rounded,
        ClipboardKind.path => Icons.folder_outlined,
        _ => Icons.content_paste_rounded,
      },
      size: 16,
      color: kind == ClipboardKind.command
          ? const Color(0xFF22C55E)
          : PopupStyle.accent,
    ),
  );
}
