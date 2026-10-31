#pragma once

#include <windows.h>
#include <shellapi.h>

#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace tray_manager {

struct ReminderPreviewRow {
  std::wstring name;
  std::optional<int> count;
  COLORREF color = RGB(220, 145, 50);
};

struct ReminderPreview {
  std::wstring title;
  std::wstring subtitle;
  std::wstring footer;
  int total_count = 0;
  std::vector<ReminderPreviewRow> rows;
};

// A lazy, non-activating native popup. Its timer exists only while the pointer
// is interacting with the tray icon/card (including the short leave grace).
class TrayHoverCard {
 public:
  TrayHoverCard(HWND owner, std::function<void()> on_click,
                std::function<void(bool)> on_visibility_changed);
  ~TrayHoverCard();

  TrayHoverCard(const TrayHoverCard&) = delete;
  TrayHoverCard& operator=(const TrayHoverCard&) = delete;

  void SetPreview(ReminderPreview preview);
  void SetEnabled(bool enabled);
  void OnTrayMouseMove(const NOTIFYICONIDENTIFIER& identifier);
  // Prevent an immediate reopen while the pointer remains on a clicked icon.
  void Dismiss();
  // Clear a hover session on teardown, unread clear, suspend or Explorer loss.
  void Reset();

 private:
  struct Layout {
    int width = 0;
    int height = 0;
    RECT capsule = {};
    std::vector<POINT> ball_centers;
    std::vector<std::wstring> ball_counts;
    int ball_diameter = 0;
    int scroll_max = 0;
  };
  // One ball's magnification, retargeted mid-flight like a CSS transition.
  struct BallHover {
    double from = 0;
    double to = 0;
    ULONGLONG started = 0;
  };
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  bool HasPreview() const;
  bool EnsureWindow();
  bool ReadAnchor(RECT* rect) const;
  bool PointerIsInside(const POINT& point) const;
  void PollPointer();
  void Scroll(int wheel_delta);
  bool Show(const RECT& anchor);
  void Hide();
  Layout MakeLayout(int max_width, int max_height) const;
  bool Render(ULONGLONG now);
  int BallAt(POINT client) const;
  void SetHoveredBall(int index);
  bool StartAnimation();
  void StopAnimation();
  void Animate();
  bool AnimationPending(ULONGLONG now) const;

  HWND owner_ = nullptr;
  HWND window_ = nullptr;
  std::function<void()> on_click_;
  std::function<void(bool)> on_visibility_changed_;
  ReminderPreview preview_;
  NOTIFYICONIDENTIFIER identifier_ = {};
  RECT body_bounds_ = {};
  int capsule_corner_radius_ = 0;
  int scroll_offset_ = 0;
  int scroll_max_ = 0;
  int scroll_step_ = 30;
  int wheel_remainder_ = 0;
  bool enabled_ = false;
  bool visible_ = false;
  bool timer_active_ = false;
  bool dismissed_until_leave_ = false;
  bool pressed_ = false;
  ULONGLONG entered_at_ = 0;
  ULONGLONG left_at_ = 0;

  // The last placed frame, replayed by the animation timer.
  Layout layout_;
  RECT bounds_ = {};
  UINT dpi_ = USER_DEFAULT_SCREEN_DPI;
  // Unit direction from the card toward the tray icon; entrances rise away
  // from it and exits sink back into it.
  POINT slide_ = {0, 1};
  std::vector<BallHover> ball_hover_;
  int hovered_ball_ = -1;
  bool motion_ = true;
  bool closing_ = false;
  bool animation_timer_active_ = false;
  bool tracking_leave_ = false;
  ULONGLONG shown_at_ = 0;
  ULONGLONG hidden_at_ = 0;
};

}  // namespace tray_manager
