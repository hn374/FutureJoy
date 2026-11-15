#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
import SwiftUI
import UIKit
import Vision
@testable import Forward

@MainActor
final class EventListBehaviorTests: EventListTestCase {
    func testSwitchingIsBlockedDuringSelectionAndResumesAfterCancel() async throws {
        let container = try store(count: 2)
        let context = ModelContext(container)
        let past = Event(title: "Past event", emoji: "🌙", date: Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86_400))
        context.insert(past)
        try context.save()
        let model = EventListViewModel(modelContext: context)
        let futureIDs = model.events.map(\.id)
        let selected = try XCTUnwrap(model.events.first)
        model.enterSelectionMode()
        model.toggleSelection(for: selected)
        model.setFilter(.past)
        XCTAssertEqual(model.filter, .future)
        XCTAssertEqual(model.events.map(\.id), futureIDs)
        XCTAssertEqual(model.selectedEventIDs, [selected.id])
        model.exitSelectionMode()
        model.setFilter(.past)
        XCTAssertEqual(model.events.map(\.id), [past.id])
        XCTAssertTrue(model.selectedEventIDs.isEmpty)
        model.setFilter(.future)
        XCTAssertEqual(Set(model.events.map(\.id)), Set(futureIDs))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Event>()), 3)
    }

    func testEventCardsTruncateLongTitlesAndKeepMetadataReadable() throws {
        let longTitle = "A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours"
        let variants: [(String, String, String?)] = [
            ("North\nEast\nSouth\nNever", "🎸", nil),
            ("Concert Night", "🎸", nil),
            ("Concert Night", "🎒🌲", "Fernwood Valley"),
            (longTitle, "🎸", nil),
            (longTitle, "🎒🌲", "Fernwood Valley")
        ]
        for width: CGFloat in [375, 402] {
            for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility5] {
                for (index, variant) in variants.enumerated() {
                    let (title, emoji, location) = variant
                    let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from:
                        DateComponents(year: 2030, month: 6, day: 15, hour: 12)))
                    let event = Event(title: title, emoji: emoji, date: date, location: location)
                    let renderer = ImageRenderer(content:
                        EventRowView(event: event, onDelete: {})
                            .environment(\.dynamicTypeSize, size)
                            .environment(\.locale, Locale(identifier: "en_US"))
                            .frame(width: width - 40)
                            .padding(20)
                            .background(Color.white)
                    )
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.uiImage)
                    let name = "Card \(Int(width))pt \(size) variant \(index)"
                    let attachment = XCTAttachment(image: image)
                    attachment.name = name
                    attachment.lifetime = .keepAlways
                    add(attachment)
                    let text = try recognizedLines(in: image).joined(separator: "\n")
                        .replacingOccurrences(of: "-\\s+", with: "", options: .regularExpression)
                    let words = Set(text.lowercased()
                        .split(whereSeparator: { !$0.isLetter }).map(String.init))
                    let visibleTitle = title == longTitle ? "" : title.replacingOccurrences(of: "\nNever", with: "")
                    let expected = Set((visibleTitle + " " + (location ?? "")).lowercased()
                        .split(whereSeparator: { !$0.isLetter }).map(String.init))
                    XCTAssertTrue(expected.isSubset(of: words),
                                  "\(name) must render short titles and location; missing \(expected.subtracting(words))")
                    XCTAssertTrue(text.contains("2030"), "\(name) must keep the event date readable")
                    if title == longTitle {
                        XCTAssertFalse(words.contains("detours"), "\(name) must truncate the long title")
                    } else if title.contains("\nNever") {
                        XCTAssertFalse(words.contains("never"), "\(name) must omit the fourth line")
                        XCTAssertTrue(text.contains("…") || text.contains("..."),
                                      "\(name) must indicate truncation with an ellipsis: \(text)")
                    }
                }
            }
        }
    }

    func testTenThousandEventsRemainCompleteThroughMutationAndFilterChanges() async throws {
        let container = try store()
        let context = ModelContext(container)
        let model = EventListViewModel(modelContext: context)
        XCTAssertEqual(model.events.count, 10_000)
        let originalIDs = Set(model.events.map(\.id))
        XCTAssertEqual(originalIDs.count, 10_000)
        let today = Calendar.current.startOfDay(for: Date())
        let added = try model.addEvent(title: "New earliest event", emoji: "🌻", date: today)
        XCTAssertEqual(model.events.first?.id, added.id)
        let edited = try XCTUnwrap(model.events.last)
        try model.saveEdit(rescheduledEdit(to: today.addingTimeInterval(60)), for: edited)
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

    func testArchivedEditToTodayMovesToFutureAndPersists() async throws {
        try assertArchivedEdit(daysFromToday: 0)
    }

    func testArchivedEditToLaterDateMovesToFutureAndPersists() async throws {
        try assertArchivedEdit(daysFromToday: 2)
    }

    func testEditBeforeTodayIsRejectedWithoutSaving() async throws {
        let calendar = testCalendar
        let now = testNow
        let today = calendar.startOfDay(for: now)
        let container = try store(count: 0)
        let context = ModelContext(container)
        let event = Event(title: "Original", emoji: "🌙", date: today)
        context.insert(event)
        try context.save()
        let model = EventListViewModel(modelContext: context, now: { now }, calendar: { calendar })
        let invalidEdit = rescheduledEdit(to: today.addingTimeInterval(-1))

        XCTAssertThrowsError(try model.saveEdit(invalidEdit, for: event)) { error in
            XCTAssertEqual(error as? EventEditError, .dateInPast)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(model.events.map(\.id), [event.id])
        XCTAssertEqual(event.title, "Original")
        XCTAssertEqual(event.date, today)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Event>()).first?.date, today)
    }

    func testFailedEditRestoresFieldsAndOverdueFlagsAndCanRetry() async throws {
        let calendar = testCalendar
        var now = testNow
        let today = calendar.startOfDay(for: now)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        let configuration = try makeStoreConfiguration()
        let editedID = try withLocalStore(configuration) { context in
            context.autosaveEnabled = true
            let yesterday = today.addingTimeInterval(-1)
            let event = Event(title: "Original", emoji: "🌙", date: yesterday, location: "Old location", notes: "Old notes")
            event.isArchived = true
            let overdue = Event(title: "Due today", emoji: "☀️", date: today)
            let unrelated = Event(title: "Unrelated", emoji: "🌻", date: tomorrow)
            for row in [event, overdue, unrelated] { context.insert(row) }
            try context.save()

            var shouldFail = true
            let model = EventListViewModel(
                modelContext: context,
                now: { now },
                calendar: { calendar },
                save: { context in
                    if shouldFail { throw InjectedStoreError.failure }
                    try context.save()
                }
            )
            model.setFilter(.past)
            now = tomorrow
            unrelated.notes = "Pending unrelated change"
            let edit = rescheduledEdit(to: tomorrow)

            XCTAssertThrowsError(try model.saveEdit(edit, for: event)) { error in
                XCTAssertEqual(error as? InjectedStoreError, .failure)
            }
            XCTAssertEqual(model.events.map(\.id), [event.id])
            XCTAssertEqual(event.title, "Original")
            XCTAssertEqual(event.emoji, "🌙")
            XCTAssertEqual(event.date, yesterday)
            XCTAssertEqual(event.location, "Old location")
            XCTAssertEqual(event.notes, "Old notes")
            XCTAssertTrue(event.isArchived)
            XCTAssertFalse(overdue.isArchived)
            XCTAssertEqual(unrelated.notes, "Pending unrelated change")

            try context.save()
            let persisted = try ModelContext(context.container).fetch(FetchDescriptor<Event>())
            XCTAssertEqual(persisted.first { $0.id == event.id }?.title, "Original")
            XCTAssertEqual(persisted.first { $0.id == event.id }?.isArchived, true)
            XCTAssertEqual(persisted.first { $0.id == overdue.id }?.isArchived, false)
            XCTAssertEqual(persisted.first { $0.id == unrelated.id }?.notes, "Pending unrelated change")

            shouldFail = false
            try model.saveEdit(edit, for: event)
            XCTAssertEqual(model.events.map(\.id), [overdue.id])
            return event.id
        }

        try withLocalStore(configuration) { context in
            let events = try context.fetch(FetchDescriptor<Event>())
            XCTAssertEqual(events.count, 3)
            let edited = try XCTUnwrap(events.first { $0.id == editedID })
            XCTAssertEqual(edited.date, tomorrow)
            XCTAssertEqual(edited.title, "Rescheduled")
            XCTAssertFalse(edited.isArchived)
            XCTAssertEqual(events.first { $0.title == "Due today" }?.isArchived, true)
        }
    }

    func testFailedPostSaveListReadKeepsSnapshotUntilHomeRefresh() async throws {
        let calendar = testCalendar
        let now = testNow
        let today = calendar.startOfDay(for: now)
        let container = try store(count: 0)
        let context = ModelContext(container)
        let event = Event(title: "Original", emoji: "🌙", date: today.addingTimeInterval(-1))
        event.isArchived = true
        let newer = Event(title: "Newer Past", emoji: "🌙", date: today.addingTimeInterval(-2))
        newer.isArchived = true
        let older = Event(title: "Older Past", emoji: "🌙", date: today.addingTimeInterval(-3))
        older.isArchived = true
        for row in [event, newer, older] { context.insert(row) }
        try context.save()

        var shouldFailRead = false
        let model = EventListViewModel(
            modelContext: context,
            now: { now },
            calendar: { calendar },
            fetchList: { context, descriptor in
                if shouldFailRead {
                    shouldFailRead = false
                    throw InjectedStoreError.failure
                }
                return try context.fetch(descriptor)
            }
        )
        model.setFilter(.past)
        XCTAssertEqual(model.events.map(\.id), [event.id, newer.id, older.id])
        shouldFailRead = true
        try model.saveEdit(rescheduledEdit(to: today), for: event)

        let persisted = try ModelContext(container).fetch(FetchDescriptor<Event>())
        let saved = try XCTUnwrap(persisted.first { $0.id == event.id })
        XCTAssertEqual(saved.date, today)
        XCTAssertFalse(saved.isArchived)
        XCTAssertEqual(model.events.map(\.id), [event.id, newer.id, older.id])
        XCTAssertFalse(context.hasChanges)

        model.archivePastEvents()

        XCTAssertEqual(model.filter, .past)
        XCTAssertEqual(model.events.map(\.id), [newer.id, older.id])
        XCTAssertFalse(context.hasChanges)
    }

    private enum InjectedStoreError: Error {
        case failure
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -5 * 3600)!
        return calendar
    }

    private var testNow: Date {
        Date(timeIntervalSince1970: 1_776_094_400)
    }

    private func rescheduledEdit(to date: Date) -> EventEdit {
        EventEdit(title: "Rescheduled", emoji: "🎉", date: date, location: nil, notes: "New notes")
    }

    private func assertArchivedEdit(daysFromToday: Int) throws {
        let calendar = testCalendar
        let now = testNow
        let today = calendar.startOfDay(for: now)
        let target = try XCTUnwrap(calendar.date(byAdding: .day, value: daysFromToday, to: today))
        let configuration = try makeStoreConfiguration()
        let editedID = try withLocalStore(configuration) { context in
            let event = Event(title: "Original", emoji: "🌙", date: today.addingTimeInterval(-1), location: "Old location")
            event.isArchived = true
            let older = Event(title: "Older Past", emoji: "🌙", date: today.addingTimeInterval(-3600))
            older.isArchived = true
            let newestPast = Event(title: "Newer Past", emoji: "🌙", date: today.addingTimeInterval(-0.5))
            newestPast.isArchived = true
            let early = Event(title: "Today", emoji: "☀️", date: today.addingTimeInterval(60))
            let late = Event(title: "Later Future", emoji: "🌻", date: target.addingTimeInterval(3600))
            for row in [event, older, newestPast, early, late] { context.insert(row) }
            try context.save()
            let model = EventListViewModel(modelContext: context, now: { now }, calendar: { calendar })
            model.setFilter(.past)

            try model.saveEdit(rescheduledEdit(to: target), for: event)

            XCTAssertEqual(model.filter, .past)
            XCTAssertEqual(model.events.map(\.id), [newestPast.id, older.id])
            model.setFilter(.future)
            let expectedOrder = daysFromToday == 0 ? [event.id, early.id, late.id] : [early.id, event.id, late.id]
            XCTAssertEqual(model.events.map(\.id), expectedOrder)
            return event.id
        }

        try withLocalStore(configuration) { context in
            let events = try context.fetch(FetchDescriptor<Event>())
            let edited = try XCTUnwrap(events.first { $0.id == editedID })
            XCTAssertEqual(edited.title, "Rescheduled")
            XCTAssertEqual(edited.emoji, "🎉")
            XCTAssertEqual(edited.date, target)
            XCTAssertNil(edited.location)
            XCTAssertEqual(edited.notes, "New notes")
            XCTAssertFalse(edited.isArchived)
        }
    }

    private func withLocalStore<Result>(
        _ configuration: ModelConfiguration,
        _ work: (ModelContext) throws -> Result
    ) throws -> Result {
        let container = try ModelContainer(for: Event.self, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try work(context)
    }

    private func renderedImage(in window: UIWindow) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
    }

    private func visibleText(in window: UIWindow) throws -> Set<String> {
        try visibleText(in: renderedImage(in: window))
    }

    private func visibleText(in image: UIImage) throws -> Set<String> {
        Set(try recognizedLines(in: image))
    }

    private func recognizedLines(in image: UIImage) throws -> [String] {
        // Read rendered content rather than relying on SwiftUI's private hosting hierarchy.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage))
        try handler.perform([request])
        return (request.results ?? [])
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScrollView(in: $0) }.first
    }
}
#endif
