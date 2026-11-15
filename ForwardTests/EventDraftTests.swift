import XCTest
@testable import Forward

final class EventDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var now: Date { date(day: 14, hour: 12) }

    func testNormalizesTitleAndOptionalFields() throws {
        for mode in modes {
            var draft = makeDraft()
            draft.title = " \n Concert  Night \t"
            draft.location = " \n "
            draft.notes = "\n first\n\nsecond \t"
            let fields = try draft.prepare(for: mode, now: now, calendar: calendar)
            XCTAssertEqual(fields.title, "Concert  Night")
            XCTAssertEqual(fields.date, draft.date)
            XCTAssertNil(fields.location)
            XCTAssertEqual(fields.notes, "first\n\nsecond")
            XCTAssertEqual(draft.title, " \n Concert  Night \t")

            draft.location = "  New York, NY\n"
            draft.notes = " \n\t"
            let cleared = try draft.prepare(for: mode, now: now, calendar: calendar)
            XCTAssertEqual(cleared.location, "New York, NY")
            XCTAssertNil(cleared.notes)
        }
    }

    func testRejectsWhitespaceOnlyTitles() {
        for mode in modes {
            for title in ["", " ", "\n\t"] {
                var draft = makeDraft()
                draft.title = title
                assertFailure(.emptyTitle, draft: draft, mode: mode)
            }
        }
    }

    func testCreationDefaultsBlankEmoji() throws {
        for (input, expected) in [("", "🎉"), (" \n\t", "🎉"), (" 🦦🌙 ", "🦦"), ("abc", "a")] {
            var draft = makeDraft()
            draft.emoji = input
            XCTAssertEqual(try draft.prepare(for: .creation, now: now, calendar: calendar).emoji, expected)
        }
    }

    func testUntouchedEditingPreservesStoredEmoji() throws {
        var draft = makeDraft()
        draft.emoji = "different snapshot"
        for original in ["🎒🌲", " 🎒🌲 ", "abc"] {
            let mode = EventDraftMode.editing(originalEmoji: original, emojiWasEdited: false)
            XCTAssertEqual(try draft.prepare(for: mode, now: now, calendar: calendar).emoji, original)
        }
        for original in ["", " \n\t"] {
            assertFailure(.emptyEmoji, draft: draft, mode: .editing(originalEmoji: original, emojiWasEdited: false))
        }
    }

    func testTouchedEditingNormalizesAndRejectsBlankEmoji() throws {
        for (input, expected) in [(" 🦦🌙 ", "🦦"), ("abc", "a"), ("🎒🌲", "🎒")] {
            var draft = makeDraft()
            draft.emoji = input
            let mode = EventDraftMode.editing(originalEmoji: input, emojiWasEdited: true)
            XCTAssertEqual(try draft.prepare(for: mode, now: now, calendar: calendar).emoji, expected)
        }
        for input in ["", " \n\t"] {
            var draft = makeDraft()
            draft.emoji = input
            assertFailure(.emptyEmoji, draft: draft, mode: .editing(originalEmoji: "🎒🌲", emojiWasEdited: true))
        }
    }

    func testPreparationKeepsCompleteCharacters() throws {
        for emoji in ["👍🏽", "👨‍👩‍👧", "🇺🇸", "❤️", "1️⃣"] {
            for mode in modes {
                var draft = makeDraft()
                draft.emoji = emoji + "🌙"
                XCTAssertEqual(try draft.prepare(for: mode, now: now, calendar: calendar).emoji, emoji)
            }
        }
    }

    func testValidationPrecedence() {
        let mode = EventDraftMode.editing(originalEmoji: "🎒🌲", emojiWasEdited: true)
        var draft = makeDraft()
        draft.date = date(day: 13, hour: 23)
        draft.title = " "
        draft.emoji = " "
        assertFailure(.pastDate, draft: draft, mode: mode)
        draft.date = date(day: 14, hour: 0)
        assertFailure(.emptyTitle, draft: draft, mode: mode)
        draft.title = "Concert"
        assertFailure(.emptyEmoji, draft: draft, mode: mode)
    }

    func testSavePreparationRechecksCurrentDay() throws {
        for mode in modes {
            let draft = makeDraft()
            XCTAssertNoThrow(try draft.prepare(for: mode, now: date(day: 14, hour: 23), calendar: calendar))
            XCTAssertThrowsError(try draft.prepare(for: mode, now: date(day: 15, hour: 0), calendar: calendar)) { error in
                XCTAssertEqual(error as? EventDraftValidationError, .pastDate)
            }
        }
    }

    private var modes: [EventDraftMode] {
        [.creation, .editing(originalEmoji: "🎒🌲", emojiWasEdited: true)]
    }

    private func makeDraft() -> EventDraft {
        EventDraft(title: "Concert", emoji: "🎸", date: date(day: 14, hour: 0), location: "", notes: "")
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func assertFailure(
        _ expected: EventDraftValidationError,
        draft: EventDraft,
        mode: EventDraftMode,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try draft.prepare(for: mode, now: now, calendar: calendar), file: file, line: line) { error in
            XCTAssertEqual(error as? EventDraftValidationError, expected, "Unexpected error: \(error)", file: file, line: line)
        }
    }
}
