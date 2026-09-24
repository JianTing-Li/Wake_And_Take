//
//  StatusBadge.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// Capsule over a bag's image: "3 left", "Opens at 7:30 AM", or red "Ends in 12 min".
public struct StatusBadge: View {
    let text: String
    let isUrgent: Bool

    public init(text: String, isUrgent: Bool) {
        self.text = text
        self.isUrgent = isUrgent
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(isUrgent ? Color.red : Color.black.opacity(0.55), in: Capsule())
            .foregroundStyle(.white)
    }
}

#Preview("Light") {
    HStack {
        StatusBadge(text: "3 left", isUrgent: false)
        StatusBadge(text: "Ends in 12 min", isUrgent: true)
    }
    .padding()
    .background(FoodCategory.breakfast.tint)
}

#Preview("Dark · large text") {
    VStack {
        StatusBadge(text: "Opens tomorrow at 7:30 AM", isUrgent: false)
        StatusBadge(text: "Ends in 12 min", isUrgent: true)
    }
    .padding()
    .background(FoodCategory.bakery.tint)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
