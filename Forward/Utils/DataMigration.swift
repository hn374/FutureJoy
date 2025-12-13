//
//  DataMigration.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import Foundation
import SwiftData

/// Utility for migrating data from local SwiftData store to CloudKit
enum DataMigration {
    private static let migrationCompletedKey = "CloudKitMigrationCompleted"
    
    /// Checks if migration from local store to CloudKit is needed
    static func needsMigration() -> Bool {
        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationCompletedKey) {
            return false
        }
        
        // Check if old local store exists
        let localStoreURL = URL.documentsDirectory.appending(path: "FutureJoy.store")
        return FileManager.default.fileExists(atPath: localStoreURL.path())
    }
    
    /// Migrates events from local store to CloudKit store
    /// - Parameter cloudKitContext: The ModelContext connected to CloudKit
    /// - Returns: Tuple of (success: Bool, count: Int) indicating migration result
    @MainActor
    static func migrateToCloudKit(cloudKitContext: ModelContext) async -> (success: Bool, count: Int) {
        guard needsMigration() else {
            return (false, 0)
        }
        
        let localStoreURL = URL.documentsDirectory.appending(path: "FutureJoy.store")
        let schema = Schema([Event.self])
        
        let localConfig = ModelConfiguration(
            schema: schema,
            url: localStoreURL,
            cloudKitDatabase: .none
        )
        
        do {
            // Open the old local store
            let localContainer = try ModelContainer(for: schema, configurations: [localConfig])
            let localContext = ModelContext(localContainer)
            
            // Fetch all events from local store
            let descriptor = FetchDescriptor<Event>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            let localEvents = try localContext.fetch(descriptor)
            
            guard !localEvents.isEmpty else {
                // No data to migrate, mark as completed
                markMigrationCompleted()
                return (true, 0)
            }
            
            // Insert events into CloudKit store
            var migratedCount = 0
            for event in localEvents {
                // Create a new event with the same data
                let newEvent = Event(
                    title: event.title,
                    emoji: event.emoji,
                    date: event.date,
                    location: event.location,
                    category: event.category,
                    notes: event.notes
                )
                // Preserve the original ID
                newEvent.id = event.id
                // Preserve archived status and creation date
                newEvent.isArchived = event.isArchived
                newEvent.createdAt = event.createdAt
                
                cloudKitContext.insert(newEvent)
                migratedCount += 1
            }
            
            // Save to CloudKit
            try cloudKitContext.save()
            
            // Mark migration as completed
            markMigrationCompleted()
            
            print("✅ Successfully migrated \(migratedCount) event(s) to CloudKit")
            return (true, migratedCount)
            
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
            return (false, 0)
        }
    }
    
    /// Marks the migration as completed so it won't run again
    private static func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
    }
    
    /// Resets the migration flag (for testing purposes)
    static func resetMigrationFlag() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
    }
}

