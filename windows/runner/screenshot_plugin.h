#ifndef RUNNER_SCREENSHOT_PLUGIN_H_
#define RUNNER_SCREENSHOT_PLUGIN_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <memory>

/// Windows-only region capture and in-memory PNG handoff. A single instance belongs to the primary engine.
class ScreenshotPlugin {
 public:
  ScreenshotPlugin(HWND owner, flutter::BinaryMessenger* messenger);
  ~ScreenshotPlugin();
  bool HandleHotKey(WPARAM id);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif
