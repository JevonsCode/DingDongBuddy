import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archive context menu changes title and pin labels by state', () {
    final List<DesktopContextMenuItem> untitled = clipboardContextMenuItems();
    final List<DesktopContextMenuItem> titled = clipboardContextMenuItems(
      pinned: true,
      hasTitle: true,
    );
    final List<DesktopContextMenuItem> ordinary = clipboardContextMenuItems(
      includePin: false,
    );

    expect(
      untitled.firstWhere((item) => item.id == 'togglePinned').englishLabel,
      'Pin',
    );
    expect(
      untitled.firstWhere((item) => item.id == 'addTitle').chineseLabel,
      '添加标题',
    );
    expect(untitled.where((item) => item.id == 'toggleEnabled'), isEmpty);
    expect(
      titled.firstWhere((item) => item.id == 'togglePinned').chineseLabel,
      '取消置顶',
    );
    expect(
      titled.firstWhere((item) => item.id == 'addTitle').englishLabel,
      'Edit title',
    );
    expect(titled.where((item) => item.id == 'toggleEnabled'), isEmpty);
    expect(ordinary.where((item) => item.id == 'togglePinned'), isEmpty);
  });
}
