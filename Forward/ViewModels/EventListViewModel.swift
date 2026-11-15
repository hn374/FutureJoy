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

struct EventEdit {
    let title: String
    let emoji: String
    let date: Date
    let location: String?
    let notes: String?
}

enum EventEditError: Error {
    case dateInPast
}

@MainActor
final class EventListViewModel: ObservableObject {
    
    private let modelContext: ModelContext
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let save: (ModelContext) throws -> Void
    private let fetchList: (ModelContext, FetchDescriptor<Event>) throws -> [Event]
    
    @Published var events: [Event] = []
    @Published var filter: EventListFilter = .future
    @Published var showingCreateEvent = false
    @Published var eventToDelete: Event?
    @Published var showingDeleteConfirmation = false
    @Published var isSelectionMode = false
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var toast: ToastData?
    
    private var isBulkDeletePending = false
    
    init(
        modelContext: ModelContext,
        now: @escaping () -> Date = { Date() },
        calendar: @escaping () -> Calendar = { .current },
        save: @escaping (ModelContext) throws -> Void = { try $0.save() },
        fetchList: @escaping (ModelContext, FetchDescriptor<Event>) throws -> [Event] = { try $0.fetch($1) }
    ) {
        self.modelContext = modelContext
        self.now = now
        self.calendar = calendar
        self.save = save
        self.fetchList = fetchList
        archivePastEvents()
    }
    
    /// Saves the edit and reconciles the active list against the same calendar day.
    func saveEdit(_ edit: EventEdit, for event: Event) throws {
        let today = calendar().startOfDay(for: now())
        guard edit.date >= today else { throw EventEditError.dateInPast }

        let overdue = try overdueEvents(before: today)
            .filter { $0 !== event }
            .map { (event: $0, wasArchived: $0.isArchived) }
        let previousEdit = EventEdit(
            title: event.title,
            emoji: event.emoji,
            date: event.date,
            location: event.location,
            notes: event.notes
        )
        let wasArchived = event.isArchived

        apply(edit, to: event)
        event.isArchived = false
        for row in overdue {
            row.event.isArchived = true
        }

        do {
            try save(modelContext)
        } catch {
            apply(previousEdit, to: event)
            event.isArchived = wasArchived
            for row in overdue {
                row.event.isArchived = row.wasArchived
            }
            throw error
        }

        do {
            events = try loadEvents(for: filter)
        } catch {
            // The edit is already committed. Home can retry the list read on return.
            print("Failed to refresh events after saving: \(error)")
        }
    }

    private func apply(_ edit: EventEdit, to event: Event) {
        event.title = edit.title
        event.emoji = edit.emoji
        event.date = edit.date
        event.location = edit.location
        event.notes = edit.notes
    }

    /// Updates the active filter and refreshes the list
    func setFilter(_ newFilter: EventListFilter) {
        guard !isSelectionMode, newFilter != filter else { return }
        filter = newFilter
        fetchEvents()
    }
    
    /// Fetches events for the current filter
    func fetchEvents(filter overrideFilter: EventListFilter? = nil) {
        do {
            events = try loadEvents(for: overrideFilter ?? filter)
        } catch {
            print("Failed to fetch events: \(error)")
            events = []
        }
    }

    private func loadEvents(for filter: EventListFilter) throws -> [Event] {
        let isArchived = filter.isArchived
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == isArchived
            },
            sortBy: [SortDescriptor(\.date, order: filter.sortOrder)]
        )
        return try fetchList(modelContext, descriptor)
    }

    /// Archives events that have passed
    func archivePastEvents() {
        do {
            let pastEvents = try overdueEvents(before: calendar().startOfDay(for: now()))
            for event in pastEvents {
                event.isArchived = true
            }
            if !pastEvents.isEmpty {
                try save(modelContext)
            }
        } catch {
            print("Failed to archive past events: \(error)")
        }
        fetchEvents()
    }

    private func overdueEvents(before today: Date) throws -> [Event] {
        let notArchived = false
        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> { event in
                event.isArchived == notArchived && event.date < today
            }
        )
        return try modelContext.fetch(descriptor)
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

