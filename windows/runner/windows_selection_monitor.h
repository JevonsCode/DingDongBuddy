#ifndef RUNNER_WINDOWS_SELECTION_MONITOR_H_
#define RUNNER_WINDOWS_SELECTION_MONITOR_H_

#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <thread>

// A primary-engine-only monitor. Hooks run on the window thread; all accessibility
// calls run serially on a separate MTA. No clipboard reads/writes or key injection.
class WindowsSelectionMonitor {
 public:
  static constexpr UINT kResultMessage = WM_APP + 0x0DD2;
  WindowsSelectionMonitor(HWND window, flutter::BinaryMessenger* messenger);
  ~WindowsSelectionMonitor();
  WindowsSelectionMonitor(const WindowsSelectionMonitor&) = delete;
  WindowsSelectionMonitor& operator=(const WindowsSelectionMonitor&) = delete;
  bool HandleMessage(UINT message);

 private:
  struct State;
  static void WorkerMain(const std::shared_ptr<State>& state);
  static LRESULT CALLBACK MouseHook(int code, WPARAM message, LPARAM data);
  static LRESULT CALLBACK KeyboardHook(int code, WPARAM message, LPARAM data);
  bool Configure(bool enabled);
  bool IsRunning() const;
  void Invalidate(bool dismiss);
  void Request(POINT point, HWND foreground);
  void OnMouse(WPARAM message, const MSLLHOOKSTRUCT& event);
  void OnKeyboard(WPARAM message, const KBDLLHOOKSTRUCT& event);
  static bool IsOwnWindow(HWND window);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::shared_ptr<State> state_;
  std::thread worker_;
  HHOOK mouse_hook_ = nullptr;
  HHOOK keyboard_hook_ = nullptr;
  bool enabled_ = false;
  bool mouse_down_ = false;
  bool shift_selection_ = false;
  POINT down_point_{};
  POINT last_click_point_{};
  DWORD last_click_time_ = 0;
  HWND down_foreground_ = nullptr;
  static WindowsSelectionMonitor* active_;
};

#endif
