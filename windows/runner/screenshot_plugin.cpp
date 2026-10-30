#include "screenshot_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <map>
#include <string>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
constexpr UINT kHotkeyA = 0xDD02;
constexpr UINT kHotkeyB = 0xDD03;
constexpr UINT_PTR kSystemCaptureTimer = 0xDD04;
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
  bool registered = false, system_pending = false;
  ULONGLONG system_wait_started = 0;
  UINT hotkey_id = kHotkeyA, modifiers = 0, key = 0;
  std::map<std::string, std::wstring> labels;
  std::unique_ptr<flutter::MethodChannel<Value>> channel;

  Impl(HWND window, flutter::BinaryMessenger* messenger) : owner(window) {
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
        else if (system_pending) result->Error("capture_busy", "capture_busy");
        else if (!Capture()) result->Error("capture_failed", "capture_failed");
        else result->Success();
      } else {
        result->NotImplemented();
      }
    });
  }

  ~Impl() {
    channel->SetMethodCallHandler(nullptr);
    if (registered) UnregisterHotKey(owner, hotkey_id);
    Close();
  }

  Value Status() const {
    return Value(Map{{Value("supported"), Value(true)},
                     {Value("running"), Value(registered)},
                     {Value("capturing"), Value(system_pending)}});
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
      if (system_pending) return "capture_busy";
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
      // The mapped system chord must remain owned by Windows, otherwise our
      // injected Win+Shift+S would trigger this same registration again.
      if (next_key == 'S' && next_modifiers == (MOD_WIN | MOD_SHIFT | MOD_NOREPEAT)) {
        return "shortcut_conflict";
      }
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

  void Close() {
    KillTimer(owner, kSystemCaptureTimer);
    system_pending = false;
  }

  bool Capture() {
    if (system_pending) return false;
    // Wait for the custom shortcut to be released before mapping Win+Shift+S.
    system_pending = true;
    system_wait_started = GetTickCount64();
    if (!SetTimer(owner, kSystemCaptureTimer, 20, nullptr)) {
      system_pending = false;
      return false;
    }
    return true;
  }
};

bool ScreenshotPlugin::HandleTimer(WPARAM id) {
  if (id != kSystemCaptureTimer) return false;
  if (!impl_->system_pending) return true;
  const bool held = (GetAsyncKeyState(VK_CONTROL) & 0x8000) ||
      (GetAsyncKeyState(VK_MENU) & 0x8000) || (GetAsyncKeyState(VK_SHIFT) & 0x8000) ||
      (GetAsyncKeyState(VK_LWIN) & 0x8000) || (GetAsyncKeyState(VK_RWIN) & 0x8000) ||
      (GetAsyncKeyState(impl_->key) & 0x8000);
  if (held && GetTickCount64() - impl_->system_wait_started < 5000) return true;
  KillTimer(impl_->owner, kSystemCaptureTimer);
  impl_->system_pending = false;
  if (held || !impl_->registered) return true;
  INPUT keys[6]{};
  const WORD codes[6] = {VK_LWIN, VK_LSHIFT, 'S', 'S', VK_LSHIFT, VK_LWIN};
  for (int i = 0; i < 6; ++i) {
    keys[i].type = INPUT_KEYBOARD;
    keys[i].ki.wVk = codes[i];
    if (i >= 3) keys[i].ki.dwFlags = KEYEVENTF_KEYUP;
  }
  if (SendInput(6, keys, sizeof(INPUT)) != 6) {
    // Release even a partially injected chord before reporting the failure.
    SendInput(3, keys + 3, sizeof(INPUT));
    MessageBoxW(nullptr, impl_->Label("captureError", L"Could not open system capture.").c_str(),
        L"DingDong", MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
  }
  return true;
}

ScreenshotPlugin::ScreenshotPlugin(HWND owner, flutter::BinaryMessenger* messenger)
    : impl_(std::make_unique<Impl>(owner, messenger)) {}
ScreenshotPlugin::~ScreenshotPlugin() = default;
bool ScreenshotPlugin::HandleHotKey(WPARAM id) {
  if (!impl_->registered || id != impl_->hotkey_id) return false;
  if (!impl_->system_pending && !impl_->Capture()) {
    MessageBoxW(nullptr, impl_->Label("captureError", L"Could not open system capture.").c_str(),
        L"DingDong", MB_OK | MB_ICONERROR | MB_SETFOREGROUND);
  }
  return true;
}
