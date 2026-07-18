import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether the host window frame should own the popup's outer corners.
bool usesSystemWindowCorners(TargetPlatform platform) {
  return platform == TargetPlatform.windows;
}

/// The native window background behind the Flutter surface.
Color desktopWindowBackground(
  TargetPlatform platform, {
  required Color opaqueColor,
}) {
  return usesSystemWindowCorners(platform) ? opaqueColor : Colors.transparent;
}
