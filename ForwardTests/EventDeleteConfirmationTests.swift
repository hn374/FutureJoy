#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftData
@testable import Forward

@MainActor
final class EventDeleteConfirmationTests: EventListTestCase {
    private func fixture() throws -> (ModelContainer, ModelContext, EventListViewModel, [Event]) {
        let container = try store(count: 3)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let model = EventListViewModel(modelContext: context)
        return (container, context, model, model.events)
    }

    private func persistedIDs(_ container: ModelContainer) throws -> Set<UUID> {
        Set(try ModelContext(container).fetch(FetchDescriptor<Event>()).map(\.id))
    }

    func testSingleFreezesIDAndTitle() async throws {
        let (container, context, model, events) = try fixture()
        let a = events[0]
        let originalTitle = a.title
        let remaining = Set(events.dropFirst().map(\.id))
        model.confirmDelete(a)
        let target = try XCTUnwrap(model.pendingDeletion)
        a.title = "Renamed while awaiting confirmation"
        try context.save()
        XCTAssertEqual(target, .single(id: a.id, title: originalTitle))
        XCTAssertEqual(target.message, "Are you sure you want to delete \"\(originalTitle)\"? This action cannot be undone.")
        model.deleteConfirmedEvent(target)
        XCTAssertEqual(try persistedIDs(container), remaining)
        XCTAssertNil(model.pendingDeletion)
        XCTAssertEqual(model.toast?.message, "Event deleted")
    }

    func testBulkFreezesIDsDespiteSelectionChanges() async throws {
        let (container, _, model, events) = try fixture()
        let a = events[0], b = events[1], c = events[2]
        let remaining = Set([c.id])
        model.enterSelectionMode()
        model.toggleSelection(for: a)
        model.toggleSelection(for: b)
        model.confirmDeleteSelected()
        let target = try XCTUnwrap(model.pendingDeletion)
        XCTAssertEqual(target.ids, Set([a.id, b.id]))
        XCTAssertEqual(target.message, "Delete 2 selected event(s)? This action cannot be undone.")
        model.toggleSelection(for: a)
        model.toggleSelection(for: c)
        model.fetchEvents()
        XCTAssertEqual(model.pendingDeletion, target)
        model.deleteConfirmedEvent(target)
        XCTAssertEqual(try persistedIDs(container), remaining)
        XCTAssertNil(model.pendingDeletion)
        XCTAssertFalse(model.isSelectionMode)
        XCTAssertTrue(model.selectedEventIDs.isEmpty)
        XCTAssertEqual(model.toast?.message, "Events deleted")
    }

    func testOneSelectedEventKeepsBulkCopy() async throws {
        let (_, _, model, events) = try fixture()
        model.enterSelectionMode()
        model.toggleSelection(for: events[0])
        model.confirmDeleteSelected()
        let target = try XCTUnwrap(model.pendingDeletion)
        XCTAssertEqual(target, .bulk(ids: [events[0].id]))
        XCTAssertEqual(target.message, "Delete 1 selected event(s)? This action cannot be undone.")
    }

    func testCancelPreservesRecordsAndSelection() async throws {
        let (container, _, model, events) = try fixture()
        let ids = Set(events.map(\.id))
        model.confirmDelete(events[0])
        model.cancelDelete()
        XCTAssertNil(model.pendingDeletion)
        XCTAssertEqual(try persistedIDs(container), ids)
        model.enterSelectionMode()
        model.toggleSelection(for: events[0])
        model.confirmDeleteSelected()
        model.cancelDelete()
        XCTAssertNil(model.pendingDeletion)
        XCTAssertTrue(model.isSelectionMode)
        XCTAssertEqual(model.selectedEventIDs, [events[0].id])
        XCTAssertEqual(try persistedIDs(container), ids)
        model.toggleSelection(for: events[1])
        model.confirmDeleteSelected()
        XCTAssertEqual(model.pendingDeletion?.ids, Set([events[0].id, events[1].id]))
    }

    func testMovedAndMissingTargetsDoNotRetargetDeletion() async throws {
        let (container, context, model, events) = try fixture()
        let a = events[0], b = events[1], c = events[2]
        let remaining = Set([c.id])
        model.enterSelectionMode()
        model.toggleSelection(for: a)
        model.toggleSelection(for: b)
        model.confirmDeleteSelected()
        let target = try XCTUnwrap(model.pendingDeletion)
        a.isArchived = true
        context.delete(b)
        try context.save()
        model.fetchEvents()
        XCTAssertEqual(Set(model.events.map(\.id)), remaining)
        model.deleteConfirmedEvent(target)
        XCTAssertEqual(try persistedIDs(container), remaining)
        model.confirmDelete(c)
        let missing = try XCTUnwrap(model.pendingDeletion)
        context.delete(c)
        try context.save()
        model.toast = nil
        model.deleteConfirmedEvent(missing)
        XCTAssertTrue(try persistedIDs(container).isEmpty)
        XCTAssertNil(model.pendingDeletion)
        XCTAssertNil(model.toast)
    }

    func testEmptyAndStaleSelectionCannotOpenConfirmation() async throws {
        let (container, _, model, events) = try fixture()
        model.enterSelectionMode()
        for selection: Set<UUID> in [[], [UUID()]] {
            model.selectedEventIDs = selection
            model.confirmDeleteSelected()
            XCTAssertNil(model.pendingDeletion)
            XCTAssertEqual(model.toast?.message, "Select events to delete")
            XCTAssertEqual(try persistedIDs(container), Set(events.map(\.id)))
        }
        model.selectedEventIDs = [UUID(), events[0].id]
        model.confirmDeleteSelected()
        XCTAssertEqual(model.pendingDeletion?.ids, [events[0].id])
    }

    func testDuplicateRequestsAndRepeatedConfirmationAreHarmless() async throws {
        let (container, _, model, events) = try fixture()
        let remaining = Set(events.dropFirst().map(\.id))
        model.confirmDelete(events[0])
        let target = try XCTUnwrap(model.pendingDeletion)
        model.confirmDelete(events[1])
        XCTAssertEqual(model.pendingDeletion, target)
        model.deleteConfirmedEvent(target)
        model.deleteConfirmedEvent(target)
        XCTAssertEqual(try persistedIDs(container), remaining)
        XCTAssertNil(model.pendingDeletion)
    }

    func testCanceledAndStaleCallbacksCannotExecuteOrClearNewRequest() async throws {
        let (container, _, model, events) = try fixture()
        let original = Set(events.map(\.id))
        let bID = events[1].id
        model.confirmDelete(events[0])
        let a = try XCTUnwrap(model.pendingDeletion)
        model.cancelDelete()
        model.deleteConfirmedEvent(a)
        XCTAssertEqual(try persistedIDs(container), original)
        model.confirmDelete(events[1])
        let b = try XCTUnwrap(model.pendingDeletion)
        model.deleteConfirmedEvent(a)
        XCTAssertEqual(model.pendingDeletion, b)
        XCTAssertEqual(try persistedIDs(container), original)
        model.deleteConfirmedEvent(b)
        XCTAssertEqual(try persistedIDs(container), original.subtracting([bID]))
    }

    func testSelectionTransitionsInvalidatePendingAndTabsStayBlocked() async throws {
        let (container, _, model, events) = try fixture()
        let ids = Set(events.map(\.id))
        model.confirmDelete(events[0])
        let single = try XCTUnwrap(model.pendingDeletion)
        model.setFilter(.past)
        XCTAssertEqual(model.filter, .future)
        model.enterSelectionMode()
        XCTAssertNil(model.pendingDeletion)
        model.deleteConfirmedEvent(single)
        model.confirmDelete(events[0])
        XCTAssertNil(model.pendingDeletion)
        model.toggleSelection(for: events[0])
        model.confirmDeleteSelected()
        let bulk = try XCTUnwrap(model.pendingDeletion)
        model.setFilter(.past)
        XCTAssertEqual(model.filter, .future)
        model.cancelDelete()
        model.setFilter(.past)
        XCTAssertEqual(model.filter, .future)
        XCTAssertEqual(model.selectedEventIDs, [events[0].id])
        model.confirmDeleteSelected()
        model.exitSelectionMode()
        XCTAssertNil(model.pendingDeletion)
        model.deleteConfirmedEvent(bulk)
        model.setFilter(.past)
        XCTAssertEqual(model.filter, .past)
        XCTAssertEqual(try persistedIDs(container), ids)
    }
}
#endif
