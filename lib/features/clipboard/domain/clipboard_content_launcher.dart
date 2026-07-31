import 'package:dingdong/core/models/clipboard_record.dart';

/// Opens file-backed clipboard content with the operating system.
abstract interface class ClipboardContentLauncher {
  Future<void> open(ClipboardRecord record);
}
