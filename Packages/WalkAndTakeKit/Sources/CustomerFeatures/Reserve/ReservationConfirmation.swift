//
//  ReservationConfirmation.swift
//  WalkAndTakeKit
//

import DesignSystem
import Domain
import Foundation
import Platform

/// What the confirmation sheet shows, worded from the reservation's snapshot.
public struct ReservationConfirmation: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let restaurantName: String
    public let code: String
    /// "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM"
    public let pickupText: String
    public let pickupInstructions: String
    public let address: String
    public let bagsText: String
    public let totalText: String
    /// "Free changes and cancellation until 9:50 AM. …", or nil when changes are off.
    public let policyText: String

    init(reservation: Reservation, now: Date, showsChangePolicy: Bool) {
        let snapshot = reservation.snapshot
        let calendar = NYCalendar.calendar
        id = reservation.id
        restaurantName = snapshot.restaurantName
        code = reservation.confirmationCode
        pickupText = PickupDayFormatter.full(snapshot.pickupWindow, now: now, calendar: calendar)
        pickupInstructions = snapshot.pickupInstructions
        address = snapshot.address.shortLine
        bagsText = "\(reservation.quantity) × \(snapshot.bagName)"
        totalText = reservation.total.usd
        let findIt = "Find this order anytime in the Orders tab."
        if showsChangePolicy {
            let deadline = TimeText.time(ReservationPolicy.changeDeadline(for: reservation), calendar: calendar)
            policyText = "Free changes and cancellation until \(deadline). \(findIt)"
        } else {
            policyText = findIt
        }
    }
}
