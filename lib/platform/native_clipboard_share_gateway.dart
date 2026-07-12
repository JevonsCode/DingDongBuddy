import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:flutter/services.dart';

/// Native share-sheet bridge used by clipboard context menus and previews.
final class NativeClipboardShareGateway implements ClipboardShareGateway {
  static const MethodChannel _channel = MethodChannel(
    'dingdong/system_actions',
  );

  @override
  Future<void> share(ClipboardRecord record) {
    return _channel.invokeMethod<void>('shareText', <String, String>{
      'title': record.title,
      'content': record.content,
    });
  }
}
