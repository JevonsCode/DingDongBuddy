import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/platform/multi_window_resource_manager_launcher.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

const String clipboardPreviewWindowKind = 'clipboard-preview';
const String clipboardQrPreviewWindowKind = 'clipboard-qr-preview';
const String clipboardPreviewFocusWindowMethod = 'focus_window';
const Size clipboardPreviewWindowSize = Size(304, 420);
const Size clipboardQrPreviewWindowSize = Size(620, 680);
const Size clipboardQrPreviewMinimumSize = Size(360, 420);

/// Hosts the original side preview in a dedicated, reusable Flutter window.
final class MultiWindowClipboardPreviewLauncher
    implements ClipboardPreviewLauncher {
  @override
  Future<void> show(ClipboardRecord record) async {
    final Offset position = await _previewPosition();
    final List<WindowController> windows = await WindowController.getAll();
    WindowController? previewWindow;
    for (final WindowController controller in windows) {
      final Map<String, Object?> arguments = decodeDesktopWindowArguments(
        controller.arguments,
      );
      if (arguments['kind'] == clipboardQrPreviewWindowKind) {
        await controller.hide();
      } else if (arguments['kind'] == clipboardPreviewWindowKind) {
        previewWindow = controller;
      }
    }
    if (previewWindow != null) {
      await previewWindow.invokeMethod<void>('update_record', <String, Object?>{
        'record': clipboardRecordToWindowJson(record),
        'x': position.dx,
        'y': position.dy,
      });
      await previewWindow.showInactive();
      return;
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': clipboardPreviewWindowKind,
          'record': clipboardRecordToWindowJson(record),
          'x': position.dx,
          'y': position.dy,
        }),
      ),
    );
  }

  @override
  Future<void> hide() async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = decodeDesktopWindowArguments(
        controller.arguments,
      );
      if (arguments['kind'] == clipboardPreviewWindowKind ||
          arguments['kind'] == clipboardQrPreviewWindowKind) {
        await controller.hide();
      }
    }
  }

  Future<Offset> _previewPosition() async {
    final Offset popupPosition = await windowManager.getPosition();
    final Size popupSize = await windowManager.getSize();
    final List<Display> displays = await screenRetriever.getAllDisplays();
    final Rect popup = popupPosition & popupSize;
    final Display? display = displays.cast<Display?>().firstWhere((
      Display? value,
    ) {
      if (value == null) return false;
      final Rect bounds =
          (value.visiblePosition ?? Offset.zero) &
          (value.visibleSize ?? value.size);
      return bounds.overlaps(popup);
    }, orElse: () => displays.isEmpty ? null : displays.first);
    final Rect visible = display == null
        ? const Offset(0, 0) & const Size(1920, 1080)
        : (display.visiblePosition ?? Offset.zero) &
              (display.visibleSize ?? display.size);
    const double gap = 10;
    final double right = popup.right + gap;
    final double x = right + clipboardPreviewWindowSize.width <= visible.right
        ? right
        : popup.left - clipboardPreviewWindowSize.width - gap;
    return Offset(
      x.clamp(
        visible.left + gap,
        visible.right - clipboardPreviewWindowSize.width - gap,
      ),
      (popup.top).clamp(
        visible.top + gap,
        visible.bottom - clipboardPreviewWindowSize.height - gap,
      ),
    );
  }
}

/// Presents only the QR artwork in a separate image-viewer-sized window.
final class MultiWindowClipboardQrPreviewLauncher {
  const MultiWindowClipboardQrPreviewLauncher();

  Future<void> show(
    ClipboardRecord record, {
    required String parentWindowId,
  }) async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = decodeDesktopWindowArguments(
        controller.arguments,
      );
      if (arguments['kind'] != clipboardQrPreviewWindowKind) continue;
      await controller.invokeMethod<void>('update_record', <String, Object?>{
        'record': clipboardRecordToWindowJson(record),
        'parentWindowId': parentWindowId,
      });
      await controller.show();
      return;
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': clipboardQrPreviewWindowKind,
          'record': clipboardRecordToWindowJson(record),
          'parentWindowId': parentWindowId,
        }),
      ),
    );
  }

  Future<void> hide() async {
    for (final WindowController controller in await WindowController.getAll()) {
      final Map<String, Object?> arguments = decodeDesktopWindowArguments(
        controller.arguments,
      );
      if (arguments['kind'] == clipboardQrPreviewWindowKind) {
        await controller.hide();
      }
    }
  }
}

Map<String, Object?> clipboardRecordToWindowJson(ClipboardRecord record) =>
    <String, Object?>{
      'id': record.id,
      'group': record.group,
      'title': record.title,
      'content': record.content,
      'tags': record.tags,
      'source': record.source,
      'sources': record.sources,
      'copyCount': record.copyCount,
      'pinned': record.pinned,
      'enabled': record.enabled,
      'activation': record.activation,
      'sortOrder': record.sortOrder,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
    };

ClipboardRecord clipboardRecordFromWindowJson(Map<Object?, Object?> json) =>
    ClipboardRecord(
      id: json['id']! as String,
      group: json['group']! as String,
      title: json['title']! as String,
      content: json['content']! as String,
      tags: (json['tags']! as List<Object?>).cast<String>(),
      source: json['source'] as String?,
      sources: (json['sources'] as List<Object?>? ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      copyCount: json['copyCount'] as int? ?? 1,
      pinned: json['pinned']! as bool,
      enabled: json['enabled']! as bool,
      activation: json['activation']! as String,
      sortOrder: json['sortOrder'] as int?,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
