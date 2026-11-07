#if DEBUG && targetEnvironment(simulator)
import XCTest

@MainActor
final class SimulatorSampleDataUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testSampleEditsAndDeletionPersistUntilExplicitReset() {
        launch(reset: true)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        attachScreenshot("Sample upcoming events")
        app.buttons["FutureJoy"].tap()
        app.buttons["Past"].tap()
        XCTAssertTrue(card("Board game night").waitForExistence(timeout: 5))
        attachScreenshot("Sample archived events")
        app.buttons["PastJoy"].tap()
        app.buttons["Future"].tap()

        card("Stargazing picnic").tap()
        app.buttons["Edit event"].tap()
        let name = app.textFields["Event name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        let text = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count) + "My sample picnic")
        app.buttons["Save changes"].tap()
        app.buttons["Back"].tap()
        XCTAssertTrue(card("My sample picnic").waitForExistence(timeout: 5))

        let delete = app.buttons["Delete Coffee and a good book"]
        XCTAssertTrue(delete.exists)
        delete.tap()
        app.alerts.buttons["Delete"].tap()
        XCTAssertFalse(card("Coffee and a good book").exists)

        launch(reset: false)
        XCTAssertTrue(card("My sample picnic").waitForExistence(timeout: 10))
        XCTAssertFalse(card("Stargazing picnic").exists)
        XCTAssertFalse(card("Coffee and a good book").exists)

        launch(reset: true)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        XCTAssertTrue(card("Stargazing picnic").exists)
        XCTAssertFalse(card("My sample picnic").exists)
    }

    func testSwitchingModesAndResetPreserveNormalEvents() {
        let title = "Normal sentinel \(UUID().uuidString.prefix(8))"
        app.launchArguments = []
        app.launch()
        app.buttons["Add New Event"].tap()
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(title)
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists { returnKey.tap() }
        app.buttons["Create Event"].tap()
        XCTAssertTrue(card(title).waitForExistence(timeout: 5))

        launch(reset: true)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        XCTAssertFalse(card(title).exists)
        launch(reset: false)
        XCTAssertFalse(card(title).exists)

        app.terminate()
        app.launchArguments = ["--reset-sample-data"]
        app.launch()
        XCTAssertTrue(card(title).waitForExistence(timeout: 10))
        XCTAssertFalse(card("Coffee and a good book").exists)

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(card(title).waitForExistence(timeout: 10))
    }

    func testSelectionSurvivesScrollingAndDeletesOnlySelectedEvent() {
        launch(reset: true)
        let selectedTitle = "Coffee and a good book"
        let lastTitle = "A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours"
        XCTAssertTrue(card(selectedTitle).waitForExistence(timeout: 10))
        app.buttons["Select"].tap()
        let selected = app.staticTexts[selectedTitle]
        selected.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 5))

        let last = app.staticTexts[lastTitle]
        for _ in 0..<8 {
            if !selected.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(last.isHittable)
        XCTAssertFalse(selected.isHittable, "The selected card must leave the visible viewport")
        scroll(until: selected, direction: .down)
        XCTAssertTrue(selected.isHittable)
        XCTAssertTrue(app.staticTexts["1 selected"].exists)

        app.buttons["Trash"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Delete 1 selected event(s)? This action cannot be undone."].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertFalse(card(selectedTitle).exists)
        XCTAssertTrue(card("Stargazing picnic").waitForExistence(timeout: 5))

        launch(reset: false)
        XCTAssertTrue(card("Stargazing picnic").waitForExistence(timeout: 10))
        XCTAssertTrue(card("Weekend baking workshop").exists)
        XCTAssertFalse(card(selectedTitle).exists)
        scroll(until: card(lastTitle), direction: .up)
        XCTAssertTrue(card(lastTitle).isHittable)
    }

    func testDateEditReordersCardsWhenReturningFromDetail() throws {
        launch(reset: true)
        let title = "Stargazing picnic"
        XCTAssertTrue(card(title).waitForExistence(timeout: 10))
        card(title).tap()
        app.buttons["Edit event"].tap()
        let picker = app.datePickers.firstMatch
        scroll(until: picker, direction: .up)
        XCTAssertTrue(picker.isHittable)
        picker.tap()

        // Move beyond every upcoming sample event without depending on today's day number.
        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: Date()))
        let targetMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: 2, to: tomorrow))
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = 15
        let targetDate = try XCTUnwrap(calendar.date(from: components))
        let nextMonth = app.buttons["Next Month"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 5), app.debugDescription)
        nextMonth.tap()
        nextMonth.tap()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        let targetDay = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", formatter.string(from: targetDate))).firstMatch
        XCTAssertTrue(targetDay.waitForExistence(timeout: 5), app.debugDescription)
        targetDay.tap()
        // The compact calendar stays open after choosing a day. Dismiss it before saving.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(nextMonth.waitForNonExistence(timeout: 5))
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5))
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        XCTAssertTrue(app.staticTexts[formatter.string(from: targetDate)].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()

        let previouslyLast = card("A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours")
        scroll(until: card(title), direction: .up)
        XCTAssertTrue(card(title).isHittable)
        XCTAssertTrue(previouslyLast.isHittable)
        XCTAssertLessThan(previouslyLast.frame.minY, card(title).frame.minY,
                          "Returning from detail must put the edited event after the previously last event")

        launch(reset: false)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        scroll(until: card(title), direction: .up)
        card(title).tap()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        XCTAssertTrue(app.staticTexts[formatter.string(from: targetDate)].waitForExistence(timeout: 5))
    }

    private enum ScrollDirection { case up, down }

    private func scroll(until element: XCUIElement, direction: ScrollDirection) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.firstMatch
            if direction == .up { scroll.swipeUp() } else { scroll.swipeDown() }
        }
    }

    private func launch(reset: Bool) {
        app.terminate()
        app.launchArguments = ["--sample-data"] + (reset ? ["--reset-sample-data"] : [])
        app.launch()
    }

    private func card(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", title)).firstMatch
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
