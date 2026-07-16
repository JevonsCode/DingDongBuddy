import 'package:flutter/widgets.dart';

/// Platform-neutral geometry for the transient desktop popup.
abstract final class PopupWindowPolicy {
  static const Size initialSize = Size(390, 760);
  static const Size minimumSize = Size(390, 540);
  static const Size maximumSize = Size(390, 940);
  static const double edgeInset = 20;
  static const double trayGap = 12;

  static Size sizeForVisibleDisplay(Rect visibleDisplay) {
    final double availableHeight = visibleDisplay.height - edgeInset * 2;
    final double height = availableHeight < minimumSize.height
        ? minimumSize.height
        : initialSize.height
              .clamp(minimumSize.height, availableHeight)
              .toDouble();
    return Size(initialSize.width, height);
  }

  /// A child preview can take key-window status without leaving DingDong.
  static bool shouldHideOnBlur({required bool applicationIsActive}) =>
      !applicationIsActive;

  /// Anchors a popup below a top menu-bar icon and keeps it on-screen.
  static Offset positionBelowTray({
    required Rect trayBounds,
    required Rect visibleDisplay,
    required Size popupSize,
  }) {
    final double x = _defaultX(visibleDisplay, popupSize);
    final double y = _clampAxis(
      trayBounds.bottom + trayGap,
      visibleDisplay.top + edgeInset,
      visibleDisplay.bottom - popupSize.height - edgeInset,
    );
    return Offset(x, y);
  }

  /// Anchors above a bottom taskbar icon on Windows.
  static Offset positionAboveTray({
    required Rect trayBounds,
    required Rect visibleDisplay,
    required Size popupSize,
  }) {
    final double x = _defaultX(visibleDisplay, popupSize);
    final double y = _clampAxis(
      trayBounds.top - popupSize.height - trayGap,
      visibleDisplay.top + edgeInset,
      visibleDisplay.bottom - popupSize.height - edgeInset,
    );
    return Offset(x, y);
  }

  static double _defaultX(Rect display, Size popupSize) {
    return _clampAxis(
      display.right - popupSize.width - edgeInset,
      display.left + edgeInset,
      display.right - popupSize.width - edgeInset,
    );
  }

  static double _clampAxis(double preferred, double minimum, double maximum) {
    if (maximum <= minimum) {
      return minimum;
    }
    return preferred.clamp(minimum, maximum);
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
