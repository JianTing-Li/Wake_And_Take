//
//  PricePin.swift
//  WalkAndTakeKit
//

import Domain
import SwiftUI

/// A map annotation showing a bag's price, colored by whether it's open now.
public struct PricePin: View {
    public enum State: Hashable, Sendable {
        /// Open for pickup and in stock (teal).
        case openNow
        /// Reservable but not open yet (orange).
        case opensLater
        /// Sold out or ended (gray, reads "Gone").
        case gone

        var color: Color {
            switch self {
            case .openNow: .splashTeal
            case .opensLater: .orange
            case .gone: .gray
            }
        }
    }

    let category: FoodCategory
    let price: Money
    let state: State
    let isSelected: Bool
    let accessibilityText: String

    public init(category: FoodCategory, price: Money, state: State, isSelected: Bool, accessibilityText: String) {
        self.category = category
        self.price = price
        self.state = state
        self.isSelected = isSelected
        self.accessibilityText = accessibilityText
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: category.symbol).font(.caption2)
                Text(state == .gone ? "Gone" : price.usd)
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(state.color, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: isSelected ? 3 : 1.5))

            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(state.color)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
        .foregroundStyle(.white)
        .scaleEffect(isSelected ? 1.2 : 1, anchor: .bottom)
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .zIndex(isSelected ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Light") {
    HStack(spacing: 16) {
        PricePin(
            category: .breakfast, price: Money(cents: 599), state: .openNow, isSelected: false, accessibilityText: "")
        PricePin(category: .meal, price: Money(cents: 899), state: .opensLater, isSelected: true, accessibilityText: "")
        PricePin(category: .bakery, price: Money(cents: 699), state: .gone, isSelected: false, accessibilityText: "")
    }
    .padding(30)
    .background(Color(.systemGray5))
}

#Preview("Dark · large text") {
    PricePin(category: .coffee, price: Money(cents: 449), state: .openNow, isSelected: false, accessibilityText: "")
        .padding(30)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
