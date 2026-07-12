import 'package:flutter/foundation.dart';

/// Navigation state shared by UI, tray commands, and global shortcuts.
final class ShellController extends ChangeNotifier {
  ShellController({int initialIndex = 0})
    : _selectedIndex = initialIndex.clamp(0, 3);

  int _selectedIndex;
  int _clipboardFilterToggleRevision = 0;

  int get selectedIndex => _selectedIndex;
  int get clipboardFilterToggleRevision => _clipboardFilterToggleRevision;

  void open(int index) {
    final int next = index.clamp(0, 3);
    if (_selectedIndex == next) {
      return;
    }
    _selectedIndex = next;
    notifyListeners();
  }

  void requestClipboardFilterToggle() {
    _clipboardFilterToggleRevision += 1;
    notifyListeners();
  }
}
