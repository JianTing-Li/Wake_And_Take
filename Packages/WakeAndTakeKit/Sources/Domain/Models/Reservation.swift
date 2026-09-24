//
//  Reservation.swift
//  WakeAndTakeKit
//

import Foundation

public enum CancelReason: String, CaseIterable, Identifiable, Codable, Sendable {
    case plansChanged, tooFar, orderedByMistake, other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .plansChanged: "My plans changed"
        case .tooFar: "It's out of my way"
        case .orderedByMistake: "I ordered by mistake"
        case .other: "Other"
        }
    }
}

/// A customer's hold on one or more bags from a single offer.
/// Status rules live in `ReservationPolicy`.
public struct Reservation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// 4 characters from `PickupCodeGenerator`'s alphabet.
    public let confirmationCode: String
    public var quantity: Int
    public let snapshot: OfferSnapshot
    public let reservedAt: Date
    public var collectedAt: Date?
    public var cancelledAt: Date?
    public var cancelReason: CancelReason?
    public var review: Review?

    public init(
        id: UUID,
        confirmationCode: String,
        quantity: Int,
        snapshot: OfferSnapshot,
        reservedAt: Date,
        collectedAt: Date? = nil,
        cancelledAt: Date? = nil,
        cancelReason: CancelReason? = nil,
        review: Review? = nil
    ) {
        self.id = id
        self.confirmationCode = confirmationCode
        self.quantity = quantity
        self.snapshot = snapshot
        self.reservedAt = reservedAt
        self.collectedAt = collectedAt
        self.cancelledAt = cancelledAt
        self.cancelReason = cancelReason
        self.review = review
    }

    public var total: Money { snapshot.unitPrice * quantity }
    public var savings: Money { (snapshot.estimatedValue - snapshot.unitPrice) * quantity }
}
