//
//  ReservationRepository.swift
//  WakeAndTakeKit
//

import Foundation

/// Reserving and managing orders. Each mutation is atomic: stock and the
/// reservation change together or not at all. Domain failures throw `ReservationError`.
public protocol ReservationRepository: Sendable {
    func reserve(offerID: String, quantity: Int, at now: Date) async throws -> Reservation
    func changeQuantity(reservationID: UUID, to quantity: Int, at now: Date) async throws -> Reservation
    func cancel(reservationID: UUID, reason: CancelReason?, at now: Date) async throws -> Reservation
    func markCollected(reservationID: UUID, at now: Date) async throws -> Reservation
    /// All reservations, newest first.
    func reservations() async throws -> [Reservation]
    func reservation(id: UUID) async throws -> Reservation?
    func changes() -> AsyncStream<MarketplaceChange>
}
