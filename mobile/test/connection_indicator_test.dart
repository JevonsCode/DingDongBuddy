import 'package:dingdong_mobile/ui/companion_controller.dart';
import 'package:dingdong_mobile/ui/tokens.dart';
import 'package:dingdong_mobile/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ComputerView _computer(String state, {bool manualDisconnect = false}) =>
    ComputerView(<String, Object?>{
      'room': 'room',
      'hostName': 'JARVIS',
      'state': state,
      'manualDisconnect': manualDisconnect,
    });

void main() {
  test(
    'automatic retries are reconnecting; only user-owned states need the banner',
    () {
      for (final String state in <String>['connecting', 'waiting', 'offline']) {
        final ComputerView computer = _computer(state);
        expect(computer.reconnecting, isTrue, reason: state);
        expect(computer.needsUserToReconnect, isFalse, reason: state);
      }
      expect(_computer('replaced').needsUserToReconnect, isTrue);
      expect(
        _computer('disconnected', manualDisconnect: true).needsUserToReconnect,
        isTrue,
      );
      expect(_computer('connected').reconnecting, isFalse);
      expect(_computer('connected').needsUserToReconnect, isFalse);
      expect(_computer('waiting').waitingForComputer, isTrue);
    },
  );

  testWidgets('the indicator swaps dot and spinner inside the same square', (
    WidgetTester tester,
  ) async {
    Future<Size> pump({required bool reconnecting}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[DingTokens.light],
          ),
          home: Center(
            child: ConnectionIndicator(
              connected: false,
              reconnecting: reconnecting,
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ConnectionIndicator));
    }

    final Size spinning = await pump(reconnecting: true);
    expect(
      find.byKey(const ValueKey<String>('reconnect-spinner')),
      findsOneWidget,
    );
    final Size idle = await pump(reconnecting: false);
    expect(
      find.byKey(const ValueKey<String>('reconnect-spinner')),
      findsNothing,
    );
    expect(spinning, idle);
  });
}
