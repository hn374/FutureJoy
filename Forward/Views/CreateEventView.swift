//
//  CreateEventView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData
import UIKit

struct CreateEventView: View {
    @ObservedObject var viewModel: EventListViewModel
    var onClose: () -> Void = {}
    @State private var title: String = ""
    @State private var selectedEmoji: String = "🎉"
    @State private var date: Date = Date()
    @State private var datePickerID = UUID()
    @State private var location: String = ""
    @State private var notes: String = ""
    
    private let popularEmojis: [String] = [
        "🎉", "🎂", "🎸", "🎬", "🎮", "🎯", "🎪", "🎭",
        "🏆", "🏖️", "🏠", "🎓", "💼", "💍", "💝", "🌟",
        "🎄", "🎃", "🐣", "🌸", "☀️", "🍂", "❄️", "🌈",
        "✈️", "🚗", "🛳️", "🏔️", "🏕️", "🎿", "🏄", "🎾",
        "🍕", "🍰", "🍷", "☕", "🎵", "📚", "💻", "📱",
        "👶", "👨‍👩‍👧", "🐕", "🐈", "🌺", "🎁", "💰", "⭐"
    ]
    
    private func isOnOrAfterToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfSelected = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: Date())
        return startOfSelected >= startOfToday
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedEmoji.isEmpty &&
        isOnOrAfterToday(date)
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.05).ignoresSafeArea()
            
            VStack(spacing: 16) {
                VStack(spacing: 20) {
                    header
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            iconField(
                                title: "Event Name",
                                placeholder: "Birthday Party",
                                systemImage: nil,
                                text: $title,
                                required: true
                            )
                            
                            dateField
                            
                            iconField(
                                title: "Location (Optional)",
                                placeholder: "New York, NY",
                                systemImage: "mappin.and.ellipse",
                                text: $location,
                                required: false
                            )
                            
                            notesField
                            emojiPicker
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                createButton
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .presentationBackground(.clear)
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Create New Event")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.2))
            
            Spacer()
            
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                    .padding(10)
            }
            .background(Color(red: 0.95, green: 0.95, blue: 0.97))
            .clipShape(Circle())
        }
    }
    
    // MARK: - Fields
    private func iconField(title: String, placeholder: String, systemImage: String?, text: Binding<String>, required: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.32))
                if required {
                    Text("*").foregroundColor(.red)
                }
            }
            
            HStack(spacing: systemImage == nil ? 0 : 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                }
                TextField(placeholder, text: text)
                    .font(.system(size: 16))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.97, green: 0.97, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
            )
        }
    }
    
    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Event Date")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.32))
                Text("*").foregroundColor(.red)
            }
            
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                
                DatePicker(
                    "Select a date",
                    selection: $date,
                    in: Date()...,
                    displayedComponents: [.date]
                )
                .id(datePickerID)
                .labelsHidden()
                .tint(Color(red: 0.45, green: 0.40, blue: 0.95))
                .datePickerStyle(.compact)
                .onChange(of: date) { _ in
                    dismissDatePicker()
                    datePickerID = UUID() // force rebuild to close popover
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.97, green: 0.97, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
            )
        }
    }
    
    private func dismissDatePicker() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.32))
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .font(.system(size: 16))
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.99))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(red: 0.9, green: 0.9, blue: 0.93), lineWidth: 1)
                    )
                
                if notes.isEmpty {
                    Text("Add any additional details...")
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("Choose an Emoji")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.32))
                Text("*").foregroundColor(.red)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(popularEmojis, id: \.self) { emoji in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedEmoji = emoji
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(
                                            selectedEmoji == emoji ?
                                            Color(red: 0.45, green: 0.40, blue: 0.95) :
                                            Color(red: 0.9, green: 0.9, blue: 0.93),
                                            lineWidth: selectedEmoji == emoji ? 2 : 1
                                        )
                                )
                            Text(emoji)
                                .font(.system(size: 28))
                        }
                        .frame(height: 52)
                    }
                }
            }
        }
    }
    
    // MARK: - Button
    private var createButton: some View {
        Button {
            saveEvent()
        } label: {
            Text("Create Event")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.40, blue: 0.95),
                            Color(red: 0.65, green: 0.45, blue: 0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }
    
    // MARK: - Save Event
    private func saveEvent() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try viewModel.addEvent(
                title: trimmedTitle,
                emoji: selectedEmoji,
                date: date,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            viewModel.presentToast(message: "Event created successfully", style: .success)
            onClose()
        } catch {
            viewModel.presentToast(message: "Failed to create event. Please try again.", style: .error)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, configurations: config)
    
    return CreateEventView(
        viewModel: EventListViewModel(modelContext: container.mainContext)
    )
}
