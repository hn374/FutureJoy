import Foundation

enum EventEmojiInput {
    static func limit(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
    }
}
