#include "tray_visual.h"

#include <algorithm>
#include <cmath>

using std::max;
using std::min;

#pragma warning(push)
#pragma warning(disable : 4458)
#include <gdiplus.h>
#pragma warning(pop)

#include <memory>

namespace tray_manager {
namespace {

class GdiplusRuntime {
 public:
  GdiplusRuntime() {
    Gdiplus::GdiplusStartupInput input;
    ready_ = Gdiplus::GdiplusStartup(&token_, &input, nullptr) == Gdiplus::Ok;
  }

  ~GdiplusRuntime() {
    if (ready_) {
      Gdiplus::GdiplusShutdown(token_);
    }
  }

  bool ready() const { return ready_; }

 private:
  ULONG_PTR token_ = 0;
  bool ready_ = false;
};

struct AlphaBounds {
  int left;
  int top;
  int right;
  int bottom;
};

GdiplusRuntime& Runtime() {
  static GdiplusRuntime runtime;
  return runtime;
}

AlphaBounds FindAlphaBounds(Gdiplus::Bitmap& bitmap) {
  AlphaBounds bounds{static_cast<int>(bitmap.GetWidth()),
                     static_cast<int>(bitmap.GetHeight()), 0, 0};
  for (UINT y = 0; y < bitmap.GetHeight(); ++y) {
    for (UINT x = 0; x < bitmap.GetWidth(); ++x) {
      Gdiplus::Color color;
      if (bitmap.GetPixel(x, y, &color) == Gdiplus::Ok &&
          color.GetAlpha() > 8) {
        bounds.left = std::min(bounds.left, static_cast<int>(x));
        bounds.top = std::min(bounds.top, static_cast<int>(y));
        bounds.right = std::max(bounds.right, static_cast<int>(x) + 1);
        bounds.bottom = std::max(bounds.bottom, static_cast<int>(y) + 1);
      }
    }
  }
  if (bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
    return {0, 0, static_cast<int>(bitmap.GetWidth()),
            static_cast<int>(bitmap.GetHeight())};
  }
  return bounds;
}

}  // namespace

HICON CreateTrayIcon(HICON source_icon, int width, int height) {
  if (source_icon == nullptr || width <= 0 || height <= 0 ||
      !Runtime().ready()) {
    return nullptr;
  }

  std::unique_ptr<Gdiplus::Bitmap> source(
      Gdiplus::Bitmap::FromHICON(source_icon));
  if (source == nullptr || source->GetLastStatus() != Gdiplus::Ok) {
    return nullptr;
  }

  const AlphaBounds bounds = FindAlphaBounds(*source);
  Gdiplus::Bitmap canvas(width, height, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&canvas);
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
  graphics.SetCompositingMode(Gdiplus::CompositingModeSourceOver);
  graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
  graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);

  const float side = std::min(width, height) * kTrayArtOccupancy;
  const float left = (width - side) / 2.0f;
  const float top = (height - side) / 2.0f;
  graphics.DrawImage(
      source.get(), Gdiplus::RectF(left, top, side, side),
      static_cast<Gdiplus::REAL>(bounds.left),
      static_cast<Gdiplus::REAL>(bounds.top),
      static_cast<Gdiplus::REAL>(bounds.right - bounds.left),
      static_cast<Gdiplus::REAL>(bounds.bottom - bounds.top),
      Gdiplus::UnitPixel);

  HICON icon = nullptr;
  return canvas.GetHICON(&icon) == Gdiplus::Ok ? icon : nullptr;
}

HICON CreateReminderTrayIcon(int width, int height, DWORD rgb, bool attention,
                             bool dimmed) {
  if (width <= 0 || height <= 0 || !Runtime().ready()) return nullptr;
  Gdiplus::Bitmap canvas(width, height, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&canvas);
  graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.ScaleTransform(width / 16.0f, height / 16.0f);
  const double intensity = dimmed ? 0.88 : 1.0;
  const BYTE red = static_cast<BYTE>(((rgb >> 16) & 0xFF) * intensity);
  const BYTE green = static_cast<BYTE>(((rgb >> 8) & 0xFF) * intensity);
  const BYTE blue = static_cast<BYTE>((rgb & 0xFF) * intensity);
  Gdiplus::SolidBrush background(Gdiplus::Color(255, red, green, blue));
  graphics.FillEllipse(&background, 0.5f, 0.5f, 15.0f, 15.0f);
  const auto linear = [](BYTE value) {
    const double channel = value / 255.0;
    return channel <= 0.04045 ? channel / 12.92 : std::pow((channel + 0.055) / 1.055, 2.4);
  };
  const bool dark_text = 0.2126 * linear(red) + 0.7152 * linear(green) +
                         0.0722 * linear(blue) > 0.179;
  const auto foreground = dark_text ? Gdiplus::Color(255, 0, 0, 0)
                                    : Gdiplus::Color(255, 255, 255, 255);
  Gdiplus::Pen pen(foreground, 1.8f);
  pen.SetStartCap(Gdiplus::LineCapRound);
  pen.SetEndCap(Gdiplus::LineCapRound);
  pen.SetLineJoin(Gdiplus::LineJoinRound);
  if (attention) {
    graphics.DrawLine(&pen, 8.0f, 4.0f, 8.0f, 8.7f);
    Gdiplus::SolidBrush dot(foreground);
    graphics.FillEllipse(&dot, 7.1f, 10.5f, 1.8f, 1.8f);
  } else {
    Gdiplus::PointF points[] = {{4.3f, 8.1f}, {7.0f, 10.8f}, {11.9f, 5.4f}};
    graphics.DrawLines(&pen, points, 3);
  }
  HICON icon = nullptr;
  return canvas.GetHICON(&icon) == Gdiplus::Ok ? icon : nullptr;
}

}  // namespace tray_manager
