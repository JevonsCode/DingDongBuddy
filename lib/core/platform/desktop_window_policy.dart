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

/// Resolves macOS's app-wide Dock policy while preserving other platforms'
/// existing per-window taskbar behavior.
bool desktopWindowSkipsTaskbar(
  TargetPlatform platform, {
  required bool hideDockIcon,
  required bool fallback,
}) {
  return platform == TargetPlatform.macOS ? hideDockIcon : fallback;
}
