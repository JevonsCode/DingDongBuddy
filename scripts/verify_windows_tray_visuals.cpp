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

void CheckOriginalArtwork(const Pixels& pixels, bool require_orange = true) {
  // The existing bicubic asset resize can leave one alpha level of ringing.
  Require(AlphaAt(pixels, 0, 0) <= 2 &&
              AlphaAt(pixels, pixels.width - 1, 0) <= 2 &&
              AlphaAt(pixels, 0, pixels.height - 1) <= 2 &&
              AlphaAt(pixels, pixels.width - 1, pixels.height - 1) <= 2,
          "Original icon corners must remain transparent");
  int transparent = 0;
  int antialiased = 0;
  int navy = 0;
  int white = 0;
  int orange = 0;
  for (size_t offset = 0; offset < pixels.bytes.size(); offset += 4) {
    const int blue = pixels.bytes[offset];
    const int green = pixels.bytes[offset + 1];
    const int red = pixels.bytes[offset + 2];
    const int alpha = pixels.bytes[offset + 3];
    transparent += alpha == 0;
    antialiased += alpha > 0 && alpha < 255;
    if (alpha > 224) {
      navy += red < 90 && green < 120 && blue < 150;
      white += red > 220 && green > 220 && blue > 220;
      orange += red > 150 && red > green + 20 && green > blue + 10;
    }
  }
  Require(transparent > pixels.width * pixels.height / 10,
          "Original artwork lost transparent surroundings");
  Require(antialiased >= pixels.width,
          "Original artwork lost antialiased alpha coverage");
  Require(navy > 0 && white > 0 && (!require_orange || orange > 0),
          "Original navy/white/orange reminder palette was not preserved");
}

double AlphaCentroidX(const Pixels& pixels) {
  double weighted = 0;
  double total = 0;
  for (int y = 0; y < pixels.height; ++y) {
    for (int x = 0; x < pixels.width; ++x) {
      const BYTE alpha = AlphaAt(pixels, x, y);
      weighted += (x + 0.5) * alpha;
      total += alpha;
    }
  }
  return weighted / total;
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
constexpr std::array<const wchar_t*, 2> kFrames = {
    L"Original frame 1", L"Original frame 2"};

void SaveSheet(const std::filesystem::path& output, const CLSID& encoder,
               const std::array<HICON, 2>& sources) {
  Gdiplus::Bitmap sheet(1040, 760, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&sheet);
  graphics.Clear(Gdiplus::Color(255, 235, 237, 241));
  Label(graphics, L"DingDong original reminder IP - actual Windows HICON output",
        20, 12, Gdiplus::Color(255, 25, 28, 36), 20);
  Label(graphics, L"Existing adaptive unread / unread2 assets. Physical pixels at left; 64 px detail at right.",
        20, 43, Gdiplus::Color(255, 62, 66, 78));
  for (int theme = 0; theme < 2; ++theme) {
    const float x = 20.0f + theme * 510.0f;
    const auto background = theme == 0 ? Gdiplus::Color(255, 249, 250, 252)
                                        : Gdiplus::Color(255, 30, 31, 35);
    const auto foreground = theme == 0 ? Gdiplus::Color(255, 36, 40, 48)
                                        : Gdiplus::Color(255, 240, 242, 248);
    Gdiplus::SolidBrush panel(background);
    graphics.FillRectangle(&panel, x, 78.0f, 490.0f, 653.0f);
    Label(graphics, theme == 0 ? L"Light taskbar" : L"Dark taskbar", x + 12,
          88, foreground, 15);
    for (size_t frame = 0; frame < kFrames.size(); ++frame) {
      Label(graphics, kFrames[frame], x + 60 + frame * 220, 116, foreground);
    }
    for (size_t row = 0; row < kSizes.size(); ++row) {
      const int size = kSizes[row];
      const float y = 146.0f + static_cast<float>(row) * 94.0f;
      const std::wstring label = std::to_wstring(size) + L" px";
      Label(graphics, label.c_str(), x + 8, y + 68, foreground);
      for (size_t frame = 0; frame < sources.size(); ++frame) {
        Icon icon(tray_manager::CreateTrayIcon(sources[frame], size, size));
        auto pixels = ReadIcon(icon.get(), size, size);
        DrawSample(graphics, pixels, x + 50 + frame * 220, y, size);
      }
    }
  }
  Require(sheet.Save((output / L"original-reminder-contact-sheet.png").c_str(),
                      &encoder) == Gdiplus::Ok,
          "Could not save original reminder contact sheet");
}

void SaveMotionSheet(const std::filesystem::path& output, const CLSID& encoder,
                     const std::array<HICON, 2>& sources) {
  Gdiplus::Bitmap sheet(1160, 760, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&sheet);
  graphics.Clear(Gdiplus::Color(255, 235, 237, 241));
  Label(graphics, L"Original DingDong IP - full-size rest and visible whole-IP rocking",
        20, 12, Gdiplus::Color(255, 25, 28, 36), 20);
  Label(graphics, L"80 ms x 8 frames, then 1500 ms full-size rest. Each cell: actual pixels and 64 px detail.",
        20, 43, Gdiplus::Color(255, 62, 66, 78));
  const std::array<const wchar_t*, 3> labels = {
      L"Full-size rest", L"Left -18 degrees", L"Right +18 degrees"};
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
    for (size_t state = 0; state < labels.size(); ++state) {
      Label(graphics, labels[state], x + 24 + state * 174, 116, foreground);
    }
    for (size_t row = 0; row < kSizes.size(); ++row) {
      const int size = kSizes[row];
      const float y = 146.0f + static_cast<float>(row) * 94.0f;
      const std::wstring label = std::to_wstring(size) + L" px";
      Label(graphics, label.c_str(), x + 8, y + 68, foreground);
      for (size_t state = 0; state < labels.size(); ++state) {
        Icon icon(state == 0
                      ? tray_manager::CreateTrayIcon(sources[0], size, size)
                      : tray_manager::CreateTrayIconMotionFrame(
                            sources[(state - 1) % 2], size, size, state - 1));
        auto pixels = ReadIcon(icon.get(), size, size);
        DrawSample(graphics, pixels, x + 15 + state * 174, y, size);
      }
    }
  }
  Require(sheet.Save((output / L"original-ip-rocking-contact-sheet.png").c_str(),
                      &encoder) == Gdiplus::Ok,
          "Could not save rocking contact sheet");
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
    const std::filesystem::path resources =
        argc > 2 ? argv[2] : L"windows\\runner\\resources";
    std::filesystem::create_directories(output);
    const CLSID encoder = PngEncoder();
    // Load exactly the same repository ICOs and 64 px source sizes as SetIcon.
    Icon first(static_cast<HICON>(LoadImageW(
        nullptr, (resources / L"tray_icon_adaptive_unread.ico").c_str(),
        IMAGE_ICON, 64, 64, LR_LOADFROMFILE)));
    Icon second(static_cast<HICON>(LoadImageW(
        nullptr, (resources / L"tray_icon_adaptive_unread2.ico").c_str(),
        IMAGE_ICON, 64, 64, LR_LOADFROMFILE)));
    const std::array<HICON, 2> sources = {first.get(), second.get()};
    Require(tray_manager::CreateTrayIcon(nullptr, 16, 16) == nullptr &&
                tray_manager::CreateTrayIcon(first.get(), 0, 16) == nullptr &&
                tray_manager::CreateTrayIcon(first.get(), 16, -1) == nullptr,
            "Null sources and invalid dimensions must be rejected");
    Require(tray_manager::CreateTrayIconMotionFrame(nullptr, 16, 16, 0) == nullptr &&
                tray_manager::CreateTrayIconMotionFrame(first.get(), 0, 16, 0) == nullptr &&
                tray_manager::CreateTrayIconMotionFrame(first.get(), 16, 16, 8) == nullptr,
            "Motion renderer must reject invalid sources, sizes and indices");
    int generated = 0;
    for (int size : kSizes) {
      std::array<Pixels, 2> frames{};
      for (size_t frame = 0; frame < sources.size(); ++frame) {
        Icon icon(tray_manager::CreateTrayIcon(sources[frame], size, size));
        frames[frame] = ReadIcon(icon.get(), size, size);
        auto bitmap = BitmapFrom(frames[frame]);
        const std::wstring file = L"original-reminder-frame-" +
            std::to_wstring(frame + 1) + L"-" + std::to_wstring(size) + L"px.png";
        Require(bitmap->Save((output / file).c_str(), &encoder) == Gdiplus::Ok,
                "Could not save original native icon PNG");
        CheckOriginalArtwork(frames[frame]);
        ++generated;
      }
      Require(DifferentPixels(frames[0], frames[1]) >= 2,
              "Original bell-shake frames must remain distinct");
      const double coverage_ratio =
          static_cast<double>(AlphaSum(frames[1])) / AlphaSum(frames[0]);
      Require(coverage_ratio > 0.90 && coverage_ratio < 1.10,
              "Original animation must keep the IP visible");
      std::array<Pixels, tray_manager::kTrayWiggleAngles.size()> motion{};
      for (size_t frame = 0; frame < motion.size(); ++frame) {
        Icon icon(tray_manager::CreateTrayIconMotionFrame(
            sources[frame % 2], size, size, frame));
        motion[frame] = ReadIcon(icon.get(), size, size);
        auto bitmap = BitmapFrom(motion[frame]);
        const std::wstring file = L"motion-frame-" + std::to_wstring(frame + 1) +
            L"-" + std::to_wstring(size) + L"px.png";
        Require(bitmap->Save((output / file).c_str(), &encoder) == Gdiplus::Ok,
                "Could not save original IP motion PNG");
        CheckOriginalArtwork(motion[frame], false);
        const double visible_ratio =
            static_cast<double>(AlphaSum(motion[frame])) / AlphaSum(frames[0]);
        Require(visible_ratio > 0.55 && visible_ratio <= 1.05,
                "Motion frame made the original IP too small or clipped");
        ++generated;
      }
      Require(DifferentPixels(motion[0], motion[1]) >=
                  static_cast<size_t>(size * size / 8),
              "Whole-IP rocking must visibly change at least 12.5% of pixels");
      Require(std::abs(AlphaCentroidX(motion[1]) - AlphaCentroidX(motion[0])) >=
                  size * 0.04,
              "Whole-IP movement must include visible lateral travel");
    }
    {
      Icon rectangular(tray_manager::CreateTrayIcon(first.get(), 32, 20));
      ReadIcon(rectangular.get(), 32, 20);
    }
    const DWORD gdi_before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
    const DWORD user_before = GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS);
    for (int index = 0; index < 300; ++index) {
      Icon icon(tray_manager::CreateTrayIconMotionFrame(
          sources[index % 2], 16, 16, index % tray_manager::kTrayWiggleAngles.size()));
    }
    Require(GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS) == gdi_before &&
                GetGuiResources(GetCurrentProcess(), GR_USEROBJECTS) == user_before,
            "Repeated original HICON rendering leaked a GDI or USER object");
    SaveSheet(output, encoder, sources);
    SaveMotionSheet(output, encoder, sources);
    std::cout << "PASS: " << generated
              << " original asset HICONs across six DPI sizes, two rest and eight rocking frames\n"
              << "PASS: physical dimensions, transparent corners, antialiasing, original palette\n"
              << "PASS: distinct original frames, visible alpha coverage, rectangular input\n"
              << "PASS: whole-IP pixel changes >=12.5%, lateral travel >=4% of cell\n"
              << "PASS: no GDI or USER object growth after 300 rendering/destruction cycles\n";
    std::wcout << L"Assets: " << std::filesystem::absolute(resources).wstring()
               << L"\nArtifacts: " << std::filesystem::absolute(output).wstring()
               << L"\n";
  } catch (const std::exception& error) {
    std::cerr << "FAIL: " << error.what() << "\n";
    result = 1;
  }
  Gdiplus::GdiplusShutdown(gdiplus_token);
  return result;
}
