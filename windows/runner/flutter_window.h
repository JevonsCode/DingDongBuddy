#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

class ApplicationUpdater;

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_monitor_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      hotkey_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      notification_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      launch_at_startup_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      updater_channel_;
  std::shared_ptr<ApplicationUpdater> application_updater_;
  bool hotkey_registered_ = false;
  HWND previous_foreground_window_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
