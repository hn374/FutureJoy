#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
import UIKit
@testable import Forward

@MainActor
class EventListTestCase: XCTestCase {
    func store(count: Int = 10_000) throws -> ModelContainer {
        let container = try ModelContainer(for: Event.self, configurations: makeStoreConfiguration())
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

    func makeStoreConfiguration() throws -> ModelConfiguration {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return ModelConfiguration(
            schema: Schema([Event.self]),
            url: directory.appending(path: "Events.store"),
            cloudKitDatabase: .none
        )
    }

    func makeWindow() -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        return window
    }

}
#endif
