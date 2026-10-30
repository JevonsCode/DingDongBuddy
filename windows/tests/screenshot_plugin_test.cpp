// System-shortcut lifecycle only. No screen capture or OS input is emitted.
#include <windows.h>
#include <cassert>
#include <iostream>
#include <vector>
#include "../runner/screenshot_plugin.cpp"

class Messenger : public flutter::BinaryMessenger {
 public:
  flutter::BinaryMessageHandler handler;
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply = nullptr) const override {
    assert(false && "System shortcut mapping must not send image data to Flutter");
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

int wmain() {
  HWND owner = CreateWindowExW(0, L"STATIC", L"System shortcut lifecycle test", 0,
      0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);
  assert(owner);
  Messenger messenger;
  const Map shortcut{{Value("key"), Value("F11")}, {Value("primary"), Value(true)},
                     {Value("alt"), Value(true)}, {Value("shift"), Value(true)}};
  {
    ScreenshotPlugin plugin(owner, &messenger);
    assert(messenger.Call("status"));
    assert(!messenger.Call("capture"));
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)}}));
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    assert(!plugin.HandleHotKey(0xDD05));
    assert(!plugin.HandleTimer(0xDD05));
    // Duplicate requests and configuration cannot interrupt a pending launch.
    assert(messenger.Call("capture"));
    assert(!messenger.Call("capture"));
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    assert(messenger.Call("configure", {{Value("enabled"), Value(false)}}));
    // The queued timer is harmless after disabling; do not pump a live timer.
    assert(plugin.HandleTimer(kSystemCaptureTimer));
    assert(!messenger.Call("capture"));
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
    // Registration failure must retain the existing shortcut.
    assert(RegisterHotKey(owner, 0xDD05, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'X'));
    const Map blocked{{Value("key"), Value("X")}, {Value("primary"), Value(true)},
                      {Value("alt"), Value(true)}};
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(blocked)}}));
    UnregisterHotKey(owner, 0xDD05);
    const Map system_chord{{Value("key"), Value("S")}, {Value("secondary"), Value(true)},
                           {Value("shift"), Value(true)}};
    assert(!messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(system_chord)}}));
    assert(messenger.Call("capture"));
    assert(messenger.Call("configure", {{Value("enabled"), Value(false)}}));
    // Leave enabled to check that destruction releases the registration.
    assert(messenger.Call("configure", {{Value("enabled"), Value(true)},
        {Value("shortcut"), Value(shortcut)}}));
  }
  assert(RegisterHotKey(owner, 0xDD05, MOD_CONTROL | MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, VK_F11));
  UnregisterHotKey(owner, 0xDD05);
  DestroyWindow(owner);
  std::cout << "System shortcut configuration, pending launch cancellation, conflicts and cleanup passed.\n";
}
