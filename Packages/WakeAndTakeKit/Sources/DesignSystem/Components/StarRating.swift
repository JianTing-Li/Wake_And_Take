//
//  StarRating.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Tappable 1–5 stars, adjustable with VoiceOver swipes.
public struct StarRating: View {
    @Binding var rating: Int
    var size: CGFloat
    var label: String

    public init(rating: Binding<Int>, size: CGFloat = 24, label: String = "Rating") {
        _rating = rating
        self.size = size
        self.label = label
    }

    public var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yolk : Color.secondary.opacity(0.5))
                    .onTapGesture { rating = star }
            }
        }
        .sensoryFeedback(.selection, trigger: rating)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(rating == 0 ? "Not rated" : "\(rating) of 5 stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(5, rating + 1)
            case .decrement: rating = max(1, rating - 1)
            @unknown default: break
            }
        }
    }
}

#Preview("Light") {
    @Previewable @State var rating = 3
    VStack(spacing: 16) {
        StarRating(rating: $rating, size: 36, label: "Overall")
    }
    .padding()
}

#Preview("Dark · large text") {
    @Previewable @State var rating = 0
    StarRating(rating: $rating, size: 20, label: "Food quality")
        .padding()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
