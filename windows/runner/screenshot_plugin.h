#ifndef RUNNER_SCREENSHOT_PLUGIN_H_
#define RUNNER_SCREENSHOT_PLUGIN_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <memory>

/// System screenshot shortcut mapping, owned only by the primary engine.
class ScreenshotPlugin {
 public:
  ScreenshotPlugin(HWND owner, flutter::BinaryMessenger* messenger);
  ~ScreenshotPlugin();
  bool HandleHotKey(WPARAM id);
  bool HandleTimer(WPARAM id);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif
