import 'package:dingdong/platform/native_clipboard_change_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'emits only when the native clipboard sequence changes while running',
    () async {
      int sequence = 10;
      final NativeClipboardChangeSource source = NativeClipboardChangeSource(
        sequenceReader: () async => sequence,
      );
      int changes = 0;
      source.changes.listen((_) => changes += 1);

      await source.start();
      await source.poll();
      expect(changes, 0);

      sequence = 11;
      await source.poll();
      await source.poll();
      expect(changes, 1);

      await source.stop();
      sequence = 12;
      await source.poll();
      expect(changes, 1);
    },
  );
}
