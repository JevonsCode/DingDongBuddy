import 'package:dingdong/features/shell/domain/popup_window_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('popup keeps the native compact dimensions', () {
    expect(PopupWindowPolicy.initialSize, const Size(390, 760));
    expect(PopupWindowPolicy.minimumSize, const Size(390, 540));
    expect(PopupWindowPolicy.maximumSize, const Size(390, 940));
  });

  test('popup shortens to the active display while respecting its minimum', () {
    expect(
      PopupWindowPolicy.sizeForVisibleDisplay(
        const Rect.fromLTWH(0, 24, 1280, 600),
      ),
      const Size(390, 560),
    );
  });

  test(
    'popup starts three default insets from the active display left edge',
    () {
      const Rect trayBounds = Rect.fromLTWH(760, 0, 24, 24);
      const Rect visibleDisplay = Rect.fromLTWH(0, 24, 1440, 876);

      expect(
        PopupWindowPolicy.positionBelowTray(
          trayBounds: trayBounds,
          visibleDisplay: visibleDisplay,
          popupSize: PopupWindowPolicy.initialSize,
        ),
        const Offset(60, 44),
      );
    },
  );

  test('popup placement uses the selected display coordinate space', () {
    const Rect trayBounds = Rect.fromLTWH(2160, 0, 24, 24);
    const Rect visibleDisplay = Rect.fromLTWH(1440, 24, 1440, 876);

    expect(
      PopupWindowPolicy.positionBelowTray(
        trayBounds: trayBounds,
        visibleDisplay: visibleDisplay,
        popupSize: PopupWindowPolicy.initialSize,
      ),
      const Offset(1500, 44),
    );
  });

  test('popup stays inside a shorter visible display', () {
    const Rect trayBounds = Rect.fromLTWH(760, 0, 24, 24);
    const Rect visibleDisplay = Rect.fromLTWH(0, 24, 1280, 600);

    expect(
      PopupWindowPolicy.positionBelowTray(
        trayBounds: trayBounds,
        visibleDisplay: visibleDisplay,
        popupSize: const Size(390, 540),
      ),
      const Offset(60, 44),
    );
  });

  test('a user drag disables default repositioning for this process', () {
    final PopupPlacementSession session = PopupPlacementSession();

    expect(session.shouldUseDefaultPosition, isTrue);

    session.markUserMoved();

    expect(session.shouldUseDefaultPosition, isFalse);
  });

  test('blur keeps the popup open while its preview window is active', () {
    expect(
      PopupWindowPolicy.shouldHideOnBlur(applicationIsActive: true),
      isFalse,
    );
    expect(
      PopupWindowPolicy.shouldHideOnBlur(applicationIsActive: false),
      isTrue,
    );
  });
}
