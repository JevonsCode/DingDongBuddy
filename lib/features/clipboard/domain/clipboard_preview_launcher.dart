import 'package:dingdong/core/models/clipboard_record.dart';

/// Opens and updates the lightweight clipboard preview beside the callout.
abstract interface class ClipboardPreviewLauncher {
  Future<void> show(ClipboardRecord record);

  Future<void> hide();
}
