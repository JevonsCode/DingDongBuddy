#pragma once

#include <windows.h>

namespace tray_manager {

inline constexpr float kTrayArtOccupancy = 1.0f;

HICON CreateTrayIcon(HICON source_icon, int width, int height);
HICON CreateReminderTrayIcon(int width, int height, DWORD rgb, bool attention,
                             bool dimmed = false);

}  // namespace tray_manager
