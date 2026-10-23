#pragma once

#include <windows.h>

namespace tray_manager {

inline constexpr float kTrayArtOccupancy = 1.0f;

HICON CreateTrayIcon(HICON source_icon, int width, int height);
// A colored speech-bubble buddy: attentive eyes while waiting, a calm smile on
// completion. The existing dimmed flag selects a visible alternate wink frame.
// The caller owns the returned icon and must release it with DestroyIcon.
HICON CreateReminderTrayIcon(int width, int height, DWORD rgb, bool attention,
                             bool dimmed = false);

}  // namespace tray_manager
