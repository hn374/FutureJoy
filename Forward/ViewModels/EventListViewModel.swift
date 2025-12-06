//
//  EventListViewModel.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
final class EventListViewModel: ObservableObject {
    
    private var modelContext: ModelContext
    
    @Published var events: [Event] = []
    @Published var showingCreateEvent = false
    @Published var eventToDelete: Event?
    @Published var showingDeleteConfirmation = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchEvents()
        archivePastEvents()
    }
    
    /// Fetches all non-archived events sorted by date ascending
    func fetchEvents() {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == false
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        
        do {
            events = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }
    
    /// Archives events that have passed
    func archivePastEvents() {
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == false
            }
        )
        
        do {
            let allEvents = try modelContext.fetch(descriptor)
            for event in allEvents where event.isPast {
                event.isArchived = true
            }
            try modelContext.save()
            fetchEvents()
        } catch {
            print("Failed to archive past events: \(error)")
        }
    }
    
    /// Creates a new event
    func addEvent(
        title: String,
        emoji: String,
        date: Date,
        location: String? = nil,
        category: String? = nil,
        notes: String? = nil
    ) {
        let event = Event(
            title: title,
            emoji: emoji,
            date: date,
            location: location,
            category: category,
            notes: notes
        )
        modelContext.insert(event)
        
        do {
            try modelContext.save()
            fetchEvents()
        } catch {
            print("Failed to save event: \(error)")
        }
    }
    
    /// Prepares to delete an event (shows confirmation)
    func confirmDelete(_ event: Event) {
        eventToDelete = event
        showingDeleteConfirmation = true
    }
    
    /// Deletes the selected event after confirmation
    func deleteConfirmedEvent() {
        guard let event = eventToDelete else { return }
        
        modelContext.delete(event)
        
        do {
            try modelContext.save()
            fetchEvents()
        } catch {
            print("Failed to delete event: \(error)")
        }
        
        eventToDelete = nil
    }
    
    /// Cancels the delete operation
    func cancelDelete() {
        eventToDelete = nil
        showingDeleteConfirmation = false
    }
}

