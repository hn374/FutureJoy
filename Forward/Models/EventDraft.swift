import Foundation

enum EventDraftMode {
    case creation
    case editing(originalEmoji: String, emojiWasEdited: Bool)
}

struct PreparedEventFields: Equatable {
    let title: String
    let emoji: String
    let date: Date
    let location: String?
    let notes: String?
}

enum EventDraftValidationError: Error, Equatable {
    case pastDate
    case emptyTitle
    case emptyEmoji
}

/// A form snapshot. Preparation neither changes the draft nor saves an event.
struct EventDraft {
    var title: String
    var emoji: String
    var date: Date
    var location: String
    var notes: String

    func prepare(for mode: EventDraftMode, now: Date, calendar: Calendar) throws -> PreparedEventFields {
        guard EventCalendarDay.isOnOrAfterToday(date, now: now, calendar: calendar) else {
            throw EventDraftValidationError.pastDate
        }

        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw EventDraftValidationError.emptyTitle
        }

        let preparedEmoji: String
        switch mode {
        case .creation:
            let limited = EventEmojiInput.limit(emoji)
            preparedEmoji = limited.isEmpty ? "🎉" : limited
        case let .editing(originalEmoji, emojiWasEdited):
            // Touch history matters even if the user changes back to the original text.
            preparedEmoji = emojiWasEdited ? EventEmojiInput.limit(emoji) : originalEmoji
        }
        guard !preparedEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventDraftValidationError.emptyEmoji
        }

        return PreparedEventFields(
            title: title,
            emoji: preparedEmoji,
            date: date,
            location: trimmedOptional(location),
            notes: trimmedOptional(notes)
        )
    }

    private func trimmedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
