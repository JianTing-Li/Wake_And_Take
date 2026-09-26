//
//  ReservationPolicy.swift
//  WalkAndTakeKit
//
//  All status math reads the reservation's snapshot, never the live offer.
//

import Foundation

public enum ReservationPolicy {
    public enum Status: Hashable, Sendable {
        case upcoming, readyNow, collected, missed, cancelled
    }

    /// How long before pickup ends changes are still allowed,
    /// so the store isn't left with a bag it already packed.
    public static let changeCutoff: TimeInterval = 10 * 60
    public static let maxQuantity = 3

    public static func status(of reservation: Reservation, at now: Date) -> Status {
        let window = reservation.snapshot.pickupWindow
        if reservation.cancelledAt != nil { return .cancelled }
        if reservation.collectedAt != nil { return .collected }
        if window.hasEnded(at: now) { return .missed }
        if window.hasStarted(at: now) { return .readyNow }
        return .upcoming
    }

    public static func isActive(_ reservation: Reservation, at now: Date) -> Bool {
        let status = status(of: reservation, at: now)
        return status == .upcoming || status == .readyNow
    }

    public static func changeDeadline(for reservation: Reservation) -> Date {
        reservation.snapshot.pickupWindow.end.addingTimeInterval(-changeCutoff)
    }

    /// Quantity changes and cancellation are allowed while active and before the deadline.
    public static func canChange(_ reservation: Reservation, at now: Date) -> Bool {
        isActive(reservation, at: now) && now < changeDeadline(for: reservation)
    }

    /// Pickup can only be confirmed during the window.
    public static func canCollect(_ reservation: Reservation, at now: Date) -> Bool {
        status(of: reservation, at: now) == .readyNow
    }

    /// Most bags a new reservation can hold, given the offer's stock.
    public static func maxQuantity(forNewReservationWithLeft quantityLeft: Int) -> Int {
        max(0, min(maxQuantity, quantityLeft))
    }

    /// Most bags an existing reservation can grow to: what it holds plus what's left.
    public static func maxQuantity(forChanging reservation: Reservation, offerQuantityLeft: Int) -> Int {
        min(maxQuantity, reservation.quantity + max(0, offerQuantityLeft))
    }

    /// Checks a new reservation. Order: visibility, window, stock, quantity.
    public static func validateReservation(
        of offer: Offer,
        quantity: Int,
        at now: Date,
        calendar: Calendar
    ) throws(ReservationError) {
        guard OfferVisibility.isVisible(offer, at: now, calendar: calendar) else {
            // A visible-day offer whose window ended reads as closed, not "not yet".
            throw offer.pickupWindow.hasEnded(at: now) ? .windowClosed : .notVisibleYet
        }
        guard !offer.pickupWindow.hasEnded(at: now) else { throw .windowClosed }
        guard !offer.isSoldOut else { throw .soldOut }
        guard (1...maxQuantity(forNewReservationWithLeft: offer.quantityLeft)).contains(quantity) else {
            throw .invalidQuantity
        }
    }

    /// Checks a quantity change against the deadline and the offer's stock.
    public static func validateChange(
        of reservation: Reservation,
        to newQuantity: Int,
        offerQuantityLeft: Int,
        at now: Date
    ) throws(ReservationError) {
        guard canChange(reservation, at: now) else { throw .changeClosed }
        let upper = maxQuantity(forChanging: reservation, offerQuantityLeft: offerQuantityLeft)
        guard (1...upper).contains(newQuantity) else { throw .invalidQuantity }
    }

    public static func validateCancel(of reservation: Reservation, at now: Date) throws(ReservationError) {
        guard canChange(reservation, at: now) else { throw .changeClosed }
    }

    public static func validateCollect(of reservation: Reservation, at now: Date) throws(ReservationError) {
        guard canCollect(reservation, at: now) else { throw .notReadyForPickup }
    }
}
