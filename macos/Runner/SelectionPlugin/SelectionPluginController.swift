import AppKit
import ApplicationServices

enum SelectionPluginControllerError: Error, LocalizedError {
  case invalidArguments
  case invalidEndpoint
  case emptyToken

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "Selection plugin settings are incomplete."
    case .invalidEndpoint:
      return "The model service address is invalid."
    case .emptyToken:
      return "Enter an API token first."
    }
  }
}

/// Lightweight, user-controlled selection tools hosted by DingDong itself.
///
/// The controller owns no timer or polling loop. When disabled it removes the
/// global event monitor and Accessibility observer, cancels pending reads and
/// requests, dismisses its panel, and releases the monitor object.
@MainActor
final class SelectionPluginController {
  var onOpenAccessibilitySettings: (() -> Void)?

  private let permissionPort: DingDongPermissionPort
  private let lifecycle: DingDongPluginLifecycle
  private let selectionReader: AccessibilitySelectionReader
  private let clipboard = ClipboardService()
  private let tokenStore: SelectionTokenStoring
  private lazy var modelClient = HTTPModelClient()
  private let toolbar = FloatingToolbarController()

  private var configuration = ModelConfiguration.preset(.ollama)
  private var monitor: SelectionMonitor?
  private var selectionBuffer = SelectionBuffer()
  private var selectionReadGeneration: UInt64 = 0
  private var modelTask: Task<Void, Never>?
  private var modelRequestGeneration = LatestRequestGeneration()
  private var listening = false

  init(
    permissionPort: DingDongPermissionPort = SystemAccessibilityPermissionPort(),
    tokenStore: SelectionTokenStoring = KeychainTokenStore()
  ) {
    self.permissionPort = permissionPort
    self.tokenStore = tokenStore
    let lifecycle = DingDongPluginLifecycle(initialState: .disabled)
    self.lifecycle = lifecycle
    selectionReader = AccessibilitySelectionReader(
      permissionPort: permissionPort,
      lifecycle: lifecycle
    )
    toolbar.onAction = { [weak self] action in
      self?.perform(action)
    }
    toolbar.onDismiss = { [weak self] in
      self?.selectionBuffer.clear()
      self?.cancelModelRequest()
    }
  }

  func applyConfiguration(_ arguments: Any?) throws -> [String: Bool] {
    guard let values = arguments as? [String: Any],
          let enabled = values["enabled"] as? Bool else {
      throw SelectionPluginControllerError.invalidArguments
    }

    // Disabling is fail-safe and does not depend on the remaining payload.
    guard enabled else {
      stopListening()
      // Configuration and enablement are independent: users can choose a
      // provider and save its token before granting access or enabling reads.
      // A malformed stop-only payload must still stop the plugin safely.
      if let candidate = try? parseConfiguration(values) {
        configuration = candidate
      }
      return status()
    }

    let candidate = try parseConfiguration(values)
    if candidate != configuration {
      invalidateSelection()
      cancelModelRequest()
    }
    configuration = candidate
    lifecycle.enable()
    if permissionPort.status.isGranted {
      startListening()
    } else {
      stopListening(preserveLifecycle: true)
    }
    return status()
  }

  func status() -> [String: Bool] {
    // A user can change Accessibility permission outside our helper window.
    // Refresh reconciles the observer lifecycle without prompting or polling.
    if lifecycle.isEnabled && permissionPort.status.isGranted {
      if !listening { startListening() }
    } else if listening {
      stopListening(preserveLifecycle: true)
    }
    return [
      "enabled": lifecycle.isEnabled,
      "running": lifecycle.isEnabled && listening &&
        permissionPort.status.isGranted,
      "permissionGranted": permissionPort.status.isGranted,
      "tokenConfigured": configuration.requiresToken && tokenStore.containsToken(
        account: tokenAccount(for: configuration)
      )
    ]
  }

  func saveToken(_ value: String) throws {
    let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      throw SelectionPluginControllerError.emptyToken
    }
    try tokenStore.save(token, account: tokenAccount(for: configuration))
  }

  func clearToken() throws {
    try tokenStore.delete(account: tokenAccount(for: configuration))
  }

  func openAccessibilitySettings() {
    onOpenAccessibilitySettings?()
  }

  func permissionDidChange() {
    if lifecycle.isEnabled && permissionPort.status.isGranted {
      startListening()
    } else {
      stopListening(preserveLifecycle: true)
    }
  }

  func shutdown() {
    lifecycle.disable()
    stopListening()
  }

  private func startListening() {
    guard lifecycle.isEnabled, permissionPort.status.isGranted else {
      stopListening(preserveLifecycle: true)
      return
    }
    if monitor == nil {
      monitor = SelectionMonitor(
        onSelectionChanged: { [weak self] element in
          self?.captureSelection(from: element)
        },
        onSelectionInvalidated: { [weak self] in
          self?.invalidateSelection()
        },
        onDirectCopy: { [weak self] in
          self?.copyCurrentSelectionDirectly()
        },
        permissionPort: permissionPort,
        lifecycle: lifecycle
      )
    }
    listening = monitor?.start() ?? false
  }

  private func stopListening(preserveLifecycle: Bool = false) {
    if !preserveLifecycle {
      lifecycle.disable()
    }
    listening = false
    selectionReadGeneration &+= 1
    cancelModelRequest()
    selectionReader.cancelPendingReads()
    monitor?.stop()
    monitor = nil
    selectionBuffer.clear()
    toolbar.dismiss()
  }

  private func parseConfiguration(
    _ values: [String: Any]
  ) throws -> ModelConfiguration {
    guard let providerName = values["provider"] as? String,
          let provider = ModelProviderKind(rawValue: providerName),
          let endpointValue = values["endpoint"] as? String,
          let endpoint = URL(string: endpointValue),
          let model = values["model"] as? String,
          let targetLanguage = values["targetLanguage"] as? String,
          let unload = values["unloadLocalModelAfterResponse"] as? Bool else {
      throw SelectionPluginControllerError.invalidArguments
    }
    guard endpoint.scheme != nil, endpoint.host != nil else {
      throw SelectionPluginControllerError.invalidEndpoint
    }
    let candidate = ModelConfiguration(
      provider: provider,
      baseURL: endpoint,
      model: model,
      targetLanguage: targetLanguage,
      unloadLocalModelAfterResponse: unload
    )
    try validate(candidate)
    return candidate
  }

  private func validate(_ configuration: ModelConfiguration) throws {
    _ = try ModelRequestFactory.makeRequest(
      action: .translate,
      text: "validation",
      configuration: configuration,
      token: configuration.requiresToken ? "validation" : nil
    )
  }

  // Credentials never follow a provider setting to another origin. Do not
  // silently migrate old provider-only entries: the user must save the token
  // for the explicitly selected service address.
  private func tokenAccount(for configuration: ModelConfiguration) -> String {
    let scheme = configuration.baseURL.scheme?.lowercased() ?? ""
    let host = configuration.baseURL.host?.lowercased() ?? ""
    let port = configuration.baseURL.port ?? (scheme == "https" ? 443 : 80)
    return "\(configuration.provider.rawValue)|\(scheme)|\(host)|\(port)"
  }

  private func captureSelection(from observedElement: AXUIElement? = nil) {
    guard lifecycle.isEnabled, permissionPort.status.isGranted else { return }
    selectionReadGeneration &+= 1
    let generation = selectionReadGeneration
    let completion: @MainActor @Sendable (SystemSelection?) -> Void = {
      [weak self] selection in
      guard let self, generation == self.selectionReadGeneration else { return }
      guard let selection else {
        self.selectionBuffer.clear()
        self.toolbar.dismiss()
        return
      }
      self.cancelModelRequest()
      guard self.selectionBuffer.update(selection.text) else { return }
      self.toolbar.showActions(near: self.panelAnchor(from: selection.bounds))
    }
    if let observedElement {
      selectionReader.readSelection(
        from: observedElement,
        completion: completion
      )
    } else {
      selectionReader.readCurrentSelection(completion: completion)
    }
  }

  private func invalidateSelection() {
    selectionReadGeneration &+= 1
    selectionReader.cancelPendingReads()
    selectionBuffer.clear()
    toolbar.dismiss()
  }

  private func perform(_ action: SelectionAction) {
    guard lifecycle.isEnabled else { return }
    guard let text = selectionBuffer.consume() else {
      toolbar.showTransient("没有可用的选区")
      return
    }

    if action == .copy {
      cancelModelRequest()
      if clipboard.write(text) {
        toolbar.showTransient("已复制到剪贴板")
      } else {
        toolbar.showResult(title: "复制失败", text: "系统剪贴板暂时不可用。")
      }
      return
    }

    guard permissionPort.status.isGranted else { return }
    // Capture one configuration for both credential lookup and the request;
    // changing settings while the task is queued must not mix providers.
    let requestConfiguration = configuration
    let token: String?
    do {
      token = requestConfiguration.requiresToken
        ? try tokenStore.load(account: tokenAccount(for: requestConfiguration))
        : nil
    } catch {
      toolbar.showResult(title: "无法读取 Token", text: error.localizedDescription)
      return
    }

    let generation = cancelModelRequest()
    toolbar.showLoading(action == .translate ? "正在翻译…" : "正在解释…")
    modelTask = Task { [weak self] in
      guard let self, !Task.isCancelled, self.lifecycle.isEnabled else { return }
      do {
        let result = try await self.modelClient.generate(
          action: action,
          text: text,
          configuration: requestConfiguration,
          token: token
        )
        guard self.modelRequestGeneration.isCurrent(generation),
              self.lifecycle.isEnabled else { return }
        self.modelTask = nil
        self.toolbar.showResult(
          title: action == .translate ? "翻译结果" : "解释结果",
          text: result
        )
      } catch {
        let cancelled = Task.isCancelled ||
          (error as? URLError)?.code == .cancelled
        guard self.modelRequestGeneration.isCurrent(generation) else { return }
        self.modelTask = nil
        if cancelled {
          self.toolbar.dismiss()
        } else {
          self.toolbar.showResult(title: "操作失败", text: error.localizedDescription)
        }
      }
    }
  }

  private func copyCurrentSelectionDirectly() {
    guard lifecycle.isEnabled, permissionPort.status.isGranted else { return }
    selectionReadGeneration &+= 1
    cancelModelRequest()
    selectionReader.readCurrentSelection { [weak self] selection in
      guard let self else { return }
      guard let selection else {
        self.selectionBuffer.clear()
        self.toolbar.showTransient("当前应用没有提供可复制的选区")
        return
      }
      if self.clipboard.write(selection.text) {
        self.selectionBuffer.clear()
        self.toolbar.showTransient("已复制到剪贴板")
      }
    }
  }

  private func panelAnchor(from accessibilityBounds: CGRect?) -> NSPoint {
    guard let bounds = accessibilityBounds,
          let mainHeight = NSScreen.screens.first(
            where: { $0.frame.origin == .zero }
          )?.frame.height else {
      return NSEvent.mouseLocation
    }
    return NSPoint(x: bounds.midX, y: mainHeight - bounds.maxY)
  }

  @discardableResult
  private func cancelModelRequest() -> UInt64 {
    let generation = modelRequestGeneration.advance()
    modelTask?.cancel()
    modelTask = nil
    return generation
  }
}
