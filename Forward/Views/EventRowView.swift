//
//  EventRowView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/5/25.
//

import SwiftUI

struct EventRowView: View {
    let event: Event
    let onDelete: () -> Void
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: event.date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Emoji + Title + Delete button
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Text(event.emoji)
                        .font(.system(size: 24))
                    
                    Text(event.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                }
            }
            
            // Date
            Text(formattedDate)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            
            // Location (if available)
            if let location = event.location, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    Text(location)
                        .font(.system(size: 15))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            // Days counter badge
            daysCounterBadge
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 0.92, green: 0.92, blue: 0.94), lineWidth: 1)
        )
    }
    
    // MARK: - Days Counter Badge
    private var daysCounterBadge: some View {
        VStack(spacing: 2) {
            Text("\(event.daysUntil)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
            
            Text(event.daysUntil == 1 ? "day" : "days")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 100, height: 80)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.45, green: 0.40, blue: 0.95),
                    Color(red: 0.55, green: 0.45, blue: 0.92)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    VStack(spacing: 16) {
        EventRowView(
            event: Event(
                title: "Concert Night",
                emoji: "🎸",
                date: Calendar.current.date(byAdding: .day, value: 11, to: Date())!
            ),
            onDelete: {}
        )
        
        EventRowView(
            event: Event(
                title: "Birthday Party",
                emoji: "🎂",
                date: Calendar.current.date(byAdding: .day, value: 38, to: Date())!
            ),
            onDelete: {}
        )
    }
    .padding()
    .background(Color(red: 0.97, green: 0.97, blue: 0.98))
}

