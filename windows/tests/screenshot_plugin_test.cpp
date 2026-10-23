// Native selection/capture integration: synthetic desktop, in-memory PNG handoff.
#include <windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include "../runner/screenshot_plugin.cpp"

class Messenger : public flutter::BinaryMessenger {
 public:
  flutter::BinaryMessageHandler handler;
  mutable std::vector<uint8_t> png;
  mutable bool fail_editor = false;
  void Send(const std::string& channel, const uint8_t* data, size_t size,
            flutter::BinaryReply reply = nullptr) const override {
    assert(channel == "dingdong/screenshot_plugin");
    auto call = flutter::StandardMethodCodec::GetInstance().DecodeMethodCall(data, size);
    assert(call && call->method_name() == "edit");
    png = std::get<std::vector<uint8_t>>(*call->arguments());
    auto response = fail_editor
        ? flutter::StandardMethodCodec::GetInstance().EncodeErrorEnvelope("unavailable", "test")
        : flutter::StandardMethodCodec::GetInstance().EncodeSuccessEnvelope();
    if (reply) reply(response->data(), response->size());
  }
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
static HWND Capture(Messenger& messenger) {
  assert(messenger.Call("capture"));
  HWND overlay = FindWindowW(kOverlayClass, nullptr);
  assert(overlay);
  return overlay;
}
static void Select(HWND overlay) {
  const int ox = -GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int oy = -GetSystemMetrics(SM_YVIRTUALSCREEN);
  SendMessageW(overlay, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(ox + 700, oy + 450));
  SendMessageW(overlay, WM_MOUSEMOVE, MK_LBUTTON, MAKELPARAM(ox + 100, oy + 100));
  SendMessageW(overlay, WM_LBUTTONUP, 0, MAKELPARAM(ox + 100, oy + 100));
}
int wmain(int argc, wchar_t** argv) {
  assert(argc == 2);
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  const auto rect = screenshot::Region({700, 450}, {-20, -10}, 600, 400);
  assert(rect.left == 0 && rect.top == 0 && rect.right == 600 && rect.bottom == 400);
  assert(!screenshot::Region({5, 5}, {5, 5}, 800, 600).usable());
  WNDCLASSW wc{}; wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"DingDongScreenshotSyntheticTest"; wc.lpfnWndProc = Background;
  RegisterClassW(&wc);
  HWND owner = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, wc.lpszClassName,
      L"Synthetic screenshot validation", WS_POPUP | WS_VISIBLE,
      GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN),
      GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN),
      nullptr, nullptr, wc.hInstance, nullptr);
  UpdateWindow(owner); DwmFlush(); Sleep(100);
  Messenger messenger;
  {
    ScreenshotPlugin plugin(owner, &messenger);
    const Map shortcut{{Value("key"), Value("F11")}, {Value("primary"), Value(true)},
                       {Value("alt"), Value(true)}, {Value("shift"), Value(true)}};
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    HWND overlay = Capture(messenger);
    assert(!messenger.Call("capture"));
    Select(overlay);
    assert(!FindWindowW(kOverlayClass, nullptr));
    assert(messenger.png.size() > 8 && messenger.png[0] == 0x89 && messenger.png[1] == 'P');
    // Editor lifetime blocks overlapping captures even after the overlay closes.
    assert(!messenger.Call("capture"));
    {
      std::ofstream file(argv[1], std::ios::binary);
      file.write(reinterpret_cast<const char*>(messenger.png.data()), messenger.png.size());
    }
    {
      Gdiplus::Bitmap image(argv[1]);
      assert(image.GetLastStatus() == Gdiplus::Ok);
      assert(image.GetWidth() == 600 && image.GetHeight() == 350);
      Gdiplus::Color color; image.GetPixel(10, 10, &color);
      assert(color.GetB() == 80 && color.GetR() == 20);
    }
    assert(messenger.Call("finish"));
    // Registration conflicts retain the existing working shortcut.
    assert(RegisterHotKey(owner, 0xDD04, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'X'));
    const Map blocked{{Value("key"), Value("X")}, {Value("primary"), Value(true)},
                       {Value("alt"), Value(true)}};
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(blocked)}}));
    UnregisterHotKey(owner, 0xDD04);
    overlay = Capture(messenger);
    SendMessageW(overlay, WM_KEYDOWN, VK_ESCAPE, 0);
    assert(!FindWindowW(kOverlayClass, nullptr));
    // Failed Flutter handoff releases busy state.
    messenger.fail_editor = true;
    Select(Capture(messenger));
    overlay = Capture(messenger);
    messenger.fail_editor = false;
    assert(messenger.Call("configure", {{Value("enabled"), Value(false)}}));
    assert(!FindWindowW(kOverlayClass, nullptr));
    assert(!messenger.Call("capture"));
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    Select(Capture(messenger));
    assert(messenger.Call("configure", {{Value("enabled"), Value(false)}}));
    assert(!messenger.Call("capture"));
  }
  DestroyWindow(owner);
  std::cout << "Native geometry, physical PNG pixels, editor handoff, busy/finish, conflict rollback, handoff failure, cancel and disable passed.\n";
}
