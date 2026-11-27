import XCTest

@MainActor
final class EventCreationAccessibilityUITests: XCTestCase {
    func testCreationStartsAtNameAndCanCancelAtLargestTextSize() {
        continueAfterFailure = false
        let app = launch(.largest)
        let name = openCreation(app)
        XCTAssertTrue(name.isHittable, "A fresh draft must start at the name field")
        XCTAssertFalse(app.buttons["Add New Event"].isHittable, "The sheet must block background Home actions")
        XCTAssertFalse(app.keyboards.firstMatch.exists)

        let create = app.buttons["Create Event"]
        XCTAssertTrue(create.isHittable)
        XCTAssertFalse(create.isEnabled)

        let title = "Cancelled Duo draft"
        name.tap()
        name.typeText(title)
        let hideKeyboard = app.buttons["Hide Keyboard"]
        XCTAssertTrue(hideKeyboard.isHittable, "The keyboard dismissal action must remain reachable while typing")
        XCTAssertTrue(name.isHittable, "The active field must remain reachable while typing")
        hideKeyboard.tap()
        XCTAssertTrue(create.isEnabled)
        app.buttons["cancel-event-creation"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add New Event"].isEnabled, "Home actions must return after Cancel")
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.exists)

        let reopenedName = openCreation(app)
        let value = reopenedName.value as? String
        XCTAssertTrue(value == nil || value == "" || value == "Birthday Party",
                      "Reopening creation must start a new draft")
    }

    func testCreationDateRemainsReachableAtLargestTextSize() throws {
        try verifyDateSelection(.largest)
    }

    func testCreationDateCanBeSelectedAtStandardTextSize() throws {
        try verifyDateSelection(.standard)
    }

    private enum TextSize: String {
        case largest = "UICTContentSizeCategoryAccessibilityXXXL"
        case standard = "UICTContentSizeCategoryL"
    }

    private func launch(_ size: TextSize, reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--sample-data", "--sample-profile", "empty",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", size.rawValue
        ]
        if reset {
            app.launchArguments.append("--reset-sample-data")
        }
        app.launch()
        return app
    }

    private func openCreation(_ app: XCUIApplication) -> XCUIElement {
        let add = app.buttons["Add New Event"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let heading = app.staticTexts["Create New Event"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(heading.frame),
                      "The heading \(heading.frame) must fit inside the window \(app.frame)")
        let name = app.textFields["event-creation-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        return name
    }

    private func verifyDateSelection(_ size: TextSize) throws {
        continueAfterFailure = false
        let app = launch(size)
        defer { app.terminate() }
        let name = openCreation(app)
        let title = "Duo QA \(UUID().uuidString.prefix(6))"
        name.tap()
        name.typeText(title)
        app.buttons["Hide Keyboard"].tap()

        let date = app.buttons["event-creation-date"]
        let form = app.scrollViews.containing(.button, identifier: "event-creation-date").firstMatch
        reveal(date, in: form)
        attachScreenshot(app, named: "Event form at \(size) text size")
        XCTAssertTrue(date.isHittable, "The date must be reachable by scrolling the form")
        XCTAssertTrue(form.frame.insetBy(dx: -1, dy: -1).contains(date.frame),
                      "The date \(date.frame) must fit in the form viewport \(form.frame)")

        date.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Event Date"].isHittable)
        attachScreenshot(app, named: "Calendar at \(size) text size")

        let today = Date.now
        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        if !calendar.isDate(today, equalTo: tomorrow, toGranularity: .month) {
            app.buttons["Next Month"].tap()
        }
        let english = Locale(identifier: "en_US")
        let dayLabel = tomorrow.formatted(.dateTime.weekday(.wide).month(.wide).day().locale(english))
        let tomorrowButton = app.buttons[dayLabel]
        XCTAssertTrue(tomorrowButton.isHittable, "The calendar must show a selectable future date")
        tomorrowButton.tap()

        done.tap()
        XCTAssertTrue(date.isHittable, "Done must return to the visible date row")
        XCTAssertEqual(date.value as? String, tomorrow.formatted(.dateTime.day().month(.wide).year().locale(english)))
        XCTAssertEqual(name.value as? String, title)

        date.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(tomorrowButton.isSelected, "Reopening the calendar must retain the selected date")
        done.tap()
        app.buttons["Create Event"].tap()

        app.terminate()
        let relaunched = launch(size, reset: false)
        let event = relaunched.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 10), "The new event must survive relaunch")
        event.tap()

        let detailDate = DateFormatter()
        detailDate.locale = english
        detailDate.dateFormat = "EEEE, MMMM d, yyyy"
        XCTAssertTrue(relaunched.staticTexts[detailDate.string(from: tomorrow)].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<5 where !scrollView.frame.contains(element.frame) {
            let viewport = scrollView.frame
            let needed = (viewport.midY - element.frame.midY) / viewport.height
            let offset = min(max(needed, -0.36), 0.36)
            let start = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = scrollView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5 + offset))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
