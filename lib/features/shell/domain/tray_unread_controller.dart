/// Applies the visual state of the desktop tray icon.
typedef ApplyTrayUnreadAppearance =
    Future<void> Function({
      required bool hot,
      required String title,
      required int iconSize,
      required int unreadCount,
    });

/// Process-local unread counter shown beside DingDong's hot tray icon.
final class TrayUnreadController {
  TrayUnreadController({required this.apply});

  final ApplyTrayUnreadAppearance apply;
  int _count = 0;

  int get count => _count;

  Future<void> markUnread() async {
    _count = (_count + 1).clamp(0, 999);
    await _apply();
  }

  Future<void> clear() async {
    _count = 0;
    await _apply();
  }

  /// Reapplies the current visual state after the taskbar appearance changes.
  Future<void> refresh() => _apply();

  Future<void> _apply() async {
    final bool hot = _count > 0;
    final String label = _count > 99 ? '99+' : '$_count';
    await apply(
      hot: hot,
      title: hot ? ' $label' : '',
      iconSize: 22,
      unreadCount: _count,
    );
  }
}
