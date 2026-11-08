#if DEBUG && targetEnvironment(simulator)
import XCTest

@MainActor
final class StableHeaderUITests: XCTestCase {
    private let app = XCUIApplication()
    private var title: XCUIElement { app.staticTexts["Forward"] }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testTitleStaysFixedAcrossEmptyAndPopulatedLists() {
        for largeText in [false, true] {
            launch(profile: "archive-heavy", largeText: largeText)
            deleteEvent("Next adventure")
            XCTAssertFalse(app.buttons["Select"].exists)
            let baseline = title.frame
            attach("Empty Future \(largeText)")
            for _ in 0..<3 {
                app.buttons["Past"].tap()
                XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
                assertTitle(at: baseline)
                app.buttons["Future"].tap()
                XCTAssertFalse(app.buttons["Select"].exists)
                assertTitle(at: baseline)
            }
            app.buttons["Past"].tap()
            attach("Populated Past \(largeText)")

            launch(profile: "typical", largeText: largeText)
            let populated = title.frame
            app.buttons["Past"].tap()
            deleteEvent("Board game night")
            deleteEvent("Lakeside sketching afternoon")
            XCTAssertFalse(app.buttons["Select"].exists)
            assertTitle(at: populated)
            for _ in 0..<3 {
                app.buttons["Future"].tap()
                XCTAssertTrue(app.buttons["Select"].exists)
                assertTitle(at: populated)
                app.buttons["Past"].tap()
                assertTitle(at: populated)
            }
            attach("Empty Past \(largeText)")
        }
    }

    func testSelectionKeepsTitleFixedAndActionsReachable() {
        for largeText in [false, true] {
            launch(profile: "typical", largeText: largeText)
            for tab in ["Future", "Past"] {
                app.buttons[tab].tap()
                let baseline = title.frame
                attach("\(tab) before selection \(largeText)")
                app.buttons["Select"].tap()
                XCTAssertTrue(app.staticTexts["0 selected"].waitForExistence(timeout: 5))
                assertTitle(at: baseline)
                assertControl(app.buttons["Cancel"])
                assertControl(app.buttons["Trash"], enabled: false)
                let eventName = tab == "Future" ? "Coffee and a good book" : "Board game night"
                let event = app.scrollViews.staticTexts[eventName]
                if !event.isHittable { app.scrollViews.firstMatch.swipeUp() }
                event.tap()
                XCTAssertTrue(app.staticTexts["1 selected"].exists)
                assertTitle(at: baseline)
                app.buttons["Trash"].tap()
                XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 5))
                app.alerts.buttons["Cancel"].tap()
                assertTitle(at: baseline)
                attach("\(tab) selection \(largeText)")
                app.buttons["Cancel"].tap()
                assertTitle(at: baseline)
            }
        }
    }

    func testFirstInsertionAndLastDeletionKeepTitleFixed() {
        for largeText in [false, true] {
            launch(profile: "empty", largeText: largeText)
            let baseline = title.frame
            XCTAssertFalse(app.buttons["Select"].exists)
            let add = app.buttons["Add New Event"]
            if !add.isHittable { app.scrollViews.firstMatch.swipeUp() }
            add.tap()
            let name = app.textFields["Birthday Party"]
            XCTAssertTrue(name.waitForExistence(timeout: 5))
            name.tap()
            name.typeText("Header anchor event")
            if app.keyboards.buttons["Return"].exists { app.keyboards.buttons["Return"].tap() }
            let save = app.buttons["Create Event"]
            if !save.isHittable { app.swipeUp() }
            save.tap()
            XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
            assertTitle(at: baseline)
            deleteEvent("Header anchor event")
            XCTAssertFalse(app.buttons["Select"].exists)
            assertTitle(at: baseline)
            attach("First insertion and last deletion \(largeText)")
        }
    }

    private func launch(profile: String, largeText: Bool) {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--sample-data", "--sample-profile", profile, "--reset-sample-data"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
    }

    private func deleteEvent(_ name: String) {
        // Creation feedback can temporarily cover the row's delete hit target.
        XCTAssertTrue(app.staticTexts["Event created successfully"].waitForNonExistence(timeout: 5))
        let delete = app.scrollViews.buttons["Delete \(name)"]
        for _ in 0..<8 {
            if delete.exists && delete.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(delete.waitForNonExistence(timeout: 5))
    }

    private func assertTitle(at baseline: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        let actual = title.frame
        XCTAssertEqual(actual.minX, baseline.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.minY, baseline.minY, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.width, baseline.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.height, baseline.height, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.midX, app.frame.midX, accuracy: 1, file: file, line: line)
        XCTAssertTrue(app.frame.contains(actual), file: file, line: line)
        XCTAssertEqual(app.staticTexts.matching(identifier: "Forward").count, 1, file: file, line: line)
        assertControl(app.buttons["Scroll to top"])
    }

    private func assertControl(_ control: XCUIElement, enabled: Bool = true) {
        XCTAssertTrue(control.exists)
        XCTAssertTrue(app.frame.contains(control.frame))
        XCTAssertGreaterThanOrEqual(control.frame.width, 44)
        XCTAssertGreaterThanOrEqual(control.frame.height, 44)
        XCTAssertFalse(control.frame.intersects(title.frame))
        if enabled { XCTAssertTrue(control.isHittable) }
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
