//
//  PickupSections.swift
//  WalkAndTakeKit
//
//  The pickup screen's cards: code + QR, steps, and rating.
//

import DesignSystem
import Domain
import SwiftUI

struct PickupCodeCard: View {
    let code: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Pickup code").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(code)
                .font(.pickupCode(size: 48))
                .tracking(10)
                .accessibilityLabel("Pickup code \(code.map(String.init).joined(separator: " "))")
                .accessibilityIdentifier("pickup.code")
            QRCodeView(text: code, size: 150)
            Text("Show this to staff at the counter")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.yolk.opacity(0.25), in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

struct PickupSteps: View {
    let restaurantName: String
    let addressLine: String
    let instructions: String
    let directionsURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            step(1, "Head to \(restaurantName)", detail: addressLine) {
                if let directionsURL {
                    Link(destination: directionsURL) {
                        Label("Get directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            step(2, "Show your pickup code", detail: instructions)
            step(3, "Confirm pickup together", detail: "Swipe below while you're at the counter.")
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func step(
        _ n: Int, _ title: String, detail: String, @ViewBuilder extra: () -> some View = { EmptyView() }
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Text("\(n)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.splashTeal, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
                extra()
            }
        }
    }
}

struct RatingCard: View {
    let restaurantName: String
    let review: Review?
    let canReview: Bool
    let onRate: @MainActor @Sendable (Int) -> Void

    var body: some View {
        if let review {
            VStack(spacing: 8) {
                Text("You rated this bag").font(.headline)
                StarsDisplay(rating: review.overall, size: 22)
                if !review.tags.isEmpty {
                    Text(ReviewTag.allCases.filter(review.tags.contains).map(\.label).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.l)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.card))
        } else if canReview {
            VStack(spacing: Spacing.s) {
                Text("How was your bag?").font(.headline)
                StarRating(rating: Binding(get: { 0 }, set: onRate), size: 34, label: "Rate your bag")
                Text("Tap a star to rate \(restaurantName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.l)
            .background(Color.yolk.opacity(0.2), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}
