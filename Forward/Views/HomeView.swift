//
//  HomeView.swift
//  Forward
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: EventListViewModel
    private let topAnchorID = "topAnchor"
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: EventListViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    // Background
                    Color(red: 0.97, green: 0.97, blue: 0.98)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        headerView(scrollProxy: proxy)

                        ScrollView {
                            VStack(spacing: 0) {
                                // Keep the header's scroll target at a non-lazy content origin.
                                Color.clear
                                    .frame(height: 0)
                                    .id(topAnchorID)

                                LazyVStack(spacing: 16) {
                                    // Event List
                                    eventList
                                }
                                .padding(.top, 16)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                        .id(viewModel.filter)
                    }
                }
            }
            .disabled(viewModel.showingCreateEvent)
            .accessibilityHidden(viewModel.showingCreateEvent)
            .overlay(alignment: .center) {
                if viewModel.showingCreateEvent {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                viewModel.showingCreateEvent = false
                            }

                        CreateEventView(
                            viewModel: viewModel,
                            onClose: { viewModel.showingCreateEvent = false }
                        )
                        .frame(maxWidth: 540)
                        .padding(.horizontal, 24)
                        .transition(.scale)
                        .zIndex(1)
                    }
                }
            }
            .animation(.easeInOut, value: viewModel.showingCreateEvent)
            .overlay(alignment: .bottom) {
                toastOverlay
            }
            .alert("Delete Event", isPresented: $viewModel.showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDelete()
                }
                Button("Delete", role: .destructive) {
                    viewModel.deleteConfirmedEvent()
                }
            } message: {
                if viewModel.isSelectionMode, !viewModel.selectedEventIDs.isEmpty {
                    Text("Delete \(viewModel.selectedEventIDs.count) selected event(s)? This action cannot be undone.")
                } else if let event = viewModel.eventToDelete {
                    Text("Are you sure you want to delete \"\(event.title)\"? This action cannot be undone.")
                }
            }
            .onAppear {
                viewModel.archivePastEvents()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - Toast Overlay
    private var toastOverlay: some View {
        Group {
            if let toast = viewModel.toast {
                ToastBannerView(toast: toast)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }
    
    // MARK: - Header View
    private func headerView(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        leadingHeaderAction
                            .frame(maxWidth: .infinity, alignment: .leading)
                        appTitle(scrollProxy: scrollProxy)
                        trailingHeaderAction
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    VStack(spacing: 8) {
                        appTitle(scrollProxy: scrollProxy)
                        HStack {
                            leadingHeaderAction
                            Spacer()
                            trailingHeaderAction
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

                if viewModel.isSelectionMode {
                    Text("\(viewModel.selectedEventIDs.count) selected")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(EventListFilter.allCases, id: \.self) { filter in
                    eventListTab(filter)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.45, green: 0.40, blue: 0.95),
                    Color(red: 0.65, green: 0.35, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(
                RoundedCornerShape(corners: [.bottomLeft, .bottomRight], radius: 16)
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private func eventListTab(_ filter: EventListFilter) -> some View {
        let isSelected = viewModel.filter == filter

        return Button {
            viewModel.setFilter(filter)
        } label: {
            Text(filter.title)
                .font(.title3.weight(isSelected ? .semibold : .medium))
                .dynamicTypeSize(.small...)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule()
                            .fill(.white)
                            .frame(width: 44, height: 3)
                            .padding(.bottom, 6)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSelectionMode)
        .accessibilityLabel(filter.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(viewModel.isSelectionMode ? "Tap Cancel to switch lists" : "")
    }

    private func appTitle(scrollProxy: ScrollViewProxy) -> some View {
        Button {
            scrollProxy.scrollTo(topAnchorID, anchor: .top)
        } label: {
            Text("Forward")
                .font(.title2.bold())
                .fixedSize()
                .padding(.horizontal, 4)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Forward, scroll to top")
        .accessibilityHint("Scrolls to the beginning of the current list")
        .accessibilityIdentifier("Scroll to top")
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var leadingHeaderAction: some View {
        if viewModel.isSelectionMode {
            Button {
                viewModel.exitSelectionMode()
            } label: {
                headerTextLabel("Cancel")
            }
            .buttonStyle(.plain)
        } else if !viewModel.events.isEmpty {
            Button {
                viewModel.enterSelectionMode()
            } label: {
                headerTextLabel("Select")
            }
            .buttonStyle(.plain)
        } else {
            headerTextLabel("Select")
                .hidden()
        }
    }

    private func headerTextLabel(_ title: String) -> some View {
        Text(title)
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(.black.opacity(0.25), in: Capsule())
            .contentShape(Rectangle())
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var trailingHeaderAction: some View {
        if viewModel.isSelectionMode {
            Button {
                viewModel.confirmDeleteSelected()
            } label: {
                Image(systemName: "trash")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Trash")
            .disabled(viewModel.selectedEventIDs.isEmpty)
        } else if viewModel.filter == .future {
            addEventButton
        } else {
            addEventLabel
                .hidden()
        }
    }

    // MARK: - Add Event Button
    private var addEventButton: some View {
        Button {
            viewModel.showingCreateEvent = true
        } label: {
            addEventLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add New Event")
    }

    private var addEventLabel: some View {
        Label("Add", systemImage: "plus")
            .padding(.horizontal, 12)
            .frame(minWidth: 44, minHeight: 44)
            .background(.black.opacity(0.25), in: Capsule())
            .contentShape(Rectangle())
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Event List
    private var eventList: some View {
        Group {
            if viewModel.filter == .past && viewModel.events.isEmpty {
                emptyPastState
            } else {
                ForEach(viewModel.events) { event in
                    if viewModel.isSelectionMode {
                        EventRowView(
                            event: event,
                            onDelete: {},
                            selectionMode: true,
                            isSelected: viewModel.isSelected(event),
                            onToggleSelection: {
                                viewModel.toggleSelection(for: event)
                            }
                        )
                        .onTapGesture {
                            viewModel.toggleSelection(for: event)
                        }
                    } else {
                        NavigationLink {
                            EventDetailView(event: event)
                        } label: {
                            EventRowView(event: event) {
                                viewModel.confirmDelete(event)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Toast View
private struct ToastBannerView: View {
    let toast: ToastData
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.style.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(toast.message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(toast.style.background.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 6)
        .frame(maxWidth: 540)
    }
}

// MARK: - Empty States
private extension HomeView {
    var emptyPastState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 46, weight: .semibold))
                .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.95).opacity(0.8))
            
            Text("No past events yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
            
            Text("Finished events will show up here after their date has passed.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    Color(red: 0.65, green: 0.60, blue: 0.95).opacity(0.8),
                    lineWidth: 1.25
                )
        )
    }
}

// MARK: - Custom Shape for Rounded Corners
struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, configurations: config)
    
    // Add sample events
    let sampleEvents = [
        Event(title: "Concert Night", emoji: "🎸", date: Calendar.current.date(byAdding: .day, value: 11, to: Date())!),
        Event(title: "Birthday Party", emoji: "🎂", date: Calendar.current.date(byAdding: .day, value: 38, to: Date())!),
        Event(title: "New Year", emoji: "🎉", date: Calendar.current.date(byAdding: .day, value: 80, to: Date())!)
    ]
    
    for event in sampleEvents {
        container.mainContext.insert(event)
    }
    
    return HomeView(modelContext: container.mainContext)
        .modelContainer(container)
}

