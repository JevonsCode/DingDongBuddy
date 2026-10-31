#include "tray_hover_card.h"

#include <algorithm>
#include <cmath>
#include <iterator>
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
constexpr int kBallDiameter = 24;
constexpr int kBallGap = 6;
constexpr int kCapsulePadding = 8;
constexpr size_t kMaximumGroups = 64;
// Motion matches the web dock's pin stack: the capsule fades and rises, then
// each ball springs in from 80% scale, the one nearest the icon first.
constexpr UINT_PTR kAnimationTimer = 2;
constexpr UINT kFrameIntervalMs = 15;
constexpr ULONGLONG kFadeMs = 140;
constexpr ULONGLONG kSpringMs = 460;
constexpr ULONGLONG kStaggerMs = 35;
constexpr int kMaximumStaggerSteps = 8;
constexpr float kCapsuleTravel = 8;
constexpr float kBallTravel = 10;
constexpr double kBallStartScale = 0.8;
constexpr double kHoverGrowth = 0.12;

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

bool MotionEnabled() {
  BOOL enabled = TRUE;
  SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &enabled, 0);
  return enabled != FALSE;
}

double Progress(ULONGLONG now, ULONGLONG start, ULONGLONG delay,
                ULONGLONG duration) {
  if (now < start + delay) return 0;
  return std::min(1.0, static_cast<double>(now - start - delay) / duration);
}

double EaseOut(double t) { return 1 - std::pow(1 - t, 3); }

// An underdamped spring sampled from CSS linear() stops: it overshoots by
// about 4% and settles, which reads as softer than any cubic-bezier.
double Spring(double t) {
  static constexpr double kStops[][2] = {
      {0, 0},         {0.0105, 0.009}, {0.021, 0.035}, {0.044, 0.141},
      {0.129, 0.723}, {0.167, 0.938},  {0.204, 1.017}, {0.244, 1.041},
      {0.286, 1.036}, {0.372, 1.013},  {0.454, 0.998}, {1, 1}};
  for (size_t index = 1; index < std::size(kStops); ++index) {
    if (t <= kStops[index][0]) {
      const double* from = kStops[index - 1];
      const double* to = kStops[index];
      return from[1] + (to[1] - from[1]) * (t - from[0]) / (to[0] - from[0]);
    }
  }
  return 1;
}

POINT SlideToward(const RECT& anchor, const RECT& card) {
  if (card.top >= anchor.bottom) return {0, -1};
  if (card.right <= anchor.left) return {1, 0};
  if (card.left >= anchor.right) return {-1, 0};
  return {0, 1};
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
  if (count.empty()) return;
  Gdiplus::FontFamily family(L"Segoe UI");
  Gdiplus::GraphicsPath glyphs;
  if (glyphs.AddString(count.c_str(), static_cast<INT>(count.size()), &family,
                        Gdiplus::FontStyleBold, 12, Gdiplus::PointF(0, 0),
                        Gdiplus::StringFormat::GenericTypographic()) != Gdiplus::Ok) {
    return;
  }
  // Center the visible glyph outlines, excluding the font's line spacing and
  // side bearings. Line-box centering leaves short digits visibly off-center.
  Gdiplus::RectF ink;
  if (glyphs.GetBounds(&ink) != Gdiplus::Ok || ink.Width <= 0 || ink.Height <= 0) {
    return;
  }
  Gdiplus::Matrix translation;
  translation.Translate(bounds.X + (bounds.Width - ink.Width) / 2 - ink.X,
                          bounds.Y + (bounds.Height - ink.Height) / 2 - ink.Y);
  glyphs.Transform(&translation);
  Gdiplus::SolidBrush brush(color);
  graphics->FillPath(&brush, &glyphs);
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
  return inside_round_rect(body_bounds_, capsule_corner_radius_);
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
  scroll_offset_ = 0;
  scroll_max_ = 0;
  wheel_remainder_ = 0;
  Hide();
}

void TrayHoverCard::Scroll(int wheel_delta) {
  if (!visible_ || scroll_max_ <= 0) {
    return;
  }
  wheel_remainder_ += wheel_delta;
  const int steps = wheel_remainder_ / WHEEL_DELTA;
  wheel_remainder_ %= WHEEL_DELTA;
  if (steps == 0) {
    return;
  }
  scroll_offset_ = std::clamp(scroll_offset_ - steps * scroll_step_, 0, scroll_max_);
  RECT anchor;
  if (!ReadAnchor(&anchor) || !Show(anchor)) {
    Reset();
    return;
  }
  // A different ball now sits under the stationary pointer.
  POINT point;
  if (GetCursorPos(&point) && ScreenToClient(window_, &point)) {
    SetHoveredBall(BallAt(point));
  }
}

void TrayHoverCard::Hide() {
  if (!visible_) {
    return;
  }
  visible_ = false;
  hovered_ball_ = -1;
  closing_ = motion_;
  hidden_at_ = GetTickCount64();
  if (!closing_ || !StartAnimation()) {
    closing_ = false;
    ShowWindow(window_, SW_HIDE);
  }
  if (on_visibility_changed_) {
    on_visibility_changed_(false);
  }
}

bool TrayHoverCard::StartAnimation() {
  if (!animation_timer_active_ && window_ != nullptr) {
    animation_timer_active_ =
        SetTimer(window_, kAnimationTimer, kFrameIntervalMs, nullptr) != 0;
  }
  return animation_timer_active_;
}

void TrayHoverCard::StopAnimation() {
  if (animation_timer_active_ && window_ != nullptr) {
    KillTimer(window_, kAnimationTimer);
  }
  animation_timer_active_ = false;
}

bool TrayHoverCard::AnimationPending(ULONGLONG now) const {
  if (closing_) {
    return true;
  }
  const int steps = std::min(
      static_cast<int>(layout_.ball_centers.size()) - 1, kMaximumStaggerSteps);
  if (now < shown_at_ + std::max(steps, 0) * kStaggerMs + kSpringMs) {
    return true;
  }
  return std::any_of(ball_hover_.begin(), ball_hover_.end(),
                     [now](const BallHover& hover) {
                       return now < hover.started + kSpringMs;
                     });
}

void TrayHoverCard::Animate() {
  const ULONGLONG now = GetTickCount64();
  if (closing_ && now >= hidden_at_ + kFadeMs) {
    closing_ = false;
    StopAnimation();
    ShowWindow(window_, SW_HIDE);
    return;
  }
  if (!visible_ && !closing_) {
    StopAnimation();
    return;
  }
  if (!Render(now)) {
    StopAnimation();
    closing_ = false;
    motion_ = false;
    ShowWindow(window_, SW_HIDE);
    Reset();
    return;
  }
  if (!AnimationPending(now)) {
    StopAnimation();
  }
}

int TrayHoverCard::BallAt(POINT client) const {
  if (!visible_) {
    return -1;
  }
  const double x = client.x * 96.0 / dpi_ - kShadowMargin;
  const double y = client.y * 96.0 / dpi_ - kBodyTop + scroll_offset_;
  const double radius = layout_.ball_diameter / 2.0;
  for (size_t index = 0; index < layout_.ball_centers.size(); ++index) {
    const double dx = x - layout_.ball_centers[index].x;
    const double dy = y - layout_.ball_centers[index].y;
    if (dx * dx + dy * dy <= radius * radius) {
      return static_cast<int>(index);
    }
  }
  return -1;
}

void TrayHoverCard::SetHoveredBall(int index) {
  if (index == hovered_ball_ || !visible_) {
    return;
  }
  const ULONGLONG now = GetTickCount64();
  for (const int target : {hovered_ball_, index}) {
    if (target < 0 || target >= static_cast<int>(ball_hover_.size())) {
      continue;
    }
    BallHover& hover = ball_hover_[target];
    hover.from += (hover.to - hover.from) *
                  Spring(Progress(now, hover.started, 0, kSpringMs));
    hover.to = target == index ? 1 : 0;
    hover.started = motion_ ? now : 0;
  }
  hovered_ball_ = index;
  if (!Render(now)) {
    Reset();
  } else if (motion_) {
    StartAnimation();
  }
}

TrayHoverCard::Layout TrayHoverCard::MakeLayout(int max_width,
                                                int max_height) const {
  Layout layout;
  layout.ball_diameter = kBallDiameter;
  if (preview_.rows.empty() || preview_.rows.size() > kMaximumGroups) {
    return layout;
  }
  for (const auto& row : preview_.rows) {
    layout.ball_counts.push_back(row.count && *row.count >= 0
                                     ? std::to_wstring(*row.count) : L"?");
    layout.ball_diameter = std::max(
        layout.ball_diameter, static_cast<int>(layout.ball_counts.back().size()) * 8 + 8);
  }
  const int capsule_width = kCapsulePadding * 2 + layout.ball_diameter;
  if (capsule_width > max_width || max_height < capsule_width) {
    return Layout{};
  }
  const int count = static_cast<int>(preview_.rows.size());
  const int pitch = layout.ball_diameter + kBallGap;
  const int full_height = kCapsulePadding * 2 + count * pitch - kBallGap;
  const int capsule_height = std::min(full_height, max_height);
  layout.scroll_max = full_height - capsule_height;
  layout.width = capsule_width;
  layout.height = capsule_height;
  layout.capsule = {0, 0, capsule_width, capsule_height};
  for (int index = 0; index < count; ++index) {
    layout.ball_centers.push_back(
        {layout.width / 2,
         layout.capsule.top + kCapsulePadding + index * pitch + layout.ball_diameter / 2});
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
  scroll_max_ = layout.scroll_max;
  scroll_step_ = layout.ball_diameter + kBallGap;
  scroll_offset_ = std::clamp(scroll_offset_, 0, scroll_max_);
  const bool entering = !visible_;
  const ULONGLONG now = GetTickCount64();
  if (entering) {
    // A reopen during the exit fade restarts the entrance from the top.
    StopAnimation();
    closing_ = false;
    motion_ = MotionEnabled();
    shown_at_ = motion_ ? now : 0;
    slide_ = SlideToward(anchor, bounds);
    hovered_ball_ = -1;
    ball_hover_.clear();
  }
  if (ball_hover_.size() != layout.ball_centers.size()) {
    hovered_ball_ = -1;
    ball_hover_.assign(layout.ball_centers.size(), BallHover{});
  }
  layout_ = layout;
  bounds_ = bounds;
  dpi_ = dpi;
  if (!Render(now)) {
    return false;
  }
  const auto screen_rect = [&bounds, dpi](const RECT& rect) -> RECT {
    return {bounds.left + Scale(kShadowMargin + rect.left, dpi),
            bounds.top + Scale(kBodyTop + rect.top, dpi),
            bounds.left + Scale(kShadowMargin + rect.right, dpi),
            bounds.top + Scale(kBodyTop + rect.bottom, dpi)};
  };
  body_bounds_ = screen_rect(layout.capsule);
  capsule_corner_radius_ = Scale((layout.capsule.right - layout.capsule.left) / 2, dpi);
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
  if (entering && motion_) {
    StartAnimation();
  }
  return true;
}

bool TrayHoverCard::Render(ULONGLONG now) {
  const RECT& bounds = bounds_;
  const UINT dpi = dpi_;
  const Layout& layout = layout_;
  // The capsule's fade and rise; an exit continues from wherever the
  // entrance had reached, so a quick in-and-out never jumps.
  double capsule_alpha = EaseOut(Progress(now, shown_at_, 0, kFadeMs));
  float capsule_offset =
      kCapsuleTravel * static_cast<float>(1 - Spring(Progress(now, shown_at_, 0, kSpringMs)));
  if (closing_) {
    const double exit = EaseOut(Progress(now, hidden_at_, 0, kFadeMs));
    capsule_alpha *= 1 - exit;
    capsule_offset += kCapsuleTravel * static_cast<float>(exit);
  }
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
    graphics.TranslateTransform(kShadowMargin + slide_.x * capsule_offset,
                                  kBodyTop + slide_.y * capsule_offset);
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
    const float capsule_radius = capsule.Width / 2;
    shadow(capsule, capsule_radius);
    Gdiplus::GraphicsPath capsule_path;
    RoundedPath(&capsule_path, capsule, capsule_radius);
    Gdiplus::SolidBrush capsule_brush(background);
    Gdiplus::Pen outline(border, 1);
    graphics.FillPath(&capsule_brush, &capsule_path);
    graphics.DrawPath(&outline, &capsule_path);
    const Gdiplus::GraphicsState saved_clip = graphics.Save();
    graphics.SetClip(&capsule_path, Gdiplus::CombineModeIntersect);
    // Preserve priority order in one vertical column. Every colored circle
    // displays its own exact count; scrolling reveals all bounded groups.
    const float pitch = static_cast<float>(layout.ball_diameter + kBallGap);
    const float radius = layout.ball_diameter / 2.0f;
    for (size_t index = 0; index < layout.ball_centers.size(); ++index) {
      const POINT& center = layout.ball_centers[index];
      const float center_y = static_cast<float>(center.y - scroll_offset_);
      if (center_y + radius < capsule.Y || center_y - radius > capsule.GetBottom()) {
        continue;
      }
      // Stagger by on-screen rank from the icon's side, so a scrolled or
      // long column still starts next to the pointer and stays brief.
      const float distance = slide_.y > 0 ? capsule.GetBottom() - center_y
                                          : center_y - capsule.Y;
      const int rank = std::clamp(static_cast<int>(distance / pitch), 0,
                                  kMaximumStaggerSteps);
      const ULONGLONG delay = rank * kStaggerMs;
      const double appear = EaseOut(Progress(now, shown_at_, delay, kFadeMs));
      if (appear <= 0) {
        continue;
      }
      const double settle = Spring(Progress(now, shown_at_, delay, kSpringMs));
      const BallHover& hover = ball_hover_[index];
      const double magnify =
          hover.from + (hover.to - hover.from) *
                           Spring(Progress(now, hover.started, 0, kSpringMs));
      const float scale = static_cast<float>(
          (kBallStartScale + (1 - kBallStartScale) * settle) *
          (1 + kHoverGrowth * magnify));
      const float travel = kBallTravel * static_cast<float>(1 - settle);
      const BYTE alpha = static_cast<BYTE>(std::lround(255 * appear));
      const Gdiplus::Color base = FromColorRef(preview_.rows[index].color);
      const Gdiplus::Color color(alpha, base.GetR(), base.GetG(), base.GetB());
      const Gdiplus::GraphicsState saved_ball = graphics.Save();
      graphics.TranslateTransform(center.x + slide_.x * travel,
                                    center_y + slide_.y * travel);
      graphics.ScaleTransform(scale, scale);
      Gdiplus::SolidBrush ball(color);
      const Gdiplus::RectF circle(-radius, -radius,
                                  static_cast<float>(layout.ball_diameter),
                                  static_cast<float>(layout.ball_diameter));
      graphics.FillEllipse(&ball, circle);
      const double lightness = 0.2126 * color.GetR() + 0.7152 * color.GetG() +
                               0.0722 * color.GetB();
      const Gdiplus::Color text = lightness >= 155
          ? Gdiplus::Color(alpha, 24, 28, 32)
          : Gdiplus::Color(alpha, 255, 255, 255);
      DrawCount(&graphics, layout.ball_counts[index], circle, text);
      graphics.Restore(saved_ball);
    }
    graphics.Restore(saved_clip);
  }
  POINT destination = {bounds.left, bounds.top};
  POINT source = {0, 0};
  SIZE size = {width, height};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0,
                         static_cast<BYTE>(std::lround(255 * capsule_alpha)),
                         AC_SRC_ALPHA};
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
      if (wparam == kAnimationTimer) {
        self->Animate();
        return 0;
      }
      break;
    case WM_MOUSEMOVE: {
      if (!self->tracking_leave_) {
        TRACKMOUSEEVENT track = {sizeof(track), TME_LEAVE, window, 0};
        self->tracking_leave_ = TrackMouseEvent(&track) != FALSE;
      }
      self->SetHoveredBall(self->BallAt({static_cast<short>(LOWORD(lparam)),
                                         static_cast<short>(HIWORD(lparam))}));
      return 0;
    }
    case WM_MOUSELEAVE:
      self->tracking_leave_ = false;
      self->SetHoveredBall(-1);
      return 0;
    case WM_MOUSEWHEEL:
      self->Scroll(static_cast<short>(HIWORD(wparam)));
      return 0;
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
      self->motion_ = false;
      self->Reset();
      self->StopAnimation();
      self->closing_ = false;
      self->window_ = nullptr;
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      break;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace tray_manager
