//
//  EventDetailView.swift
//  FutureJoy
//
//  Created by Hoang Nguyen on 12/6/25.
//

import SwiftUI
import SwiftData
import Combine

struct EventDetailView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeRemaining: (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let interval = max(event.date.timeIntervalSince(now), 0)
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return (days, hours, minutes, seconds)
    }
    
    private var formattedDate: String {
        EventDetailView.dateFormatter.string(from: event.date)
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()
    
    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.98)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    
                    VStack(spacing: 16) {
                        dateCard
                        locationCard
                        notesCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .onReceive(timer) { newDate in
            now = newDate
        }
        .navigationBarBackButtonHidden(true)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(navBarColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            ToolbarItem(placement: .principal) {
                navTitle
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            countdownCard
                .padding(.horizontal, 4)
                .offset(y: 40)
        }
        .padding(.bottom, 56)
    }

    private var navBarColor: Color {
        Color(red: 0.58, green: 0.38, blue: 0.94)
    }
    
    private var navTitle: some View {
        HStack(spacing: 8) {
            Text(event.emoji)
                .font(.system(size: 20))
            Text(event.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.32, green: 0.32, blue: 0.38))
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Countdown
    private var countdownCard: some View {
        VStack(spacing: 16) {
            Text("Time Until Event")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(spacing: 12) {
                countdownSegment(value: timeRemaining.days, label: "Days")
                countdownSegment(value: timeRemaining.hours, label: "Hours")
                countdownSegment(value: timeRemaining.minutes, label: "Mins")
                countdownSegment(value: timeRemaining.seconds, label: "Secs")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.45, green: 0.40, blue: 0.95),
                    Color(red: 0.56, green: 0.44, blue: 0.93)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
    
    private func countdownSegment(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - Info Cards
    private var dateCard: some View {
        infoCard(
            title: "Date",
            systemImage: "calendar",
            iconColor: Color(red: 0.32, green: 0.55, blue: 1.0)
        ) {
            Text(formattedDate)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
        }
    }
    
    private var locationCard: some View {
        infoCard(
            title: "Location",
            systemImage: "mappin.and.ellipse",
            iconColor: Color(red: 0.62, green: 0.42, blue: 0.95)
        ) {
            if let location = event.location, !location.isEmpty {
                Text(location)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .multilineTextAlignment(.leading)
            } else {
                Text("No location added")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
            }
        }
    }
    
    private var notesCard: some View {
        infoCard(
            title: "Notes",
            systemImage: "note.text",
            iconColor: Color(red: 0.99, green: 0.74, blue: 0.37)
        ) {
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No notes yet")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    @ViewBuilder
    private func infoCard<Content: View>(
        title: String,
        systemImage: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.92, green: 0.92, blue: 0.94), lineWidth: 1)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Event.self, configurations: config)
    
    let sample = Event(
        title: "Concert Night",
        emoji: "🎸",
        date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
        location: "Madison Square Garden, New York",
        notes: """
        VIP tickets confirmed!
        Meet Sarah at 7:00 PM
        Doors open at 7:30 PM
        Show starts at 8:30 PM
        
        Parking: Lot B pre-paid
        """
    )
    container.mainContext.insert(sample)
    
    return NavigationStack {
        EventDetailView(event: sample)
    }
    .modelContainer(container)
}
