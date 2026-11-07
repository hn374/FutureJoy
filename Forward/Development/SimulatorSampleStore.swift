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
        profile: SampleDataProfile = .typical,
        reset: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = Schema([Event.self, SampleSeedState.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: directory.appending(path: profile.storeFilename),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        context.autosaveEnabled = false

        if !reset, try context.fetchCount(FetchDescriptor<SampleSeedState>()) > 0 {
            return container
        }

        try seed(context: context, profile: profile, referenceDate: referenceDate, calendar: calendar, replacing: reset)
        return container
    }

    static func reset(container: ModelContainer, profile: SampleDataProfile, referenceDate: Date, calendar: Calendar) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try seed(context: context, profile: profile, referenceDate: referenceDate, calendar: calendar, replacing: true)
    }

    private static func seed(context: ModelContext, profile: SampleDataProfile, referenceDate: Date, calendar: Calendar, replacing: Bool) throws {
        let fixtures = try makeFixtures(profile: profile, referenceDate: referenceDate, calendar: calendar)
        do {
            if replacing {
                for event in try context.fetch(FetchDescriptor<Event>()) { context.delete(event) }
                for state in try context.fetch(FetchDescriptor<SampleSeedState>()) { context.delete(state) }
            }
            for event in fixtures { context.insert(event) }
            context.insert(SampleSeedState())
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func makeFixtures(profile: SampleDataProfile, referenceDate: Date, calendar: Calendar) throws -> [Event] {
        let today = calendar.startOfDay(for: referenceDate)
        var descriptions: [(title: String, emoji: String, days: Int, location: String?, category: String?, notes: String?)] = [
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

        switch profile {
        case .typical: break
        case .empty: descriptions = []
        case .edgeCases:
            descriptions += [
                ("Same-day breakfast", "🥐", 0, nil, "Friends", nil),
                ("Same-day dinner", "🍽️", 0, "Moonflower Meadow", nil, nil)
            ]
        case .busy:
            descriptions = (0..<300).map { index in
                ("Busy event \(index + 1)", ["☕️", "🎨", "🌌"][index % 3], index - 100,
                 index.isMultiple(of: 2) ? "Moonflower Meadow" : nil,
                 ["Friends", "Outdoors", "Learning"][index % 3], nil)
            }
        case .archiveHeavy:
            descriptions = (1...20).map { ("Archived memory \($0)", "📷", -$0, nil, "Memories", nil) }
            descriptions.append(("Next adventure", "🎒", 7, nil, "Adventure", nil))
        }

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
