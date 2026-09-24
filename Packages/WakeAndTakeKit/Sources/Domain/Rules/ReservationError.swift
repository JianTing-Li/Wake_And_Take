//
//  ReservationError.swift
//  WakeAndTakeKit
//

import Foundation

/// Why a reservation action was refused.
public enum ReservationError: Error, Hashable, Sendable {
    // Reserving
    case soldOut
    case windowClosed
    case notVisibleYet
    case invalidQuantity

    // Changing, cancelling or collecting an existing reservation
    case reservationNotFound
    /// Past the change deadline, or the order is no longer active.
    case changeClosed
    /// The live offer was pruned; only possible after its window ended.
    case offerNoLongerExists
    case notReadyForPickup
}
