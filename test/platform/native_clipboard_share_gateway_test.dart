import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/platform/native_clipboard_share_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows does not expose an unsupported native share gateway', () {
    expect(
      createNativeClipboardShareGateway(TargetPlatform.windows),
      isNull,
    );
  });

  test('macOS exposes the native share gateway', () {
    expect(
      createNativeClipboardShareGateway(TargetPlatform.macOS),
      isA<ClipboardShareGateway>(),
    );
  });
}
