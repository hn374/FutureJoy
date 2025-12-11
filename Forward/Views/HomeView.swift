//
//  HomeView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: EventListViewModel
    private let headerHeight: CGFloat = 160
    
    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: EventListViewModel(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                Color(red: 0.97, green: 0.97, blue: 0.98)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Add New Event Button
                        addEventButton
                            .padding(.top, 16)
                        
                        // Event List
                        eventList
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, headerHeight + 12)
                    .padding(.bottom, 32)
                }
                .ignoresSafeArea(edges: .top)
                
                // Fixed header
                headerView
                    .frame(maxWidth: .infinity)
                    .frame(height: headerHeight)
                    .ignoresSafeArea(edges: .top)
            }
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
            .overlay(alignment: .top) {
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
                viewModel.fetchEvents()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Toast Overlay
    private var toastOverlay: some View {
        Group {
            if let toast = viewModel.toast {
                ToastBannerView(toast: toast)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.45, green: 0.40, blue: 0.95),
                    Color(red: 0.65, green: 0.35, blue: 0.90)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    // Calendar icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "calendar")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Text("FutureJoy")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                    
                    Spacer()
                    
                    if viewModel.isSelectionMode {
                        HStack(alignment: .center, spacing: 8) {
                            Button {
                                viewModel.confirmDeleteSelected()
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.selectedEventIDs.isEmpty)
                            .opacity(viewModel.selectedEventIDs.isEmpty ? 0.6 : 1)
                            
                            Button("Cancel") {
                                viewModel.exitSelectionMode()
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.trailing, 4)
                    } else {
                        Button("Select") {
                            viewModel.enterSelectionMode()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                
                if viewModel.isSelectionMode {
                    Text("\(viewModel.selectedEventIDs.count) selected")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text("Track events you're looking forward to!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 32)
        }
        .clipShape(
            RoundedCornerShape(corners: [.bottomLeft, .bottomRight], radius: 32)
        )
    }
    
    // MARK: - Add Event Button
    private var addEventButton: some View {
        Button {
            viewModel.showingCreateEvent = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Add New Event")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.45, green: 0.40, blue: 0.95),
                        Color(red: 0.55, green: 0.35, blue: 0.92)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color(red: 0.45, green: 0.40, blue: 0.95).opacity(0.4), radius: 12, x: 0, y: 6)
        }
    }
    
    // MARK: - Event List
    private var eventList: some View {
        LazyVStack(spacing: 16) {
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

