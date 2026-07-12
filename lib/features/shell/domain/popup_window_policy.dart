import 'package:flutter/widgets.dart';

/// Platform-neutral geometry for the transient desktop popup.
abstract final class PopupWindowPolicy {
  static const Size initialSize = Size(390, 760);
  static const Size minimumSize = Size(390, 540);
  static const Size maximumSize = Size(390, 940);
  static const double edgeInset = 20;
  static const double trayGap = 12;

  /// A child preview can take key-window status without leaving DingDong.
  static bool shouldHideOnBlur({required bool applicationIsActive}) =>
      !applicationIsActive;

  /// Anchors a popup below a top menu-bar icon and keeps it on-screen.
  static Offset positionBelowTray({
    required Rect trayBounds,
    required Rect visibleDisplay,
    required Size popupSize,
  }) {
    final double x = _rightAlignedX(visibleDisplay, popupSize);
    final double y = trayBounds.bottom + trayGap;
    return Offset(x, y);
  }

  /// Anchors above a bottom taskbar icon on Windows.
  static Offset positionAboveTray({
    required Rect trayBounds,
    required Rect visibleDisplay,
    required Size popupSize,
  }) {
    final double x = _rightAlignedX(visibleDisplay, popupSize);
    final double y = trayBounds.top - popupSize.height - trayGap;
    return Offset(x, y);
  }

  static double _rightAlignedX(Rect display, Size popupSize) {
    final double preferred = display.right - popupSize.width - edgeInset;
    return preferred.clamp(display.left + edgeInset, display.right - edgeInset);
  }
}

/// Remembers whether the user moved the callout during the current process.
///
/// This state intentionally has no persistence backend: relaunching DingDong
/// creates a new session and restores the standard right-side placement.
final class PopupPlacementSession {
  bool _userMoved = false;

  bool get shouldUseDefaultPosition => !_userMoved;

  void markUserMoved() => _userMoved = true;
}
