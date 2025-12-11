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
    let selectionMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    init(
        event: Event,
        onDelete: @escaping () -> Void,
        selectionMode: Bool = false,
        isSelected: Bool = false,
        onToggleSelection: @escaping () -> Void = {}
    ) {
        self.event = event
        self.onDelete = onDelete
        self.selectionMode = selectionMode
        self.isSelected = isSelected
        self.onToggleSelection = onToggleSelection
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: event.date)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            daysCounterBadge
                .frame(width: 100, height: 100, alignment: .center)
            
            VStack(alignment: .leading, spacing: 8) {
                // Top row: Emoji + Title + Delete / Select button
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Text(event.emoji)
                            .font(.system(size: 24))
                        
                        Text(event.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                    }
                    
                    Spacer()
                    
                    if selectionMode {
                        selectionCheckbox
                    } else {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.75))
                        }
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
                
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    selectionMode
                    ? (isSelected ? Color(red: 0.35, green: 0.45, blue: 0.95) : Color(red: 0.65, green: 0.60, blue: 0.95).opacity(0.35))
                    : Color(red: 0.65, green: 0.60, blue: 0.95).opacity(0.6),
                    lineWidth: isSelected ? 2 : 1.25
                )
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Selection Checkbox
    private var selectionCheckbox: some View {
        Button {
            onToggleSelection()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.7, green: 0.7, blue: 0.75), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected
                                ? LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.35, green: 0.45, blue: 0.95),
                                        Color(red: 0.55, green: 0.35, blue: 0.92)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white,
                                        Color.white
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .frame(width: 26, height: 26)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Days Counter Badge
    private var daysCounterBadge: some View {
        // Ensure we return a concrete View by building inside a closure
        let build: () -> AnyView = {
            let days = event.daysUntil
            let value = abs(days)
            let isPast = days < 0
            
            let view = VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                
                let label: String = {
                    if isPast {
                        return value == 1 ? "day ago" : "days ago"
                    } else {
                        return value == 1 ? "day" : "days"
                    }
                }()
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 100, height: 100)
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
            
            return AnyView(view)
        }
        return build()
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

