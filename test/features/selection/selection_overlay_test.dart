import 'package:dingdong/features/selection/ui/selection_overlay_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'clamps popup on negative-coordinate display and places above bottom selection',
    () {
      final bounds = selectionOverlayBounds(
        const Rect.fromLTWH(-40, 1010, 20, 30),
        const Rect.fromLTWH(-1920, 0, 1920, 1040),
        const Size(480, 460),
      );
      expect(bounds.right, 0);
      expect(bounds.bottom, 1002);
      expect(bounds.left, -480);
    },
  );
  test('small work area limits panel size', () {
    expect(
      selectionOverlayBounds(
        const Rect.fromLTWH(10, 10, 5, 5),
        const Rect.fromLTWH(0, 0, 300, 200),
        const Size(480, 460),
      ),
      const Rect.fromLTWH(0, 0, 300, 200),
    );
  });
  testWidgets('compact Chinese toolbar requires explicit action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(394, 58));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionOverlayPanel(
          state: const {'languageCode': 'zh', 'text': 'private', 'action': ''},
          onAction: (a, [p]) async {
            actions.add(a);
          },
        ),
      ),
    );
    expect(actions, isEmpty);
    for (final text in ['复制', '翻译', '解释', '润色']) {
      expect(find.text(text), findsOneWidget);
    }
    await tester.tap(find.text('翻译'));
    expect(actions, ['translate']);
    expect(tester.takeException(), null);
  });
  testWidgets('loading cancel, retry and follow-up controls are available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final actions = <String>[];
    Future<void> mount(Map<String, Object?> state) => tester.pumpWidget(
      MaterialApp(
        home: SelectionOverlayPanel(
          state: {
            'languageCode': 'en',
            'text': 'selection',
            'action': 'translate',
            ...state,
          },
          onAction: (a, [p]) async {
            actions.add('$a:${p ?? ''}');
          },
        ),
      ),
    );
    await mount({'busy': true});
    await tester.tap(find.text('Cancel'));
    expect(actions.last, 'cancel:');
    await mount({'error': 'timeout'});
    await tester.tap(find.text('Retry'));
    expect(actions.last, 'retry:');
    await mount({'result': 'Translated result'});
    expect(find.text('Translated result'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Please simplify');
    await tester.tap(find.byTooltip('Send'));
    expect(actions.last, 'follow_up:Please simplify');
    expect(tester.takeException(), null);
  });
}
