//
//  PickupStatusPill.swift
//  WalkAndTakeKit
//

import SwiftUI

/// An order row's status line, with the rating or a "Rate your bag" prompt once collected.
public struct PickupStatusPill: View {
    public enum Tone: Hashable, Sendable {
        case readyNow, upcoming, collected, inactive

        var color: Color {
            switch self {
            case .readyNow: .splashTeal
            case .upcoming: .orange
            case .collected: .green
            case .inactive: .secondary
            }
        }
    }

    let text: String
    let tone: Tone
    let rating: Int?
    let showsRatePrompt: Bool

    /// - Parameters:
    ///   - text: e.g. "Ready now · Ends in 20 min", "Opens tomorrow at 7:30 AM", "Picked up".
    ///   - rating: The customer's overall stars, if they've rated.
    ///   - showsRatePrompt: Show "· Rate your bag" (collected, not yet rated, still in the window).
    public init(text: String, tone: Tone, rating: Int? = nil, showsRatePrompt: Bool = false) {
        self.text = text
        self.tone = tone
        self.rating = rating
        self.showsRatePrompt = showsRatePrompt
    }

    public var body: some View {
        HStack(spacing: 6) {
            Text(text).foregroundStyle(tone.color)
            if let rating {
                StarsDisplay(rating: rating, size: 10)
            } else if showsRatePrompt {
                Text("· Rate your bag").foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.semibold))
    }
}

#Preview("Light") {
    VStack(alignment: .leading, spacing: 8) {
        PickupStatusPill(text: "Ready now · Ends in 20 min", tone: .readyNow)
        PickupStatusPill(text: "Opens tomorrow at 7:30 AM", tone: .upcoming)
        PickupStatusPill(text: "Picked up", tone: .collected, showsRatePrompt: true)
        PickupStatusPill(text: "Picked up", tone: .collected, rating: 4)
        PickupStatusPill(text: "Missed pickup", tone: .inactive)
        PickupStatusPill(text: "Cancelled", tone: .inactive)
    }
    .padding()
}

#Preview("Dark · large text") {
    VStack(alignment: .leading, spacing: 8) {
        PickupStatusPill(text: "Ready now · Ends in 20 min", tone: .readyNow)
        PickupStatusPill(text: "Picked up", tone: .collected, rating: 5)
    }
    .padding()
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
