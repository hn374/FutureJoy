import XCTest

@MainActor
final class EventCreationAccessibilityUITests: XCTestCase {
    func testCreationDateRemainsReachableAtLargestTextSize() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--sample-data", "--sample-profile", "empty",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        defer { app.terminate() }

        let addEvent = app.buttons["Add New Event"]
        XCTAssertTrue(addEvent.waitForExistence(timeout: 10))
        addEvent.tap()

        let title = app.staticTexts["Create New Event"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(title.frame.minX, app.frame.minX, "The editor title must not extend off the left edge")

        let date = app.buttons["Select a date"]
        let form = app.scrollViews.containing(.button, identifier: "Select a date").firstMatch
        for _ in 0..<5 where !form.frame.contains(date.frame) {
            let dateIsAboveViewport = date.frame.minY < form.frame.minY
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = form.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: dateIsAboveViewport ? 0.85 : 0.45)
            )
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(date.isHittable, "The date must be reachable by scrolling the form")
        XCTAssertTrue(form.frame.contains(date.frame), "The full date must fit in the visible form")

        attachScreenshot(app, named: "Creation form at largest text size")

        date.tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        attachScreenshot(app, named: "Date picker at largest text size")
        let today = Date.now
        let calendar = Calendar.current
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        if !calendar.isDate(today, equalTo: tomorrow, toGranularity: .month) {
            app.buttons["Next Month"].tap()
        }
        let dayLabel = tomorrow.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let tomorrowButton = app.buttons[dayLabel]
        XCTAssertTrue(tomorrowButton.isHittable, "The calendar must show a selectable future date")
        tomorrowButton.tap()

        done.tap()
        XCTAssertTrue(title.isHittable, "Closing the date picker must return to the editor")
        XCTAssertEqual(date.value as? String, tomorrow.formatted(date: .long, time: .omitted))
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
