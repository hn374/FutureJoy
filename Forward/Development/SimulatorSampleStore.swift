#if DEBUG && targetEnvironment(simulator)
import Foundation
import SwiftData

@Model
private final class SampleSeedState {
    var version: Int = 1

    init() {}
}

@MainActor
enum SimulatorSampleStore {
    static func open(
        directory: URL,
        reset: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([Event.self, SampleSeedState.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appending(path: "Fixtures-v1.store"),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        if !reset, try context.fetchCount(FetchDescriptor<SampleSeedState>()) > 0 {
            return container
        }

        // Prepare dates before changing the store, then persist fixtures and marker together.
        let fixtures = try makeFixtures(referenceDate: referenceDate, calendar: calendar)
        do {
            if reset {
                for event in try context.fetch(FetchDescriptor<Event>()) {
                    context.delete(event)
                }
                for state in try context.fetch(FetchDescriptor<SampleSeedState>()) {
                    context.delete(state)
                }
            }
            for event in fixtures { context.insert(event) }
            context.insert(SampleSeedState())
            try context.save()
            return container
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func makeFixtures(referenceDate: Date, calendar: Calendar) throws -> [Event] {
        let today = calendar.startOfDay(for: referenceDate)
        let descriptions: [(title: String, emoji: String, days: Int, location: String?, category: String?, notes: String?)] = [
            ("Coffee and a good book", "☕️", 0, nil, nil, nil),
            ("Stargazing picnic", "🌌", 1, "Moonflower Meadow", "Outdoors", "Pack a blanket, warm drinks, and a star chart for a quiet evening under the sky."),
            ("Weekend baking workshop", "🧑🏽‍🍳", 7, nil, "Learning", "Try a new bread recipe and bring a few treats home to share."),
            (
                "A wonderfully long weekend adventure with friends, food, music, and a few unexpected detours",
                "🎒🌲", 30, "Fernwood Valley", "Adventure",
                """
                Start the morning with a gentle walk through the woods, stopping whenever someone spots an interesting bird, a colorful leaf, or the perfect place for a photograph. Bring comfortable shoes, a rain jacket, and a notebook for the little details we want to remember.

                In the afternoon, share a picnic near the old footbridge and trade stories about places we would love to visit. Leave plenty of time for an unplanned detour, a small outdoor concert, and a slow journey home with friends.
                """
            ),
            ("Board game night", "🎲", -1, nil, "Friends", "A cozy evening of cooperative games and homemade snacks."),
            ("Lakeside sketching afternoon", "🎨", -14, "Willowglass Lake", nil, nil)
        ]

        return try descriptions.enumerated().map { index, fixture in
            guard let date = calendar.date(byAdding: .day, value: fixture.days, to: today) else {
                throw FixtureError.invalidDate
            }
            let event = Event(
                title: fixture.title, emoji: fixture.emoji, date: date,
                location: fixture.location, category: fixture.category, notes: fixture.notes
            )
            event.id = UUID(uuidString: String(format: "16000000-0000-4000-8000-%012d", index + 1))!
            event.createdAt = referenceDate
            event.isArchived = fixture.days < 0
            return event
        }
    }

    private enum FixtureError: Error {
        case invalidDate
    }
}
#endif
