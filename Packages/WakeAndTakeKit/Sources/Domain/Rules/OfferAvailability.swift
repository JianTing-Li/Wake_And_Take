//
//  OfferAvailability.swift
//  WakeAndTakeKit
//

import Foundation

/// Where an offer stands right now, combining stock and its pickup window.
public enum OfferAvailability {
    public enum Status: Hashable, Sendable {
        /// Not open yet, still reservable.
        case upcoming
        case available
        /// Open with `almostGoneThreshold` or fewer bags left.
        case almostGone
        /// Open with less than `endingSoonThreshold` left in the window.
        case endingSoon
        case soldOut
        case ended

        /// Whether a customer can still reserve it (visibility aside).
        public var isReservable: Bool {
            switch self {
            case .upcoming, .available, .almostGone, .endingSoon: true
            case .soldOut, .ended: false
            }
        }

        /// Open for pickup and in stock.
        public var isOpenNow: Bool {
            switch self {
            case .available, .almostGone, .endingSoon: true
            case .upcoming, .soldOut, .ended: false
            }
        }
    }

    public static let endingSoonThreshold: TimeInterval = 30 * 60
    public static let almostGoneThreshold = 1

    /// Sold out wins over ended, matching the draft's copy; ending soon wins over almost gone.
    public static func status(of offer: Offer, at now: Date) -> Status {
        let window = offer.pickupWindow
        if offer.isSoldOut { return .soldOut }
        if window.hasEnded(at: now) { return .ended }
        if !window.hasStarted(at: now) { return .upcoming }
        if window.end.timeIntervalSince(now) < endingSoonThreshold { return .endingSoon }
        if offer.quantityLeft <= almostGoneThreshold { return .almostGone }
        return .available
    }

    /// Short status: "Sold out", or the window countdown ("Ends in 25 min", "Opens at 7:30 AM").
    public static func urgencyText(for offer: Offer, at now: Date, calendar: Calendar) -> String {
        offer.isSoldOut
            ? "Sold out"
            : PickupDayFormatter.countdown(offer.pickupWindow, now: now, calendar: calendar)
    }

    /// Badge copy: "3 left" while open and not urgent, otherwise the urgency text.
    public static func badgeText(for offer: Offer, at now: Date, calendar: Calendar) -> String {
        switch status(of: offer, at: now) {
        case .available, .almostGone: "\(offer.quantityLeft) left"
        case .upcoming, .endingSoon, .soldOut, .ended: urgencyText(for: offer, at: now, calendar: calendar)
        }
    }
}
