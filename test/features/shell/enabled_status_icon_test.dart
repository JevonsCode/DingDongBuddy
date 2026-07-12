import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enabled indicator always uses the shared DingDong symbol', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EnabledStatusIcon(enabled: true)),
    );

    final PopupSymbolIcon symbol = tester.widget<PopupSymbolIcon>(
      find.byType(PopupSymbolIcon),
    );
    expect(symbol.symbol, 'enabled');
    expect(symbol.size, 18);
  });
}
