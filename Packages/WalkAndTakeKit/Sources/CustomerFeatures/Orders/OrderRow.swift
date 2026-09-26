//
//  OrderRow.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import Foundation
import Platform
import SwiftUI

/// One order in the list, worded from its snapshot.
public struct OrderRowContent: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let restaurantName: String
    public let bagsText: String
    public let category: FoodCategory
    public let statusText: String
    public let tone: PickupStatusPill.Tone
    public let rating: Int?
    public let showsRatePrompt: Bool

    init(_ reservation: Reservation, now: Date, flags: FeatureFlags) {
        let snapshot = reservation.snapshot
        id = reservation.id
        restaurantName = snapshot.restaurantName
        bagsText = "\(reservation.quantity) × \(snapshot.bagName)"
        category = snapshot.category
        (statusText, tone) = Self.status(of: reservation, now: now)
        rating = flags.reviews ? reservation.review?.overall : nil
        showsRatePrompt = flags.reviews && ReviewPolicy.canReview(reservation, at: now)
    }

    /// "Ready now · Ends in 20 min", "Opens tomorrow at 7:30 AM", "Picked up", …
    static func status(of reservation: Reservation, now: Date) -> (String, PickupStatusPill.Tone) {
        let countdown = PickupDayFormatter.countdown(
            reservation.snapshot.pickupWindow, now: now, calendar: NYCalendar.calendar)
        return switch ReservationPolicy.status(of: reservation, at: now) {
        case .readyNow: ("Ready now · \(countdown)", .readyNow)
        case .upcoming: (countdown, .upcoming)
        case .collected: ("Picked up", .collected)
        case .missed: ("Missed pickup", .inactive)
        case .cancelled: ("Cancelled", .inactive)
        }
    }
}

struct OrderRow: View {
    let content: OrderRowContent

    var body: some View {
        HStack(spacing: Spacing.m) {
            CategoryTile(category: content.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(content.restaurantName).font(.headline)
                Text(content.bagsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                PickupStatusPill(
                    text: content.statusText, tone: content.tone, rating: content.rating,
                    showsRatePrompt: content.showsRatePrompt)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
