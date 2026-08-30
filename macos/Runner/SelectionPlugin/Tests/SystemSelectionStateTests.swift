import XCTest
@testable import DingDongSelectionHost

final class SystemSelectionStateTests: XCTestCase {
    func testOnlySelectionChangingEventsTriggerAnAccessibilityRead() {
        XCTAssertTrue(SelectionTrigger.primaryMouseUp.shouldReadSelection)
        XCTAssertTrue(SelectionTrigger.accessibilitySelectionChanged.shouldReadSelection)
        XCTAssertTrue(
            SelectionTrigger.keyUp(keyCode: 123, modifiers: [.shift]).shouldReadSelection
        )
        XCTAssertTrue(
            SelectionTrigger.keyUp(keyCode: 0, modifiers: [.command]).shouldReadSelection
        )

        XCTAssertFalse(
            SelectionTrigger.keyUp(keyCode: 0, modifiers: []).shouldReadSelection
        )
        XCTAssertFalse(
            SelectionTrigger.keyUp(keyCode: 8, modifiers: [.command, .option]).shouldReadSelection
        )
    }

    func testDirectCopyShortcutIsExplicitAndDoesNotNeedPolling() {
        XCTAssertTrue(
            SelectionTrigger.keyUp(keyCode: 8, modifiers: [.command, .option]).isDirectCopyShortcut
        )
        XCTAssertFalse(SelectionTrigger.primaryMouseUp.isDirectCopyShortcut)
        XCTAssertFalse(SelectionTrigger.accessibilitySelectionChanged.isDirectCopyShortcut)
    }

    func testSelectionBufferReleasesTextWhenConsumedOrCleared() {
        var buffer = SelectionBuffer()
        XCTAssertTrue(buffer.update("  keep me briefly  "))
        XCTAssertEqual(buffer.consume(), "keep me briefly")
        XCTAssertNil(buffer.current)

        XCTAssertTrue(buffer.update("another selection"))
        buffer.clear()
        XCTAssertNil(buffer.current)
    }

    func testFocusedApplicationCaptureReplacesAQueuedObservedElement() {
        var state = SelectionCaptureScheduleState()
        state.schedule(.observedElement)
        state.schedule(.focusedApplication)

        XCTAssertEqual(state.consume(), .focusedApplication)
        XCTAssertNil(state.consume())

        state.schedule(.observedElement)
        state.cancel()
        XCTAssertNil(state.consume())
    }

    func testLatestRequestGenerationRejectsStaleCompletions() {
        var generation = LatestRequestGeneration()
        let first = generation.advance()
        let second = generation.advance()

        XCTAssertFalse(generation.isCurrent(first))
        XCTAssertTrue(generation.isCurrent(second))
    }

    func testSecureSelectionPolicyFailsClosed() {
        XCTAssertFalse(SelectionSecurityPolicy.isKnownSubrole(nil))
        XCTAssertFalse(SelectionSecurityPolicy.isKnownSubrole(""))
        XCTAssertFalse(SelectionSecurityPolicy.isKnownSubrole("AXUnknown"))
        XCTAssertTrue(SelectionSecurityPolicy.isKnownSubrole("AXSearchField"))

        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: false,
                role: .unknown,
                subroleAdvertised: false,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .unknown,
                subroleAdvertised: false,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .textField,
                subroleAdvertised: false,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .textField,
                subroleAdvertised: true,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .textField,
                subroleAdvertised: true,
                subroleReadSucceeded: true,
                isSecureTextField: true
            )
        )
        XCTAssertTrue(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .textField,
                subroleAdvertised: true,
                subroleReadSucceeded: true,
                isSecureTextField: false
            )
        )
        XCTAssertTrue(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .nonSecretTextContainer,
                subroleAdvertised: false,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
        XCTAssertFalse(
            SelectionSecurityPolicy.allowsRead(
                attributeListAvailable: true,
                role: .nonSecretTextContainer,
                subroleAdvertised: true,
                subroleReadSucceeded: false,
                isSecureTextField: false
            )
        )
    }
}
