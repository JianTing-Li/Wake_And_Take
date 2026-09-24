//
//  BagCard.swift
//  WakeAndTakeKit
//

import Domain
import SwiftUI

/// The Discover list card for one offer.
public struct BagCard: View {
    /// Everything the card shows, already worded by the screen's view model.
    public struct Content: Hashable, Sendable {
        public var restaurantName: String
        public var bagName: String
        public var category: FoodCategory
        public var badgeText: String
        public var isUrgent: Bool
        public var savingsPercent: Int
        /// Nil hides the rating (e.g. reviews flag off).
        public var rating: Double?
        public var reviewCount: Int
        /// Day-aware window, e.g. "Tomorrow · 7:30–10:00 AM".
        public var pickupText: String
        /// e.g. "0.2 mi away".
        public var distanceText: String
        public var price: Money
        public var estimatedValue: Money
        /// Reservable; otherwise the card is dimmed and the discount hidden.
        public var isAvailable: Bool
        public var fitsCommute: Bool

        public init(
            restaurantName: String, bagName: String, category: FoodCategory, badgeText: String,
            isUrgent: Bool, savingsPercent: Int, rating: Double?, reviewCount: Int, pickupText: String,
            distanceText: String, price: Money, estimatedValue: Money, isAvailable: Bool, fitsCommute: Bool
        ) {
            self.restaurantName = restaurantName
            self.bagName = bagName
            self.category = category
            self.badgeText = badgeText
            self.isUrgent = isUrgent
            self.savingsPercent = savingsPercent
            self.rating = rating
            self.reviewCount = reviewCount
            self.pickupText = pickupText
            self.distanceText = distanceText
            self.price = price
            self.estimatedValue = estimatedValue
            self.isAvailable = isAvailable
            self.fitsCommute = fitsCommute
        }
    }

    let content: Content
    var isFavorite: Bool
    var onToggleFavorite: (() -> Void)?

    public init(_ content: Content, isFavorite: Bool = false, onToggleFavorite: (() -> Void)? = nil) {
        self.content = content
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            details.padding(Spacing.m)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .opacity(content.isAvailable ? 1 : 0.55)
        .accessibilityElement(children: .combine)
    }

    /// 100 pt tall like the draft, but grows with large text so the badge never clips.
    private var header: some View {
        HStack(alignment: .top) {
            StatusBadge(text: content.badgeText, isUrgent: content.isUrgent)
            if content.isAvailable {
                Text("-\(content.savingsPercent)%")
                    .font(.caption.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.yolk, in: Capsule())
                    .foregroundStyle(.black)
                    .fixedSize()
            }
            Spacer()
            if let onToggleFavorite {
                FavoriteButton(isFavorite: isFavorite, action: onToggleFavorite)
            }
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background { CategoryGradient(category: content.category, symbolSize: 42) }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.restaurantName).font(.headline)
                Spacer()
                if let rating = content.rating {
                    Label(String(format: "%.1f (%d)", rating, content.reviewCount), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(content.bagName).font(.subheadline).foregroundStyle(.secondary)
            if content.fitsCommute && content.isAvailable {
                Label("Fits your commute", systemImage: "tram.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.splashTeal)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.splashTeal.opacity(0.12), in: Capsule())
            }

            // Stacks vertically at large text sizes so times and prices never truncate.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom) {
                    meta
                    Spacer()
                    PriceStack(price: content.price, estimatedValue: content.estimatedValue, size: .title3)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    meta
                    PriceStack(price: content.price, estimatedValue: content.estimatedValue, size: .title3)
                }
            }
            .padding(.top, 2)
        }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(content.pickupText, systemImage: "clock")
            Label(content.distanceText, systemImage: "figure.walk")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Light") {
    ScrollView {
        VStack(spacing: 14) {
            BagCard(PreviewSamples.bagCard, isFavorite: true) {}
            BagCard(PreviewSamples.bagCardUrgent) {}
            BagCard(PreviewSamples.bagCardSoldOut)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark") {
    BagCard(PreviewSamples.bagCard, isFavorite: false) {}
        .padding()
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    ScrollView {
        BagCard(PreviewSamples.bagCardTomorrow) {}.padding()
    }
    .background(Color(.systemGroupedBackground))
    .dynamicTypeSize(.accessibility3)
}
