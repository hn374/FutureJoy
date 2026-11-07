import XCTest
@testable import Forward

final class EventEmojiInputTests: XCTestCase {
    func testInputKeepsOneCompleteCharacter() {
        for emoji in ["🎉", "👍🏽", "👨‍👩‍👧", "🇺🇸", "❤️", "1️⃣"] {
            XCTAssertEqual(EventEmojiInput.limit(emoji + "🌙"), emoji)
            XCTAssertEqual(EventEmojiInput.limit(emoji), emoji)
        }
    }

    func testBlankInputRemainsEmptyForEachFormsExistingSavePolicy() {
        for input in ["", " ", "  \n\t"] {
            XCTAssertEqual(EventEmojiInput.limit(input), "")
        }
    }

    func testInputTrimsWhitespaceAndPreservesExistingFreeTextPolicy() {
        XCTAssertEqual(EventEmojiInput.limit("  🎉🌙  "), "🎉")
        XCTAssertEqual(EventEmojiInput.limit("abc"), "a")
        XCTAssertEqual(EventEmojiInput.limit("a🎉"), "a")
        XCTAssertEqual(EventEmojiInput.limit("🎉a"), "🎉")
    }
}
