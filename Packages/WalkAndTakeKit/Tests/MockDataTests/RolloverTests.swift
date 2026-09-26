//
//  RolloverTests.swift
//  MockDataTests
//

import Domain
import Foundation
import Platform
import SwiftData
import Testing

@testable import MockData

@Suite("Rollover")
struct RolloverTests {
    let earlyBird = "tpl_early_bird_breakfast"

    @Test func firstRolloverSeedsRestaurantsAndTodayPlusTomorrow() async throws {
        let stores = try await TestEnv.makeStores(rolloverAt: TestEnv.sep(24, 8))
        let market = stores.marketplace
        #expect(try await market.restaurants().count == 21)
        // Before 20:00 only today's 32 are visible; after, today's + tomorrow's.
        #expect(try await market.offers(visibleAt: TestEnv.sep(24, 8)).count == 32)
        #expect(try await market.offers(visibleAt: TestEnv.sep(24, 20)).count == 64)
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 25)) != nil)
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 26)) == nil)
    }

    @Test func runningTwiceIsANoOp() async throws {
        let stores = try await TestEnv.makeStores()
        let market = stores.marketplace
        let now = TestEnv.sep(24, 20, 30)
        #expect(try await market.rolloverIfNeeded(at: now))
        let first = try await market.offers(visibleAt: now)
        #expect(try await market.rolloverIfNeeded(at: now) == false)
        #expect(try await market.rolloverIfNeeded(at: TestEnv.sep(24, 23, 59)) == false)
        #expect(try await market.offers(visibleAt: now) == first)
    }

    @Test func nextDayKeepsTomorrowsReservations() async throws {
        let stores = try await TestEnv.makeStores(rolloverAt: TestEnv.sep(24, 20, 30))
        let market = stores.marketplace
        let tomorrowID = TestEnv.offerID(earlyBird, day: 25)
        let reservation = try await market.reserve(offerID: tomorrowID, quantity: 2, at: TestEnv.sep(24, 20, 30))

        #expect(try await market.rolloverIfNeeded(at: TestEnv.sep(25, 7)))
        let offer = try #require(try await market.offer(id: tomorrowID))
        #expect(offer.quantityReserved == 1 + 2)  // simulated + ours, not regenerated
        #expect(try await market.reservation(id: reservation.id) == reservation)
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 26)) != nil)
        // Yesterday's (the 24th) ended offers were pruned.
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 24)) == nil)
    }

    @Test func clockSetBackwardsTriggersRollover() async throws {
        let stores = try await TestEnv.makeStores(rolloverAt: TestEnv.sep(25, 8))
        let market = stores.marketplace
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 24)) == nil)

        #expect(try await market.rolloverIfNeeded(at: TestEnv.sep(24, 8)))
        #expect(try await market.offers(visibleAt: TestEnv.sep(24, 8)).count == 32)
        // The 26th's offers from the later run are left alone.
        #expect(try await market.offer(id: TestEnv.offerID(earlyBird, day: 26)) != nil)
    }

    @Test func pruningNeverDeletesReservations() async throws {
        let stores = try await TestEnv.makeStores(rolloverAt: TestEnv.sep(24, 7))
        let market = stores.marketplace
        let todayID = TestEnv.offerID(earlyBird, day: 24)
        let reservation = try await market.reserve(offerID: todayID, quantity: 1, at: TestEnv.sep(24, 7))

        try await market.rolloverIfNeeded(at: TestEnv.sep(26, 8))
        #expect(try await market.offer(id: todayID) == nil)
        let kept = try #require(try await market.reservation(id: reservation.id))
        #expect(kept.snapshot.offerID == todayID)
        #expect(kept.snapshot.restaurantName == "Early Bird Bakehouse")
        #expect(ReservationPolicy.status(of: kept, at: TestEnv.sep(26, 8)) == .missed)
    }

    @Test func rolloverEmitsRolledOver() async throws {
        let stores = try await TestEnv.makeStores()
        var changes = stores.marketplace.changes().makeAsyncIterator()
        try await stores.marketplace.rolloverIfNeeded(at: TestEnv.sep(24, 8))
        #expect(await changes.next() == .rolledOver)
    }

    @Test func seedVersionChangeReseedsButKeepsReservedOffers() async throws {
        let now = TestEnv.sep(24, 20, 30)
        let stores = try await TestEnv.makeStores(rolloverAt: now)
        let reservedID = TestEnv.offerID(earlyBird, day: 25)
        let reservation = try await stores.marketplace.reserve(offerID: reservedID, quantity: 1, at: now)

        // Same container, new app build with a bumped template version.
        let upgraded = MarketplaceStore(
            modelContainer: stores.container, seed: TestEnv.bumpedSeed(renamingTo: "Renamed Bag"))
        #expect(try await upgraded.rolloverIfNeeded(at: now))

        #expect(try await upgraded.offer(id: reservedID)?.name == "Breakfast Surprise Bag")
        let other = try #require(try await upgraded.offer(id: TestEnv.offerID("tpl_bagel_ferry_breakfast", day: 25)))
        #expect(other.name == "Renamed Bag")
        // Tonight: Pepper Pier (19:30–21:30) is already open and keeps its data;
        // Night Owl (21:00) hasn't started, so it regenerates from the new templates.
        #expect(try await upgraded.offer(id: TestEnv.offerID("tpl_pepper_pier_dinner", day: 24))?.name == "Dinner Bag")
        #expect(try await upgraded.offer(id: TestEnv.offerID("tpl_night_owl_dinner", day: 24))?.name == "Renamed Bag")
        #expect(try await upgraded.reservation(id: reservation.id) == reservation)
        #expect(try await upgraded.rolloverIfNeeded(at: now) == false)
    }
}
