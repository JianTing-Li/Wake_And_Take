//
//  MarketplaceStore+Rollover.swift
//  WalkAndTakeKit
//
//  Keeps offers for today and tomorrow (New York), reseeds when the seed version
//  changes, and resets demo data.
//

import Domain
import Foundation
import Platform
import SwiftData

extension MarketplaceStore {
    /// Generates missing offers for today and tomorrow and prunes ended past-day offers.
    /// Runs when the stored day differs from today in either direction (so a clock moved
    /// backwards also triggers it) or the seed version changed; otherwise it's a no-op.
    /// Existing offers are never overwritten, and reservations are never touched.
    @discardableResult
    public func rolloverIfNeeded(at now: Date) throws -> Bool {
        let metadata = try metadataEntity()
        let today = NYCalendar.dayKey(for: now)
        let seedChanged = metadata.seedVersion != seed.version.rawValue
        guard seedChanged || metadata.lastGeneratedDayKey != today.rawValue else { return false }

        if seedChanged {
            try applySeed(replacingFutureOffers: metadata.seedVersion != nil, at: now)
        }
        try generateOffers(for: [today, NYCalendar.day(after: today)])
        try pruneEndedOffers(before: today, at: now)

        metadata.seedVersion = seed.version.rawValue
        metadata.lastGeneratedDayKey = today.rawValue
        try save()
        broadcaster.send(.rolledOver)
        return true
    }

    /// Deletes all marketplace data, then reseeds and rolls over from scratch.
    public func resetDemoData(at now: Date) throws {
        try deleteAll(RestaurantEntity.self)
        try deleteAll(OfferEntity.self)
        try deleteAll(ReservationEntity.self)
        try deleteAll(MetadataEntity.self)
        try save()
        try rolloverIfNeeded(at: now)
        broadcaster.send(.reset)
    }

    // MARK: - Steps

    /// Upsert-skip: inserts each template's offer for each day only if its ID is new.
    private func generateOffers(for days: [DayKey]) throws {
        let keys = days.map(\.rawValue)
        let existing = Set(
            try modelContext.fetch(FetchDescriptor<OfferEntity>(predicate: #Predicate { keys.contains($0.dayKey) }))
                .map(\.id)
        )
        for day in days {
            for offer in DailyOfferGenerator.offers(from: seed.templates, on: day) where !existing.contains(offer.id) {
                modelContext.insert(OfferEntity(offer, dayKey: day))
            }
        }
    }

    /// Removes offers from days before `today` whose windows have ended.
    private func pruneEndedOffers(before today: DayKey, at now: Date) throws {
        let ended = try modelContext.fetch(FetchDescriptor<OfferEntity>(predicate: #Predicate { $0.pickupEnd <= now }))
        for offer in ended where DayKey(rawValue: offer.dayKey) < today {
            modelContext.delete(offer)
        }
    }

    /// Upserts restaurants from the seed and removes ones it no longer lists. On a version
    /// change, future offers without customer reservations are dropped so they regenerate
    /// from the new templates; offers someone reserved are kept as they were.
    private func applySeed(replacingFutureOffers: Bool, at now: Date) throws {
        var byID = Dictionary(
            uniqueKeysWithValues: try modelContext.fetch(FetchDescriptor<RestaurantEntity>()).map { ($0.id, $0) })
        for restaurant in seed.restaurants {
            if let entity = byID.removeValue(forKey: restaurant.id) {
                entity.update(from: restaurant)
            } else {
                modelContext.insert(RestaurantEntity(restaurant))
            }
        }
        byID.values.forEach(modelContext.delete)

        guard replacingFutureOffers else { return }
        let held = Set(
            try modelContext.fetch(FetchDescriptor<ReservationEntity>(predicate: #Predicate { $0.cancelledAt == nil }))
                .map(\.offerID)
        )
        let future = try modelContext.fetch(
            FetchDescriptor<OfferEntity>(predicate: #Predicate { $0.pickupStart > now }))
        for offer in future where !held.contains(offer.id) {
            modelContext.delete(offer)
        }
    }

    private func metadataEntity() throws -> MetadataEntity {
        if let existing = try modelContext.fetch(FetchDescriptor<MetadataEntity>()).first {
            return existing
        }
        let metadata = MetadataEntity()
        modelContext.insert(metadata)
        return metadata
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        try modelContext.fetch(FetchDescriptor<T>()).forEach(modelContext.delete)
    }

    /// Test hook: simulates an offer disappearing (e.g. pruned) under a live reservation.
    func deleteOffer(id: String) throws {
        if let offer = try offerEntity(id: id) {
            modelContext.delete(offer)
            try save()
        }
    }
}
