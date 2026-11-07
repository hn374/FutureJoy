#if DEBUG && targetEnvironment(simulator)
import XCTest
import UIKit

@MainActor
final class EventDetailEmojiUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--sample-data", "--reset-sample-data"]
        app.launch()
        let event = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", "Stargazing picnic")
        ).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 10))
        event.tap()
        app.buttons["Edit event"].tap()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testEmojiEditsPreserveCharactersAndSaveOnlyOnConfirmation() {
        assertEmoji("🌌")

        replaceEmoji(with: "")
        assertEmoji("")
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.alerts["Unable to Save Changes"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts["Please add an emoji."].exists)
        app.alerts.buttons["OK"].tap()

        replaceEmoji(with: "🧑🏽‍🚀")
        assertEmoji("🧑🏽‍🚀")
        replaceEmoji(with: "🧑🏽‍🚀🇨🇦")
        assertEmoji("🧑🏽‍🚀")
        replaceEmoji(with: "🧑🏽‍🚀🇨🇦🎈")
        assertEmoji("🧑🏽‍🚀")
        let inputScreenshot = XCTAttachment(screenshot: app.screenshot())
        inputScreenshot.name = "Editing field limited to one composed emoji"
        inputScreenshot.lifetime = .keepAlways
        add(inputScreenshot)

        // Leaving without saving must discard the edited value.
        app.buttons["xmark"].tap()
        app.buttons["Edit event"].tap()
        assertEmoji("🌌")

        replaceEmoji(with: "👨‍👩‍👧‍👦🌙🎉")
        assertEmoji("👨‍👩‍👧‍👦")
        app.buttons["Save changes"].tap()
        app.buttons["Back"].tap()

        app.terminate()
        app.launchArguments = ["--sample-data"]
        app.launch()
        let event = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", "Stargazing picnic")
        ).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 10))
        XCTAssertTrue(event.label.contains("👨‍👩‍👧‍👦"))
        event.tap()
        app.buttons["Edit event"].tap()
        assertEmoji("👨‍👩‍👧‍👦")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Saved composed emoji in event editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testLegacyEmojiSurvivesUnrelatedEditAndCancel() {
        app.buttons["Back"].tap()
        let event = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", "A wonderfully long weekend adventure")
        ).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        event.tap()
        app.buttons["Edit event"].tap()
        assertEmoji("🎒🌲")

        let title = app.textFields["event-title-editor"]
        title.tap()
        title.typeText(" updated")
        app.buttons["Save changes"].tap()
        app.buttons["Edit event"].tap()
        assertEmoji("🎒🌲")

        replaceEmoji(with: "🌙🎉")
        assertEmoji("🌙")
        app.buttons["xmark"].tap()
        app.buttons["Back"].tap()
        app.terminate()
        app.launchArguments = ["--sample-data"]
        app.launch()
        let saved = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", "updated")
        ).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("🎒🌲"))
        saved.tap()
        app.buttons["Edit event"].tap()
        assertEmoji("🎒🌲")
    }

    private var emojiField: XCUIElement { app.textFields["Emoji"] }

    private func assertEmoji(_ expected: String) {
        let predicate = expected.isEmpty
            ? NSPredicate(format: "value == '' OR value == placeholderValue")
            : NSPredicate(format: "value == %@", expected)
        expectation(for: predicate, evaluatedWith: emojiField)
        waitForExpectations(timeout: 3)
    }

    private func replaceEmoji(with value: String) {
        XCTAssertTrue(emojiField.waitForExistence(timeout: 5))
        // Tap after the text but inside the padded field’s editable area.
        emojiField.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let current = emojiField.value as? String ?? ""
        if !current.isEmpty && current != emojiField.placeholderValue {
            emojiField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        guard !value.isEmpty else { return }
        // Use the system paste path because typeText cannot synthesize emoji keys.
        UIPasteboard.general.string = value
        emojiField.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 2) {
            paste.tap()
        } else {
            app.buttons["Paste"].tap()
        }
        let allowPaste = app.alerts.buttons["Allow Paste"]
        if allowPaste.waitForExistence(timeout: 1) { allowPaste.tap() }
    }
}
#endif
