import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_qr_payload.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:window_manager/window_manager.dart';

/// Root widget for the side preview window used by single-click clipboard rows.
class ClipboardPreviewApp extends StatefulWidget {
  const ClipboardPreviewApp({
    required this.initialRecord,
    required this.windowController,
    required this.clipboardGateway,
    required this.contentLauncher,
    required this.shareGateway,
    super.key,
  });

  final ClipboardRecord initialRecord;
  final WindowController windowController;
  final ClipboardGateway clipboardGateway;
  final ClipboardContentLauncher contentLauncher;
  final ClipboardShareGateway? shareGateway;

  @override
  State<ClipboardPreviewApp> createState() => _ClipboardPreviewAppState();
}

class _ClipboardPreviewAppState extends State<ClipboardPreviewApp> {
  late ClipboardRecord _record;
  final MultiWindowClipboardQrPreviewLauncher _qrPreviewLauncher =
      const MultiWindowClipboardQrPreviewLauncher();

  @override
  void initState() {
    super.initState();
    _record = widget.initialRecord;
    widget.windowController.setWindowMethodHandler((call) async {
      if (call.method == clipboardPreviewFocusWindowMethod) {
        await windowManager.focus();
        return;
      }
      if (call.method != 'update_record') return;
      final Map<Object?, Object?> values =
          call.arguments as Map<Object?, Object?>;
      final Map<Object?, Object?> record =
          values['record']! as Map<Object?, Object?>;
      await _qrPreviewLauncher.hide();
      if (mounted) {
        setState(() => _record = clipboardRecordFromWindowJson(record));
      }
      await windowManager.setPosition(
        Offset(values['x']! as double, values['y']! as double),
      );
    });
  }

  Future<void> _close() async {
    await _qrPreviewLauncher.hide();
    await widget.windowController.hide();
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

  Future<void> _open() async {
    try {
      await widget.contentLauncher.open(_record);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该内容已不存在或无法打开。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      home: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              unawaited(_close()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: ClipboardPreviewCard(
              record: _record,
              onCopy: _copy,
              onOpen: canOpenClipboardContent(_record) ? _open : null,
              onShare: widget.shareGateway == null
                  ? null
                  : () => widget.shareGateway!.share(_record),
              onQrExpand: () => _qrPreviewLauncher.show(
                _record,
                parentWindowId: widget.windowController.windowId,
              ),
              onClose: () => unawaited(_close()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Root widget for the separate, image-viewer-sized QR window.
class ClipboardQrPreviewApp extends StatefulWidget {
  const ClipboardQrPreviewApp({
    required this.initialRecord,
    required this.parentWindowId,
    required this.windowController,
    super.key,
  });

  final ClipboardRecord initialRecord;
  final String parentWindowId;
  final WindowController windowController;

  @override
  State<ClipboardQrPreviewApp> createState() => _ClipboardQrPreviewAppState();
}

class _ClipboardQrPreviewAppState extends State<ClipboardQrPreviewApp> {
  late ClipboardQrData _data;
  late String _parentWindowId;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _data = clipboardQrData(widget.initialRecord)!;
    _parentWindowId = widget.parentWindowId;
    widget.windowController.setWindowMethodHandler((call) async {
      if (call.method != 'update_record') return;
      final Map<Object?, Object?> values =
          call.arguments as Map<Object?, Object?>;
      final Map<Object?, Object?> recordValues =
          values['record']! as Map<Object?, Object?>;
      _parentWindowId = values['parentWindowId']! as String;
      final ClipboardQrData? data = clipboardQrData(
        clipboardRecordFromWindowJson(recordValues),
      );
      if (mounted && data != null) setState(() => _data = data);
    });
  }

  void _close() => unawaited(_closeAndFocusParent());

  Future<void> _closeAndFocusParent() async {
    if (_closing) return;
    _closing = true;
    try {
      await widget.windowController.hide();
      final WindowController parent = WindowController.fromWindowId(
        _parentWindowId,
      );
      await parent.show();
      await parent.invokeMethod<void>(clipboardPreviewFocusWindowMethod);
    } on Object {
      // The parent may already be gone; hiding the large QR remains valid.
    } finally {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.desktopPanelLight(),
    home: CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ClipboardQrPreviewCard(data: _data, onClose: _close),
        ),
      ),
    ),
  );
}

class ClipboardPreviewCard extends StatefulWidget {
  const ClipboardPreviewCard({
    required this.record,
    required this.onCopy,
    this.onOpen,
    this.onShare,
    this.onQrExpand,
    required this.onClose,
    super.key,
  });

  final ClipboardRecord record;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final Future<void> Function()? onQrExpand;
  final VoidCallback onClose;

  @override
  State<ClipboardPreviewCard> createState() => _ClipboardPreviewCardState();
}

class _ClipboardPreviewCardState extends State<ClipboardPreviewCard> {
  bool _showQr = false;
  late ClipboardQrData? _qrData;

  @override
  void initState() {
    super.initState();
    _qrData = clipboardQrData(widget.record);
  }

  @override
  void didUpdateWidget(covariant ClipboardPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        oldWidget.record.content != widget.record.content ||
        oldWidget.record.kind != widget.record.kind) {
      _showQr = false;
      _qrData = clipboardQrData(widget.record);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClipboardRecord record = widget.record;
    final File? image = _firstExistingImage(record);
    final bool hasImage = record.kind == ClipboardKind.image && image != null;
    final ClipboardQrData? qrData = _qrData;
    final bool showQr = _showQr && qrData != null;
    final List<_PreviewAction> actions = <_PreviewAction>[
      _PreviewAction(
        key: const Key('clipboard-preview-copy'),
        onPressed: widget.onCopy,
        icon: Icons.copy_rounded,
        label: '复制',
        tone: DesktopActionTone.primary,
      ),
      if (widget.onOpen != null)
        _PreviewAction(
          key: const Key('clipboard-preview-open'),
          onPressed: widget.onOpen!,
          icon: Icons.open_in_new_rounded,
          label: '打开',
          tone: DesktopActionTone.soft,
        ),
      if (widget.onShare != null)
        _PreviewAction(
          key: const Key('clipboard-preview-share'),
          onPressed: widget.onShare!,
          icon: Icons.share_outlined,
          label: '分享',
        ),
      if (qrData != null)
        _PreviewAction(
          key: const Key('clipboard-preview-qr'),
          onPressed: () => setState(() {
            _showQr = !showQr;
          }),
          icon: Icons.qr_code_2_rounded,
          label: '二维码',
          tone: showQr ? DesktopActionTone.soft : DesktopActionTone.neutral,
        ),
    ];
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
                DesktopIconButton(
                  key: const Key('clipboard-preview-close'),
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  size: 30,
                  iconSize: 16,
                  foregroundColor: PopupStyle.textSecondary,
                  backgroundColor: PopupStyle.field,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _PreviewMeta(label: record.kind.name),
                for (final String group in record.groupNames)
                  _PreviewMeta(label: group),
                for (final String source in record.sources)
                  _PreviewMeta(label: source),
              ],
            ),
            const SizedBox(height: 12),
            if (showQr)
              Expanded(
                child: _PreviewQrCode(
                  data: qrData,
                  onExpand: () => unawaited(widget.onQrExpand?.call()),
                ),
              )
            else ...<Widget>[
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
            ],
            const SizedBox(height: 12),
            _PreviewActionBar(actions: actions),
          ],
        ),
      ),
    );
  }
}

class _PreviewActionBar extends StatelessWidget {
  const _PreviewActionBar({required this.actions});

  final List<_PreviewAction> actions;

  @override
  Widget build(BuildContext context) {
    final List<List<_PreviewAction>> rows = actions.length <= 3
        ? <List<_PreviewAction>>[actions]
        : <List<_PreviewAction>>[
            actions.take(2).toList(growable: false),
            actions.skip(2).toList(growable: false),
          ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: PopupStyle.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PopupStyle.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (
            int rowIndex = 0;
            rowIndex < rows.length;
            rowIndex += 1
          ) ...<Widget>[
            if (rowIndex > 0) const SizedBox(height: 6),
            _PreviewActionRow(actions: rows[rowIndex]),
          ],
        ],
      ),
    );
  }
}

class _PreviewActionRow extends StatelessWidget {
  const _PreviewActionRow({required this.actions});

  final List<_PreviewAction> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (int index = 0; index < actions.length; index += 1) ...<Widget>[
        if (index > 0) const SizedBox(width: 6),
        Expanded(
          child: DesktopActionButton(
            key: actions[index].key,
            onPressed: actions[index].onPressed,
            icon: actions[index].icon,
            label: actions[index].label,
            tone: actions[index].tone,
            compact: true,
          ),
        ),
      ],
    ],
  );
}

final class _PreviewAction {
  const _PreviewAction({
    required this.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tone = DesktopActionTone.neutral,
  });

  final Key key;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final DesktopActionTone tone;
}

class _PreviewQrCode extends StatelessWidget {
  const _PreviewQrCode({required this.data, required this.onExpand});

  final ClipboardQrData data;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('clipboard-preview-qr-surface'),
    width: double.infinity,
    decoration: BoxDecoration(
      color: PopupStyle.field,
      borderRadius: BorderRadius.circular(10),
    ),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool showLabel = constraints.maxHeight >= 150;
        final double reservedHeight = showLabel ? 30 : 12;
        final double qrSize = math.max(
          72,
          math.min(
            210,
            math.min(
              constraints.maxWidth - 20,
              constraints.maxHeight - reservedHeight,
            ),
          ),
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                button: true,
                label: '放大二维码',
                onTap: onExpand,
                child: Tooltip(
                  message: '点击放大二维码',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.zoomIn,
                    child: GestureDetector(
                      key: const Key('clipboard-preview-qr-expand'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onExpand,
                      child: _QrArtwork(
                        data: data,
                        size: qrSize,
                        viewKey: const Key('clipboard-preview-qr-view'),
                      ),
                    ),
                  ),
                ),
              ),
              if (showLabel) ...<Widget>[
                const SizedBox(height: 7),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.zoom_in_rounded,
                      size: 12,
                      color: PopupStyle.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '扫码分享 · 点击放大',
                      style: TextStyle(
                        color: PopupStyle.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class ClipboardQrPreviewCard extends StatelessWidget {
  const ClipboardQrPreviewCard({
    required this.data,
    required this.onClose,
    super.key,
  });

  final ClipboardQrData data;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('clipboard-preview-qr-expanded'),
    color: PopupStyle.background.withValues(alpha: 0.98),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: PopupStyle.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: MouseRegion(
      cursor: SystemMouseCursors.zoomOut,
      child: GestureDetector(
        key: const Key('clipboard-preview-qr-collapse'),
        behavior: HitTestBehavior.opaque,
        onTap: onClose,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double qrSize = math.max(
                    96,
                    math.min(
                      constraints.maxWidth - 36,
                      constraints.maxHeight - 108,
                    ),
                  );
                  return Center(
                    child: _QrArtwork(
                      data: data,
                      size: qrSize,
                      viewKey: const Key('clipboard-preview-qr-expanded-view'),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              left: 16,
              top: 16,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 15,
                    color: PopupStyle.accent,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'QR Code',
                    style: TextStyle(
                      color: PopupStyle.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: DesktopIconButton(
                key: const Key('clipboard-preview-qr-expanded-close'),
                tooltip: '关闭大图',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 16),
                size: 30,
                iconSize: 16,
                foregroundColor: PopupStyle.textSecondary,
                backgroundColor: PopupStyle.field,
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Text(
                '点击任意处关闭大图 · Esc',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PopupStyle.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QrArtwork extends StatelessWidget {
  const _QrArtwork({
    required this.data,
    required this.size,
    required this.viewKey,
  });

  final ClipboardQrData data;
  final double size;
  final Key viewKey;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: QrImageView.withQr(
      key: viewKey,
      qr: data.qrCode,
      size: size,
      padding: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: PopupStyle.textPrimary,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: PopupStyle.textPrimary,
      ),
      semanticsLabel: '内容二维码',
    ),
  );
}

class _PreviewMeta extends StatelessWidget {
  const _PreviewMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: PopupStyle.field,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: PopupStyle.textSecondary,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

File? _firstExistingImage(ClipboardRecord record) {
  for (final String path in record.filePaths) {
    final File file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
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
