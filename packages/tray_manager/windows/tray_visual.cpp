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

Gdiplus::Color FaceColor(DWORD rgb) {
  const auto linear = [](BYTE value) {
    const double channel = value / 255.0;
    return channel <= 0.04045 ? channel / 12.92
                              : std::pow((channel + 0.055) / 1.055, 2.4);
  };
  const double luminance =
      0.2126 * linear(static_cast<BYTE>((rgb >> 16) & 0xFF)) +
      0.7152 * linear(static_cast<BYTE>((rgb >> 8) & 0xFF)) +
      0.0722 * linear(static_cast<BYTE>(rgb & 0xFF));
  // Pick whichever ink has the greater WCAG contrast with the exact user RGB.
  return luminance > 0.179 ? Gdiplus::Color(255, 0, 0, 0)
                           : Gdiplus::Color(255, 255, 255, 255);
}

void RoundPen(Gdiplus::Pen& pen) {
  pen.SetStartCap(Gdiplus::LineCapRound);
  pen.SetEndCap(Gdiplus::LineCapRound);
  pen.SetLineJoin(Gdiplus::LineJoinRound);
}

void DrawBuddy(Gdiplus::Graphics& graphics, DWORD rgb, bool attention,
               bool alternate) {
  const Gdiplus::Color body_color(
      255, static_cast<BYTE>((rgb >> 16) & 0xFF),
      static_cast<BYTE>((rgb >> 8) & 0xFF), static_cast<BYTE>(rgb & 0xFF));
  Gdiplus::SolidBrush body(body_color);
  Gdiplus::SolidBrush ink(FaceColor(rgb));
  Gdiplus::Pen face(FaceColor(rgb), 1.05f);
  // Both rims are opaque: one remains distinct on either taskbar theme.
  Gdiplus::Pen light_rim(Gdiplus::Color(255, 250, 251, 255), 1.75f);
  Gdiplus::Pen dark_rim(Gdiplus::Color(255, 29, 31, 40), 0.8f);
  RoundPen(face);
  RoundPen(light_rim);
  RoundPen(dark_rim);

  // The second existing timer frame is a small bob and wink, never a fade.
  if (alternate) graphics.TranslateTransform(0.0f, 0.35f);

  const float antenna_x = attention ? 11.2f : 12.1f;
  const float antenna_y = attention ? 1.65f : 2.15f;
  graphics.DrawLine(&light_rim, 10.2f, 3.65f, antenna_x, antenna_y);
  graphics.DrawLine(&dark_rim, 10.2f, 3.65f, antenna_x, antenna_y);
  const Gdiplus::RectF antenna(antenna_x - 0.63f, antenna_y - 0.63f,
                              1.26f, 1.26f);
  graphics.FillEllipse(&body, antenna);
  graphics.DrawEllipse(&light_rim, antenna);
  graphics.DrawEllipse(&dark_rim, antenna);

  // A generous bubble and a short tail survive the physical 16 px tray size.
  Gdiplus::GraphicsPath bubble;
  bubble.StartFigure();
  bubble.AddBezier(4.5f, 3.4f, 5.7f, 3.2f, 10.7f, 3.2f, 11.8f, 3.4f);
  bubble.AddBezier(11.8f, 3.4f, 13.6f, 3.6f, 14.3f, 4.5f, 14.3f, 6.2f);
  bubble.AddLine(14.3f, 6.2f, 14.3f, 9.2f);
  bubble.AddBezier(14.3f, 9.2f, 14.3f, 11.1f, 13.4f, 12.1f, 11.5f, 12.3f);
  bubble.AddBezier(11.5f, 12.3f, 10.4f, 12.4f, 7.0f, 12.4f, 6.0f, 12.3f);
  bubble.AddLine(6.0f, 12.3f, 3.6f, 14.4f);
  bubble.AddLine(3.6f, 14.4f, 4.0f, 12.0f);
  bubble.AddBezier(4.0f, 12.0f, 2.4f, 11.6f, 1.7f, 10.7f, 1.7f, 9.1f);
  bubble.AddLine(1.7f, 9.1f, 1.7f, 6.2f);
  bubble.AddBezier(1.7f, 6.2f, 1.7f, 4.5f, 2.6f, 3.6f, 4.5f, 3.4f);
  bubble.CloseFigure();
  graphics.FillPath(&body, &bubble);
  graphics.DrawPath(&light_rim, &bubble);
  graphics.DrawPath(&dark_rim, &bubble);

  if (attention) {
    // Upright eyes looking toward the person give "waiting for you" a face.
    graphics.FillEllipse(&ink, 4.9f, 6.2f, 1.65f, 2.75f);
    if (alternate) {
      graphics.DrawBezier(&face, 9.1f, 8.0f, 9.5f, 7.35f, 10.2f, 7.35f,
                          10.65f, 8.0f);
    } else {
      graphics.FillEllipse(&ink, 9.2f, 6.2f, 1.65f, 2.75f);
    }
    graphics.DrawBezier(&face, 6.7f, 10.2f, 7.3f, 10.7f, 8.4f, 10.7f,
                        9.0f, 10.2f);
  } else {
    // Closed smiling eyes and a relaxed antenna signal calm completion.
    graphics.DrawBezier(&face, 4.75f, 8.0f, 5.1f, 6.9f, 6.15f, 6.9f,
                        6.5f, 8.0f);
    graphics.DrawBezier(&face, 9.15f, 8.0f, 9.5f, 6.9f, 10.55f, 6.9f,
                        10.9f, 8.0f);
    graphics.DrawBezier(&face, 6.35f, 9.85f, 7.1f, 11.15f, 8.7f, 11.15f,
                        9.45f, 9.85f);
  }
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
  // Supersampling keeps the eyes, tail and two-tone outline smooth at 100% DPI.
  // Larger inputs render directly, keeping this helper's allocation bounded.
  const int sampling = width <= 128 && height <= 128 ? 4 : 1;
  Gdiplus::Bitmap artwork(width * sampling, height * sampling,
                          PixelFormat32bppARGB);
  if (artwork.GetLastStatus() != Gdiplus::Ok) return nullptr;
  {
    Gdiplus::Graphics graphics(&artwork);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
    const float side = static_cast<float>(std::min(width, height) * sampling);
    graphics.TranslateTransform((width * sampling - side) / 2.0f,
                                (height * sampling - side) / 2.0f);
    graphics.ScaleTransform(side / 16.0f, side / 16.0f);
    DrawBuddy(graphics, rgb, attention, dimmed);
  }

  Gdiplus::Bitmap canvas(width, height, PixelFormat32bppARGB);
  if (canvas.GetLastStatus() != Gdiplus::Ok) return nullptr;
  {
    Gdiplus::Graphics graphics(&canvas);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.SetCompositingMode(Gdiplus::CompositingModeSourceCopy);
    // Bilinear area filtering avoids bicubic ringing that tints tiny interiors.
    graphics.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBilinear);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
    graphics.DrawImage(&artwork, Gdiplus::Rect(0, 0, width, height));
  }

  HICON icon = nullptr;
  return canvas.GetHICON(&icon) == Gdiplus::Ok ? icon : nullptr;
}

}  // namespace tray_manager
