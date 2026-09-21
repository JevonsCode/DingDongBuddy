import Foundation
import XCTest
@testable import DingDongSelectionHost

final class ModelProviderTests: XCTestCase {
    func testOllamaPresetUsesSmallLocalModelAndImmediateUnload() throws {
        let configuration = ModelConfiguration.preset(.ollama)

        XCTAssertEqual(configuration.baseURL.absoluteString, "http://127.0.0.1:11434")
        XCTAssertEqual(configuration.model, "qwen3:0.6b")
        XCTAssertFalse(configuration.requiresToken)
        XCTAssertTrue(configuration.unloadLocalModelAfterResponse)

        let request = try ModelRequestFactory.makeRequest(
            action: .translate,
            text: "Hello, world.",
            configuration: configuration,
            token: nil
        )
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11434/api/chat")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "qwen3:0.6b")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["keep_alive"] as? Int, 0)

        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertTrue(messages.last?["content"]?.contains("Hello, world.") == true)
        XCTAssertTrue(messages.last?["content"]?.contains("简体中文") == true)
    }

    func testOpenRouterPresetUsesOwnBearerTokenWithoutPuttingItInBody() throws {
        let configuration = ModelConfiguration.preset(.openRouter)
        let token = "private-test-token"

        XCTAssertTrue(configuration.requiresToken)
        XCTAssertEqual(configuration.model, "openrouter/free")

        let request = try ModelRequestFactory.makeRequest(
            action: .explain,
            text: "compound interest",
            configuration: configuration,
            token: token
        )

        XCTAssertEqual(
            request.url?.absoluteString,
            "https://openrouter.ai/api/v1/chat/completions"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
        XCTAssertFalse(String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self).contains(token))
    }

    func testRemoteHTTPProviderIsRejectedButLoopbackHTTPIsAllowed() throws {
        let remote = ModelConfiguration(
            provider: .openAICompatible,
            baseURL: try XCTUnwrap(URL(string: "http://example.com/v1")),
            model: "model",
            targetLanguage: "简体中文",
            unloadLocalModelAfterResponse: false
        )
        XCTAssertThrowsError(
            try ModelRequestFactory.makeRequest(
                action: .translate,
                text: "hello",
                configuration: remote,
                token: "token"
            )
        ) { error in
            XCTAssertEqual(error as? ModelClientError, .insecureRemoteEndpoint)
        }

        let local = ModelConfiguration.preset(.lmStudio)
        XCTAssertNoThrow(
            try ModelRequestFactory.makeRequest(
                action: .explain,
                text: "hello",
                configuration: local,
                token: nil
            )
        )
    }

    func testLocalProvidersRequireLoopbackAndNeverReceiveBearerTokens() throws {
        var local = ModelConfiguration.preset(.ollama)
        let request = try ModelRequestFactory.makeRequest(
            action: .translate,
            text: "hello",
            configuration: local,
            token: "must-not-leave-keychain"
        )
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

        local.baseURL = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(
            try ModelRequestFactory.makeRequest(
                action: .translate,
                text: "hello",
                configuration: local,
                token: nil
            )
        ) { error in
            XCTAssertEqual(error as? ModelClientError, .localEndpointRequired)
        }
    }

    func testProviderEndpointRejectsEmbeddedCredentialsAndURLState() throws {
        for rawURL in [
            "https://user:password@example.com/v1",
            "https://example.com/v1?key=secret",
            "https://example.com/v1#fragment"
        ] {
            let configuration = ModelConfiguration(
                provider: .openAICompatible,
                baseURL: try XCTUnwrap(URL(string: rawURL)),
                model: "model",
                targetLanguage: "简体中文",
                unloadLocalModelAfterResponse: false
            )
            XCTAssertThrowsError(
                try ModelRequestFactory.makeRequest(
                    action: .translate,
                    text: "hello",
                    configuration: configuration,
                    token: "token"
                )
            ) { error in
                XCTAssertEqual(error as? ModelClientError, .invalidEndpoint)
            }
        }
    }

    func testRemoteProviderRequiresAUserOwnedToken() throws {
        let configuration = ModelConfiguration.preset(.gemini)

        XCTAssertThrowsError(
            try ModelRequestFactory.makeRequest(
                action: .translate,
                text: "hello",
                configuration: configuration,
                token: nil
            )
        ) { error in
            XCTAssertEqual(error as? ModelClientError, .tokenRequired)
        }
    }

    func testParsersExtractProviderText() throws {
        let ollama = Data(#"{"message":{"role":"assistant","content":"你好"},"done":true}"#.utf8)
        XCTAssertEqual(
            try ModelResponseParser.parse(ollama, provider: .ollama),
            "你好"
        )

        let compatible = Data(#"{"choices":[{"message":{"role":"assistant","content":"复利是利息继续产生利息。"}}]}"#.utf8)
        XCTAssertEqual(
            try ModelResponseParser.parse(compatible, provider: .openRouter),
            "复利是利息继续产生利息。"
        )
    }

    func testAnthropicProxyUsesMessagesProtocolAndOptionalBearerToken() throws {
        for base in ["http://127.0.0.1:3456", "http://127.0.0.1:3456/v1/"] {
            let configuration = ModelConfiguration(
                provider: .anthropicCompatible, baseURL: URL(string: base)!,
                model: "proxy-model", targetLanguage: "简体中文",
                unloadLocalModelAfterResponse: false
            )
            XCTAssertTrue(configuration.supportsToken)
            XCTAssertFalse(configuration.requiresToken)
            let request = try ModelRequestFactory.makeRequest(
                action: .translate, text: "Hello", configuration: configuration, token: " proxy-token "
            )
            XCTAssertEqual(request.url?.path, "/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            let data = try XCTUnwrap(request.httpBody)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNotNil(body["system"] as? String)
            XCTAssertEqual(body["max_tokens"] as? Int, 768)
            let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
            XCTAssertEqual(messages.map { $0["role"] }, ["user"])
            XCTAssertTrue(messages[0]["content"]?.contains("Hello") == true)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("proxy-token"))
            let unauthenticated = try ModelRequestFactory.makeRequest(
                action: .explain, text: "Hello", configuration: configuration, token: nil
            )
            XCTAssertNil(unauthenticated.value(forHTTPHeaderField: "Authorization"))
        }
    }

    func testCompatibleLocalProxySendsOptionalTokenAndRemoteRequiresIt() throws {
        for provider in [ModelProviderKind.openAICompatible, .anthropicCompatible] {
            var configuration = ModelConfiguration(
                provider: provider, baseURL: URL(string: "http://localhost:3456/v1")!,
                model: "proxy-model", targetLanguage: "简体中文",
                unloadLocalModelAfterResponse: false
            )
            let request = try ModelRequestFactory.makeRequest(
                action: .explain, text: "Hello", configuration: configuration, token: "local-token"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer local-token")
            configuration.baseURL = URL(string: "https://proxy.example/v1")!
            XCTAssertThrowsError(try ModelRequestFactory.makeRequest(
                action: .translate, text: "Hello", configuration: configuration, token: nil
            )) { XCTAssertEqual($0 as? ModelClientError, .tokenRequired) }
            configuration.baseURL = URL(string: "http://proxy.example/v1")!
            XCTAssertThrowsError(try ModelRequestFactory.makeRequest(
                action: .translate, text: "Hello", configuration: configuration, token: "token"
            )) { XCTAssertEqual($0 as? ModelClientError, .insecureRemoteEndpoint) }
        }
    }

    func testAnthropicParserReturnsOnlyTextBlocks() throws {
        let response = Data(#"{"content":[{"type":"thinking","thinking":"private"},{"type":"text","text":"你好"},{"type":"tool_use","name":"ignored"},{"type":"text","text":"世界"}]}"#.utf8)
        XCTAssertEqual(try ModelResponseParser.parse(response, provider: .anthropicCompatible), "你好\n世界")
        for value in [#"{"content":[]}"#, #"{"content":[{"type":"thinking","thinking":"private"}]}"#] {
            XCTAssertThrowsError(try ModelResponseParser.parse(Data(value.utf8), provider: .anthropicCompatible)) {
                XCTAssertEqual($0 as? ModelClientError, .invalidResponse)
            }
        }
    }

    func testOversizedProviderResponseIsRejectedBeforeParsing() {
        let oversized = Data(repeating: 0x20, count: ModelResponseParser.maximumResponseBytes + 1)

        XCTAssertThrowsError(
            try ModelResponseParser.parse(oversized, provider: .ollama)
        ) { error in
            XCTAssertEqual(error as? ModelClientError, .responseTooLarge)
        }
    }

    func testResponseCollectorRejectsOverflowBeforeRetainingIt() throws {
        var collector = BoundedDataCollector(maximumBytes: 4)
        try collector.append(Data([1, 2, 3, 4]))
        XCTAssertEqual(collector.data.count, 4)

        XCTAssertThrowsError(try collector.append(Data([5]))) { error in
            XCTAssertEqual(error as? ModelClientError, .responseTooLarge)
        }
        XCTAssertEqual(collector.data.count, 4)
    }
}
