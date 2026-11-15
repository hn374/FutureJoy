//
//  EventListViewModel.swift
//  Forward
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

// Immutable wording and IDs for the operation the user is being asked to confirm.
enum PendingEventDeletion: Equatable {
    case single(id: UUID, title: String)
    case bulk(ids: Set<UUID>)

    var ids: Set<UUID> {
        switch self {
        case .single(let id, _): return [id]
        case .bulk(let ids): return ids
        }
    }

    var isBulk: Bool {
        if case .bulk = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .single(_, let title):
            return "Are you sure you want to delete \"\(title)\"? This action cannot be undone."
        case .bulk(let ids):
            return "Delete \(ids.count) selected event(s)? This action cannot be undone."
        }
    }
}

@MainActor
final class EventListViewModel: ObservableObject {
    
    private var modelContext: ModelContext
    
    @Published var events: [Event] = []
    @Published var filter: EventListFilter = .future
    @Published var showingCreateEvent = false
    @Published private(set) var pendingDeletion: PendingEventDeletion?
    @Published var isSelectionMode = false
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var toast: ToastData?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        archivePastEvents()
    }
    
    /// Updates the active filter and refreshes the list
    func setFilter(_ newFilter: EventListFilter) {
        guard !isSelectionMode, pendingDeletion == nil, newFilter != filter else { return }
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
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == notArchived && event.date < today
            }
        )
        
        do {
            let pastEvents = try modelContext.fetch(descriptor)
            for event in pastEvents {
                event.isArchived = true
            }
            if !pastEvents.isEmpty {
                try modelContext.save()
            }
        } catch {
            print("Failed to archive past events: \(error)")
        }
        fetchEvents()
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
        guard !isSelectionMode, pendingDeletion == nil else { return }
        pendingDeletion = .single(id: event.id, title: event.title)
    }
    
    /// Starts multi-select mode
    func enterSelectionMode() {
        isSelectionMode = true
        selectedEventIDs.removeAll()
        pendingDeletion = nil
    }
    
    /// Exits multi-select mode and clears selection
    func exitSelectionMode() {
        isSelectionMode = false
        selectedEventIDs.removeAll()
        pendingDeletion = nil
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
    
    /// Freezes the selected records when confirmation opens.
    func confirmDeleteSelected() {
        guard isSelectionMode, pendingDeletion == nil else { return }
        let ids = selectedEventIDs.intersection(events.map(\.id))
        guard !ids.isEmpty else {
            presentToast(message: "Select events to delete", style: .error)
            return
        }
        pendingDeletion = .bulk(ids: ids)
    }

    /// The captured alert value is a guard; only the current pending operation can execute.
    func deleteConfirmedEvent(_ expected: PendingEventDeletion) {
        guard let target = pendingDeletion, target == expected else { return }
        pendingDeletion = nil

        do {
            // Resolve from persistence: a target may have left the visible list meanwhile.
            let matches = try modelContext.fetch(FetchDescriptor<Event>())
                .filter { target.ids.contains($0.id) }
            if !matches.isEmpty {
                matches.forEach { modelContext.delete($0) }
                try modelContext.save()
                presentToast(message: target.isBulk ? "Events deleted" : "Event deleted", style: .success)
            }
            fetchEvents()
            if target.isBulk { exitSelectionMode() }
        } catch {
            print("Failed to delete confirmed events: \(error)")
            presentToast(
                message: target.isBulk
                    ? "Could not delete selected events. Please try again."
                    : "Could not delete event. Please try again.",
                style: .error
            )
        }
    }

    /// Cancels confirmation while leaving the selection intact.
    func cancelDelete() {
        pendingDeletion = nil
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

