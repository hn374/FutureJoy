#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
@testable import Forward

@MainActor
final class EventDraftLifecycleTests: EventListTestCase {
    func testPreparedLegacyEditMovesListsAndPersists() async throws {
        let configuration = try makeStoreConfiguration()
        let now = testNow
        let calendar = testCalendar
        let today = calendar.startOfDay(for: now)
        let createdAt = now.addingTimeInterval(-1000)
        let editedID = try withStore(configuration) { context in
            let event = Event(title: "Original", emoji: " 🎒🌲 ", date: today.addingTimeInterval(-1), category: "Keep category")
            event.isArchived = true
            event.createdAt = createdAt
            let past = Event(title: "Other Past", emoji: "🌙", date: today.addingTimeInterval(-2))
            past.isArchived = true
            let future = Event(title: "Later Today", emoji: "☀️", date: today.addingTimeInterval(3600))
            for row in [event, past, future] { context.insert(row) }
            try context.save()
            let model = EventListViewModel(modelContext: context, now: { now }, calendar: { calendar })
            model.setFilter(.past)

            let fields = try EventDraft(
                title: " \n Prepared title \t",
                emoji: "Unrelated snapshot",
                date: today,
                location: " \n ",
                notes: "  first\n\nsecond  "
            ).prepare(for: .editing(originalEmoji: event.emoji, emojiWasEdited: false), now: now, calendar: calendar)
            try model.saveEdit(edit(from: fields), for: event)

            XCTAssertEqual(model.filter, .past)
            XCTAssertEqual(model.events.map(\.id), [past.id])
            model.setFilter(.future)
            XCTAssertEqual(model.events.map(\.id), [event.id, future.id])
            return event.id
        }

        try withStore(configuration) { context in
            let saved = try XCTUnwrap(context.fetch(FetchDescriptor<Event>()).first { $0.id == editedID })
            XCTAssertEqual(saved.title, "Prepared title")
            XCTAssertEqual(saved.emoji, " 🎒🌲 ")
            XCTAssertEqual(saved.date, today)
            XCTAssertNil(saved.location)
            XCTAssertEqual(saved.notes, "first\n\nsecond")
            XCTAssertFalse(saved.isArchived)
            XCTAssertEqual(saved.category, "Keep category")
            XCTAssertEqual(saved.createdAt, createdAt)
        }
    }

    func testLifecycleRejectsPreparedEditAfterCalendarDayChanges() async throws {
        var now = testNow
        let calendar = testCalendar
        let today = calendar.startOfDay(for: now)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        let container = try store(count: 0)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let event = Event(title: "Original", emoji: "🌙", date: tomorrow)
        context.insert(event)
        try context.save()
        let model = EventListViewModel(modelContext: context, now: { now }, calendar: { calendar })
        let fields = try EventDraft(title: "Prepared", emoji: "🦦🌙", date: today, location: "", notes: "")
            .prepare(for: .editing(originalEmoji: event.emoji, emojiWasEdited: true), now: now, calendar: calendar)

        now = tomorrow
        XCTAssertThrowsError(try model.saveEdit(edit(from: fields), for: event)) { error in
            XCTAssertEqual(error as? EventEditError, .dateInPast)
        }
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(event.title, "Original")
        XCTAssertEqual(event.emoji, "🌙")
        XCTAssertEqual(event.date, tomorrow)
        XCTAssertEqual(model.events.map(\.id), [event.id])
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Event>()).first)
        XCTAssertEqual(saved.title, "Original")
        XCTAssertEqual(saved.date, tomorrow)
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var testNow: Date {
        testCalendar.date(from: DateComponents(year: 2030, month: 3, day: 10, hour: 12))!
    }

    private func edit(from fields: PreparedEventFields) -> EventEdit {
        EventEdit(title: fields.title, emoji: fields.emoji, date: fields.date, location: fields.location, notes: fields.notes)
    }

    private func withStore<Result>(_ configuration: ModelConfiguration, _ work: (ModelContext) throws -> Result) throws -> Result {
        let container = try ModelContainer(for: Event.self, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try work(context)
    }
}
#endif
