#include "flutter_window.h"

#include <optional>
#include <string>

#include <mmsystem.h>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValueName[] = L"DingDong";

bool IsLaunchAtStartupEnabled() {
  wchar_t value[MAX_PATH * 2] = {};
  DWORD size = sizeof(value);
  return ::RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValueName,
                        RRF_RT_REG_SZ, nullptr, value, &size) == ERROR_SUCCESS;
}

LONG SetLaunchAtStartupEnabled(bool enabled) {
  if (!enabled) {
    const LONG status =
        ::RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValueName);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
  }
  wchar_t executable[MAX_PATH] = {};
  const DWORD length = ::GetModuleFileNameW(nullptr, executable, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return ERROR_BAD_PATHNAME;
  }
  const std::wstring command = L"\"" + std::wstring(executable, length) + L"\"";
  HKEY key = nullptr;
  LONG status = ::RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                                  KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status == ERROR_SUCCESS) {
    status = ::RegSetValueExW(
        key, kRunValueName, 0, REG_SZ,
        reinterpret_cast<const BYTE*>(command.c_str()),
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
    ::RegCloseKey(key);
  }
  return status;
}

const flutter::EncodableValue* FindArgument(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    const char* key) {
  const auto* arguments =
      std::get_if<flutter::EncodableMap>(call.arguments());
  if (!arguments) {
    return nullptr;
  }
  const auto found = arguments->find(flutter::EncodableValue(key));
  return found == arguments->end() ? nullptr : &found->second;
}

std::wstring Utf8ToWide(const std::string& value) {
  const int size = ::MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    return {};
  }
  std::wstring result(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), -1, result.data(), size);
  return result;
}

std::optional<std::wstring> FlutterSoundAssetPath(const std::string& sound) {
  const wchar_t* file_name = nullptr;
  if (sound == "default" || sound == "random") {
    file_name = L"ding-wood.wav";
  } else if (sound == "dingSoft") {
    file_name = L"ding-soft.wav";
  } else if (sound == "dingBright") {
    file_name = L"ding-bright.wav";
  } else if (sound == "dingCrisp") {
    file_name = L"ding-crisp.wav";
  } else if (sound == "dingWood") {
    file_name = L"ding-wood.wav";
  } else if (sound == "dingDeep") {
    file_name = L"ding-deep.wav";
  }
  if (!file_name) {
    return std::nullopt;
  }

  wchar_t executable[MAX_PATH] = {};
  const DWORD length = ::GetModuleFileNameW(nullptr, executable, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return std::nullopt;
  }
  std::wstring directory(executable, length);
  const size_t separator = directory.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return std::nullopt;
  }
  directory.resize(separator);
  return directory + L"\\data\\flutter_assets\\Assets\\Sounds\\" +
         file_name;
}

void PlayNotificationSound(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    const std::string& sound) {
  if (sound == "muted") {
    return;
  }
  if (sound == "custom") {
    if (const auto* value = FindArgument(call, "customSoundPath")) {
      if (const auto* path = std::get_if<std::string>(value)) {
        const std::wstring wide_path = Utf8ToWide(*path);
        if (!wide_path.empty() &&
            ::PlaySoundW(wide_path.c_str(), nullptr,
                         SND_FILENAME | SND_ASYNC | SND_NODEFAULT) != FALSE) {
          return;
        }
      }
    }
  }
  if (const auto asset = FlutterSoundAssetPath(sound)) {
    if (::PlaySoundW(asset->c_str(), nullptr,
                     SND_FILENAME | SND_ASYNC | SND_NODEFAULT) != FALSE) {
      return;
    }
  }
  ::MessageBeep(sound == "system" ? MB_OK : MB_ICONINFORMATION);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    RegisterPlugins(flutter_view_controller->engine());
  });
  clipboard_monitor_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "dingdong/clipboard_monitor",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_monitor_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "changeCount") {
          result->Success(flutter::EncodableValue(
              static_cast<int64_t>(::GetClipboardSequenceNumber())));
          return;
        }
        result->NotImplemented();
      });
  hotkey_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dingdong/global_hotkey",
          &flutter::StandardMethodCodec::GetInstance());
  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "register") {
          hotkey_registered_ =
              ::RegisterHotKey(GetHandle(), 0xDD01,
                               MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, 'V') != 0;
          result->Success(flutter::EncodableValue(hotkey_registered_));
          return;
        }
        if (call.method_name() == "unregister") {
          if (hotkey_registered_) {
            ::UnregisterHotKey(GetHandle(), 0xDD01);
            hotkey_registered_ = false;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "pasteToPrevious") {
          if (!previous_foreground_window_ ||
              !::IsWindow(previous_foreground_window_)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          ::ShowWindow(GetHandle(), SW_HIDE);
          ::SetForegroundWindow(previous_foreground_window_);
          ::Sleep(50);
          INPUT input[4] = {};
          input[0].type = INPUT_KEYBOARD;
          input[0].ki.wVk = VK_CONTROL;
          input[1].type = INPUT_KEYBOARD;
          input[1].ki.wVk = 'V';
          input[2] = input[1];
          input[2].ki.dwFlags = KEYEVENTF_KEYUP;
          input[3] = input[0];
          input[3].ki.dwFlags = KEYEVENTF_KEYUP;
          const UINT sent = ::SendInput(4, input, sizeof(INPUT));
          previous_foreground_window_ = nullptr;
          result->Success(flutter::EncodableValue(sent == 4));
          return;
        }
        if (call.method_name() == "isPastePermissionGranted") {
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (call.method_name() == "isApplicationActive") {
          DWORD foreground_process_id = 0;
          ::GetWindowThreadProcessId(::GetForegroundWindow(),
                                     &foreground_process_id);
          result->Success(flutter::EncodableValue(
              foreground_process_id == ::GetCurrentProcessId()));
          return;
        }
        if (call.method_name() == "openPastePermissionSettings") {
          result->Success();
          return;
        }
        result->NotImplemented();
      });
  notification_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dingdong/notification",
          &flutter::StandardMethodCodec::GetInstance());
  notification_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const bool is_preview = call.method_name() == "preview";
        if (call.method_name() != "notify" && !is_preview) {
          result->NotImplemented();
          return;
        }
        std::string sound = "default";
        if (const auto* value = FindArgument(call, "sound")) {
          if (const auto* string_value = std::get_if<std::string>(value)) {
            sound = *string_value;
          }
        }
        PlayNotificationSound(call, sound);
        if (is_preview) {
          result->Success();
          return;
        }
        FLASHWINFO flash_info = {};
        flash_info.cbSize = sizeof(FLASHWINFO);
        flash_info.hwnd = GetHandle();
        flash_info.dwFlags = FLASHW_TRAY | FLASHW_TIMERNOFG;
        flash_info.uCount = 8;
        if (const auto* value = FindArgument(call, "flashCount")) {
          if (const auto* count = std::get_if<int32_t>(value)) {
            flash_info.uCount = static_cast<UINT>(*count);
          } else if (const auto* count64 = std::get_if<int64_t>(value)) {
            flash_info.uCount = static_cast<UINT>(*count64);
          }
        }
        flash_info.dwTimeout = 0;
        ::FlashWindowEx(&flash_info);
        result->Success();
      });
  launch_at_startup_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "dingdong/launch_at_startup",
          &flutter::StandardMethodCodec::GetInstance());
  launch_at_startup_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "isEnabled") {
          result->Success(flutter::EncodableValue(IsLaunchAtStartupEnabled()));
          return;
        }
        if (call.method_name() == "setEnabled") {
          const auto* value = FindArgument(call, "enabled");
          const auto* enabled = value ? std::get_if<bool>(value) : nullptr;
          if (!enabled) {
            result->Error("invalid_arguments", "enabled must be a boolean");
            return;
          }
          const LONG status = SetLaunchAtStartupEnabled(*enabled);
          if (status == ERROR_SUCCESS) {
            result->Success();
          } else {
            result->Error("launch_at_startup_failed",
                          "Could not update the current-user startup entry");
          }
          return;
        }
        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    if (hotkey_registered_) {
      ::UnregisterHotKey(GetHandle(), 0xDD01);
      hotkey_registered_ = false;
    }
    hotkey_channel_.reset();
    notification_channel_.reset();
    launch_at_startup_channel_.reset();
    clipboard_monitor_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_HOTKEY:
      if (wparam == 0xDD01 && hotkey_channel_) {
        const HWND foreground = ::GetForegroundWindow();
        if (foreground && foreground != GetHandle()) {
          previous_foreground_window_ = foreground;
        }
        hotkey_channel_->InvokeMethod(
            "pressed", std::make_unique<flutter::EncodableValue>());
        return 0;
      }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
