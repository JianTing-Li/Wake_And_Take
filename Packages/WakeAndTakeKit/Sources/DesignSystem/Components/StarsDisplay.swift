//
//  StarsDisplay.swift
//  WakeAndTakeKit
//

import SwiftUI

/// Read-only stars for showing a rating that's already been given.
public struct StarsDisplay: View {
    let rating: Int
    var size: CGFloat

    public init(rating: Int, size: CGFloat = 14) {
        self.rating = rating
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yolk : Color.secondary.opacity(0.5))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(rating) of 5 stars")
    }
}

#Preview("Light") {
    VStack(spacing: 8) {
        StarsDisplay(rating: 4, size: 22)
        StarsDisplay(rating: 2, size: 10)
    }
    .padding()
}

#Preview("Dark · large text") {
    StarsDisplay(rating: 5).padding().preferredColorScheme(.dark).dynamicTypeSize(.accessibility2)
}
