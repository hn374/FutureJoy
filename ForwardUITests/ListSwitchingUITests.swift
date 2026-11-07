#if DEBUG && targetEnvironment(simulator)
import XCTest

@MainActor
final class ListSwitchingUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testOneTapSwitchingAndCancelKeepEventsInTheirOwnList() {
        launch(profile: "typical")
        let future = card("Coffee and a good book")
        XCTAssertTrue(future.waitForExistence(timeout: 10))
        assertForwardTitleIsVisible()
        attach("Future list")
        switchTo("Past")
        XCTAssertTrue(card("Board game night").waitForExistence(timeout: 5))
        assertForwardTitleIsVisible()
        XCTAssertFalse(app.buttons["Add New Event"].exists)
        XCTAssertFalse(future.exists)
        attach("Past list")
        switchTo("Future")
        XCTAssertTrue(future.waitForExistence(timeout: 5))
        app.buttons["Select"].tap()
        app.staticTexts["Coffee and a good book"].tap()
        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 5))
        attach("Switching disabled during selection")
        // Tap the destination's position: no switch or selection loss may occur.
        app.buttons["Past"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["1 selected"].exists)
        XCTAssertTrue(app.staticTexts["Coffee and a good book"].exists)
        app.buttons["Cancel"].tap()
        switchTo("Past")
        XCTAssertFalse(future.exists)
        switchTo("Future")
        XCTAssertTrue(future.waitForExistence(timeout: 5))
        future.tap()
        XCTAssertTrue(app.buttons["Edit event"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(future.waitForExistence(timeout: 5))
    }

    func testSwitchingFromScrolledListStartsDestinationAtTop() {
        launch(profile: "busy")
        let add = app.buttons["Add New Event"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        let initialY = add.frame.minY
        app.scrollViews.firstMatch.swipeUp()
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertFalse(add.isHittable)
        switchTo("Future")
        XCTAssertFalse(add.isHittable, "Selecting the active list must preserve its scroll position")
        switchTo("Past")
        let firstPast = card("Busy event 100")
        XCTAssertTrue(firstPast.waitForExistence(timeout: 5))
        attach("Busy Past reset to top")
        XCTAssertTrue(app.scrollViews.firstMatch.frame.contains(firstPast.frame), "The first Past card must be fully visible: card \(firstPast.frame), viewport \(app.scrollViews.firstMatch.frame)")
        app.scrollViews.firstMatch.swipeUp()
        switchTo("Future")
        XCTAssertEqual(add.frame.minY, initialY, accuracy: 2, "Returning to Future must restore its initial top position")
        XCTAssertTrue(app.scrollViews.firstMatch.frame.contains(add.frame), "Add must be fully visible below the pinned header")
        attach("Busy list reset to top")
        app.scrollViews.firstMatch.swipeUp()
        app.buttons["Scroll to top"].tap()
        XCTAssertEqual(add.frame.minY, initialY, accuracy: 2, "Calendar must reset to the same visible top position")
    }

    func testEmptyAndArchiveHeavyListsCanSwitchAtLargestTextSize() {
        for profile in ["empty", "archive-heavy"] {
            launch(profile: profile, largeText: true)
            XCTAssertTrue(app.buttons["Past"].waitForExistence(timeout: 10))
            assertForwardTitleIsVisible()
            switchTo("Past")
            assertForwardTitleIsVisible()
            XCTAssertFalse(app.buttons["Add New Event"].exists)
            attach("\(profile) Past at largest text size")
            if profile == "archive-heavy" {
                app.buttons["Select"].tap()
                let cancel = app.buttons["Cancel"]
                XCTAssertTrue(cancel.isHittable, "Cancel must remain usable with the largest text size")
                XCTAssertTrue(app.frame.contains(cancel.frame))
                attach("Selection at largest text size")
                cancel.tap()
            }
            switchTo("Future")
            XCTAssertTrue(app.buttons["Add New Event"].isHittable)
            assertForwardTitleIsVisible()
            attach("\(profile) Future at largest text size")
        }
    }

    private func assertForwardTitleIsVisible(file: StaticString = #filePath, line: UInt = #line) {
        let title = app.staticTexts["Forward"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(title.isHittable, "The app title must remain visible", file: file, line: line)
        XCTAssertTrue(app.frame.contains(title.frame), "The app title must fit on screen", file: file, line: line)
    }

    private func launch(profile: String, largeText: Bool = false) {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", profile, "--reset-sample-data"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
    }

    private func switchTo(_ title: String) {
        let tab = app.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Both list destinations must be visible")
        XCTAssertTrue(tab.isHittable, "List switching must remain pinned while scrolling")
        tab.tap()
    }

    private func card(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", title)).firstMatch
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
