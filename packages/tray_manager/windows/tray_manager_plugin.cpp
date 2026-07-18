#include "include/tray_manager/tray_manager_plugin.h"
#include "tray_visual.h"

// This must be included before many other Windows headers.
#include <stdio.h>
#include <windows.h>

#include <shellapi.h>
#include <strsafe.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <codecvt>
#include <map>
#include <memory>
#include <sstream>
#include <vector>

#define WM_MYMESSAGE (WM_USER + 1)

constexpr UINT_PTR kAttentionFlashTimerId = 0xD1D0;
constexpr UINT kAttentionFlashIntervalMs = 550;

namespace {

const flutter::EncodableValue* ValueOrNull(const flutter::EncodableMap& map,
                                           const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

double SrgbChannelToLinear(BYTE value) {
  const double channel = static_cast<double>(value) / 255.0;
  return channel <= 0.04045
             ? channel / 12.92
             : std::pow((channel + 0.055) / 1.055, 2.4);
}

double RelativeLuminance(COLORREF color) {
  return 0.2126 * SrgbChannelToLinear(GetRValue(color)) +
         0.7152 * SrgbChannelToLinear(GetGValue(color)) +
         0.0722 * SrgbChannelToLinear(GetBValue(color));
}

bool SystemUsesLightTheme() {
  DWORD value = 0;
  DWORD value_size = sizeof(value);
  const LSTATUS status = RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr, &value,
      &value_size);
  return status == ERROR_SUCCESS && value != 0;
}

std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>,
    std::default_delete<flutter::MethodChannel<flutter::EncodableValue>>>
    channel = nullptr;

class TrayManagerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  TrayManagerPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~TrayManagerPlugin();

 private:
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> g_converter;

  flutter::PluginRegistrarWindows* registrar;
  NOTIFYICONDATA nid = {};
  NOTIFYICONIDENTIFIER niif = {};
  HICON source_icon = nullptr;
  HICON attention_source_icon = nullptr;
  HICON rendered_icon = nullptr;
  HICON attention_rendered_icon = nullptr;
  int unread_count = 0;
  bool attention_frame = false;
  bool attention_timer_active = false;
  // do create pop-up menu only once.
  HMENU hMenu = CreatePopupMenu();
  bool tray_icon_setted = false;
  UINT windows_taskbar_created_message_id = 0;

  // The ID of the WindowProc delegate registration.
  int window_proc_id = -1;

  void TrayManagerPlugin::_CreateMenu(HMENU menu, flutter::EncodableMap args);
  void TrayManagerPlugin::_ApplyIcon();
  void TrayManagerPlugin::ApplyIconFrame(bool attention);
  void TrayManagerPlugin::StartAttentionFlash();
  void TrayManagerPlugin::AdvanceAttentionFlash();
  void TrayManagerPlugin::CancelAttentionFlash();
  void TrayManagerPlugin::DestroyIconResources();
  bool TrayManagerPlugin::TaskbarSurfaceIsLight();
  void TrayManagerPlugin::NotifyTaskbarAppearanceChanged();

  // Called for top-level WindowProc delegation.
  std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc(HWND hwnd,
                                                             UINT message,
                                                             WPARAM wparam,
                                                             LPARAM lparam);
  HWND TrayManagerPlugin::GetMainWindow();
  void TrayManagerPlugin::Destroy(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetIcon(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetToolTip(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::SetContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::PopUpContextMenu(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::GetBounds(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void TrayManagerPlugin::GetTaskbarSurfaceIsLight(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

static bool plugin_already_registered = false;

// static
void TrayManagerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  if (plugin_already_registered) {
    // Skip registration in subwindow
    return;
  }
  
  plugin_already_registered = true;
  
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "tray_manager",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<TrayManagerPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

TrayManagerPlugin::TrayManagerPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar(registrar) {
  window_proc_id = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
  windows_taskbar_created_message_id = RegisterWindowMessage(L"TaskbarCreated");
}

TrayManagerPlugin::~TrayManagerPlugin() {
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_DELETE, &nid);
    tray_icon_setted = false;
  }
  DestroyIconResources();
  if (hMenu != nullptr) {
    DestroyMenu(hMenu);
    hMenu = nullptr;
  }
  registrar->UnregisterTopLevelWindowProcDelegate(window_proc_id);
}

void TrayManagerPlugin::_CreateMenu(HMENU menu, flutter::EncodableMap args) {
  flutter::EncodableList items = std::get<flutter::EncodableList>(
      args.at(flutter::EncodableValue("items")));

  int count = GetMenuItemCount(menu);
  for (int i = 0; i < count; i++) {
    // always remove at 0 because they shift every time
    RemoveMenu(menu, 0, MF_BYPOSITION);
  }

  for (flutter::EncodableValue item_value : items) {
    flutter::EncodableMap item_map =
        std::get<flutter::EncodableMap>(item_value);
    int id = std::get<int>(item_map.at(flutter::EncodableValue("id")));
    std::string type =
        std::get<std::string>(item_map.at(flutter::EncodableValue("type")));
    std::string label =
        std::get<std::string>(item_map.at(flutter::EncodableValue("label")));
    auto* checked = std::get_if<bool>(ValueOrNull(item_map, "checked"));
    bool disabled =
        std::get<bool>(item_map.at(flutter::EncodableValue("disabled")));

    UINT_PTR item_id = id;
    UINT uFlags = MF_STRING;

    if (disabled) {
      uFlags |= MF_GRAYED;
    }

    if (type.compare("separator") == 0) {
      AppendMenuW(menu, MF_SEPARATOR, item_id, NULL);
    } else {
      if (type.compare("checkbox") == 0) {
        if (checked == nullptr) {
          // skip
        } else {
          uFlags |= (*checked == true ? MF_CHECKED : MF_UNCHECKED);
        }
      } else if (type.compare("submenu") == 0) {
        uFlags |= MF_POPUP;
        HMENU sub_menu = ::CreatePopupMenu();
        _CreateMenu(sub_menu, std::get<flutter::EncodableMap>(item_map.at(
                                  flutter::EncodableValue("submenu"))));
        item_id = reinterpret_cast<UINT_PTR>(sub_menu);
      }
      AppendMenuW(menu, uFlags, item_id, g_converter.from_bytes(label).c_str());
    }
  }
}

std::optional<LRESULT> TrayManagerPlugin::HandleWindowProc(HWND hWnd,
                                                           UINT message,
                                                           WPARAM wParam,
                                                           LPARAM lParam) {
  std::optional<LRESULT> result;
  if (message == WM_DESTROY) {
    if (tray_icon_setted) {
      Shell_NotifyIcon(NIM_DELETE, &nid);
    }
    tray_icon_setted = false;
    DestroyIconResources();
  } else if (message == WM_TIMER &&
             wParam == kAttentionFlashTimerId) {
    AdvanceAttentionFlash();
  } else if (message == WM_COMMAND) {
    flutter::EncodableMap eventData = flutter::EncodableMap();
    eventData[flutter::EncodableValue("id")] =
        flutter::EncodableValue((int)wParam);

    channel->InvokeMethod("onTrayMenuItemClick",
                          std::make_unique<flutter::EncodableValue>(eventData));
  } else if (message == WM_MYMESSAGE) {
    switch (lParam) {
      case WM_LBUTTONUP:
        NotifyTaskbarAppearanceChanged();
        channel->InvokeMethod("onTrayIconMouseDown",
                              std::make_unique<flutter::EncodableValue>());
        break;
      case WM_RBUTTONUP:
        NotifyTaskbarAppearanceChanged();
        channel->InvokeMethod("onTrayIconRightMouseDown",
                              std::make_unique<flutter::EncodableValue>());
        break;
      default:
        return DefWindowProc(hWnd, message, wParam, lParam);
    };
  } else if (message == windows_taskbar_created_message_id) {
    if (windows_taskbar_created_message_id != 0 && tray_icon_setted) {
      tray_icon_setted = false;
      ApplyIconFrame(unread_count > 0 && attention_frame);
    }
    NotifyTaskbarAppearanceChanged();
  } else if (message == WM_SETTINGCHANGE || message == WM_THEMECHANGED ||
             message == WM_DWMCOLORIZATIONCOLORCHANGED) {
    NotifyTaskbarAppearanceChanged();
  } else if (message == WM_POWERBROADCAST) {
    // Handle power management events (sleep/wake)
    switch (wParam) {
      case PBT_APMRESUMEAUTOMATIC:
      case PBT_APMRESUMESUSPEND:
        // System is resuming from sleep/hibernation
        if (tray_icon_setted) {
          tray_icon_setted = false;
          ApplyIconFrame(unread_count > 0 && attention_frame);
        }
        NotifyTaskbarAppearanceChanged();
        break;
      default:
        break;
    }
  }
  return result;
}

HWND TrayManagerPlugin::GetMainWindow() {
  return ::GetAncestor(registrar->GetView()->GetNativeWindow(), GA_ROOT);
}

void TrayManagerPlugin::Destroy(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_DELETE, &nid);
  }
  tray_icon_setted = false;
  DestroyIconResources();

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetIcon(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  std::string iconPath =
      std::get<std::string>(args.at(flutter::EncodableValue("iconPath")));

  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

  HICON replacement_icon = static_cast<HICON>(LoadImage(
      nullptr, converter.from_bytes(iconPath).c_str(), IMAGE_ICON, 64, 64,
      LR_LOADFROMFILE));
  if (replacement_icon == nullptr) {
    result->Error("icon_load_failed", "Unable to load the tray icon file.");
    return;
  }

  auto* attention_path_value =
      std::get_if<std::string>(ValueOrNull(args, "attentionIconPath"));
  HICON replacement_attention_icon = attention_path_value == nullptr
                                         ? CopyIcon(replacement_icon)
                                         : static_cast<HICON>(LoadImage(
                                               nullptr,
                                               converter
                                                   .from_bytes(
                                                       *attention_path_value)
                                                   .c_str(),
                                               IMAGE_ICON, 64, 64,
                                               LR_LOADFROMFILE));
  if (replacement_attention_icon == nullptr) {
    DestroyIcon(replacement_icon);
    result->Error("attention_icon_load_failed",
                  "Unable to load the attention tray icon file.");
    return;
  }

  auto* count_value = std::get_if<int>(ValueOrNull(args, "unreadCount"));
  const int next_count =
      count_value == nullptr ? 0 : std::clamp(*count_value, 0, 999);

  const int icon_width = GetSystemMetrics(SM_CXSMICON);
  const int icon_height = GetSystemMetrics(SM_CYSMICON);
  HICON replacement_rendered_icon = tray_manager::CreateTrayIcon(
      replacement_icon, icon_width, icon_height);
  HICON replacement_attention_rendered_icon = tray_manager::CreateTrayIcon(
      replacement_attention_icon, icon_width, icon_height);
  if (replacement_rendered_icon == nullptr ||
      replacement_attention_rendered_icon == nullptr) {
    if (replacement_rendered_icon != nullptr) {
      DestroyIcon(replacement_rendered_icon);
    }
    if (replacement_attention_rendered_icon != nullptr) {
      DestroyIcon(replacement_attention_rendered_icon);
    }
    DestroyIcon(replacement_attention_icon);
    DestroyIcon(replacement_icon);
    result->Error("icon_render_failed", "Unable to render the tray icons.");
    return;
  }

  HICON previous_source = source_icon;
  HICON previous_attention_source = attention_source_icon;
  HICON previous_rendered = rendered_icon;
  HICON previous_attention_rendered = attention_rendered_icon;
  source_icon = replacement_icon;
  attention_source_icon = replacement_attention_icon;
  rendered_icon = replacement_rendered_icon;
  attention_rendered_icon = replacement_attention_rendered_icon;
  unread_count = next_count;

  if (unread_count > 0) {
    StartAttentionFlash();
  } else {
    CancelAttentionFlash();
    if (!tray_icon_setted) {
      ApplyIconFrame(false);
    }
  }

  if (previous_source != nullptr) {
    DestroyIcon(previous_source);
  }
  if (previous_attention_source != nullptr) {
    DestroyIcon(previous_attention_source);
  }
  if (previous_rendered != nullptr) {
    DestroyIcon(previous_rendered);
  }
  if (previous_attention_rendered != nullptr) {
    DestroyIcon(previous_attention_rendered);
  }

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::ApplyIconFrame(bool attention) {
  HICON next_icon = attention ? attention_rendered_icon : rendered_icon;
  if (next_icon == nullptr) {
    return;
  }
  attention_frame = attention;
  nid.hIcon = next_icon;
  _ApplyIcon();
}

void TrayManagerPlugin::CancelAttentionFlash() {
  HWND window = GetMainWindow();
  if (window != nullptr && attention_timer_active) {
    KillTimer(window, kAttentionFlashTimerId);
  }
  attention_timer_active = false;
  attention_frame = false;
  if (rendered_icon != nullptr) {
    nid.hIcon = rendered_icon;
    if (tray_icon_setted) {
      _ApplyIcon();
    }
  }
}

void TrayManagerPlugin::StartAttentionFlash() {
  if (unread_count <= 0 || rendered_icon == nullptr ||
      attention_rendered_icon == nullptr) {
    CancelAttentionFlash();
    return;
  }

  if (attention_timer_active) {
    ApplyIconFrame(attention_frame);
    return;
  }

  HWND window = GetMainWindow();
  if (window == nullptr) {
    ApplyIconFrame(false);
    return;
  }

  ApplyIconFrame(true);
  if (SetTimer(window, kAttentionFlashTimerId,
               kAttentionFlashIntervalMs, nullptr) == 0) {
    attention_frame = false;
    ApplyIconFrame(false);
    return;
  }
  attention_timer_active = true;
}

void TrayManagerPlugin::AdvanceAttentionFlash() {
  if (!attention_timer_active || unread_count <= 0) {
    CancelAttentionFlash();
    return;
  }
  ApplyIconFrame(!attention_frame);
}

void TrayManagerPlugin::DestroyIconResources() {
  CancelAttentionFlash();
  if (attention_rendered_icon != nullptr) {
    DestroyIcon(attention_rendered_icon);
  }
  if (rendered_icon != nullptr) {
    DestroyIcon(rendered_icon);
  }
  if (attention_source_icon != nullptr) {
    DestroyIcon(attention_source_icon);
  }
  if (source_icon != nullptr) {
    DestroyIcon(source_icon);
  }
  attention_rendered_icon = nullptr;
  rendered_icon = nullptr;
  attention_source_icon = nullptr;
  source_icon = nullptr;
  nid.hIcon = nullptr;
}

void TrayManagerPlugin::_ApplyIcon() {
  if (nid.hIcon == nullptr) {
    return;
  }
  if (tray_icon_setted) {
    Shell_NotifyIcon(NIM_MODIFY, &nid);
  } else {
    HICON hIconBackup = nid.hIcon;
    WCHAR szTipBackup[128];
    StringCchCopy(szTipBackup, _countof(szTipBackup), nid.szTip);
    
    ZeroMemory(&nid, sizeof(NOTIFYICONDATA));
    nid.cbSize = sizeof(NOTIFYICONDATA);
    nid.hWnd = GetMainWindow();
    nid.uID = 1;
    nid.hIcon = hIconBackup;
    StringCchCopy(nid.szTip, _countof(nid.szTip), szTipBackup);
    nid.uCallbackMessage = WM_MYMESSAGE;
    nid.uFlags = NIF_MESSAGE | NIF_ICON;
    if (nid.szTip[0] != '\0') {
      nid.uFlags |= NIF_TIP;
    }
    Shell_NotifyIcon(NIM_ADD, &nid);
  }

  niif.cbSize = sizeof(NOTIFYICONIDENTIFIER);
  niif.hWnd = nid.hWnd;
  niif.uID = nid.uID;
  niif.guidItem = GUID_NULL;

  tray_icon_setted = true;
}

bool TrayManagerPlugin::TaskbarSurfaceIsLight() {
  RECT icon_rect;
  if (!tray_icon_setted ||
      FAILED(Shell_NotifyIconGetRect(&niif, &icon_rect))) {
    return SystemUsesLightTheme();
  }

  APPBARDATA appbar_data = {};
  appbar_data.cbSize = sizeof(APPBARDATA);
  const bool has_taskbar_rect =
      SHAppBarMessage(ABM_GETTASKBARPOS, &appbar_data) != 0;
  const LONG center_x = icon_rect.left + (icon_rect.right - icon_rect.left) / 2;
  const LONG center_y = icon_rect.top + (icon_rect.bottom - icon_rect.top) / 2;
  const LONG horizontal_gap =
      std::max<LONG>(6, (icon_rect.right - icon_rect.left) / 2);
  const LONG vertical_gap =
      std::max<LONG>(6, (icon_rect.bottom - icon_rect.top) / 2);
  const std::array<POINT, 12> sample_points = {{
      {icon_rect.left - horizontal_gap, center_y},
      {icon_rect.right + horizontal_gap, center_y},
      {center_x, icon_rect.top - vertical_gap},
      {center_x, icon_rect.bottom + vertical_gap},
      {icon_rect.left - horizontal_gap, icon_rect.top - vertical_gap},
      {icon_rect.right + horizontal_gap, icon_rect.top - vertical_gap},
      {icon_rect.left - horizontal_gap, icon_rect.bottom + vertical_gap},
      {icon_rect.right + horizontal_gap, icon_rect.bottom + vertical_gap},
      {icon_rect.left - horizontal_gap * 2, center_y},
      {icon_rect.right + horizontal_gap * 2, center_y},
      {center_x, icon_rect.top - vertical_gap * 2},
      {center_x, icon_rect.bottom + vertical_gap * 2},
  }};

  HDC desktop_dc = GetDC(nullptr);
  if (desktop_dc == nullptr) {
    return SystemUsesLightTheme();
  }
  std::vector<double> luminances;
  for (const POINT& point : sample_points) {
    if (has_taskbar_rect && !PtInRect(&appbar_data.rc, point)) {
      continue;
    }
    const COLORREF color = GetPixel(desktop_dc, point.x, point.y);
    if (color != CLR_INVALID) {
      luminances.push_back(RelativeLuminance(color));
    }
  }
  ReleaseDC(nullptr, desktop_dc);
  if (luminances.empty()) {
    return SystemUsesLightTheme();
  }

  std::sort(luminances.begin(), luminances.end());
  const double median = luminances[luminances.size() / 2];
  return median >= 0.55;
}

void TrayManagerPlugin::NotifyTaskbarAppearanceChanged() {
  channel->InvokeMethod(
      "onTaskbarAppearanceChanged",
      std::make_unique<flutter::EncodableValue>(TaskbarSurfaceIsLight()));
}

void TrayManagerPlugin::SetToolTip(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  std::string toolTip =
      std::get<std::string>(args.at(flutter::EncodableValue("toolTip")));

  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  StringCchCopy(nid.szTip, _countof(nid.szTip),
                converter.from_bytes(toolTip).c_str());
  Shell_NotifyIcon(NIM_MODIFY, &nid);

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::SetContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  _CreateMenu(hMenu, std::get<flutter::EncodableMap>(
                         args.at(flutter::EncodableValue("menu"))));

  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::PopUpContextMenu(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  bool bringAppToFront =
      std::get<bool>(args.at(flutter::EncodableValue("bringAppToFront")));

  HWND hWnd = GetMainWindow();

  double x, y;

  // RECT rect;
  // Shell_NotifyIconGetRect(&niif, &rect);

  // x = rect.left + ((rect.right - rect.left) / 2);
  // y = rect.top + ((rect.bottom - rect.top) / 2);

  POINT cursorPos;
  GetCursorPos(&cursorPos);
  x = cursorPos.x;
  y = cursorPos.y;

  if (bringAppToFront) {
    SetForegroundWindow(hWnd);
  }
  TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, static_cast<int>(x),
                 static_cast<int>(y), 0, hWnd, NULL);
  result->Success(flutter::EncodableValue(true));
}

void TrayManagerPlugin::GetBounds(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  if (!tray_icon_setted) {
    result->Success();
    return;
  }

  double devicePixelRatio =
      std::get<double>(args.at(flutter::EncodableValue("devicePixelRatio")));

  RECT rect;
  Shell_NotifyIconGetRect(&niif, &rect);
  flutter::EncodableMap resultMap = flutter::EncodableMap();

  double x = rect.left / devicePixelRatio * 1.0f;
  double y = rect.top / devicePixelRatio * 1.0f;
  double width = (rect.right - rect.left) / devicePixelRatio * 1.0f;
  double height = (rect.bottom - rect.top) / devicePixelRatio * 1.0f;

  resultMap[flutter::EncodableValue("x")] = flutter::EncodableValue(x);
  resultMap[flutter::EncodableValue("y")] = flutter::EncodableValue(y);
  resultMap[flutter::EncodableValue("width")] = flutter::EncodableValue(width);
  resultMap[flutter::EncodableValue("height")] =
      flutter::EncodableValue(height);

  result->Success(flutter::EncodableValue(resultMap));
}

void TrayManagerPlugin::GetTaskbarSurfaceIsLight(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(TaskbarSurfaceIsLight()));
}

void TrayManagerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("destroy") == 0) {
    Destroy(method_call, std::move(result));
  } else if (method_call.method_name().compare("setIcon") == 0) {
    SetIcon(method_call, std::move(result));
  } else if (method_call.method_name().compare("setToolTip") == 0) {
    SetToolTip(method_call, std::move(result));
  } else if (method_call.method_name().compare("setContextMenu") == 0) {
    SetContextMenu(method_call, std::move(result));
  } else if (method_call.method_name().compare("popUpContextMenu") == 0) {
    PopUpContextMenu(method_call, std::move(result));
  } else if (method_call.method_name().compare("getBounds") == 0) {
    GetBounds(method_call, std::move(result));
  } else if (method_call.method_name().compare("getTaskbarSurfaceIsLight") ==
             0) {
    GetTaskbarSurfaceIsLight(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void TrayManagerPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  TrayManagerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
