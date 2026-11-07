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
        let add = list.buttons["Add New Event"]
        let firstFuture = card("Busy event 101")
        let firstPast = card("Busy event 100")
        assertFullyVisible(add)
        let futureTop = relativeTop(of: add)
        switchTo("Past")
        assertFullyVisible(firstPast)
        let pastTop = relativeTop(of: firstPast)
        switchTo("Future")
        assertAtTop(add, relativeTo: futureTop)

        for round in 1...3 {
            scrollOffscreen([add, firstFuture])
            switchTo("Future")
            assertOffscreen([add, firstFuture], "Selecting active Future must preserve scrolling")
            switchTo("Past")
            assertAtTop(firstPast, relativeTo: pastTop)
            attach("Round \(round) Past reset to top")

            scrollOffscreen([firstPast])
            switchTo("Past")
            assertOffscreen([firstPast], "Selecting active Past must preserve scrolling")
            switchTo("Future")
            assertAtTop(add, relativeTo: futureTop)
            assertFullyVisible(firstFuture)
            let visibleEvents = list.buttons.matching(NSPredicate(
                format: "label CONTAINS 'Busy event' AND NOT label BEGINSWITH 'Delete '"
            )).allElementsBoundByIndex.filter { element in
                element.exists && list.frame.intersects(element.frame)
            }.sorted { $0.frame.minY < $1.frame.minY }
            XCTAssertEqual(visibleEvents.first?.label, firstFuture.label,
                           "Busy event 101 must be the first visible Future event")
            attach("Round \(round) Future reset to top")
        }

        scrollOffscreen([add, firstFuture])
        app.buttons["Scroll to top"].tap()
        assertAtTop(add, relativeTo: futureTop)
        assertFullyVisible(firstFuture)
        scrollOffscreen([add, firstFuture])
    }

    func testScrolledPastSwitchesToShortFutureAtTop() {
        launch(profile: "archive-heavy", largeText: true)
        let add = list.buttons["Add New Event"]
        assertFullyVisible(add)
        let futureTop = relativeTop(of: add)
        switchTo("Past")
        // An exact delete label distinguishes memory 1 from memories 10–19.
        let firstPast = list.buttons["Delete Archived memory 1"]
        assertFullyVisible(firstPast)
        let pastTop = relativeTop(of: firstPast)

        for round in 1...2 {
            scrollOffscreen([firstPast])
            switchTo("Future")
            assertAtTop(add, relativeTo: futureTop)
            assertFullyVisible(card("Next adventure"))
            attach("Round \(round) short Future reset")
            switchTo("Past")
            assertAtTop(firstPast, relativeTo: pastTop)
        }
    }

    func testScrolledFutureSwitchesToEmptyPastAtTop() {
        XCUIDevice.shared.orientation = .portrait
        launch(profile: "typical", largeText: true)
        let add = list.buttons["Add New Event"]
        let firstFuture = card("Coffee and a good book")
        assertFullyVisible(add)
        let futureTop = relativeTop(of: add)
        switchTo("Past")
        for title in ["Board game night", "Lakeside sketching afternoon"] {
            let delete = list.buttons["Delete \(title)"]
            scrollToVisible(delete)
            delete.tap()
            let confirmation = app.alerts.buttons["Delete"]
            XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
            confirmation.tap()
            XCTAssertTrue(delete.waitForNonExistence(timeout: 5))
        }
        let empty = list.staticTexts["No past events yet"]
        assertFullyVisible(empty)
        let emptyTop = relativeTop(of: empty)
        switchTo("Future")
        assertAtTop(add, relativeTo: futureTop)

        // A tall display may fit the fixtures; add real events only when displacement needs more content.
        for index in 1...8 {
            if scrollUpUntilOffscreen([add, firstFuture]) { break }
            app.buttons["Scroll to top"].tap()
            assertAtTop(add, relativeTo: futureTop)
            add.tap()
            let name = app.textFields["Birthday Party"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            name.tap()
            name.typeText("Scroll coverage event \(index)")
            if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
            app.buttons["Create Event"].tap()
            XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        }

        for round in 1...2 {
            scrollOffscreen([add, firstFuture])
            switchTo("Past")
            assertAtTop(empty, relativeTo: emptyTop)
            attach("Round \(round) empty Past reset")
            switchTo("Future")
            assertAtTop(add, relativeTo: futureTop)
            assertFullyVisible(firstFuture)
        }
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
        let exists = tab.waitForExistence(timeout: 5)
        if !exists { attach("\(title) tab unavailable for switching") }
        XCTAssertTrue(exists, "Both list destinations must remain available while scrolling")
        tab.tap()
    }

    private func card(_ title: String) -> XCUIElement {
        list.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT label BEGINSWITH 'Delete '", title)).firstMatch
    }

    private var list: XCUIElement { app.scrollViews.firstMatch }

    private func relativeTop(of element: XCUIElement) -> CGFloat {
        element.frame.minY - list.frame.minY
    }

    private func assertFullyVisible(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let visible = NSPredicate { _, _ in
            element.exists && !element.frame.isEmpty && self.list.frame.contains(element.frame)
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: nil)], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Expected fully visible content: \(element), frame \(element.frame), viewport \(list.frame)",
                       file: file, line: line)
    }

    private func assertAtTop(_ element: XCUIElement, relativeTo initialTop: CGFloat,
                             file: StaticString = #filePath, line: UInt = #line) {
        assertFullyVisible(element, file: file, line: line)
        let atTop = NSPredicate { _, _ in
            element.exists && abs(self.relativeTop(of: element) - initialTop) <= 2
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: atTop, object: nil)], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Expected initial relative top \(initialTop), actual \(relativeTop(of: element))",
                       file: file, line: line)
    }

    private func isOutsideViewport(_ element: XCUIElement) -> Bool {
        !element.exists || !list.frame.intersects(element.frame)
    }

    private func assertOffscreen(_ elements: [XCUIElement], _ message: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let outside = NSPredicate { _, _ in elements.allSatisfy { self.isOutsideViewport($0) } }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: outside, object: nil)], timeout: 5)
        XCTAssertEqual(result, .completed, message, file: file, line: line)
    }

    private func scrollOffscreen(_ elements: [XCUIElement], file: StaticString = #filePath, line: UInt = #line) {
        _ = scrollUpUntilOffscreen(elements)
        assertOffscreen(elements, "The source top content must leave the viewport before switching", file: file, line: line)
    }

    private func scrollUpUntilOffscreen(_ elements: [XCUIElement]) -> Bool {
        for _ in 0..<8 {
            if elements.allSatisfy({ isOutsideViewport($0) }) { return true }
            list.swipeUp()
        }
        return elements.allSatisfy { isOutsideViewport($0) }
    }

    private func scrollToVisible(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<8 {
            if element.exists && list.frame.contains(element.frame) && element.isHittable { break }
            list.swipeUp(velocity: .slow)
        }
        assertFullyVisible(element, file: file, line: line)
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
