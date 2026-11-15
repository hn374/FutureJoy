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
    
    private let modelContext: ModelContext
    private let now: () -> Date
    private let calendar: () -> Calendar
    private let save: (ModelContext) throws -> Void
    private let fetchList: (ModelContext, FetchDescriptor<Event>) throws -> [Event]
    
    @Published var events: [Event] = []
    @Published var filter: EventListFilter = .future
    @Published var showingCreateEvent = false
    @Published private(set) var pendingDeletion: PendingEventDeletion?
    @Published var isSelectionMode = false
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var toast: ToastData?
    
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
        guard !isSelectionMode, pendingDeletion == nil, newFilter != filter else { return }
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
            let pastEvents = try overdueEvents(before: EventCalendarDay.startOfToday(now: now(), calendar: calendar()))
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

