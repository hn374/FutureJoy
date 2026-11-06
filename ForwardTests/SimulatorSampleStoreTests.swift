#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
@testable import Forward

@MainActor
final class SimulatorSampleStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func referenceDate(_ year: Int = 2026, _ month: Int = 11, _ day: Int = 5) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func withStore<T>(
        at directory: URL,
        reset: Bool = false,
        date: Date? = nil,
        body: (ModelContext) throws -> T
    ) throws -> T {
        try autoreleasepool {
            let container = try SimulatorSampleStore.open(
                directory: directory, reset: reset,
                referenceDate: date ?? referenceDate(), calendar: calendar
            )
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return try body(context)
        }
    }

    private func events(_ context: ModelContext) throws -> [Event] {
        try context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date)]))
    }

    func testFirstLaunchPersistsRepresentativeFixtures() async throws {
        let directory = try temporaryDirectory()
        try withStore(at: directory) { context in
            let events = try events(context)
            XCTAssertEqual(events.count, 6)
            XCTAssertEqual(Set(events.map(\.id)).count, 6)
            XCTAssertEqual(events.filter(\.isArchived).count, 2)
            XCTAssertEqual(events.filter { !$0.isArchived }.count, 4)
            XCTAssertEqual(events.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: referenceDate()), to: $0.date).day! }, [-14, -1, 0, 1, 7, 30])
            XCTAssertEqual(events.first { $0.title == "Weekend baking workshop" }?.emoji, "🧑🏽‍🍳")
            XCTAssertTrue(events.contains { ($0.notes?.count ?? 0) >= 400 && $0.title.count > 60 })
            XCTAssertTrue(events.contains { $0.location == nil && $0.category == nil && $0.notes == nil })
        }
        try withStore(at: directory) { context in
            XCTAssertEqual(try events(context).count, 6)
            XCTAssertEqual(try events(context).first { $0.title == "Weekend baking workshop" }?.emoji, "🧑🏽‍🍳")
            XCTAssertEqual(try events(context).first { $0.title == "Coffee and a good book" }?.id,
                           UUID(uuidString: "16000000-0000-4000-8000-000000000001"))
            XCTAssertTrue(try events(context).contains { ($0.notes?.count ?? 0) >= 400 })
        }
    }

    func testRelaunchPreservesEditsDeletionsAndOriginalDates() async throws {
        let directory = try temporaryDirectory()
        let originalDates = try withStore(at: directory) { context -> [UUID: Date] in
            let all = try events(context)
            all[0].title = "My edited sample"
            let removedID = all[1].id
            context.delete(all[1])
            try context.save()
            return Dictionary(uniqueKeysWithValues: all.filter { $0.id != removedID }.map { ($0.id, $0.date) })
        }
        try withStore(at: directory, date: referenceDate(2027, 1, 5)) { context in
            let all = try events(context)
            XCTAssertEqual(all.count, 5)
            XCTAssertTrue(all.contains { $0.title == "My edited sample" })
            XCTAssertEqual(Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.date) }), originalDates)
        }
    }

    func testDeletingEveryEventDoesNotReseedOnRelaunch() async throws {
        let directory = try temporaryDirectory()
        try withStore(at: directory) { context in
            for event in try events(context) { context.delete(event) }
            try context.save()
        }
        try withStore(at: directory) { context in
            XCTAssertTrue(try events(context).isEmpty)
        }
    }

    func testResetRestoresFixturesAndRemovesDeveloperEvents() async throws {
        let directory = try temporaryDirectory()
        let originalIDs = try withStore(at: directory) { context -> Set<UUID> in
            let all = try events(context)
            let ids = Set(all.map(\.id))
            all[0].title = "Changed"
            context.delete(all[1])
            context.insert(Event(title: "Developer event", emoji: "🦦", date: referenceDate()))
            try context.save()
            return ids
        }
        let newDate = referenceDate(2027, 1, 5)
        try withStore(at: directory, reset: true, date: newDate) { context in
            let all = try events(context)
            XCTAssertEqual(Set(all.map(\.id)), originalIDs)
            XCTAssertEqual(all.count, 6)
            XCTAssertFalse(all.contains { $0.title == "Changed" || $0.title == "Developer event" })
            XCTAssertEqual(all.first { $0.title == "Coffee and a good book" }?.date, calendar.startOfDay(for: newDate))
            XCTAssertTrue(all.allSatisfy { $0.createdAt == newDate })
        }
        try withStore(at: directory, date: referenceDate(2028, 1, 1)) { context in
            XCTAssertEqual(try events(context).first { $0.title == "Coffee and a good book" }?.date, calendar.startOfDay(for: newDate))
        }
    }

    func testCalendarDaysAcrossDSTLeapDayAndYearBoundary() async throws {
        for (year, month, day) in [(2026, 3, 8), (2026, 11, 1), (2028, 2, 29), (2026, 12, 31)] {
            let directory = try temporaryDirectory()
            let date = referenceDate(year, month, day)
            try withStore(at: directory, date: date) { context in
                let all = try events(context)
                let offsets = all.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: $0.date).day! }
                XCTAssertEqual(offsets, [-14, -1, 0, 1, 7, 30])
                XCTAssertTrue(all.allSatisfy { calendar.startOfDay(for: $0.date) == $0.date })
            }
        }
    }

    func testSeedAndResetLeaveNormalStoreAndMigrationPreferenceUnchanged() async throws {
        let directory = try temporaryDirectory()
        let normalURL = directory.appending(path: "Normal.store")
        let schema = Schema([Event.self])
        let normalContainer = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, url: normalURL, cloudKitDatabase: .none)
        ])
        let normal = ModelContext(normalContainer)
        let sentinel = Event(title: "Normal sentinel", emoji: "🔒", date: referenceDate())
        normal.insert(sentinel)
        try normal.save()
        let originalID = sentinel.id
        let key = "CloudKitMigrationCompleted"
        let before = UserDefaults.standard.object(forKey: key) as? Bool
        let sampleDirectory = directory.appending(path: "Samples")
        try withStore(at: sampleDirectory) { _ in }
        try withStore(at: sampleDirectory, reset: true, date: referenceDate(2027, 1, 1)) { _ in }
        let reopened = try ModelContainer(for: schema, configurations: [
            ModelConfiguration(schema: schema, url: normalURL, cloudKitDatabase: .none)
        ])
        let all = try events(ModelContext(reopened))
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, originalID)
        XCTAssertEqual(all.first?.title, "Normal sentinel")
        XCTAssertEqual(all.first?.date, referenceDate())
        XCTAssertEqual(UserDefaults.standard.object(forKey: key) as? Bool, before)
    }

    func testInvalidSampleDirectoryThrowsWithoutChangingSiblingData() async throws {
        let directory = try temporaryDirectory()
        let obstruction = directory.appending(path: "obstruction")
        let sibling = directory.appending(path: "sentinel")
        try Data("keep".utf8).write(to: sibling)
        try Data("blocked".utf8).write(to: obstruction)
        XCTAssertThrowsError(try SimulatorSampleStore.open(
            directory: obstruction.appending(path: "Samples"), reset: true,
            referenceDate: referenceDate(), calendar: calendar
        ))
        XCTAssertEqual(try String(contentsOf: sibling, encoding: .utf8), "keep")
    }
}
#endif
