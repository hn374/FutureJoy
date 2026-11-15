import XCTest
@testable import Forward

final class EventCalendarDayTests: XCTestCase {
    func testTodayAcceptsEarlierTimeAndRejectsYesterday() {
        let calendar = calendar(in: "America/New_York")
        let now = date(2026, 11, 14, 12, calendar: calendar)
        let midnight = date(2026, 11, 14, 0, calendar: calendar)
        XCTAssertEqual(EventCalendarDay.startOfToday(now: now, calendar: calendar), midnight)
        for value in [midnight, date(2026, 11, 14, 1, calendar: calendar), date(2026, 11, 15, 0, calendar: calendar)] {
            XCTAssertTrue(EventCalendarDay.isOnOrAfterToday(value, now: now, calendar: calendar))
        }
        XCTAssertFalse(EventCalendarDay.isOnOrAfterToday(date(2026, 11, 13, 23, 59, calendar: calendar), now: now, calendar: calendar))
    }

    func testCalendarDayBoundariesAcrossTimeZonesDSTLeapAndYear() {
        let cases: [(String, (Int, Int, Int), (Int, Int, Int))] = [
            ("America/Los_Angeles", (2026, 3, 8), (2026, 3, 7)),
            ("America/Los_Angeles", (2026, 11, 1), (2026, 10, 31)),
            ("UTC", (2024, 2, 29), (2024, 2, 28)),
            ("UTC", (2027, 1, 1), (2026, 12, 31)),
            ("Pacific/Kiritimati", (2026, 11, 15), (2026, 11, 14))
        ]
        for (zone, today, yesterday) in cases {
            let calendar = calendar(in: zone)
            // At 00:30 in Kiritimati the UTC calendar still says yesterday.
            let now = date(today.0, today.1, today.2, 0, 30, calendar: calendar)
            let midnight = date(today.0, today.1, today.2, 0, calendar: calendar)
            let lateYesterday = date(yesterday.0, yesterday.1, yesterday.2, 23, 59, calendar: calendar)
            XCTAssertEqual(EventCalendarDay.startOfToday(now: now, calendar: calendar), midnight, zone)
            XCTAssertTrue(EventCalendarDay.isOnOrAfterToday(midnight, now: now, calendar: calendar), zone)
            XCTAssertFalse(EventCalendarDay.isOnOrAfterToday(lateYesterday, now: now, calendar: calendar), zone)
            let noon = date(today.0, today.1, today.2, 12, calendar: calendar)
            XCTAssertTrue(EventCalendarDay.isOnOrAfterToday(midnight, now: noon, calendar: calendar), zone)
        }
    }

    private func calendar(in zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
