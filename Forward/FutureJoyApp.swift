//
//  FutureJoyApp.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct FutureJoyApp: App {
    init() {
        // Initialize Google Mobile Ads SDK
        // TODO: Replace with your actual AdMob App ID from your AdMob dashboard
        // Format: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX
        MobileAds.shared.start(completionHandler: { status in
            print("AdMob SDK initialized with status: \(status.adapterStatusesByClassName)")
        })
    }
    var sharedModelContainer: ModelContainer = {
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
            HomeView(modelContext: sharedModelContainer.mainContext)
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}

