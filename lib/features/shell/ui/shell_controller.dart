import 'package:dingdong/features/shell/domain/tray_buddy_controller.dart';
import 'package:flutter/foundation.dart';

/// Navigation state shared by UI, tray commands, and global shortcuts.
final class ShellController extends ChangeNotifier {
  ShellController({int initialIndex = 0})
    : _selectedIndex = initialIndex.clamp(0, 3);

  bool _clipboardOnly = false;
  int _selectedIndex;
  int _clipboardFilterToggleRevision = 0;
  int _clipboardRefreshRevision = 0;
  int _clipboardSearchFocusRevision = 0;
  int _libraryRefreshRevision = 0;
  int _agentInstallPreviewRevision = 0;
  TrayBuddyState _mascotState = TrayBuddyState.normal;

  bool get clipboardOnly => _clipboardOnly;
  int get selectedIndex => _selectedIndex;
  int get clipboardFilterToggleRevision => _clipboardFilterToggleRevision;
  int get clipboardRefreshRevision => _clipboardRefreshRevision;
  int get clipboardSearchFocusRevision => _clipboardSearchFocusRevision;
  int get libraryRefreshRevision => _libraryRefreshRevision;
  int get agentInstallPreviewRevision => _agentInstallPreviewRevision;
  TrayBuddyState get mascotState => _mascotState;

  void setClipboardOnly(bool value) {
    if (value == _clipboardOnly) return;
    _clipboardOnly = value;
    if (value) _selectedIndex = 2;
    notifyListeners();
  }

  void open(int index) {
    if (_clipboardOnly && index != 2) return;
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

  void requestLibraryRefresh() {
    _libraryRefreshRevision += 1;
    notifyListeners();
  }

  void requestAgentInstallPreview() {
    _agentInstallPreviewRevision += 1;
    notifyListeners();
  }

  void setMascotState(TrayBuddyState value) {
    if (_mascotState == value) {
      return;
    }
    _mascotState = value;
    notifyListeners();
  }
}
