//
//  DayLabel.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// Names the pickup day so a window is never ambiguous: "Today", "Tonight", "Tomorrow", "Wed Sep 23".
/// Used as section headers and in rows.
public struct DayLabel: View {
    let text: String
    let day: PickupDayFormatter.Day

    public init(_ text: String, day: PickupDayFormatter.Day) {
        self.text = text
        self.day = day
    }

    public var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(color)
            .accessibilityLabel("Pickup \(text)")
    }

    private var symbol: String {
        switch day {
        case .today: "sun.max.fill"
        case .tonight: "moon.stars.fill"
        case .tomorrow: "sunrise.fill"
        case .other: "calendar"
        }
    }

    private var color: Color {
        switch day {
        case .today: .orange
        case .tonight: .indigo
        case .tomorrow: .splashTeal
        case .other: .secondary
        }
    }
}

#Preview("Light") {
    VStack(alignment: .leading, spacing: 12) {
        DayLabel("Today", day: .today)
        DayLabel("Tonight", day: .tonight)
        DayLabel("Tomorrow", day: .tomorrow)
        DayLabel("Wed Sep 23", day: .other(.distantPast))
    }
    .padding()
}

#Preview("Dark · large text") {
    VStack(alignment: .leading, spacing: 12) {
        DayLabel("Tonight", day: .tonight)
        DayLabel("Tomorrow", day: .tomorrow)
    }
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
