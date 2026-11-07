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
