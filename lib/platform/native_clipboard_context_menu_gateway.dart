import 'package:dingdong/features/clipboard/domain/clipboard_context_menu_gateway.dart';
import 'package:flutter/services.dart';

/// macOS native menu bridge, avoiding Material route animations on right click.
final class NativeClipboardContextMenuGateway
    implements ClipboardContextMenuGateway {
  static const MethodChannel _channel = MethodChannel(
    'dingdong/system_actions',
  );

  @override
  Future<ClipboardContextAction?> show({
    required double x,
    required double y,
    required bool useChinese,
  }) async {
    final String? value = await _channel.invokeMethod<String>(
      'showClipboardContextMenu',
      <String, Object>{'x': x, 'y': y, 'useChinese': useChinese},
    );
    if (value == null) {
      return null;
    }
    for (final ClipboardContextAction action in ClipboardContextAction.values) {
      if (action.name == value) {
        return action;
      }
    }
    return null;
  }
}
