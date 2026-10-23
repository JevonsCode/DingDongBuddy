// Standalone verification of the actual Windows HICON renderer (no Flutter).
// Run from an x64 VS developer prompt at the repository root:
//   cl /nologo /std:c++17 /EHsc /W4 /WX /DNOMINMAX
//      scripts\verify_windows_tray_visuals.cpp
//      packages\tray_manager\windows\tray_visual.cpp
//      /Fe:build\tray_visual_verification\verify.exe
//      /link gdiplus.lib gdi32.lib user32.lib
//   build\tray_visual_verification\verify.exe build\tray_visual_verification

#include <windows.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <filesystem>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using std::max;
using std::min;

#pragma warning(push)
#pragma warning(disable : 4458)
#include <gdiplus.h>
#pragma warning(pop)

#include "../packages/tray_manager/windows/tray_visual.h"

namespace {

void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

class Icon {
 public:
  explicit Icon(HICON value) : value_(value) {
    Require(value_ != nullptr, "Renderer returned a null HICON");
  }
  ~Icon() { DestroyIcon(value_); }
  HICON get() const { return value_; }
  Icon(const Icon&) = delete;
  Icon& operator=(const Icon&) = delete;

 private:
  HICON value_;
};

struct Pixels {
  int width;
  int height;
  std::vector<BYTE> bytes;
};

Pixels ReadIcon(HICON icon, int width, int height) {
  ICONINFO info{};
  Require(GetIconInfo(icon, &info) != FALSE, "GetIconInfo failed");
  BITMAP bitmap{};
  const bool dimensions_ok =
      GetObject(info.hbmColor, sizeof(bitmap), &bitmap) == sizeof(bitmap) &&
      bitmap.bmWidth == width && bitmap.bmHeight == height;
  Pixels pixels{width, height,
                std::vector<BYTE>(static_cast<size_t>(width) * height * 4)};
  BITMAPINFO format{};
  format.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  format.bmiHeader.biWidth = width;
  format.bmiHeader.biHeight = -height;
  format.bmiHeader.biPlanes = 1;
  format.bmiHeader.biBitCount = 32;
  format.bmiHeader.biCompression = BI_RGB;
  HDC dc = GetDC(nullptr);
  const int lines = GetDIBits(dc, info.hbmColor, 0, height, pixels.bytes.data(),
                            &format, DIB_RGB_COLORS);
  ReleaseDC(nullptr, dc);
  DeleteObject(info.hbmColor);
  DeleteObject(info.hbmMask);
  Require(dimensions_ok, "HICON has incorrect physical pixel dimensions");
  Require(lines == height, "GetDIBits did not return every icon row");
  return pixels;
}

BYTE AlphaAt(const Pixels& pixels, int x, int y) {
  return pixels.bytes[(static_cast<size_t>(y) * pixels.width + x) * 4 + 3];
}

unsigned long long AlphaSum(const Pixels& pixels) {
  unsigned long long result = 0;
  for (size_t offset = 3; offset < pixels.bytes.size(); offset += 4) {
    result += pixels.bytes[offset];
  }
  return result;
}

size_t DifferentPixels(const Pixels& first, const Pixels& second) {
  size_t count = 0;
  for (size_t offset = 0; offset < first.bytes.size(); offset += 4) {
    if (!std::equal(first.bytes.begin() + offset,
                    first.bytes.begin() + offset + 4,
                    second.bytes.begin() + offset)) {
      ++count;
    }
  }
  return count;
}

void CheckTransparencyAndColor(const Pixels& pixels, DWORD rgb) {
  Require(AlphaAt(pixels, 0, 0) == 0 &&
              AlphaAt(pixels, pixels.width - 1, 0) == 0 &&
              AlphaAt(pixels, 0, pixels.height - 1) == 0 &&
              AlphaAt(pixels, pixels.width - 1, pixels.height - 1) == 0,
          "Icon corners must remain transparent");
  int transparent = 0;
  int antialiased = 0;
  int selected_rgb = 0;
  for (size_t offset = 3; offset < pixels.bytes.size(); offset += 4) {
    transparent += pixels.bytes[offset] == 0;
    antialiased += pixels.bytes[offset] > 0 && pixels.bytes[offset] < 255;
    if (pixels.bytes[offset] == 255 &&
        pixels.bytes[offset - 1] == ((rgb >> 16) & 0xFF) &&
        pixels.bytes[offset - 2] == ((rgb >> 8) & 0xFF) &&
        pixels.bytes[offset - 3] == (rgb & 0xFF)) {
      ++selected_rgb;
    }
  }
  Require(transparent > pixels.width * pixels.height / 10,
          "Icon lost its transparent surroundings");
  Require(antialiased >= pixels.width,
          "Icon boundary lost antialiased alpha coverage");
  // Facial antialiasing can reach this point at fractional DPI; check opacity
  // here and the exact selected fill color across the whole opaque body.
  const size_t forehead =
      (static_cast<size_t>(std::lround(pixels.height * 5.0 / 16.0)) *
           pixels.width +
       pixels.width / 2) *
      4;
  Require(pixels.bytes[forehead + 3] == 255,
          "Buddy body must stay fully visible");
  Require(selected_rgb >= 3, "Renderer changed the selected reminder RGB");
}

CLSID PngEncoder() {
  UINT count = 0;
  UINT bytes = 0;
  Require(Gdiplus::GetImageEncodersSize(&count, &bytes) == Gdiplus::Ok,
          "Image encoder discovery failed");
  std::vector<BYTE> storage(bytes);
  auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(storage.data());
  Require(Gdiplus::GetImageEncoders(count, bytes, encoders) == Gdiplus::Ok,
          "Image encoder retrieval failed");
  for (UINT index = 0; index < count; ++index) {
    if (std::wstring(encoders[index].MimeType) == L"image/png") {
      return encoders[index].Clsid;
    }
  }
  throw std::runtime_error("PNG encoder unavailable");
}

std::unique_ptr<Gdiplus::Bitmap> BitmapFrom(Pixels& pixels) {
  // HICON's color bitmap contains premultiplied BGRA. Preserve its actual alpha.
  return std::make_unique<Gdiplus::Bitmap>(
      pixels.width, pixels.height, pixels.width * 4, PixelFormat32bppPARGB,
      pixels.bytes.data());
}

void Label(Gdiplus::Graphics& graphics, const wchar_t* text, float x, float y,
           const Gdiplus::Color& color, float size = 12.0f) {
  Gdiplus::FontFamily family(L"Segoe UI");
  Gdiplus::Font font(&family, size, Gdiplus::FontStyleRegular,
                     Gdiplus::UnitPixel);
  Gdiplus::SolidBrush brush(color);
  graphics.DrawString(text, -1, &font, Gdiplus::PointF(x, y), &brush);
}

void DrawSample(Gdiplus::Graphics& graphics, Pixels& pixels, float x, float y,
                int native_size) {
  auto bitmap = BitmapFrom(pixels);
  graphics.SetInterpolationMode(Gdiplus::InterpolationModeNearestNeighbor);
  graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
  graphics.DrawImage(bitmap.get(),
                     Gdiplus::RectF(x + 12, y + (76 - native_size) / 2.0f,
                                    static_cast<float>(native_size),
                                    static_cast<float>(native_size)),
                     0, 0, static_cast<float>(pixels.width),
                     static_cast<float>(pixels.height), Gdiplus::UnitPixel);
  graphics.DrawImage(bitmap.get(), Gdiplus::RectF(x + 78, y + 6, 64, 64),
                     0, 0, static_cast<float>(pixels.width),
                     static_cast<float>(pixels.height), Gdiplus::UnitPixel);
}

constexpr std::array<int, 6> kSizes = {16, 20, 24, 32, 40, 48};
constexpr std::array<DWORD, 6> kColors = {
    0x7C6CF3, 0x3B82F6, 0xFBBF24, 0xF43F5E, 0xFFFFFF, 0x000000};
constexpr std::array<const wchar_t*, 3> kStates = {
    L"Waiting for you", L"Alternate wink", L"All done"};

void SaveSheets(const std::filesystem::path& output, const CLSID& encoder) {
  Gdiplus::Bitmap sheet(1160, 760, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&sheet);
  graphics.Clear(Gdiplus::Color(255, 235, 237, 241));
  Label(graphics, L"DingDong Windows tray buddy - actual native HICON output",
        20, 12, Gdiplus::Color(255, 25, 28, 36), 20);
  Label(graphics, L"Each cell: physical pixels at left; nearest-neighbor 64 px detail at right. RGB #7C6CF3.",
        20, 43, Gdiplus::Color(255, 62, 66, 78));
  for (int theme = 0; theme < 2; ++theme) {
    const float x = 20.0f + theme * 570.0f;
    const auto background = theme == 0 ? Gdiplus::Color(255, 249, 250, 252)
                                        : Gdiplus::Color(255, 30, 31, 35);
    const auto foreground = theme == 0 ? Gdiplus::Color(255, 36, 40, 48)
                                        : Gdiplus::Color(255, 240, 242, 248);
    Gdiplus::SolidBrush panel(background);
    graphics.FillRectangle(&panel, x, 78.0f, 550.0f, 653.0f);
    Label(graphics, theme == 0 ? L"Light taskbar" : L"Dark taskbar", x + 12,
          88, foreground, 15);
    for (size_t state = 0; state < kStates.size(); ++state) {
      Label(graphics, kStates[state], x + 40 + state * 164, 116, foreground);
    }
    for (size_t row = 0; row < kSizes.size(); ++row) {
      const int size = kSizes[row];
      const float y = 146.0f + static_cast<float>(row) * 94.0f;
      const std::wstring label = std::to_wstring(size) + L" px";
      Label(graphics, label.c_str(), x + 8, y + 68, foreground);
      for (size_t state = 0; state < kStates.size(); ++state) {
        Icon icon(tray_manager::CreateReminderTrayIcon(
            size, size, kColors[0], state != 2, state == 1));
        auto pixels = ReadIcon(icon.get(), size, size);
        DrawSample(graphics, pixels, x + 31 + state * 164, y, size);
      }
    }
  }
  Require(sheet.Save((output / L"tray-buddy-contact-sheet.png").c_str(),
                      &encoder) == Gdiplus::Ok,
          "Could not save native icon contact sheet");

  Gdiplus::Bitmap palette(1160, 660, PixelFormat32bppARGB);
  Gdiplus::Graphics palette_graphics(&palette);
  palette_graphics.Clear(Gdiplus::Color(255, 235, 237, 241));
  Label(palette_graphics, L"Custom RGB and contrast - actual 24 px HICON output",
        20, 12, Gdiplus::Color(255, 25, 28, 36), 20);
  for (int theme = 0; theme < 2; ++theme) {
    const float x = 20.0f + theme * 570.0f;
    const auto background = theme == 0 ? Gdiplus::Color(255, 249, 250, 252)
                                        : Gdiplus::Color(255, 30, 31, 35);
    const auto foreground = theme == 0 ? Gdiplus::Color(255, 36, 40, 48)
                                        : Gdiplus::Color(255, 240, 242, 248);
    Gdiplus::SolidBrush panel(background);
    palette_graphics.FillRectangle(&panel, x, 54.0f, 550.0f, 585.0f);
    for (size_t row = 0; row < kColors.size(); ++row) {
      const float y = 64.0f + static_cast<float>(row) * 94.0f;
      wchar_t label[16]{};
      swprintf_s(label, L"#%06lX", kColors[row]);
      Label(palette_graphics, label, x + 8, y + 68, foreground);
      for (size_t state = 0; state < kStates.size(); ++state) {
        Icon icon(tray_manager::CreateReminderTrayIcon(
            24, 24, kColors[row], state != 2, state == 1));
        auto pixels = ReadIcon(icon.get(), 24, 24);
        DrawSample(palette_graphics, pixels, x + 31 + state * 164, y, 24);
      }
    }
  }
  Require(palette.Save((output / L"tray-buddy-color-checks.png").c_str(),
                        &encoder) == Gdiplus::Ok,
          "Could not save custom color contact sheet");
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
  ULONG_PTR gdiplus_token = 0;
  Gdiplus::GdiplusStartupInput input;
  if (Gdiplus::GdiplusStartup(&gdiplus_token, &input, nullptr) != Gdiplus::Ok) {
    std::cerr << "GDI+ startup failed\n";
    return 1;
  }
  int result = 0;
  try {
    const std::filesystem::path output =
        argc > 1 ? argv[1] : L"build\\tray_visual_verification";
    std::filesystem::create_directories(output);
    const CLSID encoder = PngEncoder();
    Require(tray_manager::CreateReminderTrayIcon(0, 16, kColors[0], true) ==
                nullptr &&
                tray_manager::CreateReminderTrayIcon(16, -1, kColors[0], false) ==
                    nullptr,
            "Invalid icon dimensions must be rejected");
    int generated = 0;
    for (int size : kSizes) {
      for (DWORD color : kColors) {
        std::array<Pixels, 3> states{};
        for (size_t state = 0; state < states.size(); ++state) {
          Icon icon(tray_manager::CreateReminderTrayIcon(
              size, size, color, state != 2, state == 1));
          states[state] = ReadIcon(icon.get(), size, size);
          if (color == kColors[0]) {
            auto bitmap = BitmapFrom(states[state]);
            const std::wstring file = std::wstring(L"buddy-") +
                (state == 0 ? L"attention-" : state == 1 ? L"wink-" : L"done-") +
                std::to_wstring(size) + L"px.png";
            Require(bitmap->Save((output / file).c_str(), &encoder) ==
                        Gdiplus::Ok,
                    "Could not save native icon PNG");
          }
          CheckTransparencyAndColor(states[state], color);
          ++generated;
        }
        Require(DifferentPixels(states[0], states[1]) >= 8 &&
                    DifferentPixels(states[0], states[2]) >= 8,
                "Attention, completion and alternate frame must be distinct");
        const double coverage_ratio =
            static_cast<double>(AlphaSum(states[1])) / AlphaSum(states[0]);
        Require(coverage_ratio > 0.95 && coverage_ratio < 1.05,
                "Alternate frame must retain the full visible body");
        Icon completion_alternate(tray_manager::CreateReminderTrayIcon(
            size, size, color, false, true));
        const Pixels completion_frame = ReadIcon(completion_alternate.get(), size, size);
        Require(DifferentPixels(states[2], completion_frame) >= 8,
                "Completion softPulse must have a distinct alternate frame");
        CheckTransparencyAndColor(completion_frame, color);
        ++generated;
      }
    }
    {
      Icon rectangular(tray_manager::CreateReminderTrayIcon(
          32, 20, kColors[0], true));
      ReadIcon(rectangular.get(), 32, 20);
      Icon source(tray_manager::CreateReminderTrayIcon(32, 32, kColors[0], true));
      Icon resized(tray_manager::CreateTrayIcon(source.get(), 16, 16));
      ReadIcon(resized.get(), 16, 16);
    }
    const DWORD handles_before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
    const DWORD user_handles_before = GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS);
    for (int index = 0; index < 300; ++index) {
      Icon icon(tray_manager::CreateReminderTrayIcon(
          16, 16, kColors[index % kColors.size()], true, index % 2 == 0));
    }
    const DWORD handles_after = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
    const DWORD user_handles_after = GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS);
    Require(handles_after == handles_before &&
                user_handles_after == user_handles_before,
            "Repeated HICON creation/destruction leaked a GDI or USER object");
    SaveSheets(output, encoder);
    std::cout << "PASS: " << generated
              << " native icons across six DPI sizes, six RGB colors and four states\n"
              << "PASS: physical dimensions, transparent corners, antialiasing, exact RGB, distinct states\n"
              << "PASS: alternate coverage within 5%, rectangular input, source-icon resizing\n"
              << "PASS: no GDI or USER object growth after 300 creation/destruction cycles\n";
    std::wcout << L"Artifacts: " << std::filesystem::absolute(output).wstring()
               << L"\n";
  } catch (const std::exception& error) {
    std::cerr << "FAIL: " << error.what() << "\n";
    result = 1;
  }
  Gdiplus::GdiplusShutdown(gdiplus_token);
  return result;
}
