#include "application_updater.h"

#include <algorithm>
#include <exception>
#include <thread>
#include <utility>

#include "Velopack.hpp"

namespace {

constexpr char kRepositoryUrl[] =
    "https://github.com/JevonsCode/DingDongBuddy";

}  // namespace

ApplicationUpdater::ApplicationUpdater(HWND application_window)
    : application_window_(application_window) {}

bool ApplicationUpdater::IsSupported() const {
  try {
    auto source = std::make_unique<Velopack::GithubSource>(kRepositoryUrl);
    Velopack::UpdateManager manager(std::move(source));
    return !manager.IsPortable();
  } catch (...) {
    return false;
  }
}

ApplicationUpdateSnapshot ApplicationUpdater::Snapshot() const {
  std::scoped_lock lock(mutex_);
  return snapshot_;
}

bool ApplicationUpdater::InstallLatest(std::string* error) {
  {
    std::scoped_lock lock(mutex_);
    if (update_running_) {
      return true;
    }
    update_running_ = true;
    snapshot_ = ApplicationUpdateSnapshot{};
    snapshot_.phase = "checking";
  }

  try {
    std::thread([self = shared_from_this()] { self->RunUpdate(); }).detach();
    return true;
  } catch (const std::exception& exception) {
    SetState("failed", std::nullopt, {}, exception.what());
    if (error) {
      *error = exception.what();
    }
    return false;
  }
}

void ApplicationUpdater::RunUpdate() {
  try {
    auto source = std::make_unique<Velopack::GithubSource>(kRepositoryUrl);
    Velopack::UpdateManager manager(std::move(source));
    const auto update = manager.CheckForUpdates();
    if (!update.has_value()) {
      SetState("current");
      return;
    }

    const std::string version = update->TargetFullRelease.Version;
    SetState("downloading", 0.0, version);
    manager.DownloadUpdates(
        update.value(),
        [](void* user_data, size_t progress) {
          auto* self = static_cast<ApplicationUpdater*>(user_data);
          const double normalized =
              std::clamp(static_cast<double>(progress) / 100.0, 0.0, 1.0);
          const auto snapshot = self->Snapshot();
          self->SetState("downloading", normalized,
                         snapshot.target_version);
        },
        this);

    SetState("installing", std::nullopt, version);
    manager.WaitExitThenApplyUpdates(update.value(), true, true);
    ::PostMessageW(application_window_, kDingDongExitForUpdateMessage, 0, 0);
  } catch (const std::exception& exception) {
    SetState("failed", std::nullopt, {}, exception.what());
  } catch (...) {
    SetState("failed", std::nullopt, {},
             "The Windows updater failed unexpectedly.");
  }
}

void ApplicationUpdater::SetState(std::string phase,
                                  std::optional<double> progress,
                                  std::string target_version,
                                  std::string message) {
  std::scoped_lock lock(mutex_);
  snapshot_ = ApplicationUpdateSnapshot{};
  snapshot_.phase = std::move(phase);
  snapshot_.progress = progress;
  snapshot_.target_version = std::move(target_version);
  snapshot_.message = std::move(message);
  update_running_ = snapshot_.phase == "checking" ||
                    snapshot_.phase == "downloading" ||
                    snapshot_.phase == "extracting" ||
                    snapshot_.phase == "installing";
}
