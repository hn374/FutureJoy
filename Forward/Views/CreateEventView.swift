//
//  CreateEventView.swift
//  Forward
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI
import SwiftData
import UIKit

struct CreateEventView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: Field?
    @AccessibilityFocusState(for: .voiceOver) private var dateRowFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 26.0
    @ScaledMetric(relativeTo: .title2) private var emojiCellWidth = 62
    @ObservedObject var viewModel: EventListViewModel
    var onClose: () -> Void = {}
    @State private var title: String = ""
    @State private var selectedEmoji: String = "🎉"
    @State private var date: Date = Date()
    @State private var showingDatePicker = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var showingSaveError = false

    private enum Field: Hashable {
        case name, location, notes, emoji
    }

    private let accent = Color(red: 0.36, green: 0.23, blue: 0.77)
    private let fieldBackground = Color(red: 0.97, green: 0.96, blue: 0.99)
    private let fieldBorder = Color(red: 0.90, green: 0.88, blue: 0.94)
    private let placeholderColor = Color(red: 0.38, green: 0.35, blue: 0.43)
    private let columnWidth: CGFloat = 520
    
    private let popularEmojis: [String] = [
        "🎉", "🎂", "🎸", "🎬", "🎮", "🎯", "🎪", "🎭",
        "🏆", "🏖️", "🏠", "🎓", "💼", "💍", "💝", "🌟",
        "🎄", "🎃", "🐣", "🌸", "☀️", "🍂", "❄️", "🌈",
        "✈️", "🚗", "🛳️", "🏔️", "🏕️", "🎿", "🏄", "🎾",
        "🍕", "🍰", "🍷", "☕", "🎵", "📚", "💻", "📱",
        "👶", "👨‍👩‍👧", "🐕", "🐈", "🌺", "🎁", "💰", "⭐"
    ]
    
    private var draft: EventDraft {
        EventDraft(title: title, emoji: selectedEmoji, date: date, location: location, notes: notes)
    }

    private var isFormValid: Bool {
        (try? draft.prepare(for: .creation, now: Date(), calendar: .current)) != nil
    }
    
    var body: some View {
        NavigationStack {
            form
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showingDatePicker) {
                    datePickerPage
                        .navigationBarBackButtonHidden()
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .alert("Failed to create event. Please try again.", isPresented: $showingSaveError) {
            Button("OK", role: .cancel) {}
        }
        .preferredColorScheme(.light)
    }

    private var form: some View {
        let showHeading = focusedField == nil || !dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: 0) {
            editorHeader(showHeading ? "Create New Event" : nil) {
                if focusedField == nil {
                    headerButton("Cancel", role: .cancel, action: onClose)
                        .accessibilityIdentifier("cancel-event-creation")
                } else {
                    headerButton("Hide Keyboard") { focusedField = nil }
                }
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        textField("Event Name", prompt: "Birthday Party", text: $title, field: .name, required: true)
                        dateField
                            .id("event-date")
                        textField("Location", prompt: "New York, NY", text: $location, field: .location)
                        notesField
                        emojiPicker
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: columnWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.top)
                .onChange(of: showingDatePicker) { wasShowing, isShowing in
                    if wasShowing && !isShowing {
                        proxy.scrollTo("event-date")
                        dateRowFocused = true
                    }
                }
            }
            if focusedField == nil {
                Divider()
                createButton
                    .frame(maxWidth: columnWidth)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(Color(.systemBackground))
    }

    private func editorHeader<Action: View>(
        _ title: LocalizedStringKey?,
        @ViewBuilder action: () -> Action
    ) -> some View {
        Group {
            if let title {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        heading(title)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        action()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        action().frame(maxWidth: .infinity, alignment: .trailing)
                        heading(title)
                    }
                }
            } else {
                action().frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: columnWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: headingSize, weight: .bold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func headerButton(
        _ title: LocalizedStringKey,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(accent)
                .background(accent.opacity(0.12), in: Capsule())
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func fieldLabel(_ title: LocalizedStringKey, required: Bool = false) -> some View {
        Group {
            if required {
                Text("\(Text(title))\(Text(" *").foregroundStyle(.red))")
            } else {
                Text("\(Text(title))\(Text(" (Optional)").foregroundStyle(.secondary).fontWeight(.regular))")
            }
        }
        .font(.footnote.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }

    private func textField(
        _ label: LocalizedStringKey,
        prompt: LocalizedStringKey,
        text: Binding<String>,
        field: Field,
        required: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(label, required: required)
            TextField(label, text: text, prompt: Text(prompt).foregroundStyle(placeholderColor))
                .font(.body)
                .focused($focusedField, equals: field)
                .onSubmit { focusedField = nil }
                .accessibilityLabel(required ? Text("Event Name, required") : Text("Location, optional"))
                .accessibilityIdentifier(required ? "event-creation-name" : "event-creation-location")
                .padding(12)
                .frame(minHeight: 44)
                .background(fieldSurface)
        }
    }

    private var fieldSurface: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(fieldBackground)
            .strokeBorder(fieldBorder)
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Event Date", required: true)
            Button {
                focusedField = nil
                showingDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    Text(date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .frame(minHeight: 44)
                .background(fieldSurface)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Event Date, required")
            .accessibilityValue(Text(date, format: .dateTime.day().month(.wide).year()))
            .accessibilityIdentifier("event-creation-date")
            .accessibilityFocused($dateRowFocused)
        }
    }

    private var datePickerPage: some View {
        VStack(spacing: 0) {
            editorHeader("Event Date") {
                headerButton("Done") { showingDatePicker = false }
            }
            Divider()
            ScrollView {
                DatePicker(
                    "Event Date",
                    selection: $date,
                    in: EventCalendarDay.startOfToday(now: Date(), calendar: .current)...,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.graphical)
                .tint(accent)
                .frame(maxWidth: columnWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(Color(.systemBackground))
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Notes")
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add any additional details…")
                        .font(.body)
                        .foregroundStyle(placeholderColor)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $notes)
                    .font(.body)
                    .focused($focusedField, equals: .notes)
                    .frame(minHeight: 112)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Notes, optional")
            }
            .background(fieldSurface)
        }
    }

    private var emojiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Emoji")
            TextField("Emoji", text: $selectedEmoji)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .emoji)
                .onSubmit { focusedField = nil }
                .padding(12)
                .frame(minHeight: 44)
                .background(fieldSurface)
                .accessibilityHint("Choose one emoji. Extra emoji are ignored.")
                .onChange(of: selectedEmoji) { _, newValue in
                    let limited = EventEmojiInput.limit(newValue)
                    if limited != newValue {
                        selectedEmoji = limited
                    }
                }

            Text("Choose one emoji. Defaults to 🎉 if left blank.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: emojiCellWidth), spacing: 8)], spacing: 8) {
                ForEach(popularEmojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                        focusedField = nil
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: max(44, emojiCellWidth - 10))
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(selectedEmoji == emoji ? accent : fieldBorder, lineWidth: selectedEmoji == emoji ? 2 : 1)
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedEmoji == emoji ? .isSelected : [])
                }
            }
        }
    }

    private var createButton: some View {
        Button(action: saveEvent) {
            Text("Create Event")
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(isFormValid ? Color.white : placeholderColor)
                .background(isFormValid ? accent : fieldBorder, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isFormValid)
    }

    // MARK: - Save Event
    private func saveEvent() {
        guard let fields = try? draft.prepare(for: .creation, now: Date(), calendar: .current) else {
            return
        }
        
        do {
            try viewModel.addEvent(
                title: fields.title,
                emoji: fields.emoji,
                date: fields.date,
                location: fields.location,
                notes: fields.notes
            )
            viewModel.presentToast(message: "Event created successfully", style: .success)
            onClose()
        } catch {
            showingSaveError = true
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
