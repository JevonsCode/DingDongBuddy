/// Applies the visual state of the desktop tray icon.
typedef ApplyTrayUnreadAppearance =
    Future<void> Function({
      required bool hot,
      required String title,
      required int iconSize,
    });

/// Process-local unread counter shown beside DingDong's hot tray icon.
final class TrayUnreadController {
  TrayUnreadController({required this.apply});

  final ApplyTrayUnreadAppearance apply;
  int _count = 0;

  int get count => _count;

  Future<void> markUnread() async {
    _count = (_count + 1).clamp(0, 999);
    final String label = _count > 99 ? '99+' : '$_count';
    await apply(hot: true, title: ' $label', iconSize: 22);
  }

  Future<void> clear() async {
    _count = 0;
    await apply(hot: false, title: '', iconSize: 22);
  }
}
