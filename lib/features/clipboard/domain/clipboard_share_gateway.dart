import 'package:dingdong/core/models/clipboard_record.dart';

/// Presents the host operating system's share UI for clipboard content.
abstract interface class ClipboardShareGateway {
  Future<void> share(ClipboardRecord record);
}
