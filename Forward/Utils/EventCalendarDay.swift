import Foundation

enum EventCalendarDay {
    static func startOfToday(now: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: now)
    }

    static func isOnOrAfterToday(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        calendar.startOfDay(for: date) >= startOfToday(now: now, calendar: calendar)
    }
}
