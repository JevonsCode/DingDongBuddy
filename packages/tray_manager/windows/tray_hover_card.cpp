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
constexpr int kBallDiameter = 16;
constexpr int kBallGap = 6;
constexpr int kCapsulePadding = 8;
constexpr int kBadgeGap = 2;
constexpr size_t kMaximumGroups = 64;

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

void DrawCount(Gdiplus::Graphics* graphics, const std::wstring& count,
              const Gdiplus::RectF& bounds, const Gdiplus::Color& color) {
  Gdiplus::Font font(L"Segoe UI", 12, Gdiplus::FontStyleBold,
                      Gdiplus::UnitPixel);
  Gdiplus::StringFormat format;
  format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  Gdiplus::SolidBrush brush(color);
  graphics->DrawString(count.c_str(), static_cast<INT>(count.size()), &font,
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

struct TrayHoverCard::Layout {
  int width = 0;
  int height = 0;
  RECT capsule = {};
  RECT badge = {};
  std::vector<POINT> ball_centers;
  std::wstring count_text;
  COLORREF primary_color = 0;
};

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
  if (preview_.total_count <= 0 || preview_.rows.empty()) {
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
  if (!enabled_ || preview_.total_count <= 0 || preview_.rows.empty()) {
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
  if (!visible_) {
    return false;
  }
  const auto inside_round_rect = [&point](const RECT& rect, double radius) {
    if (!PtInRect(&rect, point) || radius <= 0) {
      return false;
    }
    radius = std::min(radius,
                        std::min(rect.right - rect.left, rect.bottom - rect.top) / 2.0);
    const double x = std::clamp(static_cast<double>(point.x),
                                rect.left + radius, rect.right - radius);
    const double y = std::clamp(static_cast<double>(point.y),
                                rect.top + radius, rect.bottom - radius);
    const double dx = point.x - x;
    const double dy = point.y - y;
    return dx * dx + dy * dy <= radius * radius;
  };
  return inside_round_rect(body_bounds_, capsule_corner_radius_) ||
         inside_round_rect(badge_bounds_,
                            (badge_bounds_.right - badge_bounds_.left) / 2.0);
}

void TrayHoverCard::PollPointer() {
  RECT anchor;
  POINT point;
  if (!enabled_ || preview_.total_count <= 0 || preview_.rows.empty() ||
      !ReadAnchor(&anchor) ||
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

TrayHoverCard::Layout TrayHoverCard::MakeLayout(int max_width,
                                                int max_height) const {
  Layout layout;
  if (preview_.rows.empty() || preview_.rows.size() > kMaximumGroups ||
      max_width < 60) {
    return layout;
  }
  const auto& primary = preview_.rows.front();
  layout.count_text = primary.count && *primary.count >= 0
                          ? std::to_wstring(*primary.count)
                          : L"?";
  layout.primary_color = primary.color;
  const int badge_diameter = std::max(
      24, static_cast<int>(layout.count_text.size()) * 8 + 8);
  if (badge_diameter > max_width) {
    return Layout{};
  }
  const int count = static_cast<int>(preview_.rows.size());
  const int pitch = kBallDiameter + kBallGap;
  const int max_columns = std::min(
      count, (max_width - kCapsulePadding * 2 + kBallGap) / pitch);
  int columns = std::min(8, max_columns);
  if (columns <= 0) {
    return Layout{};
  }
  int rows = (count + columns - 1) / columns;
  int capsule_height = kCapsulePadding * 2 + rows * pitch - kBallGap;
  // Show every bounded input group. A short work area uses more columns;
  // ordinary four-group previews remain a single 98 x 32 DIP capsule.
  while (badge_diameter + kBadgeGap + capsule_height > max_height &&
         columns < max_columns) {
    ++columns;
    rows = (count + columns - 1) / columns;
    capsule_height = kCapsulePadding * 2 + rows * pitch - kBallGap;
  }
  if (badge_diameter + kBadgeGap + capsule_height > max_height) {
    return Layout{};
  }
  const int capsule_width = std::max(
      60, kCapsulePadding * 2 + columns * pitch - kBallGap);
  layout.width = std::max(capsule_width, badge_diameter);
  layout.height = badge_diameter + kBadgeGap + capsule_height;
  const int capsule_left = (layout.width - capsule_width) / 2;
  layout.capsule = {capsule_left, badge_diameter + kBadgeGap,
                    capsule_left + capsule_width, layout.height};
  const int badge_left = (layout.width - badge_diameter) / 2;
  layout.badge = {badge_left, 0, badge_left + badge_diameter, badge_diameter};
  for (int index = 0; index < count; ++index) {
    const int row = index / columns;
    const int column = index % columns;
    const int row_count = std::min(columns, count - row * columns);
    const int row_width = row_count * pitch - kBallGap;
    const int row_left = capsule_left + (capsule_width - row_width) / 2;
    layout.ball_centers.push_back(
        {row_left + column * pitch + kBallDiameter / 2,
         layout.capsule.top + kCapsulePadding + row * pitch + kBallDiameter / 2});
  }
  return layout;
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
  const Layout layout = MakeLayout(max_width, max_height);
  if (layout.ball_centers.empty()) {
    return false;
  }
  const SIZE size = {Scale(layout.width + kShadowMargin * 2, dpi),
                     Scale(layout.height + kShadowMargin * 2, dpi)};
  const RECT bounds = PlaceCard(anchor, work, size, Scale(6, dpi), Scale(6, dpi));
  if (!Render(bounds, dpi, layout)) {
    return false;
  }
  const auto screen_rect = [&bounds, dpi](const RECT& rect) -> RECT {
    return {bounds.left + Scale(kShadowMargin + rect.left, dpi),
            bounds.top + Scale(kBodyTop + rect.top, dpi),
            bounds.left + Scale(kShadowMargin + rect.right, dpi),
            bounds.top + Scale(kBodyTop + rect.bottom, dpi)};
  };
  body_bounds_ = screen_rect(layout.capsule);
  badge_bounds_ = screen_rect(layout.badge);
  capsule_corner_radius_ = Scale(16, dpi);
  // All wording is available to accessibility, never painted in the capsule.
  std::wstring accessible_name = L"DingDong. " + preview_.title + L". " +
                                 std::to_wstring(preview_.total_count) + L". " +
                                 preview_.subtitle;
  for (const auto& row : preview_.rows) {
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

bool TrayHoverCard::Render(const RECT& bounds, UINT dpi, const Layout& layout) {
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
    graphics.TranslateTransform(static_cast<float>(kShadowMargin),
                                  static_cast<float>(kBodyTop));
    const bool dark = SystemIsDark();
    HIGHCONTRASTW contrast = {};
    contrast.cbSize = sizeof(contrast);
    const bool high_contrast =
        SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(contrast), &contrast, 0) &&
        (contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;
    const Gdiplus::Color background = high_contrast
        ? FromColorRef(GetSysColor(COLOR_WINDOW))
        : (dark ? Gdiplus::Color(255, 41, 56, 64)
                : Gdiplus::Color(255, 255, 255, 255));
    const Gdiplus::Color border = high_contrast
        ? FromColorRef(GetSysColor(COLOR_WINDOWTEXT))
        : (dark ? Gdiplus::Color(255, 68, 87, 97)
                : Gdiplus::Color(255, 208, 208, 204));
    const auto rect_f = [](const RECT& rect) {
      return Gdiplus::RectF(static_cast<float>(rect.left),
                              static_cast<float>(rect.top),
                              static_cast<float>(rect.right - rect.left),
                              static_cast<float>(rect.bottom - rect.top));
    };
    const auto shadow = [&graphics, dark](const Gdiplus::RectF& rect, float radius) {
      for (int spread = 5; spread > 0; --spread) {
        const float expansion = spread * 0.7f;
        Gdiplus::GraphicsPath path;
        RoundedPath(&path,
                      Gdiplus::RectF(rect.X - expansion, rect.Y + 2 - expansion,
                                      rect.Width + expansion * 2,
                                      rect.Height + expansion * 2),
                      radius + expansion);
        Gdiplus::SolidBrush brush(Gdiplus::Color(dark ? 9 : 6, 0, 0, 0));
        graphics.FillPath(&brush, &path);
      }
    };
    const Gdiplus::RectF capsule = rect_f(layout.capsule);
    const Gdiplus::RectF badge = rect_f(layout.badge);
    shadow(capsule, 16);
    shadow(badge, badge.Width / 2);
    Gdiplus::GraphicsPath capsule_path;
    RoundedPath(&capsule_path, capsule, 16);
    Gdiplus::SolidBrush capsule_brush(background);
    Gdiplus::Pen outline(border, 1);
    graphics.FillPath(&capsule_brush, &capsule_path);
    graphics.DrawPath(&outline, &capsule_path);
    // Input order is the existing reminder priority order. Each group appears
    // once inside, including the first group whose color is repeated above.
    for (size_t index = 0; index < layout.ball_centers.size(); ++index) {
      const POINT& center = layout.ball_centers[index];
      Gdiplus::SolidBrush ball(FromColorRef(preview_.rows[index].color));
      graphics.FillEllipse(&ball,
                              static_cast<float>(center.x - kBallDiameter / 2),
                              static_cast<float>(center.y - kBallDiameter / 2),
                              static_cast<float>(kBallDiameter),
                              static_cast<float>(kBallDiameter));
    }
    const Gdiplus::Color primary = FromColorRef(layout.primary_color);
    Gdiplus::SolidBrush badge_brush(primary);
    graphics.FillEllipse(&badge_brush, badge);
    Gdiplus::Pen badge_outline(high_contrast ? border : Gdiplus::Color(70, 255, 255, 255), 1);
    graphics.DrawEllipse(&badge_outline, badge);
    const double lightness = 0.2126 * primary.GetR() + 0.7152 * primary.GetG() +
                             0.0722 * primary.GetB();
    const Gdiplus::Color count_color = lightness >= 155
        ? Gdiplus::Color(255, 24, 28, 32)
        : Gdiplus::Color(255, 255, 255, 255);
    // This is the only visible text: the FIRST group's exact count, or '?'.
    // total_count and all descriptive wording are intentionally unpainted.
    DrawCount(&graphics, layout.count_text, badge, count_color);
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
