// Standalone verification of the actual native hover window and renderer.
// Requires an interactive Windows desktop; avoid changing focus while it runs.
// The clock, pointer, icon anchor, DPI and theme inputs are simulated. Actual
// non-activating HWNDs and GDI+ rendering run without moving the pointer or
// changing the system theme. This does not replace real Explorer acceptance.
//
// From the repository root in an x64 VS Native Tools Command Prompt:
//   if not exist build\tray_hover_verification mkdir build\tray_hover_verification
//   cl /nologo /std:c++17 /EHsc /W4 /WX /wd4100 /utf-8 ^
//      /DNOMINMAX /DUNICODE /D_UNICODE ^
//      /Ipackages\tray_manager\windows scripts\verify_windows_tray_hover.cpp ^
//      /Fobuild\tray_hover_verification\verify.obj ^
//      /Febuild\tray_hover_verification\verify.exe ^
//      /link user32.lib gdi32.lib gdiplus.lib shell32.lib shcore.lib advapi32.lib
//   build\tray_hover_verification\verify.exe
// Optional argument: an output directory for the PNG renders. The default
// is build\tray_hover_verification, relative to the current working directory.
#include <windows.h>
#include <shellapi.h>
#include <shellscalingapi.h>
#include <algorithm>
#include <cmath>
#include <filesystem>
#include <functional>
#include <optional>
#include <string>
#include <vector>
#include <iostream>
#include <utility>
using std::max;
using std::min;
#pragma warning(push)
#pragma warning(disable:4458)
#include <gdiplus.h>
#pragma warning(pop)
#define private public
#include "tray_hover_card.h"
#undef private

static RECT test_anchor = {};
static POINT test_pointer = {};
static ULONGLONG test_now = 1000;
static bool test_anchor_valid = true;
static UINT test_dpi = 96;
static std::wstring test_capture;
static int test_failures = 0;
static int test_checks = 0;
static int test_captures = 0;
static bool test_force_light = false;
static std::vector<BYTE> test_last_pixels;
static SIZE test_last_size = {};

static HRESULT TestAnchor(const NOTIFYICONIDENTIFIER*, RECT* rect) {
  *rect = test_anchor;
  return test_anchor_valid ? S_OK : E_FAIL;
}
static BOOL TestCursor(POINT* point) { *point = test_pointer; return TRUE; }
static ULONGLONG TestClock() { return test_now; }
static SHORT TestButton(int) { return 0; }
static HRESULT TestDpi(HMONITOR, MONITOR_DPI_TYPE, UINT* x, UINT* y) {
  *x = test_dpi; *y = test_dpi; return S_OK;
}
static LSTATUS TestTheme(HKEY key, LPCWSTR subkey, LPCWSTR value, DWORD flags,
                         LPDWORD type, PVOID data, LPDWORD bytes) {
  if (data != nullptr && bytes != nullptr && *bytes >= sizeof(DWORD)) {
    *static_cast<DWORD*>(data) = test_force_light ? 1 : 0;
    *bytes = sizeof(DWORD);
    return ERROR_SUCCESS;
  }
  return ERROR_INVALID_PARAMETER;
}
static BOOL TestLayer(HWND window, HDC destination, POINT* pos, SIZE* size,
                      HDC source, POINT* src, COLORREF color,
                      BLENDFUNCTION* blend, DWORD flags) {
  DIBSECTION dib = {};
  if (GetObjectW(GetCurrentObject(source, OBJ_BITMAP), sizeof(dib), &dib) != sizeof(dib) ||
      dib.dsBm.bmBits == nullptr) {
    return FALSE;
  }
  const auto* bytes_begin = static_cast<const BYTE*>(dib.dsBm.bmBits);
  test_last_pixels.assign(bytes_begin,
                            bytes_begin + dib.dsBm.bmWidthBytes * size->cy);
  test_last_size = *size;
  if (!test_capture.empty()) {
    Gdiplus::Bitmap image(size->cx, size->cy, dib.dsBm.bmWidthBytes,
                          PixelFormat32bppPARGB,
                          static_cast<BYTE*>(dib.dsBm.bmBits));
    UINT bytes = 0, count = 0;
    Gdiplus::GetImageEncodersSize(&count, &bytes);
    std::vector<BYTE> storage(bytes);
    auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(storage.data());
    Gdiplus::GetImageEncoders(count, bytes, encoders);
    for (UINT index = 0; index < count; ++index) {
      if (wcscmp(encoders[index].MimeType, L"image/png") == 0 &&
          image.Save(test_capture.c_str(), &encoders[index].Clsid) == Gdiplus::Ok) {
        ++test_captures;
        break;
      }
    }
    test_capture.clear();
  }
  return UpdateLayeredWindow(window, destination, pos, size, source, src, color, blend, flags);
}

#define Shell_NotifyIconGetRect TestAnchor
#define GetCursorPos TestCursor
#define GetTickCount64 TestClock
#define GetAsyncKeyState TestButton
#define GetDpiForMonitor TestDpi
#define UpdateLayeredWindow TestLayer
#define RegGetValueW TestTheme
#include "tray_hover_card.cpp"
#undef Shell_NotifyIconGetRect
#undef GetCursorPos
#undef GetTickCount64
#undef GetAsyncKeyState
#undef GetDpiForMonitor
#undef UpdateLayeredWindow
#undef RegGetValueW

#define CHECK(condition) do { ++test_checks; if (!(condition)) { ++test_failures; std::cerr << "FAIL line " << __LINE__ << ": " << #condition << "\n"; } } while (0)

static COLORREF PixelAt(int x, int y) {
  if (x < 0 || y < 0 || x >= test_last_size.cx || y >= test_last_size.cy) {
    return CLR_INVALID;
  }
  const size_t offset = (static_cast<size_t>(y) * test_last_size.cx + x) * 4;
  return RGB(test_last_pixels[offset + 2], test_last_pixels[offset + 1],
               test_last_pixels[offset]);
}

int wmain(int argc, wchar_t* argv[]) {
  if (argc > 2) {
    std::cerr << "Usage: verify_windows_tray_hover.exe [output-directory]\n";
    return 2;
  }
  const std::filesystem::path output = argc == 2
      ? std::filesystem::path(argv[1])
      : std::filesystem::path(L"build") / L"tray_hover_verification";
  std::error_code directory_error;
  std::filesystem::create_directories(output, directory_error);
  if (directory_error) {
    std::cerr << "Cannot create output directory: " << directory_error.message() << "\n";
    return 2;
  }
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(MonitorFromPoint({0, 0}, MONITOR_DEFAULTTOPRIMARY), &info)) {
    std::cerr << "Cannot read the desktop monitor work area.\n";
    return 2;
  }
  test_anchor = {info.rcWork.right - 90, info.rcWork.bottom - 36,
                 info.rcWork.right - 66, info.rcWork.bottom - 12};
  const POINT icon_point = {test_anchor.left + 12, test_anchor.top + 12};
  const POINT away = {info.rcWork.left + 5, info.rcWork.top + 5};
  test_pointer = icon_point;
  HWND owner = CreateWindowExW(0, L"STATIC", L"DingDong native hover tests",
                                WS_OVERLAPPEDWINDOW, 0, 0, 100, 100,
                                nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (owner == nullptr) {
    std::cerr << "Cannot create the native test window.\n";
    return 2;
  }
  HWND initial_focus = GetForegroundWindow();
  int clicks = 0;
  std::vector<bool> visibility;
  tray_manager::TrayHoverCard card(owner, [&] { ++clicks; },
                                    [&](bool shown) { visibility.push_back(shown); });
  tray_manager::ReminderPreview preview;
  preview.title = L"轮到你啦";
  preview.subtitle = L"12 条提醒待查看";
  preview.footer = L"点击打开 DingDong";
  preview.total_count = 12;
  preview.rows = {{L"等待输入", 5, RGB(236, 159, 58)},
                   {L"任务完成", 4, RGB(52, 173, 124)},
                   {L"构建失败", std::nullopt, RGB(230, 98, 103)},
                   {L"Code review", 3, RGB(92, 143, 225)}};
  card.SetPreview(preview);
  card.SetEnabled(true);
  NOTIFYICONIDENTIFIER identifier = {};
  identifier.cbSize = sizeof(identifier);
  card.OnTrayMouseMove(identifier);
  CHECK(card.timer_active_ && !card.visible_);
  test_now = 1399; card.PollPointer();
  CHECK(!card.visible_);
  test_capture = (output / L"card-96.png").wstring();
  test_now = 1400; card.PollPointer();
  CHECK(card.visible_);
  CHECK(GetForegroundWindow() == initial_focus);
  CHECK((GetWindowLongPtrW(card.window_, GWL_EXSTYLE) & WS_EX_NOACTIVATE) != 0);
  CHECK(SendMessageW(card.window_, WM_MOUSEACTIVATE, 0, 0) == MA_NOACTIVATE);
  CHECK(card.body_bounds_.left >= info.rcWork.left && card.body_bounds_.right <= info.rcWork.right);
  CHECK(card.body_bounds_.top >= info.rcWork.top && card.body_bounds_.bottom <= info.rcWork.bottom);
  const auto normal_layout = card.MakeLayout(600, 600);
  CHECK(normal_layout.width == 98 && normal_layout.height == 58);
  CHECK(normal_layout.capsule.bottom - normal_layout.capsule.top == 32);
  CHECK(normal_layout.count_text == L"5" && preview.total_count == 12);
  CHECK(normal_layout.primary_color == preview.rows.front().color);
  CHECK(normal_layout.ball_centers.size() == preview.rows.size());
  CHECK(card.badge_bounds_.bottom < card.body_bounds_.top);
  const POINT top_badge = {(card.badge_bounds_.left + card.badge_bounds_.right) / 2,
                           (card.badge_bounds_.top + card.badge_bounds_.bottom) / 2};
  CHECK(card.PointerIsInside(top_badge));
  CHECK(SendMessageW(card.window_, WM_NCHITTEST, 0,
                       MAKELPARAM(top_badge.x, top_badge.y)) == HTCLIENT);
  const POINT transparent_corner = {card.badge_bounds_.left, card.badge_bounds_.top};
  CHECK(!card.PointerIsInside(transparent_corner));
  for (size_t index = 0; index < normal_layout.ball_centers.size(); ++index) {
    const auto& point = normal_layout.ball_centers[index];
    CHECK(PixelAt(tray_manager::kShadowMargin + point.x,
                    tray_manager::kBodyTop + point.y) == preview.rows[index].color);
  }
  CHECK(PixelAt(tray_manager::kShadowMargin +
                    (normal_layout.badge.left + normal_layout.badge.right) / 2,
                    tray_manager::kBodyTop + normal_layout.badge.top + 3) ==
        preview.rows.front().color);
  const auto baseline_pixels = test_last_pixels;
  auto invisible_metadata = preview;
  invisible_metadata.title = L"THIS TITLE MUST NEVER BE PAINTED";
  invisible_metadata.subtitle = L"INVISIBLE SUBTITLE";
  invisible_metadata.footer = L"INVISIBLE FOOTER";
  invisible_metadata.total_count = 987;
  for (auto& row : invisible_metadata.rows) row.name = L"INVISIBLE GROUP NAME";
  invisible_metadata.rows[1].count = 12345;
  invisible_metadata.rows[2].count = 999;
  invisible_metadata.rows[3].count = 0;
  card.SetPreview(invisible_metadata);
  // Pixel identity proves no visible wording, totals, or internal ball counts.
  CHECK(test_last_pixels == baseline_pixels);
  auto first_changed = preview;
  first_changed.rows.front().count = 6;
  card.SetPreview(first_changed);
  CHECK(card.MakeLayout(600, 600).count_text == L"6");
  CHECK(test_last_pixels != baseline_pixels);
  card.SetPreview(preview);
  CHECK(test_last_pixels == baseline_pixels);
  wchar_t accessible[1024] = {};
  GetWindowTextW(card.window_, accessible, 1024);
  CHECK(std::wstring(accessible).find(L"?") != std::wstring::npos);
  test_pointer = {(card.body_bounds_.left + card.body_bounds_.right) / 2,
                   (card.body_bounds_.top + card.body_bounds_.bottom) / 2};
  test_now = 1450; card.PollPointer();
  CHECK(card.visible_);
  test_pointer = top_badge;
  test_now = 1460; card.PollPointer();
  CHECK(card.visible_);
  test_pointer = away;
  test_now = 1500; card.PollPointer();
  CHECK(card.visible_);
  test_now = 1719; card.PollPointer();
  CHECK(card.visible_);
  test_now = 1720; card.PollPointer();
  CHECK(!card.visible_ && !card.timer_active_);
  CHECK(visibility == std::vector<bool>({true, false}));

  auto hover = [&](ULONGLONG start) {
    test_pointer = icon_point;
    test_now = start;
    card.OnTrayMouseMove(identifier);
    test_now = start + 400;
    card.PollPointer();
  };
  hover(2000);
  CHECK(card.visible_);
  card.Dismiss();
  test_now = 3000; card.PollPointer();
  CHECK(!card.visible_ && card.dismissed_until_leave_);
  test_pointer = away; card.PollPointer();
  CHECK(!card.timer_active_ && !card.dismissed_until_leave_);
  hover(4000); CHECK(card.visible_);
  card.SetEnabled(false);
  CHECK(!card.visible_ && !card.timer_active_);
  card.SetEnabled(true);
  hover(5000); CHECK(card.visible_);
  auto cleared = preview; cleared.total_count = 0; card.SetPreview(cleared);
  CHECK(!card.visible_ && !card.timer_active_);
  card.SetPreview(preview);
  hover(6000); CHECK(card.visible_);
  SendMessageW(card.window_, WM_LBUTTONDOWN, MK_LBUTTON, 0);
  SendMessageW(card.window_, WM_LBUTTONUP, 0, 0);
  CHECK(clicks == 1 && !card.visible_);
  CHECK(GetForegroundWindow() == initial_focus);
  test_pointer = away; card.PollPointer();
  hover(7000); CHECK(card.visible_);
  test_anchor_valid = false; card.PollPointer();
  CHECK(!card.visible_ && !card.timer_active_);
  test_anchor_valid = true;
  hover(8000); CHECK(card.visible_);
  SendMessageW(card.window_, WM_THEMECHANGED, 0, 0);
  CHECK(!card.visible_ && !card.timer_active_);

  hover(9000);
  const DWORD gdi_before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
  for (int index = 0; index < 50; ++index) card.SetPreview(preview);
  const DWORD gdi_after = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
  CHECK(gdi_after <= gdi_before + 1);
  for (UINT dpi : {144u, 192u}) {
    test_dpi = dpi;
    test_capture = (output / (L"card-" + std::to_wstring(dpi) + L".png")).wstring();
    CHECK(card.Show(test_anchor));
    CHECK(card.body_bounds_.right <= info.rcWork.right && card.body_bounds_.bottom <= info.rcWork.bottom);
  }
  test_force_light = true;
  test_capture = (output / L"card-light-192.png").wstring();
  CHECK(card.Show(test_anchor));
  CHECK(GetForegroundWindow() == initial_focus);
  CHECK(test_captures == 4);
  auto unknown_primary = preview;
  unknown_primary.rows.front().count = std::nullopt;
  test_capture = (output / L"card-unknown-primary.png").wstring();
  card.SetPreview(unknown_primary);
  CHECK(card.MakeLayout(600, 600).count_text == L"?");
  auto large_primary = preview;
  large_primary.rows.front().count = 12345;
  test_capture = (output / L"card-large-primary.png").wstring();
  card.SetPreview(large_primary);
  const auto large_layout = card.MakeLayout(600, 600);
  CHECK(large_layout.count_text == L"12345");
  CHECK(large_layout.badge.right - large_layout.badge.left >= 48);
  auto many_groups = preview;
  many_groups.total_count = 2048;
  many_groups.rows.clear();
  for (int index = 0; index < 64; ++index) {
    many_groups.rows.push_back({L"Group " + std::to_wstring(index), index + 1,
                                 RGB((index * 73 + 41) % 256,
                                     (index * 47 + 80) % 256,
                                     (index * 29 + 119) % 256)});
  }
  test_capture = (output / L"card-64-groups.png").wstring();
  card.SetPreview(many_groups);
  const auto wrapped = card.MakeLayout(600, 600);
  CHECK(wrapped.ball_centers.size() == 64);
  CHECK(wrapped.width <= 186 && wrapped.height <= 212);
  CHECK(wrapped.ball_centers.front().y < wrapped.ball_centers.back().y);
  for (size_t index = 0; index < wrapped.ball_centers.size(); ++index) {
    const auto& point = wrapped.ball_centers[index];
    CHECK(PixelAt(tray_manager::Scale(tray_manager::kShadowMargin + point.x, test_dpi),
                    tray_manager::Scale(tray_manager::kBodyTop + point.y, test_dpi)) ==
          many_groups.rows[index].color);
  }
  const auto narrow_wrap = card.MakeLayout(100, 600);
  CHECK(narrow_wrap.ball_centers.size() == 64 && narrow_wrap.width <= 100);
  const auto short_wrap = card.MakeLayout(400, 130);
  CHECK(short_wrap.ball_centers.size() == 64 && short_wrap.height <= 130);
  CHECK(test_captures == 7);
  card.SetPreview(preview);
  CHECK(GetForegroundWindow() == initial_focus);
  const POINT final_badge = {(card.badge_bounds_.left + card.badge_bounds_.right) / 2,
                             (card.badge_bounds_.top + card.badge_bounds_.bottom) / 2};
  CHECK(SendMessageW(card.window_, WM_NCHITTEST, 0,
                       MAKELPARAM(final_badge.x, final_badge.y)) == HTCLIENT);
  SendMessageW(card.window_, WM_LBUTTONDOWN, MK_LBUTTON, 0);
  SendMessageW(card.window_, WM_LBUTTONUP, 0, 0);
  CHECK(clicks == 2 && !card.visible_);
  card.Reset();
  auto no_groups = preview;
  no_groups.rows.clear();
  card.SetPreview(no_groups);
  CHECK(card.MakeLayout(600, 600).ball_centers.empty());
  card.OnTrayMouseMove(identifier);
  CHECK(!card.visible_ && !card.timer_active_);
  const RECT work = {0, 0, 1920, 1040};
  const SIZE size = {122, 82};
  for (RECT anchor : {RECT{1800, 1050, 1824, 1074}, RECT{1800, -30, 1824, -6},
                      RECT{-30, 800, -6, 824}, RECT{1926, 800, 1950, 824},
                      RECT{100, 100, 124, 124}}) {
    RECT placed = tray_manager::PlaceCard(anchor, work, size, 6, 6);
    CHECK(placed.left >= work.left && placed.right <= work.right &&
          placed.top >= work.top && placed.bottom <= work.bottom);
  }
  DestroyWindow(owner);
  CHECK(card.window_ == nullptr && !card.visible_ && !card.timer_active_);
  std::cout << test_checks << " native checks, " << test_failures << " failures; "
            << test_captures << " PNG renders; GDI " << gdi_before << " -> " << gdi_after << "\n";
  return test_failures == 0 ? 0 : 1;
}
