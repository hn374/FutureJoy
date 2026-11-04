import XCTest
import UIKit

@MainActor
final class EventCreationEmojiUITests: XCTestCase {
    private var app: XCUIApplication!
    private var createdTitles: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
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
        dismissKeyboard()
        attachScreenshot(named: "Custom emoji during creation")
        saveAndAssertCard(title, emoji: "🧑🏽‍🚀")
        attachScreenshot(named: "Saved event with custom emoji")

        app.terminate()
        app.launch()
        assertCard(title, emoji: "🧑🏽‍🚀")
        openEditor(title, expectedEmoji: "🧑🏽‍🚀")
        replaceEmoji(with: "🦦")
        app.buttons["Save changes"].tap()
        app.buttons["Back"].tap()
        assertCard(title, emoji: "🦦")
    }

    func testCreateEventWithoutChoosingEmojiUsesDefault() {
        let title = openCreation()
        saveAndAssertCard(title, emoji: "🎉")
        openEditor(title, expectedEmoji: "🎉")
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
        saveAndAssertCard(customTitle, emoji: "🦦🌙")
        openEditor(customTitle, expectedEmoji: "🦦🌙")
    }

    func testCreateEventLimitsCustomEmojiWithoutSplittingCharacters() {
        let title = openCreation()
        replaceEmoji(with: "🧑🏽‍🚀🌙🎈")
        saveAndAssertCard(title, emoji: "🧑🏽‍🚀🌙")
        openEditor(title, expectedEmoji: "🧑🏽‍🚀🌙")
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
        field.tap()
        let current = field.value as? String ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        if !text.isEmpty {
            // Paste through the system menu: typeText cannot synthesize emoji keys.
            UIPasteboard.general.string = text
            field.press(forDuration: 1.2)
            let paste = app.menuItems["Paste"]
            if paste.waitForExistence(timeout: 2) {
                paste.tap()
            } else {
                app.buttons["Paste"].tap()
            }
            let allowPaste = app.alerts.buttons["Allow Paste"]
            if allowPaste.waitForExistence(timeout: 1) {
                allowPaste.tap()
            }
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
