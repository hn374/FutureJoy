//
//  FutureJoyApp.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData

@main
struct FutureJoyApp: App {
    private static let normalModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
        ])
        
        // Try CloudKit first, fallback to local storage if not configured
        let containerIdentifier = "iCloud.Hoang.Forward"
        let cloudKitConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private(containerIdentifier)
        )
        
        // Try CloudKit-enabled configuration
        do {
            return try ModelContainer(for: schema, configurations: [cloudKitConfig])
        } catch {
            // Fallback to local storage if CloudKit fails
        }
        
        let localStoreURL = URL.documentsDirectory.appending(path: "FutureJoy.store")
        let localConfig = ModelConfiguration(
            schema: schema,
            url: localStoreURL,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            content
                .preferredColorScheme(.light)
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG && targetEnvironment(simulator)
        switch SampleDataLaunchMode.resolve(arguments: ProcessInfo.processInfo.arguments) {
        case let .enabled(reset, profile):
            SimulatorSampleRootView(profile: profile, reset: reset)
        case let .invalid(message):
            ContentUnavailableView("Invalid testing profile", systemImage: "exclamationmark.triangle", description: Text(message))
        case .disabled:
            normalContent
        }
        #else
        normalContent
        #endif
    }

    private var normalContent: some View {
        HomeView(modelContext: Self.normalModelContainer.mainContext)
            .modelContainer(Self.normalModelContainer)
    }
}

