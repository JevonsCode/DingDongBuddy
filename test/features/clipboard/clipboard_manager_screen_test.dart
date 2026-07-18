import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bulk manager keeps only the explicit archive-to action', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[_record('first', now), _record('second', now)],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardManagerScreen(viewModel: model)),
    );

    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester
          .widgetList<SelectionMark>(find.byType(SelectionMark))
          .every((SelectionMark mark) => !mark.selected),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('clipboard-manager-select-first')));
    await tester.tap(find.byKey(const Key('clipboard-manager-select-second')));
    await tester.pump();
    expect(
      tester
          .widgetList<SelectionMark>(find.byType(SelectionMark))
          .every((SelectionMark mark) => mark.selected),
      isTrue,
    );
    expect(find.byKey(const Key('clipboard-bulk-archive')), findsNothing);
    expect(find.byKey(const Key('clipboard-bulk-archive-to')), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
    expect(find.text('Archive to…'), findsOneWidget);
  });

  testWidgets('archive group picker becomes searchable after five groups', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => showDialog<Set<String>>(
              context: context,
              builder: (BuildContext context) => const ClipboardGroupDialog(
                availableGroups: <String>[
                  'Alpha',
                  'Beta',
                  'DingDong',
                  'Docs',
                  'Ideas',
                  'Release',
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-group-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('clipboard-group-search')),
      'ding',
    );
    await tester.pump();

    expect(find.text('DingDong'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('manager rows expose the clipboard context actions', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[_record('context-item', now)],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardManagerScreen(viewModel: model)),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('clipboard-manager-row-context-item')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Archive to…'), findsOneWidget);
    expect(find.text('Save as prompt'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.list(limit: 100), isEmpty);
  });

  testWidgets('manager context menu opens beside the mouse pointer', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record('pointer-item', now)]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardManagerScreen(viewModel: model)),
    );

    final Finder row = find.byKey(
      const ValueKey<String>('clipboard-manager-row-pointer-item'),
    );
    final Offset pointer = tester.getTopLeft(row) + const Offset(270, 12);
    final TestGesture gesture = await tester.startGesture(
      pointer,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    final Rect details = tester.getRect(
      find.byKey(const Key('clipboard-manager-action-details')),
    );
    expect((details.left - pointer.dx).abs(), lessThanOrEqualTo(12));
    expect((details.top - pointer.dy).abs(), lessThanOrEqualTo(45));
  });

  testWidgets('manager delegates item menus to the native gateway', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final _FakeManagerContextMenuGateway menuGateway =
        _FakeManagerContextMenuGateway(
          itemAction: ClipboardContextAction.toggleEnabled,
        );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record('native-item', now)]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardManagerScreen(
          viewModel: model,
          contextMenuGateway: menuGateway,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('clipboard-manager-row-native-item')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();

    expect(menuGateway.itemShowCount, 1);
    expect(menuGateway.lastIncludeShare, isFalse);
    expect(menuGateway.lastEnabled, isTrue);
    expect(model.allRecords.single.enabled, isFalse);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('manager groups can be deleted from their context menu', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[_record('grouped-item', now, group: 'Project')],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    final _FakeManagerContextMenuGateway menuGateway =
        _FakeManagerContextMenuGateway(groupAction: 'delete');
    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardManagerScreen(
          viewModel: model,
          contextMenuGateway: menuGateway,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('clipboard-manager-group-Project')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(menuGateway.groupShowCount, 1);
    expect(
      find.byKey(const Key('clipboard-group-action-delete')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('clipboard-delete-group-confirm')));
    await tester.pumpAndSettle();

    expect(model.groups, isEmpty);
    expect(store.list(limit: 100), hasLength(1));
    expect(store.list(limit: 100).single.groupNames, isEmpty);
  });

  testWidgets('users can add a regular-expression category', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record('dingdong', now)]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardManagerScreen(viewModel: model)),
    );

    await tester.tap(find.byKey(const Key('clipboard-manager-categories')));
    await tester.pumpAndSettle();
    final Finder dialog = find.byKey(
      const Key('clipboard-category-rules-dialog'),
    );
    expect(tester.getSize(dialog).height, lessThan(430));
    expect(
      find.descendant(
        of: dialog,
        matching: find.byType(ReorderableDragStartListener),
      ),
      findsNWidgets(model.categoryRules.length),
    );
    final Finder textDeleteButton = find.byKey(
      const Key('clipboard-category-delete-text'),
    );
    expect(
      find.descendant(
        of: textDeleteButton,
        matching: find.byType(PopupSymbolIcon),
      ),
      findsOneWidget,
    );
    expect(
      <String>['links', 'images', 'files', 'text'].every((String id) {
        final PopupSymbolIcon icon = tester.widget<PopupSymbolIcon>(
          find.descendant(
            of: find.byKey(Key('clipboard-category-icon-$id')),
            matching: find.byType(PopupSymbolIcon),
          ),
        );
        return icon.symbol ==
            switch (id) {
              'links' => 'link',
              'images' => 'image',
              'files' => 'file',
              _ => 'text',
            };
      }),
      isTrue,
    );
    expect(
      find.byKey(const Key('clipboard-category-edit-text')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('clipboard-category-add')));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CompactSwitch), findsNWidgets(2));
    expect(
      tester
          .getSize(find.byKey(const Key('clipboard-category-rules-dialog')))
          .width,
      lessThanOrEqualTo(620),
    );
    await tester.enterText(
      find.byKey(const Key('clipboard-category-name')),
      'DingDong project',
    );
    await tester.enterText(
      find.byKey(const Key('clipboard-category-content-regex')),
      'dingdong',
    );
    await tester.ensureVisible(
      find.byKey(const Key('clipboard-category-save')),
    );
    await tester.tap(find.byKey(const Key('clipboard-category-save')));
    await tester.pumpAndSettle();

    expect(
      model.categoryRules.any(
        (rule) =>
            rule.name == 'DingDong project' &&
            rule.contentPattern == 'dingdong',
      ),
      isTrue,
    );
  });
}

ClipboardRecord _record(String id, DateTime now, {String group = ''}) =>
    ClipboardRecord(
      id: id,
      group: group,
      title: id,
      content: '$id content',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );

final class _FakeManagerContextMenuGateway
    implements DesktopContextMenuGateway {
  _FakeManagerContextMenuGateway({this.itemAction, this.groupAction});

  final ClipboardContextAction? itemAction;
  final String? groupAction;
  int itemShowCount = 0;
  int groupShowCount = 0;
  bool? lastIncludeShare;
  bool? lastEnabled;

  @override
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  }) async {
    if (items.length == 1 && items.single.englishLabel == 'Delete group') {
      groupShowCount += 1;
      return groupAction;
    }
    itemShowCount += 1;
    lastIncludeShare = items.any(
      (DesktopContextMenuItem item) => item.id == 'share',
    );
    lastEnabled = items.any(
      (DesktopContextMenuItem item) =>
          item.id == 'toggleEnabled' && item.englishLabel == 'Disable',
    );
    return itemAction?.name;
  }
}
