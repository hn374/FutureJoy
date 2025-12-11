//
//  EventDetailView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/6/25.
//

import SwiftUI
import SwiftData
import Combine

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedEmoji: String
    @State private var editedDate: Date
    @State private var editedLocation: String
    @State private var editedNotes: String
    @State private var alertMessage: String?
    
    init(event: Event) {
        self.event = event
        _editedTitle = State(initialValue: event.title)
        _editedEmoji = State(initialValue: event.emoji)
        _editedDate = State(initialValue: event.date)
        _editedLocation = State(initialValue: event.location ?? "")
        _editedNotes = State(initialValue: event.notes ?? "")
    }
    
    private var timeRemaining: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let interval = max(event.date.timeIntervalSince(now), 0)
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return (days, hours, minutes, seconds)
    }
    
    private var formattedDate: String {
        EventDetailView.dateFormatter.string(from: event.date)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    
                    VStack(spacing: 16) {
                        detailsCard
                        dateCard
                        locationCard
                        notesCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onReceive(timer) { newDate in
            now = newDate
        }
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(navBarColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            ToolbarItem(placement: .principal) {
                navTitle
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                editControls
            }
        }
        .alert(
            "Unable to Save Changes",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { newValue in
                    if !newValue {
                        alertMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        ZStack {
            countdownCard
                .padding(.horizontal, 4)
                .offset(y: 40)
        }
        .padding(.bottom, 56)
    }

    private var navBarColor: Color {
        Color(red: 0.58, green: 0.38, blue: 0.94)
    }
    
    private var navTitle: some View {
        HStack(spacing: 8) {
            Text(event.emoji)
                .font(.system(size: 20))
            Text(event.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.32, green: 0.32, blue: 0.38))
                )
        }
        .buttonStyle(.plain)
    }
    
    private var editControls: some View {
        HStack(spacing: 10) {
            if isEditing {
                Button {
                    cancelEditing()
                } label: {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.32, green: 0.32, blue: 0.38))
                        )
                }
                .buttonStyle(.plain)
            }
            
            Button {
                handleEditTapped()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(red: 0.32, green: 0.32, blue: 0.38))
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Countdown
    private var countdownCard: some View {
        VStack(spacing: 16) {
            Text("Time Until Event")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(spacing: 12) {
                countdownSegment(value: timeRemaining.days, label: "Days")
                countdownSegment(value: timeRemaining.hours, label: "Hours")
                countdownSegment(value: timeRemaining.minutes, label: "Mins")
                countdownSegment(value: timeRemaining.seconds, label: "Secs")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.45, green: 0.40, blue: 0.95),
                    Color(red: 0.56, green: 0.44, blue: 0.93)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
    
    private func countdownSegment(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - Info Cards
    private var detailsCard: some View {
        infoCard(
            title: "Event",
            systemImage: "sparkles",
            iconColor: Color(red: 0.32, green: 0.55, blue: 1.0)
        ) {
            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Event name", text: $editedTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(12)
                        .background(Color(red: 0.97, green: 0.97, blue: 0.99))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.words)
                    
                    HStack(spacing: 12) {
                        TextField("Emoji", text: $editedEmoji)
                            .font(.system(size: 22))
                            .frame(width: 64)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color(red: 0.97, green: 0.97, blue: 0.99))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
                            )
                            .multilineTextAlignment(.center)
                            .onChange(of: editedEmoji) { newValue in
                                let limited = String(newValue.prefix(2))
                                if limited != newValue {
                                    editedEmoji = limited
                                }
                            }
                        
                        Text("Pick an emoji")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Text(event.emoji)
                        .font(.system(size: 22))
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                }
            }
        }
    }
    
    private var dateCard: some View {
        infoCard(
            title: "Date",
            systemImage: "calendar",
            iconColor: Color(red: 0.32, green: 0.55, blue: 1.0)
        ) {
            if isEditing {
                DatePicker(
                    "",
                    selection: $editedDate,
                    in: minimumDate...,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .tint(Color(red: 0.45, green: 0.40, blue: 0.95))
                .datePickerStyle(.compact)
            } else {
                Text(formattedDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
            }
        }
    }
    
    private var locationCard: some View {
        infoCard(
            title: "Location",
            systemImage: "mappin.and.ellipse",
            iconColor: Color(red: 0.62, green: 0.42, blue: 0.95)
        ) {
            if isEditing {
                VStack(spacing: 8) {
                    TextField("Add a location", text: $editedLocation)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(12)
                        .background(Color(red: 0.97, green: 0.97, blue: 0.99))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.sentences)
                }
            } else {
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .multilineTextAlignment(.leading)
                } else {
                    Text("No location added")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                }
            }
        }
    }
    
    private var notesCard: some View {
        infoCard(
            title: "Notes",
            systemImage: "note.text",
            iconColor: Color(red: 0.99, green: 0.74, blue: 0.37)
        ) {
            if isEditing {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $editedNotes)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(minHeight: 120)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(Color(red: 0.97, green: 0.97, blue: 0.99))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
                        )
                    
                    if editedNotes.isEmpty {
                        Text("Add notes or details...")
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No notes yet")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    @ViewBuilder
    private func infoCard<Content: View>(
        title: String,
        systemImage: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Editing Helpers
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private var isDateValid: Bool {
        Calendar.current.startOfDay(for: editedDate) >= minimumDate
    }
    
    private func handleEditTapped() {
        if isEditing {
            saveChanges()
        } else {
            startEditing()
        }
    }
    
    private func startEditing() {
        resetEdits()
        isEditing = true
    }
    
    private func cancelEditing() {
        resetEdits()
        isEditing = false
    }
    
    private func resetEdits() {
        editedDate = event.date
        editedTitle = event.title
        editedEmoji = event.emoji
        editedLocation = event.location ?? ""
        editedNotes = event.notes ?? ""
    }
    
    private func saveChanges() {
        guard isDateValid else {
            alertMessage = "Event date cannot be in the past."
            return
        }
        
        let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = editedEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = editedLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedTitle.isEmpty == false else {
            alertMessage = "Event name cannot be empty."
            return
        }
        
        guard trimmedEmoji.isEmpty == false else {
            alertMessage = "Please add an emoji."
            return
        }
        
        event.title = trimmedTitle
        event.emoji = trimmedEmoji
        event.date = editedDate
        event.location = trimmedLocation.isEmpty ? nil : trimmedLocation
        event.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        do {
            try modelContext.save()
            isEditing = false
        } catch {
            alertMessage = "Something went wrong while saving. Please try again."
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, configurations: config)
    
    let sample = Event(
        title: "Concert Night",
        emoji: "🎸",
        date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
        location: "Madison Square Garden, New York",
        notes: """
        VIP tickets confirmed!
        Meet Sarah at 7:00 PM
        Doors open at 7:30 PM
        Show starts at 8:30 PM
        
        Parking: Lot B pre-paid
        """
    )
    container.mainContext.insert(sample)
    
    return NavigationStack {
        EventDetailView(event: sample)
    }
    .modelContainer(container)
}
