#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import Forward

@MainActor
final class EventListPerformanceTests: XCTestCase {
    private func store(count: Int = 10_000) throws -> ModelContainer {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let schema = Schema([Event.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, url: directory.appending(path: "Events.store"), cloudKitDatabase: .none)
        ])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let today = Calendar.current.startOfDay(for: Date())
        for index in 0..<count {
            let event = Event(title: String(format: "Event %05d", index), emoji: "🎉",
                              date: today.addingTimeInterval(Double(index / 10 + 1) * 86_400),
                              location: index.isMultiple(of: 3) ? "Local park" : nil)
            context.insert(event)
        }
        try context.save()
        return container
    }

    func testTenThousandEventsRemainReachableThroughMutationAndFilterChanges() async throws {
        let container = try store()
        let context = ModelContext(container)
        let model = EventListViewModel(modelContext: context)
        XCTAssertEqual(model.events.count, 10_000)
        let originalIDs = Set(model.events.map(\.id))
        XCTAssertEqual(originalIDs.count, 10_000)
        model.fetchEvents()
        XCTAssertEqual(Set(model.events.map(\.id)), originalIDs)

        let added = try model.addEvent(title: "New earliest event", emoji: "🌻", date: Date())
        XCTAssertEqual(model.events.first?.id, added.id)
        let edited = try XCTUnwrap(model.events.last)
        edited.date = Date().addingTimeInterval(60)
        try context.save()
        model.fetchEvents()
        XCTAssertEqual(model.events.prefix(2).map(\.id), [added.id, edited.id])
        model.confirmDelete(added)
        model.deleteConfirmedEvent()
        XCTAssertEqual(model.events.count, 10_000)
        XCTAssertEqual(Set(model.events.map(\.id)), originalIDs)
        model.setFilter(.past)
        XCTAssertTrue(model.events.isEmpty)
        model.setFilter(.future)
        XCTAssertEqual(Set(model.events.map(\.id)), originalIDs)
    }

    func testBulkSelectionSurvivesRefreshAndDeletesOnlySelectedEvents() async throws {
        let container = try store(count: 100)
        let context = ModelContext(container)
        let model = EventListViewModel(modelContext: context)
        let selected = [model.events[0], model.events[80]]
        let selectedIDs = Set(selected.map(\.id))
        let remainingIDs = Set(model.events.map(\.id)).subtracting(selectedIDs)
        model.enterSelectionMode()
        for event in selected { model.toggleSelection(for: event) }
        model.fetchEvents()
        XCTAssertEqual(model.selectedEventIDs, selectedIDs)
        model.confirmDeleteSelected()
        model.deleteConfirmedEvent()
        XCTAssertEqual(Set(model.events.map(\.id)), remainingIDs)
        let persisted = try ModelContext(container).fetch(FetchDescriptor<Event>())
        XCTAssertEqual(Set(persisted.map(\.id)), remainingIDs)
        XCTAssertFalse(model.isSelectionMode)
    }

    func testArchiveUsesCalendarDayBoundary() async throws {
        let container = try store(count: 0)
        let context = ModelContext(container)
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Event(title: "Yesterday", emoji: "🌙", date: today.addingTimeInterval(-1))
        let midnight = Event(title: "Midnight", emoji: "☀️", date: today)
        context.insert(yesterday)
        context.insert(midnight)
        try context.save()
        let model = EventListViewModel(modelContext: context)
        XCTAssertTrue(yesterday.isArchived)
        XCTAssertFalse(midnight.isArchived)
        XCTAssertEqual(model.events.map(\.id), [midnight.id])
        model.setFilter(.past)
        XCTAssertEqual(model.events.map(\.id), [yesterday.id])
    }

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

    func testTenThousandEventScrollTraversal() async throws {
        let container = try store()
        let controller = UIHostingController(rootView: HomeView(modelContext: ModelContext(container)).modelContainer(container))
        let window = makeWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        let scroll = try XCTUnwrap(findScrollView(in: controller.view))
        let start = CFAbsoluteTimeGetCurrent()
        for step in 1...20 {
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom * Double(step) / 20), animated: false)
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(20))
        }
        // Lazy layouts refine their estimated content size as distant rows become visible.
        for _ in 0..<3 {
            let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            controller.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        XCTAssertEqual(scroll.contentOffset.y, bottom, accuracy: 1)
        print("ISSUE8_SCROLL_SECONDS=\(CFAbsoluteTimeGetCurrent() - start)")
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Ten thousand event list at end"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(200))
        withExtendedLifetime(controller) {}
    }

    private func makeWindow() -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        return window
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScrollView(in: $0) }.first
    }
}
#endif
