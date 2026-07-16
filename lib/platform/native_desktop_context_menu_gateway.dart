import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:flutter/services.dart';

/// macOS native menu bridge shared by every secondary-click interaction.
final class NativeDesktopContextMenuGateway
    implements DesktopContextMenuGateway {
  static const MethodChannel _channel = MethodChannel(
    'dingdong/system_actions',
  );

  @override
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  }) {
    return _channel.invokeMethod<String>('showContextMenu', <String, Object>{
      'x': x,
      'y': y,
      'useChinese': useChinese,
      'items': items
          .map((DesktopContextMenuItem item) => item.toJson())
          .toList(growable: false),
    });
  }
}
