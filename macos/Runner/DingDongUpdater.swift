import Foundation
import Sparkle

/// Sparkle owns the transactional replacement. DingDong owns the visible
/// progress and treats the user's single button click as install consent.
@MainActor
final class DingDongUpdater {
  private let userDriver = DingDongUpdateUserDriver()
  private let updater: SPUUpdater
  private(set) var startupError: String?

  init() {
    updater = SPUUpdater(
      hostBundle: .main,
      applicationBundle: .main,
      userDriver: userDriver,
      delegate: nil
    )
    do {
      try updater.start()
    } catch {
      startupError = error.localizedDescription
      userDriver.fail(error.localizedDescription)
    }
  }

  var isSupported: Bool {
    startupError == nil
  }

  func installLatest() throws {
    if let startupError {
      throw DingDongUpdaterError.unavailable(startupError)
    }
    guard !userDriver.status.isBusy else { return }
    userDriver.begin()
    updater.checkForUpdates()
  }

  func state() -> [String: Any] {
    userDriver.status.json
  }
}

private enum DingDongUpdaterError: LocalizedError {
  case unavailable(String)

  var errorDescription: String? {
    switch self {
    case .unavailable(let message): message
    }
  }
}

private struct DingDongUpdateStatus {
  var phase = "idle"
  var progress: Double?
  var targetVersion: String?
  var message: String?

  var isBusy: Bool {
    ["checking", "downloading", "extracting", "installing"].contains(phase)
  }

  var json: [String: Any] {
    var value: [String: Any] = ["phase": phase]
    if let progress { value["progress"] = progress }
    if let targetVersion { value["targetVersion"] = targetVersion }
    if let message { value["message"] = message }
    return value
  }
}

@MainActor
private final class DingDongUpdateUserDriver: NSObject, SPUUserDriver {
  private(set) var status = DingDongUpdateStatus()
  private var expectedBytes: UInt64 = 0
  private var receivedBytes: UInt64 = 0

  func begin() {
    expectedBytes = 0
    receivedBytes = 0
    status = DingDongUpdateStatus(phase: "checking")
  }

  func fail(_ message: String) {
    status = DingDongUpdateStatus(phase: "failed", message: message)
  }

  func show(
    _ request: SPUUpdatePermissionRequest
  ) async -> SUUpdatePermissionResponse {
    SUUpdatePermissionResponse(
      automaticUpdateChecks: false,
      automaticUpdateDownloading: false,
      sendSystemProfile: false
    )
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    status = DingDongUpdateStatus(phase: "checking")
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState
  ) async -> SPUUserUpdateChoice {
    guard !appcastItem.isInformationOnlyUpdate else {
      fail("This release cannot be installed automatically.")
      return .dismiss
    }
    status.targetVersion = appcastItem.displayVersionString
    status.phase = state.stage == .installing ? "installing" : "downloading"
    return .install
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

  func showUpdateNotFoundWithError(_ error: Error) async {
    status = DingDongUpdateStatus(phase: "current")
  }

  func showUpdaterError(_ error: Error) async {
    fail(error.localizedDescription)
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    status.phase = "downloading"
    status.progress = 0
  }

  func showDownloadDidReceiveExpectedContentLength(
    _ expectedContentLength: UInt64
  ) {
    expectedBytes = expectedContentLength
    receivedBytes = 0
    status.progress = expectedContentLength == 0 ? nil : 0
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    receivedBytes += length
    guard expectedBytes > 0 else { return }
    status.progress = min(1, Double(receivedBytes) / Double(expectedBytes))
  }

  func showDownloadDidStartExtractingUpdate() {
    status.phase = "extracting"
    status.progress = 0
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    status.phase = "extracting"
    status.progress = min(1, max(0, progress))
  }

  func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
    status.phase = "installing"
    status.progress = nil
    return .install
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    status.phase = "installing"
    status.progress = nil
  }

  func showUpdateInstalledAndRelaunched(_ relaunched: Bool) async {
    status = DingDongUpdateStatus(phase: "current")
  }

  func dismissUpdateInstallation() {
    if status.isBusy {
      status = DingDongUpdateStatus()
    }
  }
}
