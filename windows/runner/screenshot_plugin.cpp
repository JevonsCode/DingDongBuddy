#include "screenshot_plugin.h"
#include "screenshot_geometry.h"

#include <windowsx.h>
#include <objidl.h>
#include <flutter/method_result_functions.h>
// Older Windows SDK GDI+ headers expect unqualified min/max even with NOMINMAX.
namespace Gdiplus { using std::min; using std::max; }
#pragma warning(push)
#pragma warning(disable: 4458)
#include <gdiplus.h>
#pragma warning(pop)
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <cmath>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Point = screenshot::Point;
using Rect = screenshot::Rect;
constexpr UINT kHotkeyA = 0xDD02;
constexpr UINT kHotkeyB = 0xDD03;
constexpr wchar_t kOverlayClass[] = L"DingDongScreenshotEditor";
const Value* Find(const Map& map, const char* name) {
  auto it = map.find(Value(name));
  return it == map.end() ? nullptr : &it->second;
}
bool Flag(const Map& map, const char* name) {
  const auto* value = Find(map, name);
  return value && std::holds_alternative<bool>(*value) && std::get<bool>(*value);
}
std::wstring Wide(const std::string& text) {
  const int size = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                      static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      out.data(), size);
  return out;
}
UINT VirtualKey(const std::string& key) {
  if (key.size() == 1 && ((key[0] >= 'A' && key[0] <= 'Z') ||
                         (key[0] >= '0' && key[0] <= '9'))) return key[0];
  for (int i = 1; i <= 12; ++i) {
    if (key == "F" + std::to_string(i)) return VK_F1 + i - 1;
  }
  static const std::map<std::string, UINT> keys{
    {"SPACE", VK_SPACE}, {"RETURN", VK_RETURN}, {"LEFT", VK_LEFT},
    {"RIGHT", VK_RIGHT}, {"UP", VK_UP}, {"DOWN", VK_DOWN}};
  auto it = keys.find(key);
  return it == keys.end() ? 0 : it->second;
}
}  // namespace

struct ScreenshotPlugin::Impl {
  HWND owner;
  HWND overlay = nullptr;
  HDC snapshot_dc = nullptr;
  HBITMAP bitmap = nullptr;
  HGDIOBJ previous_bitmap = nullptr;
  HFONT font = nullptr;
  ULONG_PTR gdiplus = 0;
  int screen_x = 0, screen_y = 0, width = 0, height = 0;
  bool registered = false, dragging = false, selected = false;
  bool editing = false;
  UINT hotkey_id = kHotkeyA, modifiers = 0, key = 0;
  Point start{}, current{};
  Rect region{};
  RECT hint_bounds{};
  std::wstring error;
  std::map<std::string, std::wstring> labels;
  std::unique_ptr<flutter::MethodChannel<Value>> channel;

  Impl(HWND window, flutter::BinaryMessenger* messenger) : owner(window) {
    Gdiplus::GdiplusStartupInput input;
    if (Gdiplus::GdiplusStartup(&gdiplus, &input, nullptr) != Gdiplus::Ok) {
      gdiplus = 0;
    }
    channel = std::make_unique<flutter::MethodChannel<Value>>(
        messenger, "dingdong/screenshot_plugin",
        &flutter::StandardMethodCodec::GetInstance());
    channel->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() == "status") {
        result->Success(Status());
      } else if (call.method_name() == "configure") {
        const auto* args = std::get_if<Map>(call.arguments());
        const std::string failure = args ? Configure(*args) : "invalid_shortcut";
        if (failure.empty()) result->Success(Status());
        else result->Error(failure, failure);
      } else if (call.method_name() == "capture") {
        if (!registered) result->Error("disabled", "disabled");
        else if (overlay || editing) result->Error("capture_busy", "capture_busy");
        else if (!Capture()) result->Error("capture_failed", "capture_failed");
        else result->Success();
      } else if (call.method_name() == "finish") {
        editing = false;
        result->Success();
      } else {
        result->NotImplemented();
      }
    });
  }

  ~Impl() {
    channel->SetMethodCallHandler(nullptr);
    if (registered) UnregisterHotKey(owner, hotkey_id);
    Close();
    if (gdiplus) Gdiplus::GdiplusShutdown(gdiplus);
  }

  Value Status() const {
    return Value(Map{{Value("supported"), Value(gdiplus != 0)},
                     {Value("running"), Value(registered)},
                     {Value("capturing"), Value(overlay != nullptr || editing)}});
  }

  std::wstring Label(const std::string& id, const wchar_t* fallback) const {
    auto it = labels.find(id);
    return it == labels.end() ? fallback : it->second;
  }

  std::string Configure(const Map& args) {
    if (!Flag(args, "enabled")) {
      if (registered) UnregisterHotKey(owner, hotkey_id);
      registered = false;
      Close();
    } else {
      if (!gdiplus) return "capture_failed";
      const auto* shortcut_value = Find(args, "shortcut");
      const auto* shortcut = shortcut_value ? std::get_if<Map>(shortcut_value) : nullptr;
      if (!shortcut) return "invalid_shortcut";
      const auto* key_value = Find(*shortcut, "key");
      const auto* key_name = key_value ? std::get_if<std::string>(key_value) : nullptr;
      const UINT next_key = key_name ? VirtualKey(*key_name) : 0;
      const UINT next_modifiers = (Flag(*shortcut, "primary") ? MOD_CONTROL : 0) |
          (Flag(*shortcut, "shift") ? MOD_SHIFT : 0) |
          (Flag(*shortcut, "alt") ? MOD_ALT : 0) |
          (Flag(*shortcut, "secondary") ? MOD_WIN : 0) | MOD_NOREPEAT;
      if (!next_key || next_modifiers == MOD_NOREPEAT) return "invalid_shortcut";
      if (!registered || key != next_key || modifiers != next_modifiers) {
        // Alternate IDs: retain the old registration until the replacement has
        // succeeded. There is no unregister/register race or lost old shortcut.
        const UINT next_id = hotkey_id == kHotkeyA ? kHotkeyB : kHotkeyA;
        if (!RegisterHotKey(owner, next_id, next_modifiers, next_key)) {
          return "shortcut_conflict";
        }
        if (registered) UnregisterHotKey(owner, hotkey_id);
        hotkey_id = next_id;
        key = next_key;
        modifiers = next_modifiers;
        registered = true;
      }
    }
    const auto* label_value = Find(args, "labels");
    const auto* next_labels = label_value ? std::get_if<Map>(label_value) : nullptr;
    if (next_labels) {
      for (const auto& pair : *next_labels) {
        const auto* name = std::get_if<std::string>(&pair.first);
        const auto* text = std::get_if<std::string>(&pair.second);
        if (name && text) labels[*name] = Wide(*text);
      }
    }
    return "";
  }

  void ReleaseBitmap() {
    if (snapshot_dc) {
      if (previous_bitmap) SelectObject(snapshot_dc, previous_bitmap);
      DeleteDC(snapshot_dc);
    }
    if (bitmap) DeleteObject(bitmap);
    snapshot_dc = nullptr;
    bitmap = nullptr;
    previous_bitmap = nullptr;
    if (font) DeleteObject(font);
    font = nullptr;
    error.clear();
  }

  void Close() {
    if (overlay) {
      HWND window = overlay;
      overlay = nullptr;
      DestroyWindow(window);
    }
    editing = false;
    ReleaseBitmap();
  }

  bool Capture() {
    if (overlay || editing) return false;
    screen_x = GetSystemMetrics(SM_XVIRTUALSCREEN);
    screen_y = GetSystemMetrics(SM_YVIRTUALSCREEN);
    width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    // Bound allocations on pathological remote/virtual display setups.
    if (width <= 0 || height <= 0 ||
        static_cast<int64_t>(width) * height > 100000000) return false;
    HDC screen = GetDC(nullptr);
    if (!screen) return false;
    snapshot_dc = CreateCompatibleDC(screen);
    bitmap = CreateCompatibleBitmap(screen, width, height);
    bool captured = false;
    if (snapshot_dc && bitmap) {
      previous_bitmap = SelectObject(snapshot_dc, bitmap);
      captured = BitBlt(snapshot_dc, 0, 0, width, height, screen,
                        screen_x, screen_y, SRCCOPY | CAPTUREBLT) != FALSE;
    }
    ReleaseDC(nullptr, screen);
    if (!captured) { ReleaseBitmap(); return false; }
    WNDCLASSW cls{};
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpfnWndProc = WindowProc;
    cls.lpszClassName = kOverlayClass;
    cls.hCursor = LoadCursor(nullptr, IDC_CROSS);
    if (!RegisterClassW(&cls) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
      ReleaseBitmap(); return false;
    }
    selected = dragging = false;
    region = {};
    overlay = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, kOverlayClass,
        L"DingDong Screenshot", WS_POPUP, screen_x, screen_y, width, height,
        owner, nullptr, cls.hInstance, this);
    if (!overlay) { ReleaseBitmap(); return false; }
    const int dpi = static_cast<int>(GetDpiForWindow(overlay));
    font = CreateFontW(-MulDiv(13, dpi, 96), 0, 0, 0, FW_NORMAL, FALSE, FALSE,
        FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
    POINT cursor{}; GetCursorPos(&cursor);
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfoW(MonitorFromPoint(cursor, MONITOR_DEFAULTTOPRIMARY), &monitor);
    const int hint_width = std::min(MulDiv(520, dpi, 96),
        static_cast<int>(monitor.rcMonitor.right - monitor.rcMonitor.left) - 48);
    const int hint_left = monitor.rcMonitor.left - screen_x +
        (monitor.rcMonitor.right - monitor.rcMonitor.left - hint_width) / 2;
    hint_bounds = {hint_left, monitor.rcMonitor.top - screen_y + MulDiv(24, dpi, 96),
                   hint_left + hint_width,
                   monitor.rcMonitor.top - screen_y + MulDiv(64, dpi, 96)};
    ShowWindow(overlay, SW_SHOW);
    SetWindowPos(overlay, HWND_TOPMOST, screen_x, screen_y, width, height,
                 SWP_SHOWWINDOW);
    SetForegroundWindow(overlay);
    SetFocus(overlay);
    UpdateWindow(overlay);
    return true;
  }

  static LRESULT CALLBACK WindowProc(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
    auto* self = reinterpret_cast<Impl*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      self = static_cast<Impl*>(reinterpret_cast<CREATESTRUCTW*>(l)->lpCreateParams);
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (!self) return DefWindowProcW(hwnd, message, w, l);
    switch (message) {
      case WM_ERASEBKGND: return 1;
      case WM_PAINT: self->Paint(hwnd); return 0;
      case WM_LBUTTONDOWN:
        self->PointerDown({GET_X_LPARAM(l), GET_Y_LPARAM(l)}); return 0;
      case WM_MOUSEMOVE:
        if (self->dragging) {
          self->current = screenshot::Clip({GET_X_LPARAM(l), GET_Y_LPARAM(l)},
              self->selected ? self->region : Rect{0, 0, self->width, self->height});
          if (!self->selected) self->region = screenshot::Region(
              self->start, self->current, self->width, self->height);
          InvalidateRect(hwnd, nullptr, FALSE);
        }
        return 0;
      case WM_LBUTTONUP: self->PointerUp(); return 0;
      case WM_CAPTURECHANGED:
        self->dragging = false; InvalidateRect(hwnd, nullptr, FALSE); return 0;
      case WM_RBUTTONUP:
        if (self->selected) self->Reselect(); else self->Close(); return 0;
      case WM_KEYDOWN:
        self->Key(w); return 0;
      case WM_DISPLAYCHANGE:
      case WM_CLOSE: self->Close(); return 0;
    }
    return DefWindowProcW(hwnd, message, w, l);
  }

  RECT SelectionMonitor() const {
    RECT absolute{region.left + screen_x, region.top + screen_y,
                  region.right + screen_x, region.bottom + screen_y};
    MONITORINFO monitor{sizeof(MONITORINFO)};
    if (!GetMonitorInfoW(MonitorFromRect(&absolute, MONITOR_DEFAULTTONEAREST), &monitor)) {
      return {0, 0, width, height};
    }
    return {monitor.rcMonitor.left - screen_x, monitor.rcMonitor.top - screen_y,
            monitor.rcMonitor.right - screen_x, monitor.rcMonitor.bottom - screen_y};
  }

  void Text(HDC dc, const std::wstring& value, RECT bounds, COLORREF color,
            UINT flags = DT_LEFT | DT_VCENTER | DT_SINGLELINE) {
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, color);
    auto old = SelectObject(dc, font ? font : GetStockObject(DEFAULT_GUI_FONT));
    DrawTextW(dc, value.c_str(), static_cast<int>(value.size()), &bounds, flags);
    SelectObject(dc, old);
  }

  void Paint(HWND hwnd) {
    PAINTSTRUCT paint{};
    HDC window_dc = BeginPaint(hwnd, &paint);
    HDC dc = CreateCompatibleDC(window_dc);
    HBITMAP frame = CreateCompatibleBitmap(window_dc, width, height);
    if (!dc || !frame) {
      if (dc) DeleteDC(dc);
      if (frame) DeleteObject(frame);
      EndPaint(hwnd, &paint); return;
    }
    auto old = SelectObject(dc, frame);
    BitBlt(dc, 0, 0, width, height, snapshot_dc, 0, 0, SRCCOPY);
    {
      Gdiplus::Graphics graphics(dc);
      Gdiplus::SolidBrush dim(Gdiplus::Color(120, 0, 0, 0));
      graphics.FillRectangle(&dim, 0, 0, width, height);
    }
    if (region.usable()) {
      BitBlt(dc, region.left, region.top, region.width(), region.height(),
             snapshot_dc, region.left, region.top, SRCCOPY);
      HPEN border = CreatePen(PS_SOLID, 2, RGB(74, 158, 255));
      auto old_pen = SelectObject(dc, border);
      auto old_brush = SelectObject(dc, GetStockObject(NULL_BRUSH));
      Rectangle(dc, region.left, region.top, region.right, region.bottom);
      SelectObject(dc, old_brush); SelectObject(dc, old_pen); DeleteObject(border);
      std::wstring dimensions = std::to_wstring(region.width()) + L" \u00D7 " +
                                std::to_wstring(region.height());
      const RECT monitor = SelectionMonitor();
      const int size_y = region.top - 28 >= monitor.top ? region.top - 28 : region.top + 2;
      const int size_x = static_cast<int>(std::clamp<LONG>(region.left, monitor.left,
                                    std::max(monitor.left, monitor.right - 180)));
      RECT size_rect{size_x, size_y, size_x + 180, size_y + 26};
      FillRect(dc, &size_rect, reinterpret_cast<HBRUSH>(GetStockObject(BLACK_BRUSH)));
      Text(dc, dimensions, size_rect, RGB(255, 255, 255), DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    }
    const auto hint = error.empty() ? Label("hint", L"Drag to select an area. Release to edit. Esc to cancel.") : error;
    RECT hint_rect = hint_bounds;
    HBRUSH hint_brush = CreateSolidBrush(RGB(31, 42, 49));
    auto previous_hint_brush = SelectObject(dc, hint_brush);
    auto previous_hint_pen = SelectObject(dc, GetStockObject(NULL_PEN));
    RoundRect(dc, hint_rect.left, hint_rect.top, hint_rect.right, hint_rect.bottom, 16, 16);
    SelectObject(dc, previous_hint_pen);
    SelectObject(dc, previous_hint_brush);
    DeleteObject(hint_brush);
    Text(dc, hint, hint_rect, error.empty() ? RGB(245, 247, 250) : RGB(255, 166, 166),
         DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    BitBlt(window_dc, 0, 0, width, height, dc, 0, 0, SRCCOPY);
    SelectObject(dc, old); DeleteObject(frame); DeleteDC(dc);
    EndPaint(hwnd, &paint);
  }

  void PointerDown(Point p) {
    dragging = true; start = current = p;
    SetCapture(overlay);
  }
  void PointerUp() {
    if (!dragging) return;
    dragging = false;
    ReleaseCapture();
    selected = region.usable();
    if (selected) OpenEditor();
  }
  void Reselect() {
    selected = dragging = false;
    region = {};
    error.clear();
    InvalidateRect(overlay, nullptr, FALSE);
  }
  void Key(WPARAM value) {
    if (value == VK_ESCAPE) Close();
    else if (value == VK_RETURN && selected) OpenEditor();
  }

  // Pass selected physical pixels in memory; Flutter owns all annotations.
  void OpenEditor() {
    HDC dc = CreateCompatibleDC(snapshot_dc);
    HBITMAP output = CreateCompatibleBitmap(snapshot_dc, region.width(), region.height());
    std::vector<uint8_t> png;
    if (dc && output) {
      auto old = SelectObject(dc, output);
      BitBlt(dc, 0, 0, region.width(), region.height(), snapshot_dc,
             region.left, region.top, SRCCOPY);
      SelectObject(dc, old);
      UINT count = 0, size = 0;
      if (Gdiplus::GetImageEncodersSize(&count, &size) == Gdiplus::Ok && size) {
        std::vector<BYTE> codecs(size);
        auto* encoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(codecs.data());
        if (Gdiplus::GetImageEncoders(count, size, encoders) == Gdiplus::Ok) {
          for (UINT i = 0; i < count; ++i) {
            if (wcscmp(encoders[i].MimeType, L"image/png") != 0) continue;
            IStream* stream = nullptr;
            if (SUCCEEDED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) {
              Gdiplus::Bitmap image(output, nullptr);
              if (image.Save(stream, &encoders[i].Clsid, nullptr) == Gdiplus::Ok) {
                STATSTG stat{};
                HGLOBAL memory = nullptr;
                if (SUCCEEDED(stream->Stat(&stat, STATFLAG_NONAME)) &&
                    SUCCEEDED(GetHGlobalFromStream(stream, &memory)) &&
                    stat.cbSize.HighPart == 0) {
                  auto* data = static_cast<uint8_t*>(GlobalLock(memory));
                  if (data) {
                    png.assign(data, data + stat.cbSize.LowPart);
                    GlobalUnlock(memory);
                  }
                }
              }
              stream->Release();
            }
            break;
          }
        }
      }
    }
    if (output) DeleteObject(output);
    if (dc) DeleteDC(dc);
    if (png.empty()) {
      error = Label("exportError", L"Could not open editor. Retry or press Esc.");
      InvalidateRect(overlay, nullptr, FALSE);
      return;
    }
    Close();
    editing = true;
    channel->InvokeMethod("edit", std::make_unique<Value>(std::move(png)),
        std::make_unique<flutter::MethodResultFunctions<Value>>(
            nullptr,
            [this](const std::string&, const std::string&, const Value*) {
              editing = false;
            },
            [this]() { editing = false; }));
  }
};

ScreenshotPlugin::ScreenshotPlugin(HWND owner, flutter::BinaryMessenger* messenger)
    : impl_(std::make_unique<Impl>(owner, messenger)) {}
ScreenshotPlugin::~ScreenshotPlugin() = default;
bool ScreenshotPlugin::HandleHotKey(WPARAM id) {
  if (!impl_->registered || id != impl_->hotkey_id) return false;
  if (!impl_->overlay && !impl_->editing && !impl_->Capture()) {
    MessageBoxW(nullptr, impl_->Label("captureError", L"Could not capture the screen.").c_str(),
        L"DingDong", MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
  }
  return true;
}
