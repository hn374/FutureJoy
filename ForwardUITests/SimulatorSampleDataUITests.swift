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

    func testProfilesSwitchPersistAndResetIndependently() {
        app.launchArguments = ["--sample-data", "--sample-profile", "empty", "--reset-sample-data"]
        app.launch()
        launch(reset: true)
        app.buttons["Delete Coffee and a good book"].tap()
        app.alerts.buttons["Delete"].tap()
        selectProfile("Empty")
        XCTAssertFalse(card("Stargazing picnic").exists)
        app.buttons["Add New Event"].tap()
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Empty profile addition")
        if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
        app.buttons["Create Event"].tap()
        XCTAssertTrue(card("Empty profile addition").waitForExistence(timeout: 5))
        attachScreenshot("Empty profile with a saved addition")
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", "empty"]
        app.launch()
        XCTAssertTrue(card("Empty profile addition").waitForExistence(timeout: 10))
        selectProfile("Typical")
        XCTAssertTrue(card("Stargazing picnic").waitForExistence(timeout: 5))
        XCTAssertFalse(card("Coffee and a good book").exists)
        XCTAssertFalse(card("Empty profile addition").exists)
        card("Stargazing picnic").tap()
        selectProfile("Empty")
        XCTAssertTrue(card("Empty profile addition").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Edit event"].exists)
        app.buttons["Reset profile"].tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(card("Empty profile addition").exists)
        app.buttons["Reset profile"].tap()
        app.alerts.buttons["Reset"].tap()
        XCTAssertFalse(card("Empty profile addition").waitForExistence(timeout: 2))
        selectProfile("Typical")
        XCTAssertFalse(card("Coffee and a good book").exists)
        attachScreenshot("Typical profile preserves independent edits")
        app.buttons["Testing profiles"].tap()
        attachScreenshot("Testing profile choices")
    }

    private func selectProfile(_ title: String) {
        app.buttons["Testing profiles"].tap()
        app.buttons[title].tap()
    }

    func testSampleEditsAndDeletionPersistUntilExplicitReset() {
        launch(reset: true)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        attachScreenshot("Sample upcoming events")
        app.buttons["Past"].tap()
        XCTAssertTrue(card("Board game night").waitForExistence(timeout: 5))
        attachScreenshot("Sample archived events")
        app.buttons["Future"].tap()

        card("Stargazing picnic").tap()
        app.buttons["Edit event"].tap()
        let name = app.descendants(matching: .any)["event-title-editor"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        // Start deletion at the end, rather than the cursor position chosen by a center tap.
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()
        let text = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count) + "My sample picnic")
        XCTAssertEqual(name.value as? String, "My sample picnic")
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
        for profile in ["empty", "busy"] {
            app.terminate()
            app.launchArguments = ["--sample-data", "--sample-profile", profile, "--reset-sample-data"]
            app.launch()
            XCTAssertTrue(app.buttons["Testing profiles"].waitForExistence(timeout: 10))
            XCTAssertFalse(card(title).exists)
            if profile == "busy" { attachScreenshot("Busy profile with hundreds of events") }
        }

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
        launch(reset: true, profile: "busy")
        let selectedTitle = "Busy event 101"
        let lastTitle = "Busy event 110"
        XCTAssertTrue(card(selectedTitle).waitForExistence(timeout: 10))
        app.buttons["Select"].tap()
        let selected = app.staticTexts[selectedTitle]
        selected.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 5))

        let last = app.staticTexts[lastTitle]
        // Distinct dates keep the selected event first and the tenth event beyond the viewport.
        scroll(until: last, direction: .up, fullyVisible: true)
        XCTAssertTrue(last.isHittable)
        XCTAssertFalse(selected.isHittable, "The selected card must leave the visible viewport")
        scroll(until: selected, direction: .down)
        XCTAssertTrue(selected.isHittable)
        XCTAssertTrue(app.staticTexts["1 selected"].exists)

        app.buttons["Trash"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Delete 1 selected event(s)? This action cannot be undone."].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertFalse(card(selectedTitle).exists)
        XCTAssertTrue(card("Busy event 102").waitForExistence(timeout: 5))

        launch(reset: false, profile: "busy")
        XCTAssertTrue(card("Busy event 102").waitForExistence(timeout: 10))
        XCTAssertTrue(card("Busy event 103").exists)
        XCTAssertFalse(card(selectedTitle).exists)
        scroll(until: card(lastTitle), direction: .up)
        XCTAssertTrue(card(lastTitle).isHittable)
    }

    func testTruncatedTitleOpensFullTitleForEditingAndStillDeletes() {
        launch(reset: true)
        let title = "A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours"
        let eventCard = card(title)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        scroll(until: app.buttons["Delete \(title)"], direction: .up)
        app.scrollViews.firstMatch.swipeUp()
        let titleText = app.staticTexts[title]
        XCTAssertTrue(titleText.isHittable)
        attachScreenshot("Long title at bottom of sample list")

        titleText.tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5))
        app.buttons["Edit event"].tap()
        let titleEditor = app.descendants(matching: .any)["event-title-editor"]
        scroll(until: titleEditor, direction: .up, fullyVisible: true)
        XCTAssertTrue(titleEditor.isHittable)
        XCTAssertEqual(titleEditor.value as? String, title)
        attachScreenshot("Full long title in edit screen")
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        scroll(until: app.buttons["Delete \(title)"], direction: .up)
        app.buttons["Delete \(title)"].tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertFalse(eventCard.exists)
        XCTAssertTrue(card("Weekend baking workshop").exists)
    }

    func testLongCardRemainsUsableAtLargestAccessibilityTextSize() {
        app.launchArguments = ["--sample-data", "--reset-sample-data",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let title = "A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours"
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        scroll(until: app.staticTexts[title], direction: .up)
        XCTAssertTrue(app.staticTexts[title].isHittable)
        attachScreenshot("Long title at largest accessibility text size")
        app.staticTexts[title].tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()

        let location = app.staticTexts["Fernwood Valley"]
        scroll(until: location, direction: .up, fullyVisible: true)
        XCTAssertTrue(location.isHittable)
        XCTAssertTrue(app.scrollViews.firstMatch.frame.contains(location.frame))
        attachScreenshot("Long card metadata at largest accessibility text size")
        let delete = app.buttons["Delete \(title)"]
        scroll(until: delete, direction: .down, fullyVisible: true)
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(card(title).exists)
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
        attachScreenshot("Long title in the middle after date edit")

        launch(reset: false)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        scroll(until: card(title), direction: .up)
        card(title).tap()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        XCTAssertTrue(app.staticTexts[formatter.string(from: targetDate)].waitForExistence(timeout: 5))
    }

    func testArchivedEventRescheduledToFutureMovesListsAndPersists() throws {
        let calendar = Calendar.current
        let targetMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: 2, to: Date()))
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = 15
        try assertArchivedEventReschedules(to: XCTUnwrap(calendar.date(from: components)))
    }

    func testArchivedEventRescheduledToTodayMovesListsAndPersists() throws {
        try assertArchivedEventReschedules(to: Calendar.current.startOfDay(for: Date()))
    }

    func testSavingArchivedEventWithPastDateKeepsItArchived() {
        launch(reset: true)
        app.buttons["Past"].tap()
        card("Board game night").tap()
        app.buttons["Edit event"].tap()
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Event date cannot be in the past."].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()

        launch(reset: false)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        XCTAssertFalse(card("Board game night").exists)
        app.buttons["Past"].tap()
        XCTAssertTrue(card("Board game night").waitForExistence(timeout: 5))
    }

    private func assertArchivedEventReschedules(to targetDate: Date) throws {
        let title = "Board game night"
        launch(reset: true)
        app.buttons["Past"].tap()
        XCTAssertTrue(card(title).waitForExistence(timeout: 5))
        card(title).tap()
        app.buttons["Edit event"].tap()
        let picker = app.datePickers.firstMatch
        scroll(until: picker, direction: .up)
        XCTAssertTrue(picker.isHittable)
        picker.tap()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        let targetDay = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", formatter.string(from: targetDate))).firstMatch
        if Calendar.current.isDateInToday(targetDate) {
            // A past picker value is displayed as today; change it before selecting today.
            let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: targetDate))
            let tomorrowDay = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", formatter.string(from: tomorrow))).firstMatch
            if !tomorrowDay.waitForExistence(timeout: 2) {
                app.buttons["Next Month"].tap()
            }
            XCTAssertTrue(tomorrowDay.waitForExistence(timeout: 5))
            tomorrowDay.tap()
            if !targetDay.waitForExistence(timeout: 2) {
                app.buttons["Previous Month"].tap()
            }
        }
        for _ in 0..<3 {
            if targetDay.waitForExistence(timeout: 2) { break }
            app.buttons["Next Month"].tap()
        }
        XCTAssertTrue(targetDay.waitForExistence(timeout: 5), app.debugDescription)
        targetDay.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.buttons["Next Month"].waitForNonExistence(timeout: 5))
        app.buttons["Save changes"].tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5), app.debugDescription)
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        XCTAssertTrue(app.staticTexts[formatter.string(from: targetDate)].waitForExistence(timeout: 5))
        attachScreenshot("Rescheduled archived event")
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Past"].isSelected)
        XCTAssertTrue(card(title).waitForNonExistence(timeout: 5), "A rescheduled event must leave Past")
        XCTAssertTrue(card("Lakeside sketching afternoon").exists)
        app.buttons["Future"].tap()
        scroll(until: card(title), direction: .up)
        XCTAssertTrue(card(title).isHittable)
        XCTAssertEqual(cards(title).count, 1)
        attachScreenshot("Rescheduled event in Future")

        launch(reset: false)
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        scroll(until: card(title), direction: .up)
        XCTAssertTrue(card(title).isHittable)
        XCTAssertEqual(cards(title).count, 1)
        card(title).tap()
        XCTAssertTrue(app.staticTexts[formatter.string(from: targetDate)].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        app.buttons["Past"].tap()
        XCTAssertTrue(card("Lakeside sketching afternoon").waitForExistence(timeout: 5))
        XCTAssertFalse(card(title).exists)
    }

    private enum ScrollDirection { case up, down }

    private func scroll(until element: XCUIElement, direction: ScrollDirection, fullyVisible: Bool = false) {
        for _ in 0..<8 {
            let scroll = app.scrollViews.firstMatch
            if element.exists && element.isHittable && (!fullyVisible || scroll.frame.contains(element.frame)) { return }
            if direction == .up {
                scroll.swipeUp(velocity: fullyVisible ? .slow : .default)
            } else {
                scroll.swipeDown(velocity: fullyVisible ? .slow : .default)
            }
        }
    }

    private func launch(reset: Bool, profile: String = "typical") {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", profile] + (reset ? ["--reset-sample-data"] : [])
        app.launch()
    }

    private func card(_ title: String) -> XCUIElement {
        cards(title).firstMatch
    }

    private func cards(_ title: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", title))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
