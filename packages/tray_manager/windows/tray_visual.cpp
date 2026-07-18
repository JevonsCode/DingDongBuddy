#include "tray_visual.h"

#include <algorithm>

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

}  // namespace tray_manager
