#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
import SwiftUI
import UIKit
import Vision
@testable import Forward

@MainActor
final class EventListBehaviorTests: EventListTestCase {
    func testTenThousandEventsRemainCompleteThroughMutationAndFilterChanges() async throws {
        let container = try store()
        let context = ModelContext(container)
        let model = EventListViewModel(modelContext: context)
        XCTAssertEqual(model.events.count, 10_000)
        let originalIDs = Set(model.events.map(\.id))
        XCTAssertEqual(originalIDs.count, 10_000)
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
        context.autosaveEnabled = false
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
        let persisted = try ModelContext(container).fetch(FetchDescriptor<Event>())
        let archivedByID = Dictionary(uniqueKeysWithValues: persisted.map { ($0.id, $0.isArchived) })
        XCTAssertEqual(archivedByID[yesterday.id], true)
        XCTAssertEqual(archivedByID[midnight.id], false)
    }

    func testTenThousandEventScrollTraversalRendersFinalCard() async throws {
        let container = try store()
        let context = ModelContext(container)
        let finalTitle = "Event 09999"
        let finalEvent = try XCTUnwrap(context.fetch(FetchDescriptor<Event>()).first { $0.title == finalTitle })
        // Equal-date ordering is unspecified. Give the sentinel a unique final date.
        finalEvent.date = Calendar.current.date(byAdding: .day, value: 1, to: finalEvent.date)!
        try context.save()
        let controller = UIHostingController(rootView: HomeView(modelContext: context).modelContainer(container))
        let window = makeWindow()
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(try visibleText(in: window).contains(finalTitle),
                       "The final event must begin outside the visible viewport")
        let scroll = try XCTUnwrap(findScrollView(in: controller.view))
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
        let image = renderedImage(in: window)
        XCTAssertTrue(try visibleText(in: image).contains(finalTitle),
                      "The known final event must be rendered in the visible viewport")
        let attachment = XCTAttachment(image: image)
        attachment.name = "Ten thousand event list at end"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
        window.rootViewController = nil
        try await Task.sleep(for: .milliseconds(200))
        withExtendedLifetime(controller) {}
    }

    private func renderedImage(in window: UIWindow) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
    }

    private func visibleText(in window: UIWindow) throws -> Set<String> {
        try visibleText(in: renderedImage(in: window))
    }

    private func visibleText(in image: UIImage) throws -> Set<String> {
        // Read rendered content rather than relying on SwiftUI's private hosting hierarchy.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage))
        try handler.perform([request])
        return Set((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") })
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScrollView(in: $0) }.first
    }
}
#endif
