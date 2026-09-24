//
//  MarketplaceStore.swift
//  WakeAndTakeKit
//
//  Owns restaurants, offers, reservations and reviews. Every mutation runs
//  synchronously inside the actor, so stock and reservations change atomically.
//

import Domain
import Foundation
import Platform
import SwiftData

public actor MarketplaceStore: ModelActor {
    public nonisolated let modelContainer: ModelContainer
    public nonisolated let modelExecutor: any ModelExecutor

    let seed: Seed
    let codes: any PickupCodeGenerator
    let broadcaster = Broadcaster<MarketplaceChange>()
    var calendar: Calendar { NYCalendar.calendar }

    /// A hand-written `ModelActor` (instead of `@ModelActor`) so the seed and code
    /// generator can be injected alongside the shared container.
    public init(
        modelContainer: ModelContainer,
        seed: Seed,
        codes: any PickupCodeGenerator = RandomPickupCodeGenerator()
    ) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        modelExecutor = DefaultSerialModelExecutor(modelContext: context)
        self.seed = seed
        self.codes = codes
    }

    public nonisolated func changes() -> AsyncStream<MarketplaceChange> {
        broadcaster.stream()
    }

    // MARK: - Reads

    /// Offers visible at `now`: today's, plus tomorrow's from 20:00 New York, by pickup start.
    public func offers(visibleAt now: Date) throws -> [Offer] {
        let today = NYCalendar.dayKey(for: now)
        let keys = [today.rawValue, NYCalendar.day(after: today).rawValue]
        let descriptor = FetchDescriptor<OfferEntity>(
            predicate: #Predicate { keys.contains($0.dayKey) },
            sortBy: [SortDescriptor(\.pickupStart), SortDescriptor(\.id)]
        )
        return try modelContext.fetch(descriptor)
            .map(\.domain)
            .filter { OfferVisibility.isVisible($0, at: now, calendar: calendar) }
    }

    /// Every stored offer that hasn't opened yet, regardless of visibility (for scheduling alerts).
    public func offersNotYetOpen(at now: Date) throws -> [Offer] {
        let descriptor = FetchDescriptor<OfferEntity>(
            predicate: #Predicate { $0.pickupStart > now },
            sortBy: [SortDescriptor(\.pickupStart), SortDescriptor(\.id)]
        )
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func offer(id: String) throws -> Offer? {
        try offerEntity(id: id)?.domain
    }

    public func restaurants() throws -> [Restaurant] {
        try modelContext.fetch(FetchDescriptor<RestaurantEntity>(sortBy: [SortDescriptor(\.name)])).map(\.domain)
    }

    public func restaurant(id: String) throws -> Restaurant? {
        try restaurantEntity(id: id)?.domain
    }

    /// All reservations, newest first.
    public func reservations() throws -> [Reservation] {
        let descriptor = FetchDescriptor<ReservationEntity>(sortBy: [SortDescriptor(\.reservedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.domain)
    }

    public func reservation(id: UUID) throws -> Reservation? {
        try reservationEntity(id: id)?.domain
    }

    // MARK: - Entity lookups

    func offerEntity(id: String) throws -> OfferEntity? {
        try modelContext.fetch(FetchDescriptor<OfferEntity>(predicate: #Predicate { $0.id == id })).first
    }

    func restaurantEntity(id: String) throws -> RestaurantEntity? {
        try modelContext.fetch(FetchDescriptor<RestaurantEntity>(predicate: #Predicate { $0.id == id })).first
    }

    func reservationEntity(id: UUID) throws -> ReservationEntity? {
        try modelContext.fetch(FetchDescriptor<ReservationEntity>(predicate: #Predicate { $0.id == id })).first
    }

    /// Saves, or rolls back every pending change if the save fails.
    func save() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
