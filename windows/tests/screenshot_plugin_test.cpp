// Standalone native integration test. The background is synthetic; dialog and
// clipboard ports are replaced so no personal screenshot or clipboard is touched.
#include <windows.h>
#include <windowsx.h>
#include <commdlg.h>
#include <dwmapi.h>
#include <cassert>
#include <filesystem>
#include <iostream>
#include <string>

static std::wstring output_path;
static HGLOBAL clipboard_data = nullptr;
static bool clipboard_available = true;
static bool cancel_save = false;
static int origin_x = 0, origin_y = 0;
static BOOL WINAPI TestSaveFileName(OPENFILENAMEW* dialog) {
  if (cancel_save) return FALSE;
  wcscpy_s(dialog->lpstrFile, dialog->nMaxFile, output_path.c_str());
  return TRUE;
}
static DWORD WINAPI TestDialogError() { return 0; }
static BOOL WINAPI TestOpenClipboard(HWND) { return clipboard_available; }
static BOOL WINAPI TestEmptyClipboard() { return TRUE; }
static BOOL WINAPI TestCloseClipboard() { return TRUE; }
static HANDLE WINAPI TestSetClipboardData(UINT format, HANDLE memory) {
  assert(format == CF_DIB);
  clipboard_data = static_cast<HGLOBAL>(memory);
  return memory;
}
#define GetSaveFileNameW TestSaveFileName
#define CommDlgExtendedError TestDialogError
#define OpenClipboard TestOpenClipboard
#define EmptyClipboard TestEmptyClipboard
#define CloseClipboard TestCloseClipboard
#define SetClipboardData TestSetClipboardData
#include "../runner/screenshot_plugin.cpp"
#undef GetSaveFileNameW
#undef CommDlgExtendedError
#undef OpenClipboard
#undef EmptyClipboard
#undef CloseClipboard
#undef SetClipboardData

class Messenger : public flutter::BinaryMessenger {
 public:
  flutter::BinaryMessageHandler handler;
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply = nullptr) const override {}
  void SetMessageHandler(const std::string&, flutter::BinaryMessageHandler value) override {
    handler = std::move(value);
  }
  bool Call(const std::string& name, const Map& args = {}) {
    auto encoded = flutter::StandardMethodCodec::GetInstance().EncodeMethodCall(
        flutter::MethodCall<Value>(name, std::make_unique<Value>(args)));
    bool success = false, replied = false;
    handler(encoded->data(), encoded->size(), [&](const uint8_t* data, size_t size) {
      replied = true; success = size > 0 && data[0] == 0;
    });
    assert(replied);
    return success;
  }
};

static LRESULT CALLBACK Background(HWND hwnd, UINT message, WPARAM w, LPARAM l) {
  if (message == WM_PAINT) {
    PAINTSTRUCT p{}; HDC dc = BeginPaint(hwnd, &p);
    RECT bounds{}; GetClientRect(hwnd, &bounds);
    HBRUSH brush = CreateSolidBrush(RGB(20, 40, 80));
    FillRect(dc, &bounds, brush); DeleteObject(brush);
    EndPaint(hwnd, &p); return 0;
  }
  return DefWindowProcW(hwnd, message, w, l);
}

static void Drag(HWND overlay, int x1, int y1, int x2, int y2) {
  x1 += origin_x; x2 += origin_x;
  y1 += origin_y; y2 += origin_y;
  SendMessageW(overlay, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(x1, y1));
  SendMessageW(overlay, WM_MOUSEMOVE, MK_LBUTTON, MAKELPARAM(x2, y2));
  SendMessageW(overlay, WM_LBUTTONUP, 0, MAKELPARAM(x2, y2));
}
static void Button(HWND overlay, int index) {
  const int dpi = static_cast<int>(GetDpiForWindow(overlay));
  const int bw = MulDiv(72, dpi, 96), bh = MulDiv(40, dpi, 96);
  const int left = std::clamp(origin_x + 700 - bw * 8, 0,
      std::max(0, GetSystemMetrics(SM_CXVIRTUALSCREEN) - bw * 8));
  SendMessageW(overlay, WM_LBUTTONDOWN, MK_LBUTTON,
      MAKELPARAM(left + bw * index + bw / 2, origin_y + 460 + bh / 2));
}
static HWND Capture(Messenger& messenger) {
  assert(messenger.Call("capture"));
  HWND overlay = FindWindowW(kOverlayClass, nullptr);
  assert(overlay);
  Drag(overlay, 100, 100, 700, 450);
  return overlay;
}
static void CheckGeometry() {
  auto rect = screenshot::Region({700, 450}, {-20, -10}, 600, 400);
  assert(rect.left == 0 && rect.top == 0 && rect.right == 600 && rect.bottom == 400);
  assert(!screenshot::Region({5, 5}, {5, 5}, 800, 600).usable());
  rect = screenshot::Region({700, 450}, {100, 100}, 1920, 1080);
  assert(rect.width() == 600 && rect.height() == 350);
  auto point = screenshot::Clip({1000, -20}, rect);
  assert(point.x == 700 && point.y == 100);
}

int wmain(int argc, wchar_t** argv) {
  assert(argc == 2);
  output_path = std::filesystem::absolute(argv[1]).wstring();
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  CheckGeometry();
  // The virtual desktop's bounding box may begin in a gap between monitors.
  // Place the test region on the primary monitor, whose origin is (0, 0).
  origin_x = -GetSystemMetrics(SM_XVIRTUALSCREEN);
  origin_y = -GetSystemMetrics(SM_YVIRTUALSCREEN);
  WNDCLASSW wc{}; wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"DingDongScreenshotSyntheticTest"; wc.lpfnWndProc = Background;
  RegisterClassW(&wc);
  HWND owner = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, wc.lpszClassName,
      L"Synthetic screenshot validation", WS_POPUP | WS_VISIBLE,
      GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN),
      GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN),
      nullptr, nullptr, wc.hInstance, nullptr);
  UpdateWindow(owner);
  DwmFlush();
  Sleep(100);
  Messenger messenger;
  {
    ScreenshotPlugin plugin(owner, &messenger);
    const Map shortcut{{Value("key"), Value("F11")}, {Value("primary"), Value(true)},
                       {Value("alt"), Value(true)}, {Value("shift"), Value(true)}};
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    HWND overlay = Capture(messenger);
    // Add a red rectangle and export via the real crop/GDI+/PNG code.
    Button(overlay, 0); Drag(overlay, 180, 160, 300, 260);
    Button(overlay, 5);
    assert(!FindWindowW(kOverlayClass, nullptr));
    {
      Gdiplus::Bitmap image(output_path.c_str());
      assert(image.GetLastStatus() == Gdiplus::Ok);
      assert(image.GetWidth() == 600 && image.GetHeight() == 350);
      Gdiplus::Color color;
      image.GetPixel(10, 10, &color);
      assert(color.GetB() == 80 && color.GetR() == 20);
      image.GetPixel(80, 80, &color);
      assert(color.GetR() > 180 && color.GetB() < 140);
    }
    overlay = Capture(messenger);
    Button(overlay, 1); Drag(overlay, 180, 160, 350, 280);
    Button(overlay, 6);
    assert(!FindWindowW(kOverlayClass, nullptr));
    assert(clipboard_data);
    auto* info = static_cast<BITMAPINFOHEADER*>(GlobalLock(clipboard_data));
    assert(info->biWidth == 600 && info->biHeight == -350 && info->biBitCount == 32);
    auto* pixels = reinterpret_cast<BYTE*>(info + 1);
    bool red = false;
    for (int y = 55; y < 190; ++y) for (int x = 75; x < 260; ++x) {
      auto* pixel = pixels + (y * 600 + x) * 4;
      if (pixel[2] > 180 && pixel[0] < 140) red = true;
    }
    assert(red);
    GlobalUnlock(clipboard_data); GlobalFree(clipboard_data); clipboard_data = nullptr;

    overlay = Capture(messenger);
    Button(overlay, 2);
    SendMessageW(overlay, WM_LBUTTONDOWN, MK_LBUTTON,
        MAKELPARAM(origin_x + 180, origin_y + 160));
    HWND edit = FindWindowExW(overlay, nullptr, L"EDIT", nullptr);
    assert(edit);
    SetWindowTextW(edit, L"Screenshot test");
    SendMessageW(edit, WM_KEYDOWN, VK_RETURN, 0);
    assert(!FindWindowExW(overlay, nullptr, L"EDIT", nullptr));
    Button(overlay, 6);
    assert(clipboard_data);
    info = static_cast<BITMAPINFOHEADER*>(GlobalLock(clipboard_data));
    pixels = reinterpret_cast<BYTE*>(info + 1);
    red = false;
    for (int y = 60; y < 110; ++y) for (int x = 80; x < 240; ++x) {
      auto* pixel = pixels + (y * 600 + x) * 4;
      if (pixel[2] > 180 && pixel[0] < 140) red = true;
    }
    assert(red);
    GlobalUnlock(clipboard_data); GlobalFree(clipboard_data); clipboard_data = nullptr;

    overlay = Capture(messenger);
    Button(overlay, 0); Drag(overlay, 180, 160, 300, 260);
    Button(overlay, 3); Button(overlay, 6);
    info = static_cast<BITMAPINFOHEADER*>(GlobalLock(clipboard_data));
    pixels = reinterpret_cast<BYTE*>(info + 1);
    auto* sample = pixels + (80 * 600 + 80) * 4;
    assert(sample[0] == 80 && sample[2] == 20);
    GlobalUnlock(clipboard_data); GlobalFree(clipboard_data); clipboard_data = nullptr;

    assert(RegisterHotKey(owner, 0xDD04, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'X'));
    Map blocked{{Value("key"), Value("X")}, {Value("primary"), Value(true)},
                 {Value("alt"), Value(true)}};
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(blocked)}}));
    UnregisterHotKey(owner, 0xDD04);

    overlay = Capture(messenger);
    clipboard_available = false; Button(overlay, 6);
    assert(FindWindowW(kOverlayClass, nullptr));
    SendMessageW(overlay, WM_KEYDOWN, VK_ESCAPE, 0);
    assert(!FindWindowW(kOverlayClass, nullptr));
    clipboard_available = true;
    overlay = Capture(messenger);
    cancel_save = true; Button(overlay, 5);
    assert(FindWindowW(kOverlayClass, nullptr));
    SendMessageW(overlay, WM_KEYDOWN, VK_ESCAPE, 0);
    cancel_save = false;
    overlay = Capture(messenger);
    assert(messenger.Call("configure", {{Value("enabled"), Value(false)}}));
    assert(!FindWindowW(kOverlayClass, nullptr));
    assert(!messenger.Call("capture"));
  }
  DestroyWindow(owner);
  std::cout << "Native geometry, PNG crop/rectangle, clipboard arrow/text/undo, conflict, export failure, cancel and disable passed.\n";
}
