import XCTest
import UIKit

@MainActor
final class EventCreationEmojiUITests: XCTestCase {
    private var app: XCUIApplication!
    private var createdTitles: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--sample-data", "--reset-sample-data", "--sample-profile", "empty"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", "empty"]
        app.launch()
        for title in createdTitles {
            let delete = app.buttons["Delete \(title)"]
            revealOnHome(delete)
            if delete.exists && delete.isHittable {
                delete.tap()
                app.alerts.buttons["Delete"].tap()
            }
        }
        app.terminate()
    }

    func testCreateEventWithCustomEmojiPersistsAndCanBeEdited() {
        let title = openCreation(titlePrefix: "Concert Night")
        replaceEmoji(with: "🧑🏽‍🚀")
        assertEmoji("🧑🏽‍🚀")
        dismissKeyboard()
        attachScreenshot(named: "Custom emoji during creation")
        saveAndAssertCard(title, emoji: "🧑🏽‍🚀")
        attachScreenshot(named: "Saved event with custom emoji")

        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", "empty"]
        app.launch()
        assertCard(title, emoji: "🧑🏽‍🚀")
        openEditor(title, expectedEmoji: "🧑🏽‍🚀")
        replaceEmoji(with: "🦦")
        assertEmoji("🦦")
        app.buttons["Save changes"].tap()
        app.buttons["Back"].tap()
        assertCard(title, emoji: "🦦")
    }

    func testCreateEventWithBlankEmojiUsesDefault() {
        for input in ["", "  "] {
            let title = openCreation()
            replaceEmoji(with: input)
            saveAndAssertCard(title, emoji: "🎉")
            openEditor(title, expectedEmoji: "🎉")
            app.buttons["Back"].tap()
        }
    }

    func testCreateEventSavesLatestEmojiChoice() {
        let presetTitle = openCreation()
        replaceEmoji(with: "🦦")
        dismissKeyboard()
        reveal(app.buttons["🎂"])
        app.buttons["🎂"].tap()
        saveAndAssertCard(presetTitle, emoji: "🎂")

        let customTitle = openCreation()
        reveal(app.buttons["🎂"])
        app.buttons["🎂"].tap()
        replaceEmoji(with: "🦦🌙")
        saveAndAssertCard(customTitle, emoji: "🦦")
        openEditor(customTitle, expectedEmoji: "🦦")
    }

    func testCreateEventLimitsCustomEmojiWithoutSplittingCharacters() {
        let title = openCreation()
        replaceEmoji(with: "🧑🏽‍🚀🌙🎈")
        assertEmoji("🧑🏽‍🚀")
        pasteEmoji("🌙")
        assertEmoji("🧑🏽‍🚀")
        dismissKeyboard()
        attachScreenshot(named: "Creation field limited to one composed emoji")
        saveAndAssertCard(title, emoji: "🧑🏽‍🚀")
        openEditor(title, expectedEmoji: "🧑🏽‍🚀")
    }

    func testCreationRequiresNonblankTitleAndEnablesForToday() {
        app.buttons["Add New Event"].tap()
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let create = app.buttons["Create Event"]
        XCTAssertFalse(create.isEnabled)
        name.tap()
        name.typeText("   ")
        XCTAssertFalse(create.isEnabled)
        name.typeText("Cancelled valid draft")
        XCTAssertTrue(create.isEnabled, "Today's initial date must be accepted")
        dismissKeyboard()
        app.buttons["xmark"].tap()
        XCTAssertTrue(app.buttons["Add New Event"].isEnabled)
        XCTAssertFalse(card("Cancelled valid draft").exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete '")).count, 0)
    }

    func testPreparedTextFieldsPersistThroughCreationAndEditing() {
        let suffix = UUID().uuidString.prefix(8)
        let title = "Draft fields \(suffix)"
        let updatedTitle = "Updated draft \(suffix)"
        app.buttons["Add New Event"].tap()
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("  \(title)  ")
        let location = app.textFields["New York, NY"]
        reveal(location)
        location.tap()
        location.typeText("  New York, NY  ")
        let notes = app.textViews.firstMatch
        reveal(notes)
        notes.tap()
        notes.typeText("  first\n\nsecond  ")
        // Tapping a non-text control dismisses the multiline editor's keyboard.
        app.staticTexts["Create New Event"].tap()
        saveAndAssertCard(title, emoji: "🎉")

        relaunchEmptyProfile()
        assertCard(title, emoji: "🎉")
        openEditor(title, expectedEmoji: "🎉")
        XCTAssertEqual(app.textFields["event-title-editor"].value as? String, title)
        XCTAssertEqual(app.textFields["Add a location"].value as? String, "New York, NY")
        XCTAssertEqual(app.textViews.firstMatch.value as? String, "first\n\nsecond")

        replaceText(in: app.textFields["event-title-editor"], with: "  \(updatedTitle)  ")
        replaceText(in: app.textFields["Add a location"], with: "   ")
        replaceText(in: app.textViews.firstMatch, with: "   ")
        app.buttons["Save changes"].tap()
        createdTitles.removeAll { $0 == title }
        createdTitles.append(updatedTitle)
        app.buttons["Back"].tap()
        relaunchEmptyProfile()
        assertCard(updatedTitle, emoji: "🎉")
        card(updatedTitle).tap()
        XCTAssertTrue(app.staticTexts["No location added"].exists)
        XCTAssertTrue(app.staticTexts["No notes yet"].exists)
        app.buttons["Edit event"].tap()
        XCTAssertEqual(app.textFields["event-title-editor"].value as? String, updatedTitle)
        let emptyLocation = app.textFields["Add a location"]
        XCTAssertTrue(["", "Add a location"].contains(emptyLocation.value as? String ?? ""))
        XCTAssertEqual(app.textViews.firstMatch.value as? String, "")
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        let value = field.value as? String ?? ""
        field.tap()
        // Tap after the final line, as the emoji helper taps after its text.
        // A center tap can place the caret at the beginning; hardware shortcuts
        // and contextual menu contents vary with the simulator keyboard state.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        field.typeText(text)
        XCTAssertEqual(field.value as? String, text)
    }

    private func relaunchEmptyProfile() {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", "empty"]
        app.launch()
    }

    @discardableResult
    private func openCreation(titlePrefix: String = "Emoji QA") -> String {
        let title = "\(titlePrefix) \(UUID().uuidString.prefix(8))"
        app.buttons["Add New Event"].tap()
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(title)
        dismissKeyboard()
        return title
    }

    private func replaceEmoji(with text: String) {
        let field = app.textFields["Emoji"]
        reveal(field)
        XCTAssertTrue(field.exists, "Creation must allow custom emoji input")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        let empty = NSPredicate(format: "value == '' OR value == placeholderValue")
        expectation(for: empty, evaluatedWith: field)
        waitForExpectations(timeout: 3)
        if !text.isEmpty {
            pasteEmoji(text)
        }
    }

    private func assertEmoji(_ expected: String) {
        expectation(for: NSPredicate(format: "value == %@", expected), evaluatedWith: app.textFields["Emoji"])
        waitForExpectations(timeout: 3)
    }

    private func pasteEmoji(_ text: String) {
        // Paste through the system menu: typeText cannot synthesize emoji keys.
        UIPasteboard.general.string = text
        app.textFields["Emoji"].press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 2) {
            paste.tap()
        } else {
            let pasteButton = app.buttons["Paste"]
            guard pasteButton.waitForExistence(timeout: 2) else {
                XCTFail("The system Paste control did not appear for the Emoji field.")
                return
            }
            pasteButton.tap()
        }
        let allowPaste = app.alerts.buttons["Allow Paste"]
        if allowPaste.waitForExistence(timeout: 1) {
            allowPaste.tap()
        }
    }

    private func dismissKeyboard() {
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists {
            returnKey.tap()
        }
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            let form = app.scrollViews.containing(.textField, identifier: "Emoji").firstMatch
            guard form.exists else { break }
            let needsScrollDown = element.exists && element.frame.minY < form.frame.minY
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: needsScrollDown ? 0.85 : 0.45))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }

    private func revealOnHome(_ element: XCUIElement) {
        let list = app.scrollViews.firstMatch
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            list.swipeUp()
        }
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            list.swipeDown()
        }
    }

    private func card(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    private func saveAndAssertCard(_ title: String, emoji: String) {
        createdTitles.append(title)
        app.buttons["Create Event"].tap()
        assertCard(title, emoji: emoji)
    }

    private func assertCard(_ title: String, emoji: String) {
        let event = card(title)
        revealOnHome(event)
        XCTAssertTrue(event.waitForExistence(timeout: 5), "Created event must appear on home")
        XCTAssertTrue(event.label.contains(emoji), "The saved card must show \(emoji): \(event.label)")
    }

    private func openEditor(_ title: String, expectedEmoji: String) {
        card(title).tap()
        app.buttons["Edit event"].tap()
        let field = app.textFields["Emoji"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, expectedEmoji)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
