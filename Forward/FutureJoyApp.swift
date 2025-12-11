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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Event.self,
        ])
        
        // Local store configuration.
        // Note: If you previously ran a different schema (e.g., the starter Item model),
        // the old store can conflict. This uses a dedicated store file to avoid that.
        let storeURL = URL.documentsDirectory.appending(path: "FutureJoy.store")
        let modelConfiguration = ModelConfiguration(
            .init(),
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView(modelContext: sharedModelContainer.mainContext)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}

