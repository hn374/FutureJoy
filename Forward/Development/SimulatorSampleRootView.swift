#if DEBUG && targetEnvironment(simulator)
import SwiftUI
import Combine
import SwiftData

@MainActor
final class SimulatorSampleSession: ObservableObject {
    struct Snapshot {
        let profile: SampleDataProfile
        let container: ModelContainer
        let context: ModelContext
        let id = UUID()
    }

    @Published private(set) var snapshot: Snapshot
    private let directory: URL

    init(directory: URL, profile: SampleDataProfile, reset: Bool) throws {
        self.directory = directory
        let container = try SimulatorSampleStore.open(
            directory: directory, profile: profile, reset: reset, referenceDate: Date(), calendar: .current
        )
        snapshot = Snapshot(profile: profile, container: container, context: ModelContext(container))
    }

    func select(_ profile: SampleDataProfile) throws {
        guard profile != snapshot.profile else { return }
        try snapshot.context.save()
        let container = try SimulatorSampleStore.open(
            directory: directory, profile: profile, reset: false, referenceDate: Date(), calendar: .current
        )
        snapshot = Snapshot(profile: profile, container: container, context: ModelContext(container))
    }

    func reset() throws {
        try snapshot.context.save()
        try SimulatorSampleStore.reset(
            container: snapshot.container, profile: snapshot.profile, referenceDate: Date(), calendar: .current
        )
        snapshot = Snapshot(profile: snapshot.profile, container: snapshot.container, context: ModelContext(snapshot.container))
    }
}

struct SimulatorSampleRootView: View {
    @StateObject private var session: SimulatorSampleSession
    @State private var showingReset = false
    @State private var errorMessage: String?

    init(profile: SampleDataProfile, reset: Bool) {
        _session = StateObject(wrappedValue: Self.makeSession(profile: profile, reset: reset))
    }

    private static func makeSession(profile: SampleDataProfile, reset: Bool) -> SimulatorSampleSession {
        do {
            return try SimulatorSampleSession(
                directory: URL.applicationSupportDirectory.appending(path: "SimulatorSampleData"),
                profile: profile, reset: reset
            )
        } catch {
            fatalError("Could not prepare simulator sample data: \(error.localizedDescription)")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(SampleDataProfile.allCases) { profile in
                        Button(profile.title) { perform { try session.select(profile) } }
                    }
                } label: {
                    Label("Profile: \(session.snapshot.profile.title)", systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("Testing profiles")
                Spacer()
                Button("Reset profile") { showingReset = true }
            }
            .font(.subheadline)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)

            HomeView(modelContext: session.snapshot.context)
                .environment(\.modelContext, session.snapshot.context)
                .modelContainer(session.snapshot.container)
                .id(session.snapshot.id)
        }
        .alert("Reset \(session.snapshot.profile.title)?", isPresented: $showingReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { perform { try session.reset() } }
        } message: {
            Text("Replace all events in this testing profile with its original sample data?")
        }
        .alert("Could not update testing profile", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() }
        catch { errorMessage = error.localizedDescription }
    }
}
#endif
