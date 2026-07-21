#ifndef RUNNER_APPLICATION_UPDATER_H_
#define RUNNER_APPLICATION_UPDATER_H_

#include <windows.h>

#include <memory>
#include <mutex>
#include <optional>
#include <string>

/// Bypasses the normal "close means hide to tray" path after Velopack has
/// launched its external apply process. The main UI thread handles this by
/// destroying the window so the process exits within Velopack's timeout.
constexpr UINT kDingDongExitForUpdateMessage = WM_APP + 0x0DD1;

struct ApplicationUpdateSnapshot {
  std::string phase = "idle";
  std::optional<double> progress;
  std::string target_version;
  std::string message;
};

/// Runs Velopack network and package work away from Flutter's platform thread.
/// Velopack stages a verified package, waits for DingDong to quit, swaps the
/// current directory, removes obsolete packages, and starts the new version.
class ApplicationUpdater
    : public std::enable_shared_from_this<ApplicationUpdater> {
 public:
  explicit ApplicationUpdater(HWND application_window);

  bool IsSupported() const;
  ApplicationUpdateSnapshot Snapshot() const;
  bool InstallLatest(std::string* error);

 private:
  void RunUpdate();
  void SetState(std::string phase, std::optional<double> progress = std::nullopt,
                std::string target_version = {}, std::string message = {});

  HWND application_window_;
  mutable std::mutex mutex_;
  ApplicationUpdateSnapshot snapshot_;
  bool update_running_ = false;
};

#endif  // RUNNER_APPLICATION_UPDATER_H_
