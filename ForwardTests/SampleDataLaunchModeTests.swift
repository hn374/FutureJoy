import XCTest
@testable import Forward

final class SampleDataLaunchModeTests: XCTestCase {
    func testSampleModeRequiresExplicitOptIn() {
        for arguments in [[], ["Forward"], ["--other"], ["--reset-sample-data"]] {
            XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: arguments), .disabled)
        }
    }

    func testOptInAndResetAreRestrictedToDebugSimulator() {
        let inputs = [
            ["--sample-data"],
            ["Forward", "--sample-data", "--sample-data"],
            ["--sample-data", "--reset-sample-data"],
            ["--reset-sample-data", "--sample-data", "--reset-sample-data"]
        ]
        for (index, arguments) in inputs.enumerated() {
            #if DEBUG && targetEnvironment(simulator)
            XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: arguments), .enabled(reset: index >= 2))
            #else
            XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: arguments), .disabled)
            #endif
        }
    }
}
