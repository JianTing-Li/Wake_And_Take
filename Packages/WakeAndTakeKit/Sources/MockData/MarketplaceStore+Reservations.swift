//
//  MarketplaceStore+Reservations.swift
//  WakeAndTakeKit
//

import Domain
import Foundation
import Platform
import SwiftData

extension MarketplaceStore {
    /// Reserves bags if the offer is visible, open and in stock. Throws `ReservationError`.
    public func reserve(offerID: String, quantity: Int, at now: Date) throws -> Reservation {
        guard let offer = try offerEntity(id: offerID) else { throw ReservationError.offerNoLongerExists }
        try ReservationPolicy.validateReservation(of: offer.domain, quantity: quantity, at: now, calendar: calendar)
        guard let restaurant = try restaurantEntity(id: offer.restaurantID)?.domain else {
            throw ReservationError.offerNoLongerExists
        }

        let reservation = Reservation(
            id: UUID(),
            confirmationCode: codes.makeCode(),
            quantity: quantity,
            snapshot: OfferSnapshot(offer: offer.domain, restaurant: restaurant),
            reservedAt: now
        )
        offer.quantityReserved += quantity
        modelContext.insert(ReservationEntity(reservation))
        try save()

        broadcaster.send(.stockChanged(offerID: offerID))
        broadcaster.send(.reservationsChanged)
        return reservation
    }

    /// Changes how many bags are held; the difference goes back to or comes from stock.
    public func changeQuantity(reservationID: UUID, to quantity: Int, at now: Date) throws -> Reservation {
        guard let entity = try reservationEntity(id: reservationID) else { throw ReservationError.reservationNotFound }
        var reservation = entity.domain
        guard ReservationPolicy.canChange(reservation, at: now) else { throw ReservationError.changeClosed }
        guard let offer = try offerEntity(id: entity.offerID) else { throw ReservationError.offerNoLongerExists }
        try ReservationPolicy.validateChange(
            of: reservation, to: quantity, offerQuantityLeft: offer.quantityLeft, at: now)

        offer.quantityReserved += quantity - reservation.quantity
        reservation.quantity = quantity
        entity.apply(reservation)
        try save()

        broadcaster.send(.stockChanged(offerID: offer.id))
        broadcaster.send(.reservationsChanged)
        return reservation
    }

    /// Cancels the order and puts its bags back on sale.
    public func cancel(reservationID: UUID, reason: CancelReason?, at now: Date) throws -> Reservation {
        guard let entity = try reservationEntity(id: reservationID) else { throw ReservationError.reservationNotFound }
        var reservation = entity.domain
        try ReservationPolicy.validateCancel(of: reservation, at: now)
        guard let offer = try offerEntity(id: entity.offerID) else { throw ReservationError.offerNoLongerExists }

        offer.quantityReserved = max(0, offer.quantityReserved - reservation.quantity)
        reservation.cancelledAt = now
        reservation.cancelReason = reason
        entity.apply(reservation)
        try save()

        broadcaster.send(.stockChanged(offerID: offer.id))
        broadcaster.send(.reservationsChanged)
        return reservation
    }

    /// Confirms pickup at the counter; only allowed during the pickup window.
    public func markCollected(reservationID: UUID, at now: Date) throws -> Reservation {
        guard let entity = try reservationEntity(id: reservationID) else { throw ReservationError.reservationNotFound }
        var reservation = entity.domain
        try ReservationPolicy.validateCollect(of: reservation, at: now)

        reservation.collectedAt = now
        entity.apply(reservation)
        try save()

        broadcaster.send(.reservationsChanged)
        return reservation
    }

    /// Saves a rating and folds it into the restaurant's average in the same save.
    /// Throws `ReviewError`.
    public func submitReview(_ review: Review, for reservationID: UUID, at now: Date) throws -> Restaurant? {
        guard let entity = try reservationEntity(id: reservationID) else { throw ReviewError.notEligible }
        var reservation = entity.domain
        try ReviewPolicy.validate(review, for: reservation, at: now)

        var saved = review
        saved.submittedAt = now
        reservation.review = saved
        entity.apply(reservation)

        let restaurant = try restaurantEntity(id: entity.restaurantID)
        if let restaurant {
            let folded = ReviewPolicy.foldedRating(
                rating: restaurant.rating, reviewCount: restaurant.reviewCount, adding: review.overall)
            restaurant.rating = folded.rating
            restaurant.reviewCount = folded.reviewCount
        }
        try save()

        broadcaster.send(.reservationsChanged)
        broadcaster.send(.ratingChanged(restaurantID: entity.restaurantID))
        return restaurant?.domain
    }
}
