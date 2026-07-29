#include "flutter_window.h"

#include <optional>
#include <string>

#include <mmsystem.h>

#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "application_updater.h"

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

struct GlobalHotKeyConfiguration {
  UINT modifiers;
  UINT virtual_key;
};

constexpr GlobalHotKeyConfiguration kDefaultGlobalHotKey{
    MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, 'V'};

std::optional<UINT> GlobalHotKeyVirtualKey(const std::string& name) {
  if (name.size() == 1) {
    const char value = name.front();
    if ((value >= 'A' && value <= 'Z') || (value >= '0' && value <= '9')) {
      return static_cast<UINT>(value);
    }
  }
  if (name.size() >= 2 && name.front() == 'F') {
    int number = 0;
    for (size_t index = 1; index < name.size(); index += 1) {
      const char value = name[index];
      if (value < '0' || value > '9') {
        return std::nullopt;
      }
      number = number * 10 + (value - '0');
    }
    if (number >= 1 && number <= 12) {
      return static_cast<UINT>(VK_F1 + number - 1);
    }
  }
  if (name == "SPACE") {
    return VK_SPACE;
  }
  if (name == "RETURN") {
    return VK_RETURN;
  }
  if (name == "LEFT") {
    return VK_LEFT;
  }
  if (name == "RIGHT") {
    return VK_RIGHT;
  }
  if (name == "UP") {
    return VK_UP;
  }
  if (name == "DOWN") {
    return VK_DOWN;
  }
  return std::nullopt;
}

std::optional<GlobalHotKeyConfiguration> ReadGlobalHotKeyConfiguration(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  if (!call.arguments()) {
    return kDefaultGlobalHotKey;
  }
  const auto* key_value = FindArgument(call, "key");
  const auto* key = key_value ? std::get_if<std::string>(key_value) : nullptr;
  if (!key) {
    return std::nullopt;
  }
  const std::optional<UINT> virtual_key = GlobalHotKeyVirtualKey(*key);
  if (!virtual_key) {
    return std::nullopt;
  }
  UINT modifiers = MOD_NOREPEAT;
  const auto is_enabled = [&call](const char* name) {
    const auto* value = FindArgument(call, name);
    const auto* enabled = value ? std::get_if<bool>(value) : nullptr;
    return enabled && *enabled;
  };
  if (is_enabled("primary")) {
    modifiers |= MOD_CONTROL;
  }
  if (is_enabled("secondary")) {
    modifiers |= MOD_WIN;
  }
  if (is_enabled("alt")) {
    modifiers |= MOD_ALT;
  }
  if (is_enabled("shift")) {
    modifiers |= MOD_SHIFT;
  }
  if (modifiers == MOD_NOREPEAT) {
    return std::nullopt;
  }
  return GlobalHotKeyConfiguration{modifiers, *virtual_key};
}

bool SameGlobalHotKey(const GlobalHotKeyConfiguration& left,
                      const GlobalHotKeyConfiguration& right) {
  return left.modifiers == right.modifiers &&
         left.virtual_key == right.virtual_key;
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

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int size = ::WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  if (size <= 0) {
    return {};
  }
  std::string result(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
      result.data(), size, nullptr, nullptr);
  return result;
}

std::string ForegroundApplicationDescription() {
  const HWND window = ::GetForegroundWindow();
  if (!window) {
    return {};
  }
  wchar_t title[512] = {};
  ::GetWindowTextW(window, title, 512);
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(window, &process_id);
  HANDLE process = ::OpenProcess(
      PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  std::wstring executable;
  if (process) {
    wchar_t path[MAX_PATH * 4] = {};
    DWORD length = MAX_PATH * 4;
    if (::QueryFullProcessImageNameW(process, 0, path, &length)) {
      executable.assign(path, length);
      const size_t separator = executable.find_last_of(L"\\/");
      if (separator != std::wstring::npos) {
        executable = executable.substr(separator + 1);
      }
    }
    ::CloseHandle(process);
  }
  const std::wstring window_title(title);
  if (!window_title.empty() && !executable.empty()) {
    return WideToUtf8(window_title + L" · " + executable);
  }
  return WideToUtf8(
      !executable.empty() ? executable : window_title);
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
        if (call.method_name() == "sourceApplication") {
          result->Success(
              flutter::EncodableValue(ForegroundApplicationDescription()));
          return;
        }
        result->NotImplemented();
      });
  application_updater_ = std::make_shared<ApplicationUpdater>(GetHandle());
  updater_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "dingdong/updater",
          &flutter::StandardMethodCodec::GetInstance());
  updater_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "isSupported") {
          result->Success(
              flutter::EncodableValue(application_updater_->IsSupported()));
          return;
        }
        if (call.method_name() == "state") {
          const ApplicationUpdateSnapshot snapshot =
              application_updater_->Snapshot();
          flutter::EncodableMap values;
          values[flutter::EncodableValue("phase")] =
              flutter::EncodableValue(snapshot.phase);
          if (snapshot.progress.has_value()) {
            values[flutter::EncodableValue("progress")] =
                flutter::EncodableValue(snapshot.progress.value());
          }
          if (!snapshot.target_version.empty()) {
            values[flutter::EncodableValue("targetVersion")] =
                flutter::EncodableValue(snapshot.target_version);
          }
          if (!snapshot.message.empty()) {
            values[flutter::EncodableValue("message")] =
                flutter::EncodableValue(snapshot.message);
          }
          result->Success(flutter::EncodableValue(values));
          return;
        }
        if (call.method_name() == "installLatest") {
          std::string error;
          if (application_updater_->InstallLatest(&error)) {
            result->Success();
          } else {
            result->Error("update_unavailable", error);
          }
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
          const auto configuration = ReadGlobalHotKeyConfiguration(call);
          if (!configuration) {
            result->Success(flutter::EncodableValue(false));
            return;
          }
          const GlobalHotKeyConfiguration previous{
              hotkey_modifiers_, hotkey_virtual_key_};
          if (hotkey_registered_ &&
              SameGlobalHotKey(previous, *configuration)) {
            result->Success(flutter::EncodableValue(true));
            return;
          }
          const bool had_registered_hotkey = hotkey_registered_;
          if (hotkey_registered_) {
            ::UnregisterHotKey(GetHandle(), 0xDD01);
            hotkey_registered_ = false;
          }
          const bool registered =
              ::RegisterHotKey(GetHandle(), 0xDD01, configuration->modifiers,
                               configuration->virtual_key) != 0;
          if (registered) {
            hotkey_registered_ = true;
            hotkey_modifiers_ = configuration->modifiers;
            hotkey_virtual_key_ = configuration->virtual_key;
          } else if (had_registered_hotkey ||
                     !SameGlobalHotKey(*configuration,
                                       kDefaultGlobalHotKey)) {
            hotkey_registered_ =
                ::RegisterHotKey(GetHandle(), 0xDD01, previous.modifiers,
                                 previous.virtual_key) != 0;
          }
          result->Success(flutter::EncodableValue(registered));
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
    updater_channel_.reset();
    application_updater_.reset();
    clipboard_monitor_channel_.reset();
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kDingDongExitForUpdateMessage) {
    // Do not let window_manager turn this close into "hide to tray". Velopack
    // is already waiting for this process to terminate before swapping files.
    ::DestroyWindow(hwnd);
    return 0;
  }

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
