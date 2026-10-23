#pragma once

#include <windows.h>
#include <array>
#include <cstddef>

namespace tray_manager {

inline constexpr float kTrayArtOccupancy = 1.0f;
inline constexpr UINT kTrayWiggleFrameIntervalMs = 80;
inline constexpr UINT kTrayWiggleRestIntervalMs = 1500;
inline constexpr std::array<float, 8> kTrayWiggleAngles = {
    -18.0f, 18.0f, -18.0f, 18.0f, -14.0f, 12.0f, -8.0f, 5.0f};
inline constexpr std::array<float, 8> kTrayWiggleOffsets = {
    -1.0f, 1.0f, -1.0f, 1.0f, -0.8f, 0.8f, -0.5f, 0.25f};

HICON CreateTrayIcon(HICON source_icon, int width, int height);
// Transforms only the supplied original artwork. Caller owns the cached HICON.
HICON CreateTrayIconMotionFrame(HICON source_icon, int width, int height,
                                size_t frame);

}  // namespace tray_manager
