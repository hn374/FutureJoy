//
//  Event.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import Foundation
import SwiftData

@Model
final class Event {
    var id: UUID = UUID()
    var title: String = ""
    var emoji: String = ""
    var date: Date = Date()
    var location: String?
    var category: String?
    var notes: String?
    var isArchived: Bool = false
    var createdAt: Date = Date()
    
    init(
        title: String,
        emoji: String,
        date: Date,
        location: String? = nil,
        category: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.emoji = emoji
        self.date = date
        self.location = location
        self.category = category
        self.notes = notes
        self.isArchived = false
        self.createdAt = Date()
    }
    
    /// Returns the number of days until the event
    /// Negative values indicate past events
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDay = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: eventDay)
        return components.day ?? 0
    }
    
    /// Returns true if the event date has passed
    var isPast: Bool {
        return daysUntil < 0
    }
}

