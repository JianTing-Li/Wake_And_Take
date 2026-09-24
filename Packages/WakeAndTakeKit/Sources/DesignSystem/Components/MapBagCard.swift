//
//  MapBagCard.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// The floating card shown when a map pin is selected.
public struct MapBagCard: View {
    public struct Content: Hashable, Sendable {
        public var restaurantName: String
        public var bagName: String
        public var category: FoodCategory
        /// e.g. "Ends in 25 min · 0.3 mi".
        public var statusLine: String
        public var isUrgent: Bool
        public var price: Money
        public var estimatedValue: Money
        public var isAvailable: Bool

        public init(
            restaurantName: String, bagName: String, category: FoodCategory, statusLine: String,
            isUrgent: Bool, price: Money, estimatedValue: Money, isAvailable: Bool
        ) {
            self.restaurantName = restaurantName
            self.bagName = bagName
            self.category = category
            self.statusLine = statusLine
            self.isUrgent = isUrgent
            self.price = price
            self.estimatedValue = estimatedValue
            self.isAvailable = isAvailable
        }
    }

    let content: Content
    let onView: () -> Void
    let onClose: () -> Void

    public init(_ content: Content, onView: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.content = content
        self.onView = onView
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top, spacing: Spacing.m) {
                CategoryTile(category: content.category, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(content.restaurantName).font(.headline)
                    Text(content.bagName).font(.subheadline).foregroundStyle(.secondary)
                    Text(content.statusLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(content.isUrgent ? .red : .secondary)
                }

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    prices
                    Spacer()
                    viewButton
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    prices
                    viewButton
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.floating))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private var prices: some View {
        HStack {
            Text(content.estimatedValue.usd)
                .strikethrough()
                .foregroundStyle(.secondary)
            Text(content.price.usd)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.splashTeal)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private var viewButton: some View {
        Button(action: onView) {
            Text(content.isAvailable ? "View bag" : "See details")
                .font(.headline)
                .padding(.horizontal, 18).padding(.vertical, Spacing.s)
                .background(content.isAvailable ? Color.splashTeal : .gray, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Light") {
    MapBagCard(PreviewSamples.mapCard, onView: {}, onClose: {})
        .padding()
        .background(Color(.systemGray5))
}

#Preview("Dark") {
    MapBagCard(PreviewSamples.mapCard, onView: {}, onClose: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    MapBagCard(PreviewSamples.mapCard, onView: {}, onClose: {})
        .padding()
        .dynamicTypeSize(.accessibility3)
}
