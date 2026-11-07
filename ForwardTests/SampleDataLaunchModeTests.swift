import XCTest
@testable import Forward

final class SampleDataLaunchModeTests: XCTestCase {
    func testNamedProfilesRequireOptInAndRejectMalformedValues() {
        #if DEBUG && targetEnvironment(simulator)
        XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: ["--sample-data", "--sample-profile", "empty"]), .enabled(reset: false, profile: .empty))
        XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: ["--sample-data", "--sample-profile", "busy", "--reset-sample-data"]), .enabled(reset: true, profile: .busy))
        for value in ["unknown", "../normal", "--reset-sample-data"] {
            guard case .invalid = SampleDataLaunchMode.resolve(arguments: ["--sample-data", "--sample-profile", value]) else {
                return XCTFail("Malformed profile should be diagnosed")
            }
        }
        guard case .invalid = SampleDataLaunchMode.resolve(arguments: ["--sample-data", "--sample-profile"]) else {
            return XCTFail("Missing profile should be diagnosed")
        }
        #endif
        XCTAssertEqual(SampleDataLaunchMode.resolve(arguments: ["--sample-profile", "empty"]), .disabled)
    }

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
