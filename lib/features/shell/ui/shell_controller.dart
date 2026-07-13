import 'package:flutter/foundation.dart';

/// Navigation state shared by UI, tray commands, and global shortcuts.
final class ShellController extends ChangeNotifier {
  ShellController({int initialIndex = 0})
    : _selectedIndex = initialIndex.clamp(0, 3);

  int _selectedIndex;
  int _clipboardFilterToggleRevision = 0;
  int _clipboardRefreshRevision = 0;
  int _clipboardSearchFocusRevision = 0;

  int get selectedIndex => _selectedIndex;
  int get clipboardFilterToggleRevision => _clipboardFilterToggleRevision;
  int get clipboardRefreshRevision => _clipboardRefreshRevision;
  int get clipboardSearchFocusRevision => _clipboardSearchFocusRevision;

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

  void requestClipboardRefresh() {
    _clipboardRefreshRevision += 1;
    notifyListeners();
  }

  void requestClipboardSearchFocus() {
    _clipboardSearchFocusRevision += 1;
    notifyListeners();
  }
}
