#if DEBUG && targetEnvironment(simulator)
import XCTest

@MainActor
final class EventDeleteConfirmationUITests: XCTestCase {
    private let app = XCUIApplication()
    private let first = "Coffee and a good book"
    private let second = "Stargazing picnic"
    private let survivor = "Weekend baking workshop"

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testSingleDeleteAlertCancelsThenDeletesCapturedEvent() {
        launch(reset: true)
        app.buttons["Delete \(first)"].tap()
        let message = "Are you sure you want to delete \"\(first)\"? This action cannot be undone."
        XCTAssertTrue(app.alerts.staticTexts[message].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Delete \(first)"].waitForExistence(timeout: 5))
        app.buttons["Delete \(first)"].tap()
        XCTAssertTrue(app.alerts.staticTexts[message].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Delete \(second)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete \(first)"].exists)
        cancelSurvivorAlert()
        launch(reset: false)
        XCTAssertFalse(app.buttons["Delete \(first)"].exists)
        XCTAssertTrue(app.buttons["Delete \(second)"].exists)
        XCTAssertTrue(app.buttons["Delete \(survivor)"].exists)
    }

    func testBulkAlertCancellationPreservesSelectionAndConfirmationDeletesOnlySelected() {
        launch(reset: true)
        app.buttons["Select"].tap()
        app.staticTexts[first].tap()
        app.staticTexts[second].tap()
        XCTAssertFalse(app.buttons["Future"].isEnabled)
        XCTAssertFalse(app.buttons["Past"].isEnabled)
        app.buttons["Trash"].tap()
        let message = "Delete 2 selected event(s)? This action cannot be undone."
        XCTAssertTrue(app.alerts.staticTexts[message].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["2 selected"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Past"].isEnabled)
        app.buttons["Trash"].tap()
        XCTAssertTrue(app.alerts.staticTexts[message].waitForExistence(timeout: 5))
        app.alerts.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete \(first)"].exists)
        XCTAssertFalse(app.buttons["Delete \(second)"].exists)
        XCTAssertTrue(app.buttons["Future"].isEnabled)
        XCTAssertTrue(app.buttons["Past"].isEnabled)
        cancelSurvivorAlert()
        launch(reset: false)
        XCTAssertFalse(app.buttons["Delete \(first)"].exists)
        XCTAssertFalse(app.buttons["Delete \(second)"].exists)
        XCTAssertTrue(app.buttons["Delete \(survivor)"].exists)
    }

    private func launch(reset: Bool) {
        app.terminate()
        app.launchArguments = ["--sample-data", "--sample-profile", "typical"]
        if reset { app.launchArguments.append("--reset-sample-data") }
        app.launch()
        XCTAssertTrue(app.buttons["Delete \(survivor)"].waitForExistence(timeout: 10))
    }

    private func cancelSurvivorAlert() {
        app.buttons["Delete \(survivor)"].tap()
        XCTAssertTrue(app.alerts.buttons["Cancel"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Delete \(survivor)"].waitForExistence(timeout: 5))
    }
}
#endif
