//
//  FakeMarketplace.swift
//  CustomerFeaturesTests
//
//  In-memory marketplace: applies the real policies and emits changes on mutation.
//

import Domain
import Foundation
import Platform
import Synchronization

@testable import CustomerFeatures

/// Marketplace fake: applies the real visibility rule and emits changes on mutation.
nonisolated final class FakeMarketplace: OfferRepository, ReservationRepository, ReviewRepository, Sendable {
    private struct State {
        var offers: [Offer] = []
        var restaurants: [Restaurant] = []
        var reservations: [Reservation] = []
        var failReads = false
        var nextReserveError: (any Error)?
        var codes = 0
    }

    private let state: Mutex<State>
    private let broadcaster = Broadcaster<MarketplaceChange>()

    init(offers: [Offer] = [], restaurants: [Restaurant] = Fixture.restaurants) {
        state = Mutex(State(offers: offers, restaurants: restaurants))
    }

    func set(offers: [Offer]) {
        state.withLock { $0.offers = offers }
        broadcaster.send(.rolledOver)
    }

    func failReads(_ fail: Bool) { state.withLock { $0.failReads = fail } }

    /// Makes the next `reserve` throw `error` instead of reserving.
    func failNextReserve(with error: any Error) { state.withLock { $0.nextReserveError = error } }

    var reservationCount: Int { state.withLock { $0.reservations.count } }

    private func read<T>(_ body: (State) -> T) throws -> T {
        try state.withLock { s in
            if s.failReads { throw TestError() }
            return body(s)
        }
    }

    // OfferRepository
    func offers(visibleAt now: Date) async throws -> [Offer] {
        try read { $0.offers.filter { OfferVisibility.isVisible($0, at: now, calendar: NYCalendar.calendar) } }
    }
    func offer(id: String) async throws -> Offer? { try read { $0.offers.first { $0.id == id } } }
    func restaurants() async throws -> [Restaurant] { try read(\.restaurants) }
    func restaurant(id: String) async throws -> Restaurant? { try read { $0.restaurants.first { $0.id == id } } }
    func changes() -> AsyncStream<MarketplaceChange> { broadcaster.stream() }

    // ReservationRepository (filled in by later sub-phases)
    func reserve(offerID: String, quantity: Int, at now: Date) async throws -> Reservation {
        let reservation = try state.withLock { s -> Reservation in
            if let error = s.nextReserveError {
                s.nextReserveError = nil
                throw error
            }
            guard let index = s.offers.firstIndex(where: { $0.id == offerID }),
                let restaurant = s.restaurants.first(where: { $0.id == s.offers[index].restaurantID })
            else { throw ReservationError.offerNoLongerExists }
            try ReservationPolicy.validateReservation(
                of: s.offers[index], quantity: quantity, at: now, calendar: NYCalendar.calendar)
            s.offers[index].quantityReserved += quantity
            s.codes += 1
            let reservation = Reservation(
                id: UUID(), confirmationCode: "AB2\(s.codes)", quantity: quantity,
                snapshot: OfferSnapshot(offer: s.offers[index], restaurant: restaurant), reservedAt: now)
            s.reservations.append(reservation)
            return reservation
        }
        broadcaster.send(.stockChanged(offerID: offerID))
        broadcaster.send(.reservationsChanged)
        return reservation
    }
    func changeQuantity(reservationID: UUID, to quantity: Int, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { s, r, offerIndex in
            let left = offerIndex.map { s.offers[$0].quantityLeft } ?? 0
            try ReservationPolicy.validateChange(of: r, to: quantity, offerQuantityLeft: left, at: now)
            if let i = offerIndex { s.offers[i].quantityReserved += quantity - r.quantity }
            r.quantity = quantity
        }
    }
    func cancel(reservationID: UUID, reason: CancelReason?, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { s, r, offerIndex in
            try ReservationPolicy.validateCancel(of: r, at: now)
            if let i = offerIndex { s.offers[i].quantityReserved -= r.quantity }
            r.cancelledAt = now
            r.cancelReason = reason
        }
    }
    func markCollected(reservationID: UUID, at now: Date) async throws -> Reservation {
        try mutate(reservationID) { _, r, _ in
            try ReservationPolicy.validateCollect(of: r, at: now)
            r.collectedAt = now
        }
    }

    /// Adds a reservation directly (as if made earlier) and takes its stock.
    @discardableResult
    func add(_ reservation: Reservation) -> Reservation {
        state.withLock { s in
            s.reservations.insert(reservation, at: 0)
            if let i = s.offers.firstIndex(where: { $0.id == reservation.snapshot.offerID }) {
                s.offers[i].quantityReserved += reservation.quantity
            }
        }
        broadcaster.send(.reservationsChanged)
        return reservation
    }

    func offerLeft(_ id: String) -> Int? { state.withLock { s in s.offers.first { $0.id == id }?.quantityLeft } }

    private func mutate(
        _ id: UUID, _ change: (inout State, inout Reservation, Int?) throws -> Void
    ) throws -> Reservation {
        let updated = try state.withLock { s -> Reservation in
            if let error = s.nextReserveError {
                s.nextReserveError = nil
                throw error
            }
            guard let index = s.reservations.firstIndex(where: { $0.id == id }) else {
                throw ReservationError.reservationNotFound
            }
            var reservation = s.reservations[index]
            let offerIndex = s.offers.firstIndex { $0.id == reservation.snapshot.offerID }
            try change(&s, &reservation, offerIndex)
            s.reservations[index] = reservation
            return reservation
        }
        broadcaster.send(.reservationsChanged)
        return updated
    }
    func reservations() async throws -> [Reservation] { try read(\.reservations) }
    func reservation(id: UUID) async throws -> Reservation? { try read { $0.reservations.first { $0.id == id } } }

    // ReviewRepository
    func submitReview(_ review: Review, for reservationID: UUID, at now: Date) async throws -> Restaurant? {
        let restaurant = try state.withLock { s -> Restaurant? in
            guard let index = s.reservations.firstIndex(where: { $0.id == reservationID }) else {
                throw ReviewError.notEligible
            }
            try ReviewPolicy.validate(review, for: s.reservations[index], at: now)
            s.reservations[index].review = review
            guard let r = s.restaurants.firstIndex(where: { $0.id == s.reservations[index].snapshot.restaurantID })
            else { return nil }
            let folded = ReviewPolicy.foldedRating(
                rating: s.restaurants[r].rating, reviewCount: s.restaurants[r].reviewCount, adding: review.overall)
            s.restaurants[r].rating = folded.rating
            s.restaurants[r].reviewCount = folded.reviewCount
            return s.restaurants[r]
        }
        broadcaster.send(.reservationsChanged)
        return restaurant
    }

    /// Clears reservations (what a reset does to the marketplace, for these tests).
    func clearReservations() {
        state.withLock { $0.reservations = [] }
        broadcaster.send(.reset)
    }
}
