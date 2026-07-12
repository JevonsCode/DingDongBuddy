import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native notification sends stable sound strings and supports preview',
    () async {
      const MethodChannel channel = MethodChannel('dingdong/notification');
      final List<MethodCall> calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final NativeNotificationGateway gateway = NativeNotificationGateway();

      await gateway.trigger(const DingRequest(sound: DingSound.dingSoft));
      await gateway.preview(sound: 'dingCrisp');

      expect(calls[0].method, 'notify');
      expect(
        (calls[0].arguments! as Map<Object?, Object?>)['sound'],
        'dingSoft',
      );
      expect(calls[1].method, 'preview');
      expect(
        (calls[1].arguments! as Map<Object?, Object?>)['sound'],
        'dingCrisp',
      );
    },
  );
}
