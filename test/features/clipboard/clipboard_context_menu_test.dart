import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive context menu changes title and pin labels by state', () {
    final DingDongLocalizations english = lookupDingDongLocalizations(
      const Locale('en'),
    );
    final DingDongLocalizations chinese = lookupDingDongLocalizations(
      const Locale('zh'),
    );
    final DingDongLocalizations spanish = lookupDingDongLocalizations(
      const Locale('es'),
    );
    final List<DesktopContextMenuItem> untitled = clipboardContextMenuItems(
      strings: english,
    );
    final List<DesktopContextMenuItem> titled = clipboardContextMenuItems(
      strings: chinese,
      pinned: true,
      hasTitle: true,
    );
    final List<DesktopContextMenuItem> ordinary = clipboardContextMenuItems(
      strings: spanish,
      includePin: false,
    );

    expect(
      untitled.firstWhere((item) => item.id == 'togglePinned').label,
      'Pin',
    );
    expect(
      untitled.firstWhere((item) => item.id == 'addTitle').label,
      'Add title',
    );
    expect(untitled.where((item) => item.id == 'toggleEnabled'), isEmpty);
    expect(
      titled.firstWhere((item) => item.id == 'togglePinned').label,
      '取消置顶',
    );
    expect(titled.firstWhere((item) => item.id == 'addTitle').label, '修改标题');
    expect(titled.where((item) => item.id == 'toggleEnabled'), isEmpty);
    expect(ordinary.where((item) => item.id == 'togglePinned'), isEmpty);
    expect(
      ordinary.firstWhere((item) => item.id == 'delete').label,
      isNot('Delete'),
    );
  });
}
