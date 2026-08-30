import XCTest
@testable import DingDongSelectionHost

final class SelectionPluginControllerTests: XCTestCase {
    func testLocalProviderStatusDoesNotReadCloudTokenStorage() async throws {
        try await MainActor.run {
            let tokens = MemoryTokens()
            let controller = SelectionPluginController(
                permissionPort: DeniedPermission(),
                tokenStore: tokens
            )
            defer { controller.shutdown() }

            let local = try controller.applyConfiguration(arguments(.ollama))
            XCTAssertEqual(local["tokenConfigured"], false)
            XCTAssertEqual(tokens.inspectionCount, 0)
            _ = try controller.applyConfiguration(arguments(.openRouter))
            XCTAssertEqual(tokens.inspectionCount, 1)
        }
    }

    func testDisabledPluginAcceptsProviderBeforeTokenAndPermission() async throws {
        try await MainActor.run {
            let permission = DeniedPermission()
            let tokens = MemoryTokens()
            let controller = SelectionPluginController(
                permissionPort: permission,
                tokenStore: tokens
            )
            defer { controller.shutdown() }

            let status = try controller.applyConfiguration(arguments(.openRouter))
            try controller.saveToken("  test-fixture-only  ")

            XCTAssertEqual(status["enabled"], false)
            XCTAssertEqual(status["running"], false)
            XCTAssertEqual(status["permissionGranted"], false)
            XCTAssertEqual(Array(tokens.values.values), ["test-fixture-only"])
            XCTAssertEqual(controller.status()["tokenConfigured"], true)
            let local = try controller.applyConfiguration(arguments(.ollama))
            XCTAssertEqual(local["tokenConfigured"], false)
            let restored = try controller.applyConfiguration(arguments(.openRouter))
            XCTAssertEqual(restored["tokenConfigured"], true)
        }
    }

    func testProviderSwitchAndDeleteKeepTokensSeparateWhileDisabled() async throws {
        try await MainActor.run {
            let tokens = MemoryTokens()
            let controller = SelectionPluginController(
                permissionPort: DeniedPermission(),
                tokenStore: tokens
            )
            defer { controller.shutdown() }

            _ = try controller.applyConfiguration(arguments(.openRouter))
            try controller.saveToken("router-fixture")
            let geminiStatus = try controller.applyConfiguration(arguments(.gemini))
            XCTAssertEqual(geminiStatus["tokenConfigured"], false)
            try controller.saveToken("gemini-fixture")

            let routerStatus = try controller.applyConfiguration(arguments(.openRouter))
            XCTAssertEqual(routerStatus["tokenConfigured"], true)
            try controller.clearToken()
            XCTAssertEqual(controller.status()["tokenConfigured"], false)
            let restored = try controller.applyConfiguration(arguments(.gemini))
            XCTAssertEqual(restored["tokenConfigured"], true)
            XCTAssertEqual(Array(tokens.values.values), ["gemini-fixture"])
        }
    }

    func testStopOnlyPayloadDisablesAnEnabledPluginWaitingForPermission() async throws {
        try await MainActor.run {
            let permission = DeniedPermission()
            let controller = SelectionPluginController(
                permissionPort: permission,
                tokenStore: MemoryTokens()
            )
            defer { controller.shutdown() }

            let waiting = try controller.applyConfiguration(arguments(.openRouter, enabled: true))
            XCTAssertEqual(waiting["enabled"], true)
            XCTAssertEqual(waiting["running"], false)
            let stopped = try controller.applyConfiguration(["enabled": false])
            XCTAssertEqual(stopped["enabled"], false)
            XCTAssertEqual(stopped["running"], false)
        }
    }

    func testInvalidEnablePayloadPreservesTheLastValidProvider() async throws {
        try await MainActor.run {
            let tokens = MemoryTokens()
            let controller = SelectionPluginController(
                permissionPort: DeniedPermission(),
                tokenStore: tokens
            )
            defer { controller.shutdown() }
            _ = try controller.applyConfiguration(arguments(.openRouter))
            var invalid = arguments(.gemini, enabled: true)
            invalid["endpoint"] = "http://remote.invalid/v1"

            XCTAssertThrowsError(try controller.applyConfiguration(invalid))
            try controller.saveToken("last-valid-provider-fixture")
            XCTAssertEqual(controller.status()["enabled"], false)
            let gemini = try controller.applyConfiguration(arguments(.gemini))
            XCTAssertEqual(gemini["tokenConfigured"], false)
            let router = try controller.applyConfiguration(arguments(.openRouter))
            XCTAssertEqual(router["tokenConfigured"], true)
        }
    }

    func testTokenDoesNotFollowProviderToAnotherServiceAddress() async throws {
        try await MainActor.run {
            let controller = SelectionPluginController(
                permissionPort: DeniedPermission(),
                tokenStore: MemoryTokens()
            )
            defer { controller.shutdown() }
            _ = try controller.applyConfiguration(arguments(.openRouter))
            try controller.saveToken("original-service-fixture")

            var changed = arguments(.openRouter)
            changed["endpoint"] = "https://another-service.invalid/v1"
            let otherOrigin = try controller.applyConfiguration(changed)
            XCTAssertEqual(otherOrigin["tokenConfigured"], false)
            try controller.saveToken("other-service-fixture")
            try controller.clearToken()

            let original = try controller.applyConfiguration(arguments(.openRouter))
            XCTAssertEqual(original["tokenConfigured"], true)
            var explicitDefaultPort = arguments(.openRouter)
            explicitDefaultPort["endpoint"] = "https://openrouter.ai:443/api/v1"
            let sameOrigin = try controller.applyConfiguration(explicitDefaultPort)
            XCTAssertEqual(sameOrigin["tokenConfigured"], true)
            var otherPort = arguments(.openRouter)
            otherPort["endpoint"] = "https://openrouter.ai:8443/api/v1"
            XCTAssertEqual(
                try controller.applyConfiguration(otherPort)["tokenConfigured"],
                false
            )
        }
    }
}

private func arguments(_ preset: ModelPreset, enabled: Bool = false) -> [String: Any] {
    let configuration = ModelConfiguration.preset(preset)
    return [
        "enabled": enabled,
        "provider": configuration.provider.rawValue,
        "endpoint": configuration.baseURL.absoluteString,
        "model": configuration.model,
        "targetLanguage": configuration.targetLanguage,
        "unloadLocalModelAfterResponse": configuration.unloadLocalModelAfterResponse
    ]
}

private final class DeniedPermission: DingDongPermissionPort {
    let status: DingDongPermissionStatus = .denied
}

private final class MemoryTokens: SelectionTokenStoring {
    var values: [String: String] = [:]
    private(set) var inspectionCount = 0
    func containsToken(account: String) -> Bool {
        inspectionCount += 1
        return values[account] != nil
    }
    func load(account: String) throws -> String? { values[account] }
    func save(_ token: String, account: String) throws { values[account] = token }
    func delete(account: String) throws { values.removeValue(forKey: account) }
}
