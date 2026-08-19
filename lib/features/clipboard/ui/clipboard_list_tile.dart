import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_copy_count.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_pinned_indicator.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_timestamp_label.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Reusable fixed-height clipboard row suitable for very long lazy lists.
class ClipboardListTile extends StatelessWidget {
  const ClipboardListTile({
    required this.record,
    required this.selected,
    required this.onSelected,
    this.onDoubleTap,
    this.onOpenContent,
    this.onSecondaryTapUp,
    this.callout = false,
    this.shortcutIndex,
    this.plainTextShortcut = false,
    this.showPinnedIndicator = false,
    this.now,
    super.key,
  });

  final ClipboardRecord record;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onOpenContent;
  final GestureTapUpCallback? onSecondaryTapUp;
  final bool callout;
  final int? shortcutIndex;
  final bool plainTextShortcut;
  final bool showPinnedIndicator;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (callout) {
      return _CalloutClipboardTile(
        record: record,
        selected: selected,
        shortcutIndex: shortcutIndex,
        plainTextShortcut: plainTextShortcut,
        onSelected: onSelected,
        onDoubleTap: onDoubleTap,
        onOpenContent: onOpenContent,
        onSecondaryTapUp: onSecondaryTapUp,
        showPinnedIndicator: showPinnedIndicator,
        now: now,
      );
    }
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          child: _InteractiveInkWell(
            onTap: onSelected,
            onDoubleTap: onDoubleTap,
            onSecondaryTapUp: onSecondaryTapUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: <Widget>[
                  _SystemContentAction(
                    record: record,
                    onOpen: onOpenContent,
                    child: Icon(_iconForRecord(record), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                record.sensitive
                                    ? context.l10n.sensitiveContentHidden
                                    : record.content.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            if (record.copyCount > 1) ...<Widget>[
                              const SizedBox(width: 7),
                              ClipboardCopyCount(
                                recordId: record.id,
                                count: record.copyCount,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clipboardTimestampLabel(
                      context,
                      record.updatedAt,
                      now: now,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showPinnedIndicator && record.pinned)
          Positioned(
            top: -6,
            right: -2,
            child: ClipboardPinnedIndicator(
              recordId: record.id,
              keyPrefix: 'clipboard-pinned-indicator',
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          ),
      ],
    );
  }
}

class _CalloutClipboardTile extends StatelessWidget {
  const _CalloutClipboardTile({
    required this.record,
    required this.selected,
    required this.shortcutIndex,
    required this.plainTextShortcut,
    required this.onSelected,
    required this.onDoubleTap,
    required this.onOpenContent,
    required this.onSecondaryTapUp,
    required this.showPinnedIndicator,
    required this.now,
  });

  final ClipboardRecord record;
  final bool selected;
  final int? shortcutIndex;
  final bool plainTextShortcut;
  final VoidCallback onSelected;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onOpenContent;
  final GestureTapUpCallback? onSecondaryTapUp;
  final bool showPinnedIndicator;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: selected
                ? PopupStyle.of(context).accentSoft
                : PopupStyle.of(context).surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(color: PopupStyle.of(context).border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _InteractiveInkWell(
              onTap: onSelected,
              onDoubleTap: onDoubleTap,
              onSecondaryTapUp: onSecondaryTapUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    _RecordLeading(record: record, onOpen: onOpenContent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PopupStyle.of(context).textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  _subtitle(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PopupStyle.of(context).textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (record.copyCount > 1) ...<Widget>[
                                const SizedBox(width: 7),
                                ClipboardCopyCount(
                                  recordId: record.id,
                                  count: record.copyCount,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clipboardTimestampLabel(
                        context,
                        record.updatedAt,
                        now: now,
                      ),
                      style: TextStyle(
                        color: PopupStyle.of(context).textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (shortcutIndex != null) ...<Widget>[
                      const SizedBox(width: 10),
                      Container(
                        width: plainTextShortcut
                            ? 52
                            : usesMetaAsPrimaryModifier(platform)
                            ? 38
                            : 44,
                        height: 29,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PopupStyle.of(context).accent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          plainTextShortcut
                              ? '⌥⌘ $shortcutIndex'
                              : primaryShortcutLabel(
                                  '$shortcutIndex',
                                  platform,
                                ),
                          style: TextStyle(
                            color: PopupStyle.of(context).background,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (plainTextShortcut) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.plainText,
                          style: TextStyle(
                            color: PopupStyle.of(context).textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (showPinnedIndicator && record.pinned)
            Positioned(
              top: -7,
              right: -2,
              child: ClipboardPinnedIndicator(
                recordId: record.id,
                keyPrefix: 'clipboard-pinned-indicator',
                color: PopupStyle.of(context).accent,
                size: 17,
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context) {
    if (record.sensitive) {
      return context.l10n.sensitiveContentHidden;
    }
    if (record.kind == ClipboardKind.image) {
      final File? file = _firstExistingFile(record);
      if (file != null) {
        final int kilobytes = file.lengthSync() ~/ 1024;
        return 'PNG · ${context.l10n.image} · $kilobytes KB';
      }
    }
    return record.content.replaceAll('\n', ' ');
  }
}

/// Keeps single-click preview immediate while still recognizing a second click.
/// Flutter's stock double-tap recognizer delays the single-tap callback, which
/// makes desktop rows feel sluggish and differs from the original app.
class _InteractiveInkWell extends StatefulWidget {
  const _InteractiveInkWell({
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTapUp,
    required this.child,
  });

  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final Widget child;

  @override
  State<_InteractiveInkWell> createState() => _InteractiveInkWellState();
}

class _InteractiveInkWellState extends State<_InteractiveInkWell> {
  Duration? _lastPrimaryDown;
  bool _suppressNextTap = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || widget.onDoubleTap == null) {
      return;
    }
    final Duration? previous = _lastPrimaryDown;
    _lastPrimaryDown = event.timeStamp;
    if (previous != null &&
        event.timeStamp - previous <= const Duration(milliseconds: 500)) {
      _lastPrimaryDown = null;
      _suppressNextTap = true;
      widget.onDoubleTap?.call();
    }
  }

  void _handleTap() {
    if (_suppressNextTap) {
      _suppressNextTap = false;
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      child: InkWell(
        onTap: _handleTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: widget.child,
      ),
    );
  }
}

class _RecordLeading extends StatelessWidget {
  const _RecordLeading({required this.record, required this.onOpen});

  final ClipboardRecord record;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final File? imageFile = _firstExistingFile(record);
    final Widget leading =
        record.kind == ClipboardKind.image && imageFile != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.file(
              imageFile,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              cacheWidth: 92,
              errorBuilder: (_, _, _) => _iconBox(context, record),
            ),
          )
        : _iconBox(context, record);
    return _SystemContentAction(record: record, onOpen: onOpen, child: leading);
  }

  Widget _iconBox(BuildContext context, ClipboardRecord record) {
    final ClipboardKind kind = record.kind;
    final bool fromDevice = _isFromLinkedDevice(record);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: PopupStyle.of(context).field,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(
        child: fromDevice
            ? Icon(
                Icons.phone_iphone_rounded,
                size: 17,
                color: PopupStyle.of(context).accent,
              )
            : PopupSymbolIcon(
                record.sensitive ? 'sensitive' : _symbolFor(kind),
                size: 17,
                color: record.sensitive
                    ? const Color(0xFFC65A55)
                    : kind == ClipboardKind.command
                    ? const Color(0xFF22C55E)
                    : kind == ClipboardKind.url
                    ? PopupStyle.of(context).accent
                    : PopupStyle.of(context).textSecondary,
              ),
      ),
    );
  }
}

class _SystemContentAction extends StatelessWidget {
  const _SystemContentAction({
    required this.record,
    required this.onOpen,
    required this.child,
  });

  final ClipboardRecord record;
  final VoidCallback? onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (onOpen == null || !canOpenClipboardContent(record)) {
      return child;
    }
    final String label = switch (record.kind) {
      ClipboardKind.image => context.l10n.previewImageWithSystemApp,
      ClipboardKind.url => context.l10n.openLinkWithSystemBrowser,
      ClipboardKind.path => context.l10n.openPathWithSystemApp,
      _ => context.l10n.openFileWithSystemApp,
    };
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: Key('clipboard-open-content-${record.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: child,
          ),
        ),
      ),
    );
  }
}

File? _firstExistingFile(ClipboardRecord record) {
  for (final String path in record.filePaths) {
    final File file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
}

String _symbolFor(ClipboardKind kind) {
  return switch (kind) {
    ClipboardKind.url => 'link',
    ClipboardKind.command => 'command',
    ClipboardKind.image => 'image',
    ClipboardKind.file => 'file',
    ClipboardKind.code || ClipboardKind.json => 'code',
    ClipboardKind.path => 'path',
    _ => 'text',
  };
}

IconData _iconFor(ClipboardKind kind) {
  return switch (kind) {
    ClipboardKind.text => Icons.notes_rounded,
    ClipboardKind.url => Icons.link_rounded,
    ClipboardKind.command => Icons.terminal_rounded,
    ClipboardKind.code => Icons.code_rounded,
    ClipboardKind.json => Icons.data_object_rounded,
    ClipboardKind.path => Icons.folder_outlined,
    ClipboardKind.email => Icons.alternate_email_rounded,
    ClipboardKind.file => Icons.insert_drive_file_outlined,
    ClipboardKind.image => Icons.image_outlined,
  };
}

IconData _iconForRecord(ClipboardRecord record) => _isFromLinkedDevice(record)
    ? Icons.phone_iphone_rounded
    : _iconFor(record.kind);

bool _isFromLinkedDevice(ClipboardRecord record) =>
    record.tags.any((String value) => value.startsWith('device-origin:')) ||
    record.sources.any((String value) => value.startsWith('来自 '));
