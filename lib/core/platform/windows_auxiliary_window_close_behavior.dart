import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Prevents a visible Windows auxiliary window from reaching the native
/// destroy path before its Flutter close listener has mounted.
Future<void> preventWindowsAuxiliaryWindowClose() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.setPreventClose(true);
  }
}

/// Keeps a reusable Windows auxiliary window alive when its native close
/// button is pressed. The window can be shown again by its existing launcher,
/// while application exit remains owned by the main process and tray menu.
mixin WindowsAuxiliaryWindowCloseBehavior<T extends StatefulWidget>
    on State<T>, WindowListener {
  bool _interceptsWindowsClose = false;

  @protected
  void enableWindowsHideOnClose() {
    if (defaultTargetPlatform != TargetPlatform.windows ||
        _interceptsWindowsClose) {
      return;
    }
    _interceptsWindowsClose = true;
    windowManager.addListener(this);
    unawaited(preventWindowsAuxiliaryWindowClose());
  }

  @override
  void onWindowClose() {
    unawaited(windowManager.hide());
  }

  @override
  void dispose() {
    if (_interceptsWindowsClose) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
