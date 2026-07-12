import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unread tray title requests the native capsule treatment', () async {
    MethodCall? receivedCall;
    const MethodChannel channel = MethodChannel('tray_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await trayManager.setTitle(' 1', style: TrayTitleStyle.unreadBadge);

    expect(receivedCall?.method, 'setTitle');
    expect(receivedCall?.arguments, <String, Object>{
      'title': ' 1',
      'style': 'unreadBadge',
    });
  });
}
