//
//  EventListViewModel.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Toast Presentation Models
enum ToastStyle {
    case success
    case error
    
    var background: Color {
        switch self {
        case .success:
            return Color(red: 0.45, green: 0.40, blue: 0.95) // matches app purple gradient
        case .error:
            return Color(red: 0.82, green: 0.23, blue: 0.25)
        }
    }
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct ToastData: Identifiable {
    let id = UUID()
    let message: String
    let style: ToastStyle
}

// MARK: - List Filter
enum EventListFilter: String, CaseIterable {
    case future
    case past
    
    var title: String {
        switch self {
        case .future: return "Future"
        case .past: return "Past"
        }
    }
    
    var isArchived: Bool {
        switch self {
        case .future: return false
        case .past: return true
        }
    }
    
    var sortOrder: SortOrder {
        switch self {
        case .future: return .forward
        case .past: return .reverse
        }
    }
}

@MainActor
final class EventListViewModel: ObservableObject {
    
    private var modelContext: ModelContext
    
    @Published var events: [Event] = []
    @Published var filter: EventListFilter = .future
    @Published var showingCreateEvent = false
    @Published var eventToDelete: Event?
    @Published var showingDeleteConfirmation = false
    @Published var isSelectionMode = false
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var toast: ToastData?
    
    private var isBulkDeletePending = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        archivePastEvents()
        fetchEvents()
    }
    
    /// Updates the active filter and refreshes the list
    func setFilter(_ newFilter: EventListFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        fetchEvents()
    }
    
    /// Fetches events for the current filter
    func fetchEvents(filter overrideFilter: EventListFilter? = nil) {
        let activeFilter = overrideFilter ?? filter
        let isArchivedValue = activeFilter.isArchived
        let sort: SortDescriptor<Event> = SortDescriptor(\.date, order: activeFilter.sortOrder)
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == isArchivedValue
            },
            sortBy: [sort]
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
        let notArchived = false
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == notArchived
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
    @discardableResult
    func addEvent(
        title: String,
        emoji: String,
        date: Date,
        location: String? = nil,
        category: String? = nil,
        notes: String? = nil
    ) throws -> Event {
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
            return event
        } catch {
            print("Failed to save event: \(error)")
            throw error
        }
    }
    
    /// Prepares to delete an event (shows confirmation)
    func confirmDelete(_ event: Event) {
        guard isSelectionMode == false else { return }
        eventToDelete = event
        showingDeleteConfirmation = true
    }
    
    /// Starts multi-select mode
    func enterSelectionMode() {
        isSelectionMode = true
        selectedEventIDs.removeAll()
        eventToDelete = nil
        showingDeleteConfirmation = false
        isBulkDeletePending = false
    }
    
    /// Exits multi-select mode and clears selection
    func exitSelectionMode() {
        isSelectionMode = false
        selectedEventIDs.removeAll()
        isBulkDeletePending = false
    }
    
    /// Toggles selection state for an event
    func toggleSelection(for event: Event) {
        if selectedEventIDs.contains(event.id) {
            selectedEventIDs.remove(event.id)
        } else {
            selectedEventIDs.insert(event.id)
        }
    }
    
    /// Returns whether an event is currently selected
    func isSelected(_ event: Event) -> Bool {
        selectedEventIDs.contains(event.id)
    }
    
    /// Requests confirmation to delete selected events
    func confirmDeleteSelected() {
        guard isSelectionMode else { return }
        guard selectedEventIDs.isEmpty == false else {
            presentToast(message: "Select events to delete", style: .error)
            return
        }
        
        isBulkDeletePending = true
        showingDeleteConfirmation = true
    }
    
    /// Deletes the selected event after confirmation
    func deleteConfirmedEvent() {
        if isBulkDeletePending {
            deleteSelectedEvents()
            isBulkDeletePending = false
            showingDeleteConfirmation = false
            return
        }
        
        guard let event = eventToDelete else { return }
        
        modelContext.delete(event)
        
        do {
            try modelContext.save()
            fetchEvents()
            presentToast(message: "Event deleted", style: .success)
        } catch {
            print("Failed to delete event: \(error)")
            presentToast(message: "Could not delete event. Please try again.", style: .error)
        }
        
        eventToDelete = nil
        showingDeleteConfirmation = false
    }
    
    /// Deletes all selected events
    private func deleteSelectedEvents() {
        let ids = selectedEventIDs
        guard ids.isEmpty == false else { return }
        
        events
            .filter { ids.contains($0.id) }
            .forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            fetchEvents()
            presentToast(message: "Events deleted", style: .success)
            exitSelectionMode()
        } catch {
            print("Failed to delete selected events: \(error)")
            presentToast(message: "Could not delete selected events. Please try again.", style: .error)
        }
    }
    
    /// Cancels the delete operation
    func cancelDelete() {
        eventToDelete = nil
        showingDeleteConfirmation = false
        isBulkDeletePending = false
    }
    
    /// Presents a toast message with auto dismissal
    func presentToast(message: String, style: ToastStyle, duration: TimeInterval = 2.5) {
        let toastData = ToastData(message: message, style: style)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            toast = toastData
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            if self.toast?.id == toastData.id {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.toast = nil
                }
            }
        }
    }
}

