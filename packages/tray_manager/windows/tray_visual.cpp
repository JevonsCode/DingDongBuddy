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

HICON CreateTrayIconMotionFrame(HICON source_icon, int width, int height,
                                size_t frame) {
  if (source_icon == nullptr || width <= 0 || height <= 0 ||
      frame >= kTrayWiggleAngles.size() || !Runtime().ready()) {
    return nullptr;
  }
  std::unique_ptr<Gdiplus::Bitmap> source(
      Gdiplus::Bitmap::FromHICON(source_icon));
  if (source == nullptr || source->GetLastStatus() != Gdiplus::Ok) {
    return nullptr;
  }
  const AlphaBounds bounds = FindAlphaBounds(*source);
  const float side = static_cast<float>(std::min(width, height));
  const float angle = kTrayWiggleAngles[frame];
  const float radians = angle * 3.14159265358979323846f / 180.0f;
  const float cosine = std::cos(radians);
  const float sine = std::sin(radians);
  float min_x = side;
  float max_x = -side;
  float min_y = side;
  float max_y = -side;
  // Fit the actual rotated silhouette, rather than an oversized square. This
  // leaves the original IP as large as possible during the visible rock.
  for (int y = bounds.top; y < bounds.bottom; ++y) {
    for (int x = bounds.left; x < bounds.right; ++x) {
      Gdiplus::Color color;
      if (source->GetPixel(x, y, &color) != Gdiplus::Ok ||
          color.GetAlpha() <= 8) {
        continue;
      }
      for (int corner = 0; corner < 4; ++corner) {
        const float px = ((x + (corner & 1) - bounds.left) /
                              static_cast<float>(bounds.right - bounds.left) -
                          0.5f) * side;
        const float py = ((y + (corner >> 1) - bounds.top) /
                              static_cast<float>(bounds.bottom - bounds.top) -
                          0.5f) * side;
        const float rx = px * cosine - py * sine;
        const float ry = px * sine + py * cosine;
        min_x = std::min(min_x, rx);
        max_x = std::max(max_x, rx);
        min_y = std::min(min_y, ry);
        max_y = std::max(max_y, ry);
      }
    }
  }
  const float offset_x = kTrayWiggleOffsets[frame] * side / 16.0f;
  const float margin = side / 64.0f;
  const float fit = std::min(
      1.0f, std::min((width - 2.0f * margin - 2.0f * std::abs(offset_x)) /
                        std::max(1.0f, max_x - min_x),
                    (height - 2.0f * margin) /
                        std::max(1.0f, max_y - min_y)));
  const float center_x = (min_x + max_x) / 2.0f;
  const float center_y = (min_y + max_y) / 2.0f;
  Gdiplus::Bitmap canvas(width, height, PixelFormat32bppARGB);
  if (canvas.GetLastStatus() != Gdiplus::Ok) return nullptr;
  {
    Gdiplus::Graphics graphics(&canvas);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
    Gdiplus::Matrix transform(fit * cosine, fit * sine, -fit * sine,
                              fit * cosine,
                              width / 2.0f + offset_x - fit * center_x,
                              height / 2.0f - fit * center_y);
    graphics.SetTransform(&transform);
    graphics.DrawImage(
        source.get(), Gdiplus::RectF(-side / 2.0f, -side / 2.0f, side, side),
        static_cast<Gdiplus::REAL>(bounds.left),
        static_cast<Gdiplus::REAL>(bounds.top),
        static_cast<Gdiplus::REAL>(bounds.right - bounds.left),
        static_cast<Gdiplus::REAL>(bounds.bottom - bounds.top),
        Gdiplus::UnitPixel);
  }
  HICON icon = nullptr;
  return canvas.GetHICON(&icon) == Gdiplus::Ok ? icon : nullptr;
}

}  // namespace tray_manager
