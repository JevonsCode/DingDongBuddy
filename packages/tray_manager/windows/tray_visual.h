#pragma once

#include <windows.h>

namespace tray_manager {

inline constexpr float kTrayArtOccupancy = 1.0f;

HICON CreateTrayIcon(HICON source_icon, int width, int height);

}  // namespace tray_manager
