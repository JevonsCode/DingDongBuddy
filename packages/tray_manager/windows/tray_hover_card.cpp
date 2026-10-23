#include "tray_hover_card.h"

#include <algorithm>
#include <cmath>
#include <utility>

using std::max;
using std::min;

#pragma warning(push)
#pragma warning(disable : 4458)
#include <gdiplus.h>
#pragma warning(pop)

#include <shellscalingapi.h>

namespace tray_manager {
namespace {

constexpr wchar_t kWindowClass[] = L"DingDong.TrayReminderPreview";
constexpr UINT_PTR kHoverTimer = 1;
constexpr UINT kPollIntervalMs = 50;
constexpr ULONGLONG kDwellMs = 400;
constexpr ULONGLONG kLeaveGraceMs = 220;
constexpr int kShadowMargin = 12;
constexpr int kBodyTop = 10;
constexpr int kRowsTop = 46;
constexpr int kRowHeight = 30;
constexpr int kFooterHeight = 40;
constexpr size_t kVisibleRows = 4;

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

GdiplusRuntime& Runtime() {
  static GdiplusRuntime runtime;
  return runtime;
}

int Scale(int value, UINT dpi) {
  return MulDiv(value, static_cast<int>(dpi), USER_DEFAULT_SCREEN_DPI);
}

Gdiplus::Color FromColorRef(COLORREF color) {
  return Gdiplus::Color(255, GetRValue(color), GetGValue(color), GetBValue(color));
}

bool SystemIsDark() {
  DWORD light = 1;
  DWORD bytes = sizeof(light);
  return RegGetValueW(
             HKEY_CURRENT_USER,
             L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
             L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr, &light,
             &bytes) == ERROR_SUCCESS &&
         light == 0;
}

void RoundedPath(Gdiplus::GraphicsPath* path, const Gdiplus::RectF& rect,
                 float radius) {
  const float diameter = radius * 2;
  path->AddArc(rect.X, rect.Y, diameter, diameter, 180, 90);
  path->AddArc(rect.GetRight() - diameter, rect.Y, diameter, diameter, 270, 90);
  path->AddArc(rect.GetRight() - diameter, rect.GetBottom() - diameter,
               diameter, diameter, 0, 90);
  path->AddArc(rect.X, rect.GetBottom() - diameter, diameter, diameter, 90, 90);
  path->CloseFigure();
}

void DrawLabel(Gdiplus::Graphics* graphics, const std::wstring& text,
              const Gdiplus::RectF& bounds, float size,
              const Gdiplus::Color& color, bool bold = false,
              Gdiplus::StringAlignment alignment = Gdiplus::StringAlignmentNear) {
  Gdiplus::Font font(L"Segoe UI", size,
                      bold ? Gdiplus::FontStyleBold : Gdiplus::FontStyleRegular,
                      Gdiplus::UnitPixel);
  Gdiplus::StringFormat format;
  format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
  format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  format.SetAlignment(alignment);
  Gdiplus::SolidBrush brush(color);
  graphics->DrawString(text.c_str(), static_cast<INT>(text.size()), &font,
                       bounds, &format, &brush);
}

// Respect each taskbar edge. An icon in Explorer's overflow panel is inside
// the work area, so prefer above it and use the other side if space is tight.
RECT PlaceCard(const RECT& anchor, const RECT& work_area, SIZE size, int gap,
                int margin) {
  const LONG center_x = anchor.left + (anchor.right - anchor.left) / 2;
  const LONG center_y = anchor.top + (anchor.bottom - anchor.top) / 2;
  LONG x = anchor.right - size.cx;
  LONG y = anchor.top - gap - size.cy;
  if (center_x < work_area.left) {
    x = anchor.right + gap;
    y = center_y - size.cy / 2;
  } else if (center_x >= work_area.right) {
    x = anchor.left - gap - size.cx;
    y = center_y - size.cy / 2;
  } else if (center_y < work_area.top ||
             (y < work_area.top + margin &&
              anchor.bottom + gap + size.cy <= work_area.bottom - margin)) {
    y = anchor.bottom + gap;
  }
  const LONG min_x = work_area.left + margin;
  const LONG min_y = work_area.top + margin;
  const LONG max_x = std::max(min_x, work_area.right - margin - size.cx);
  const LONG max_y = std::max(min_y, work_area.bottom - margin - size.cy);
  x = std::clamp(x, min_x, max_x);
  y = std::clamp(y, min_y, max_y);
  return {x, y, x + size.cx, y + size.cy};
}

}  // namespace

TrayHoverCard::TrayHoverCard(HWND owner, std::function<void()> on_click,
                             std::function<void(bool)> on_visibility_changed)
    : owner_(owner),
      on_click_(std::move(on_click)),
      on_visibility_changed_(std::move(on_visibility_changed)) {}

TrayHoverCard::~TrayHoverCard() {
  Reset();
  if (window_ != nullptr) {
    DestroyWindow(window_);
  }
}

void TrayHoverCard::SetPreview(ReminderPreview preview) {
  preview_ = std::move(preview);
  if (preview_.total_count <= 0) {
    Reset();
  } else if (visible_) {
    RECT anchor;
    if (!ReadAnchor(&anchor) || !Show(anchor)) {
      Reset();
    }
  }
}

void TrayHoverCard::SetEnabled(bool enabled) {
  enabled_ = enabled;
  if (!enabled_) {
    Reset();
  }
}

bool TrayHoverCard::EnsureWindow() {
  if (window_ != nullptr) {
    return true;
  }
  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = WindowProc;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.hCursor = LoadCursorW(nullptr, IDC_HAND);
  window_class.lpszClassName = kWindowClass;
  if (RegisterClassExW(&window_class) == 0 &&
      GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return false;
  }
  window_ = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE | WS_EX_TOPMOST | WS_EX_LAYERED,
      kWindowClass, L"DingDong", WS_POPUP, 0, 0, 0, 0, owner_, nullptr,
      window_class.hInstance, this);
  return window_ != nullptr;
}

bool TrayHoverCard::ReadAnchor(RECT* rect) const {
  return SUCCEEDED(Shell_NotifyIconGetRect(&identifier_, rect)) &&
         rect->right > rect->left && rect->bottom > rect->top;
}

void TrayHoverCard::OnTrayMouseMove(
    const NOTIFYICONIDENTIFIER& identifier) {
  if (!enabled_ || preview_.total_count <= 0) {
    return;
  }
  identifier_ = identifier;
  if (!EnsureWindow()) {
    return;
  }
  if (!timer_active_) {
    entered_at_ = GetTickCount64();
    left_at_ = 0;
    if (SetTimer(window_, kHoverTimer, kPollIntervalMs, nullptr) == 0) {
      return;
    }
    timer_active_ = true;
  }
  PollPointer();
}

bool TrayHoverCard::PointerIsInside(const POINT& point) const {
  return visible_ && PtInRect(&body_bounds_, point);
}

void TrayHoverCard::PollPointer() {
  RECT anchor;
  POINT point;
  if (!enabled_ || preview_.total_count <= 0 || !ReadAnchor(&anchor) ||
      !GetCursorPos(&point)) {
    Reset();
    return;
  }
  const bool on_icon = PtInRect(&anchor, point) != FALSE;
  const bool on_card = PointerIsInside(point);
  const ULONGLONG now = GetTickCount64();
  if (!on_card && ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) != 0 ||
                   (GetAsyncKeyState(VK_RBUTTON) & 0x8000) != 0 ||
                   (GetAsyncKeyState(VK_MBUTTON) & 0x8000) != 0)) {
    Dismiss();
  }
  if (!on_icon && !on_card) {
    if (!visible_ || dismissed_until_leave_) {
      Reset();
    } else if (left_at_ == 0) {
      left_at_ = now;
    } else if (now - left_at_ >= kLeaveGraceMs) {
      Reset();
    }
    return;
  }
  left_at_ = 0;
  if (on_icon && !visible_ && !dismissed_until_leave_ &&
      now - entered_at_ >= kDwellMs && !Show(anchor)) {
    Reset();
  }
}

void TrayHoverCard::Dismiss() {
  Hide();
  dismissed_until_leave_ = timer_active_;
  pressed_ = false;
}

void TrayHoverCard::Reset() {
  if (window_ != nullptr && timer_active_) {
    KillTimer(window_, kHoverTimer);
  }
  timer_active_ = false;
  dismissed_until_leave_ = false;
  entered_at_ = 0;
  left_at_ = 0;
  pressed_ = false;
  Hide();
}

void TrayHoverCard::Hide() {
  if (!visible_) {
    return;
  }
  visible_ = false;
  ShowWindow(window_, SW_HIDE);
  if (on_visibility_changed_) {
    on_visibility_changed_(false);
  }
}

bool TrayHoverCard::Show(const RECT& anchor) {
  if (!Runtime().ready() || !EnsureWindow()) {
    return false;
  }
  HMONITOR monitor = MonitorFromRect(&anchor, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!GetMonitorInfoW(monitor, &monitor_info)) {
    return false;
  }
  UINT dpi = USER_DEFAULT_SCREEN_DPI;
  UINT dpi_y = dpi;
  if (FAILED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi, &dpi_y)) ||
      dpi == 0) {
    dpi = USER_DEFAULT_SCREEN_DPI;
  }
  const RECT& work = monitor_info.rcWork;
  const int max_width = MulDiv(work.right - work.left, 96,
                               static_cast<int>(dpi)) - kShadowMargin * 2 - 12;
  const int max_height = MulDiv(work.bottom - work.top, 96,
                                static_cast<int>(dpi)) - kShadowMargin * 2 - 12;
  // A very small work area keeps the accessible shell tooltip as fallback.
  if (max_width < 240 || max_height < kRowsTop + kFooterHeight) {
    return false;
  }
  const int body_width = std::min(max_width, 280);
  const int rows = std::min(
      static_cast<int>(std::min(preview_.rows.size(), kVisibleRows)),
      (max_height - kRowsTop - kFooterHeight) / kRowHeight);
  const int body_height = kRowsTop + rows * kRowHeight + kFooterHeight;
  const SIZE size = {Scale(body_width + kShadowMargin * 2, dpi),
                     Scale(body_height + kShadowMargin * 2, dpi)};
  const RECT bounds = PlaceCard(anchor, work, size, Scale(6, dpi), Scale(6, dpi));
  if (!Render(bounds, dpi, body_width, body_height)) {
    return false;
  }
  body_bounds_ = {bounds.left + Scale(kShadowMargin, dpi),
                   bounds.top + Scale(kBodyTop, dpi),
                   bounds.left + Scale(kShadowMargin + body_width, dpi),
                   bounds.top + Scale(kBodyTop + body_height, dpi)};
  std::wstring accessible_name = L"DingDong. " + preview_.title + L". " +
                                 std::to_wstring(preview_.total_count) + L". " +
                                 preview_.subtitle;
  for (size_t index = 0; index < static_cast<size_t>(rows);
       ++index) {
    const auto& row = preview_.rows[index];
    accessible_name += L". " + row.name + L": " +
                       (row.count ? std::to_wstring(*row.count) : L"?");
  }
  accessible_name += L". " + preview_.footer;
  SetWindowTextW(window_, accessible_name.c_str());
  SetWindowPos(window_, HWND_TOPMOST, bounds.left, bounds.top,
                bounds.right - bounds.left, bounds.bottom - bounds.top,
                SWP_NOACTIVATE | SWP_SHOWWINDOW);
  if (!visible_) {
    visible_ = true;
    if (on_visibility_changed_) {
      on_visibility_changed_(true);
    }
  }
  return true;
}

bool TrayHoverCard::Render(const RECT& bounds, UINT dpi, int body_width,
                            int body_height) {
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;
  BITMAPINFO bitmap_info = {};
  bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmap_info.bmiHeader.biWidth = width;
  bitmap_info.bmiHeader.biHeight = -height;
  bitmap_info.bmiHeader.biPlanes = 1;
  bitmap_info.bmiHeader.biBitCount = 32;
  bitmap_info.bmiHeader.biCompression = BI_RGB;
  void* pixels = nullptr;
  HBITMAP dib = CreateDIBSection(nullptr, &bitmap_info, DIB_RGB_COLORS,
                                  &pixels, nullptr, 0);
  HDC memory = CreateCompatibleDC(nullptr);
  if (dib == nullptr || memory == nullptr) {
    if (dib != nullptr) DeleteObject(dib);
    if (memory != nullptr) DeleteDC(memory);
    return false;
  }
  HGDIOBJ previous = SelectObject(memory, dib);
  {
    Gdiplus::Bitmap canvas(width, height, width * 4, PixelFormat32bppPARGB,
                            static_cast<BYTE*>(pixels));
    Gdiplus::Graphics graphics(&canvas);
    graphics.Clear(Gdiplus::Color(0, 0, 0, 0));
    graphics.ScaleTransform(static_cast<float>(dpi) / 96,
                              static_cast<float>(dpi) / 96);
    graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
    graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    const bool dark = SystemIsDark();
    HIGHCONTRASTW contrast = {};
    contrast.cbSize = sizeof(contrast);
    const bool high_contrast =
        SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
        (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;
    const Gdiplus::Color background = high_contrast
        ? FromColorRef(GetSysColor(COLOR_WINDOW))
        : (dark ? Gdiplus::Color(255, 32, 35, 41)
                : Gdiplus::Color(255, 253, 253, 254));
    const Gdiplus::Color foreground = high_contrast
        ? FromColorRef(GetSysColor(COLOR_WINDOWTEXT))
        : (dark ? Gdiplus::Color(255, 245, 247, 250)
                : Gdiplus::Color(255, 29, 35, 44));
    const Gdiplus::Color secondary = high_contrast
        ? foreground
        : (dark ? Gdiplus::Color(255, 168, 177, 190)
                : Gdiplus::Color(255, 102, 113, 128));
    const Gdiplus::Color border = high_contrast
        ? foreground
        : (dark ? Gdiplus::Color(255, 65, 71, 81)
                : Gdiplus::Color(255, 220, 225, 233));
    const Gdiplus::Color accent = high_contrast
        ? foreground
        : (dark ? Gdiplus::Color(255, 247, 185, 86)
                : Gdiplus::Color(255, 169, 102, 20));
    const Gdiplus::RectF body(static_cast<float>(kShadowMargin),
                               static_cast<float>(kBodyTop),
                               static_cast<float>(body_width),
                               static_cast<float>(body_height));
    for (int spread = 8; spread > 0; --spread) {
      Gdiplus::GraphicsPath shadow;
      const float expansion = spread * 0.8f;
      RoundedPath(&shadow,
                    Gdiplus::RectF(body.X - expansion,
                                    body.Y + 3 - expansion,
                                    body.Width + expansion * 2,
                                    body.Height + expansion * 2),
                    12 + expansion);
      Gdiplus::SolidBrush shadow_brush(Gdiplus::Color(dark ? 7 : 4, 0, 0, 0));
      graphics.FillPath(&shadow_brush, &shadow);
    }
    Gdiplus::GraphicsPath body_path;
    RoundedPath(&body_path, body, 12);
    Gdiplus::SolidBrush background_brush(background);
    Gdiplus::Pen border_pen(border, 1);
    graphics.FillPath(&background_brush, &body_path);
    graphics.DrawPath(&border_pen, &body_path);
    graphics.TranslateTransform(body.X, body.Y);

    const float content_width = static_cast<float>(body_width - 32);
    DrawLabel(&graphics, preview_.title,
               Gdiplus::RectF(16, 10, content_width - 62, 26),
               15, foreground, true);
    const std::wstring total = preview_.total_count > 999
                                   ? L"999+"
                                   : std::to_wstring(preview_.total_count);
    Gdiplus::GraphicsPath total_pill;
    RoundedPath(&total_pill,
                  Gdiplus::RectF(static_cast<float>(body_width - 66), 12, 50, 23),
                  11.5f);
    Gdiplus::SolidBrush total_background(high_contrast
        ? background
        : Gdiplus::Color(35, accent.GetR(), accent.GetG(), accent.GetB()));
    graphics.FillPath(&total_background, &total_pill);
    if (high_contrast) {
      graphics.DrawPath(&border_pen, &total_pill);
    }
    DrawLabel(&graphics, total,
               Gdiplus::RectF(static_cast<float>(body_width - 66), 11, 50, 24),
               13, accent, true, Gdiplus::StringAlignmentCenter);
    Gdiplus::Pen divider(border, 0.7f);
    graphics.DrawLine(&divider, 16.0f, 43.0f,
                        static_cast<float>(body_width - 16), 43.0f);
    const size_t count = std::min(
        std::min(preview_.rows.size(), kVisibleRows),
        static_cast<size_t>((body_height - kRowsTop - kFooterHeight) / kRowHeight));
    for (size_t index = 0; index < count; ++index) {
      const auto& row = preview_.rows[index];
      const float y = static_cast<float>(kRowsTop + index * kRowHeight);
      const Gdiplus::Color dot = high_contrast ? foreground : FromColorRef(row.color);
      Gdiplus::SolidBrush dot_brush(dot);
      graphics.FillEllipse(&dot_brush, 17.0f, y + 11, 8.0f, 8.0f);
      DrawLabel(&graphics, row.name, Gdiplus::RectF(34, y, content_width - 70, 30),
                 13, foreground);
      DrawLabel(&graphics, row.count ? std::to_wstring(*row.count) : L"?",
                 Gdiplus::RectF(static_cast<float>(body_width - 70), y, 54, 30),
                 13, foreground, true, Gdiplus::StringAlignmentFar);
    }
    const float footer_line = static_cast<float>(kRowsTop + count * kRowHeight + 6);
    graphics.DrawLine(&divider, 16.0f, footer_line,
                        static_cast<float>(body_width - 16), footer_line);
    const bool overflow = preview_.rows.size() > count;
    DrawLabel(&graphics, preview_.footer,
               Gdiplus::RectF(16, footer_line + 6,
                               content_width - (overflow ? 62 : 20), 22),
               11, secondary);
    if (overflow) {
      DrawLabel(&graphics,
                 L"+" + std::to_wstring(preview_.rows.size() - count),
                 Gdiplus::RectF(static_cast<float>(body_width - 76),
                                 footer_line + 6, 34, 22),
                 10, secondary, true, Gdiplus::StringAlignmentFar);
    }
    DrawLabel(&graphics, L"\x203A",
               Gdiplus::RectF(static_cast<float>(body_width - 30),
                               footer_line + 4, 14, 23),
               18, secondary, false, Gdiplus::StringAlignmentFar);
  }
  POINT destination = {bounds.left, bounds.top};
  POINT source = {0, 0};
  SIZE size = {width, height};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  const BOOL updated = UpdateLayeredWindow(window_, nullptr, &destination,
                                            &size, memory, &source, 0, &blend,
                                            ULW_ALPHA);
  SelectObject(memory, previous);
  DeleteObject(dib);
  DeleteDC(memory);
  return updated != FALSE;
}

LRESULT CALLBACK TrayHoverCard::WindowProc(HWND window, UINT message,
                                           WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<TrayHoverCard*>(GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    self = static_cast<TrayHoverCard*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
  }
  if (self == nullptr) {
    return DefWindowProcW(window, message, wparam, lparam);
  }
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_ERASEBKGND:
      return 1;
    case WM_TIMER:
      if (wparam == kHoverTimer) {
        self->PollPointer();
        return 0;
      }
      break;
    case WM_NCHITTEST: {
      POINT point = {static_cast<short>(LOWORD(lparam)),
                     static_cast<short>(HIWORD(lparam))};
      return self->PointerIsInside(point) ? HTCLIENT : HTTRANSPARENT;
    }
    case WM_LBUTTONDOWN:
      self->pressed_ = true;
      return 0;
    case WM_LBUTTONUP:
      if (self->pressed_) {
        self->Dismiss();
        if (self->on_click_) {
          self->on_click_();
        }
      }
      return 0;
    case WM_RBUTTONDOWN:
    case WM_MBUTTONDOWN:
      self->Dismiss();
      return 0;
    case WM_CLOSE:
    case WM_CANCELMODE:
    case WM_DISPLAYCHANGE:
    case WM_SETTINGCHANGE:
    case WM_THEMECHANGED:
      self->Reset();
      return 0;
    case WM_NCDESTROY:
      self->Reset();
      self->window_ = nullptr;
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace tray_manager
