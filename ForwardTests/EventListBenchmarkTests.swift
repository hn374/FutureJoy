#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import Forward

// Run explicitly for controlled comparisons; these measurements have no timing budget.
@MainActor
final class EventListBenchmarkTests: EventListTestCase {
    func testTenThousandEventStartupPerformance() async throws {
        let container = try store()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            autoreleasepool {
                let model = EventListViewModel(modelContext: ModelContext(container))
                XCTAssertEqual(model.events.count, 10_000)
            }
        }
    }

    func testTenThousandEventFirstLayoutPerformance() async throws {
        let container = try store()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        // iOS 26.1 can crash when UIKit releases an actor-isolated model outside a Swift task.
        // Keep hosts alive through UIKit's deferred teardown, then release in this async test.
        var retainedControllers: [UIViewController] = []
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            autoreleasepool {
                let context = ModelContext(container)
                let controller = UIHostingController(rootView: HomeView(modelContext: context).modelContainer(container))
                retainedControllers.append(controller)
                let window = makeWindow()
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                window.isHidden = true
                window.rootViewController = nil
            }
        }
        try await Task.sleep(for: .milliseconds(200))
        retainedControllers.removeAll()
    }

}
#endif
