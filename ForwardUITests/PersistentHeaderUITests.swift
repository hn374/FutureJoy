#if DEBUG && targetEnvironment(simulator)
import XCTest

@MainActor
final class PersistentHeaderUITests: XCTestCase {
    private let app = XCUIApplication()
    private var list: XCUIElement { app.scrollViews.firstMatch }
    private var addEvent: XCUIElement { app.buttons["Add New Event"] }
    private var titleButton: XCUIElement { app.buttons["Scroll to top"] }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testAddRemainsReachableAtTopMiddleAndBottomAndCancelPreservesPosition() {
        launch(profile: "busy")
        XCTAssertTrue(card("Busy event 101").waitForExistence(timeout: 10))
        assertCanCancelDraft(at: card("Busy event 101"))
        for _ in 0..<5 { list.swipeUp() }
        let middle = visibleCard()
        attach("Busy middle event space")
        assertCanCancelDraft(at: middle)
        // A fast drag traverses the long list without relying on lazy offscreen elements.
        let last = card("Busy event 300")
        for _ in 0..<80 {
            if last.exists && last.isHittable { break }
            list.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(card("Busy event 300").isHittable)
        assertCanCancelDraft(at: card("Busy event 300"))
        tapEdge(titleButton)
        XCTAssertTrue(card("Busy event 101").isHittable)
        relaunch(profile: "busy")
        XCTAssertTrue(card("Busy event 101").waitForExistence(timeout: 10))
        XCTAssertFalse(card("Cancelled header draft").exists)
    }

    func testHeaderCreationSavesExactlyOneEventAndPersists() {
        launch(profile: "empty")
        XCTAssertTrue(addEvent.waitForExistence(timeout: 10))
        tapEdge(addEvent)
        let name = app.textFields["Birthday Party"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Persistent header event")
        dismissKeyboard()
        app.buttons["Create Event"].tap()
        XCTAssertTrue(card("Persistent header event").waitForExistence(timeout: 5))
        let toast = app.staticTexts["Event created successfully"]
        XCTAssertTrue(toast.isHittable, "Saving must leave the existing success feedback visible")
        attach("Header creation success")
        relaunch(profile: "empty")
        XCTAssertTrue(card("Persistent header event").waitForExistence(timeout: 10))
        XCTAssertEqual(list.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Delete '")).count, 1)
    }

    func testSelectionCancelAndDeleteConfirmationPreserveEvents() {
        launch(profile: "typical")
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
        tapEdge(app.buttons["Select"])
        XCTAssertFalse(addEvent.exists)
        XCTAssertTrue(app.staticTexts["0 selected"].exists)
        app.staticTexts["Coffee and a good book"].tap()
        app.buttons["Trash"].tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["1 selected"].exists)
        attach("Header selection")
        tapEdge(app.buttons["Cancel"])
        XCTAssertTrue(card("Coffee and a good book").exists)
        XCTAssertTrue(addEvent.isHittable)
        tapEdge(app.buttons["Select"])
        XCTAssertTrue(app.staticTexts["0 selected"].exists)
        XCTAssertFalse(app.buttons["Trash"].isEnabled)
        tapEdge(app.buttons["Cancel"])
        relaunch(profile: "typical")
        XCTAssertTrue(card("Coffee and a good book").waitForExistence(timeout: 10))
    }

    func testCreationAvailableOnlyInFutureIncludingEmptyLists() {
        for profile in ["empty", "archive-heavy"] {
            launch(profile: profile)
            XCTAssertTrue(addEvent.waitForExistence(timeout: 10))
            if profile == "empty" {
                XCTAssertFalse(app.buttons["Select"].exists)
                tapEdge(addEvent)
                fillDraftAndClose()
                relaunch(profile: profile)
                XCTAssertTrue(addEvent.waitForExistence(timeout: 10))
                XCTAssertFalse(card("Cancelled header draft").exists)
                XCTAssertFalse(app.buttons["Select"].exists)
            }
            app.buttons["Past"].tap()
            XCTAssertFalse(addEvent.exists)
            XCTAssertTrue(titleButton.isHittable)
            if profile == "empty" { XCTAssertFalse(app.buttons["Select"].exists) }
            attach("\(profile) Past header")
            app.buttons["Future"].tap()
            XCTAssertTrue(addEvent.isHittable)
        }
    }

    func testHeaderControlsRemainReachableAtAccessibilityTextSizes() {
        launch(profile: "archive-heavy", largeText: true)
        XCTAssertTrue(addEvent.waitForExistence(timeout: 10))
        XCTAssertTrue(titleButton.label.contains("Forward"))
        tapEdge(titleButton)
        tapEdge(addEvent)
        XCTAssertTrue(app.textFields["Birthday Party"].waitForExistence(timeout: 5))
        closeCreation()
        tapEdge(app.buttons["Select"])
        XCTAssertTrue(app.staticTexts["0 selected"].exists)
        XCTAssertFalse(addEvent.exists)
        attach("Accessibility selection header")
        tapEdge(app.buttons["Cancel"])
        app.buttons["Past"].tap()
        XCTAssertFalse(addEvent.exists)
        let firstPast = app.staticTexts["Archived memory 1"]
        XCTAssertTrue(firstPast.isHittable)
        for _ in 0..<3 { list.swipeUp() }
        XCTAssertFalse(firstPast.isHittable)
        tapEdge(titleButton)
        XCTAssertTrue(firstPast.isHittable, "The title must scroll the active Past list")
        tapEdge(app.buttons["Select"])
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        attach("Accessibility Past selection header")
        tapEdge(app.buttons["Cancel"])
        XCTAssertTrue(app.buttons["Select"].exists)
    }

    private func assertCanCancelDraft(at event: XCUIElement) {
        XCTAssertTrue(event.isHittable)
        let before = event.frame.minY
        XCTAssertTrue(addEvent.isHittable, "Add must remain reachable at every list position")
        tapEdge(addEvent)
        fillDraftAndClose()
        XCTAssertTrue(event.isHittable)
        XCTAssertEqual(event.frame.minY, before, accuracy: 3, "Cancel must preserve browsing position")
    }

    private func fillDraftAndClose() {
        let field = app.textFields["Birthday Party"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Cancelled header draft")
        dismissKeyboard()
        closeCreation()
    }

    private func closeCreation() {
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(app.textFields["Birthday Party"].waitForNonExistence(timeout: 5))
    }

    private func tapEdge(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(app.frame.contains(button.frame))
        XCTAssertGreaterThanOrEqual(button.frame.width, 44)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        // Exercise the touch area directly; XCUI can retain stale hittability after overlay dismissal.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
    }

    private func dismissKeyboard() {
        if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
    }

    private func visibleCard() -> XCUIElement {
        let cards = list.buttons.matching(NSPredicate(format: "label CONTAINS 'Busy event' AND NOT label BEGINSWITH 'Delete '")).allElementsBoundByIndex
        let chosen = cards.first { list.frame.contains($0.frame) && $0.isHittable } ?? cards[0]
        return list.buttons.matching(NSPredicate(format: "label == %@", chosen.label)).firstMatch
    }

    private func card(_ title: String) -> XCUIElement {
        list.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", title)).firstMatch
    }

    private func launch(profile: String, largeText: Bool = false) {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", profile, "--reset-sample-data"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
    }

    private func relaunch(profile: String) {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", profile]
        app.launch()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
