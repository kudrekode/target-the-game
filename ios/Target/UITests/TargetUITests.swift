import XCTest

final class TargetUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testScreensInvalidMoveUndoAndExactHintPath() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["homePlay"].waitForExistence(timeout: 10))
        capture(app, "Home")
        app.buttons["homeStats"].tap()
        XCTAssertTrue(app.staticTexts["statsTitle"].waitForExistence(timeout: 5))
        capture(app, "Stats")
        app.buttons["homeButton"].tap()
        app.buttons["homePlay"].tap()
        XCTAssertTrue(app.buttons["numberSlot0"].waitForExistence(timeout: 5))
        let original = (0..<6).map { app.buttons["numberSlot\($0)"].label }
        capture(app, "Game")

        // A small starting number minus a large number must reject without consuming tiles.
        app.buttons["numberSlot0"].tap()
        app.buttons["Subtract"].tap()
        app.buttons["numberSlot4"].tap()
        XCTAssertTrue(app.staticTexts["gameMessage"].label.contains("positive"))
        XCTAssertEqual((0..<6).map { app.buttons["numberSlot\($0)"].label }, original)
        app.buttons["numberSlot0"].tap() // Deselect the rejected first input.

        // Addition of two small tiles cannot hit a target >=100; safely exercise undo.
        app.buttons["numberSlot0"].tap()
        app.buttons["Add"].tap()
        app.buttons["numberSlot1"].tap()
        XCTAssertTrue(wait { !app.buttons["numberSlot1"].exists && app.buttons["undoButton"].isEnabled })
        app.buttons["undoButton"].tap()
        XCTAssertTrue(wait { app.buttons["numberSlot1"].exists })
        XCTAssertEqual((0..<6).map { app.buttons["numberSlot\($0)"].label }, original)

        // Follow real generated hints, including the solver path after undo's fresh IDs.
        for _ in 0..<5 {
            if app.staticTexts["resultTitle"].exists { break }
            app.buttons["hintButton"].tap()
            let message = app.staticTexts["gameMessage"]
            XCTAssertTrue(wait { message.label.hasPrefix("Try ") })
            let expression = try NSRegularExpression(pattern: #"Try (\d+) ([+−×÷]) (\d+)"#)
            let text = message.label
            let match = try XCTUnwrap(expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)))
            let a = String(text[try XCTUnwrap(Range(match.range(at: 1), in: text))])
            let operation = String(text[try XCTUnwrap(Range(match.range(at: 2), in: text))])
            let b = String(text[try XCTUnwrap(Range(match.range(at: 3), in: text))])
            let first = app.buttons.matching(NSPredicate(format: "label == %@", "Number \(a)")).firstMatch
            let firstIdentifier = first.identifier
            first.tap()
            let names = ["+": "Add", "−": "Subtract", "×": "Multiply", "÷": "Divide"]
            app.buttons[try XCTUnwrap(names[operation])].tap()
            let second = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Number \(b)", firstIdentifier)).firstMatch
            XCTAssertTrue(second.exists)
            let secondIdentifier = second.identifier
            second.tap()
            XCTAssertTrue(wait { app.staticTexts["resultTitle"].exists || !app.buttons.matching(identifier: secondIdentifier).firstMatch.exists })
        }
        XCTAssertTrue(app.staticTexts["resultTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["resultTitle"].label, "EXACT")
        capture(app, "Exact result")
        app.buttons["nextRound"].tap()
        XCTAssertTrue(app.buttons["numberSlot0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["STREAK 1"].exists)
    }

    @MainActor
    func testBackgroundTimeoutAndSavedStats() async throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["homeStats"].waitForExistence(timeout: 10))
        app.buttons["homeStats"].tap()
        let before = try roundsPlayed(app)
        app.buttons["homeButton"].tap()
        app.buttons["homePlay"].tap()
        XCTAssertTrue(app.buttons["numberSlot0"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        try await Task.sleep(for: .seconds(62))
        app.activate()
        XCTAssertTrue(app.staticTexts["resultTitle"].waitForExistence(timeout: 10))
        XCTAssertNotEqual(app.staticTexts["resultTitle"].label, "EXACT")
        capture(app, "Background timeout")
        app.buttons["homeButton"].tap()
        app.buttons["homeStats"].tap()
        XCTAssertEqual(try roundsPlayed(app), before + 1)
        app.terminate()
        app.launch()
        app.buttons["homeStats"].tap()
        XCTAssertEqual(try roundsPlayed(app), before + 1)
        capture(app, "Persisted stats")
    }

    @MainActor
    private func roundsPlayed(_ app: XCUIApplication) throws -> Int {
        let value = app.descendants(matching: .any).matching(identifier: "roundsPlayedValue").firstMatch
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        return try XCTUnwrap(Int(value.label.filter(\.isNumber)))
    }

    @MainActor
    private func wait(timeout: TimeInterval = 5, _ predicate: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
