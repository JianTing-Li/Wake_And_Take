//
//  OfferRepository.swift
//  WakeAndTakeKit
//

import Foundation

/// Read access to restaurants and their offers.
public protocol OfferRepository: Sendable {
    /// Offers visible at `now` (see `OfferVisibility`), including ended or sold-out ones for today.
    func offers(visibleAt now: Date) async throws -> [Offer]
    func offer(id: String) async throws -> Offer?
    func restaurants() async throws -> [Restaurant]
    func restaurant(id: String) async throws -> Restaurant?
    func changes() -> AsyncStream<MarketplaceChange>
}
