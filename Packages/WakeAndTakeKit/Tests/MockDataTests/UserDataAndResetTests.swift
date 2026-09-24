//
//  UserDataAndResetTests.swift
//  MockDataTests
//

import Domain
import Foundation
import Platform
import Testing

@testable import MockData

@Suite("User data")
struct UserDataStoreTests {
    @Test func favoritesAndAlerts() async throws {
        let user = try await TestEnv.makeStores().userData
        try await user.setFavorite(true, restaurantID: "rst_a")
        #expect(try await user.favorites() == [FavoriteRestaurant(restaurantID: "rst_a", alertsEnabled: false)])

        // Turning alerts on for a non-favorite also favorites it.
        try await user.setAlerts(true, restaurantID: "rst_b")
        #expect(try await user.favorites().map(\.restaurantID) == ["rst_a", "rst_b"])
        #expect(try await user.favorites().last?.alertsEnabled == true)

        // Unfavoriting removes its alerts too.
        try await user.setFavorite(false, restaurantID: "rst_b")
        try await user.setFavorite(true, restaurantID: "rst_b")
        #expect(try await user.favorites().last?.alertsEnabled == false)
    }

    @Test func alertsOffForAnUnknownRestaurantDoesNothing() async throws {
        let user = try await TestEnv.makeStores().userData
        try await user.setAlerts(false, restaurantID: "rst_a")
        #expect(try await user.favorites().isEmpty)
    }

    @Test func preferencesAndCommuteDefaultThenPersist() async throws {
        let user = try await TestEnv.makeStores().userData
        #expect(try await user.preferences() == UserPreferences())
        #expect(try await user.commuteProfile() == CommuteProfile())

        let prefs = UserPreferences(name: "Jian", homeArea: "Hunters Point", maxDistanceMiles: 0.5, dietary: [.vegan])
        try await user.updatePreferences(prefs)
        #expect(try await user.preferences() == prefs)

        let commute = CommuteProfile(leaveMinutes: 480, arriveMinutes: 540, commuteDays: [2, 4], travelMode: .bike)
        try await user.updateCommuteProfile(commute)
        #expect(try await user.commuteProfile() == commute)
    }

    @Test func changesAreEmitted() async throws {
        let user = try await TestEnv.makeStores().userData
        var changes = user.changes().makeAsyncIterator()
        try await user.setFavorite(true, restaurantID: "rst_a")
        #expect(await changes.next() == .favoritesChanged)
        try await user.updatePreferences(UserPreferences(name: "A"))
        #expect(await changes.next() == .preferencesChanged)
    }
}

@Suite("Reset & persistence")
struct ResetTests {
    @Test func resetLeavesAFreshSeededState() async throws {
        let now = TestEnv.sep(24, 8)
        let stores = try await TestEnv.makeStores(rolloverAt: now)
        let market = stores.marketplace
        let user = stores.userData
        let offerID = TestEnv.offerID("tpl_early_bird_breakfast", day: 24)
        let r = try await market.reserve(offerID: offerID, quantity: 1, at: TestEnv.sep(24, 7, 45))
        _ = try await market.markCollected(reservationID: r.id, at: now)
        _ = try await market.submitReview(Review(overall: 1, submittedAt: now), for: r.id, at: now)
        try await user.setAlerts(true, restaurantID: "rst_early_bird_bakehouse")
        try await user.updatePreferences(UserPreferences(name: "Jian", maxDistanceMiles: 2))

        let spy = SpyNotificationScheduler()
        let resetter = DemoDataResetter(
            marketplace: market, userData: user, notifications: spy, clock: AdjustableClock(fixedAt: now))
        var changes = market.changes().makeAsyncIterator()
        try await resetter.resetAll()

        #expect(try await market.reservations().isEmpty)
        #expect(try await market.offer(id: offerID)?.quantityReserved == 1)  // simulated only
        #expect(try await market.offers(visibleAt: now).count == 32)
        #expect(try await market.restaurants().count == 21)
        #expect(try await market.restaurant(id: "rst_early_bird_bakehouse")?.reviewCount == 212)
        #expect(try await user.favorites().isEmpty)
        #expect(try await user.preferences() == UserPreferences())
        #expect(spy.recorded == ["cancelAll"])
        #expect(await changes.next() == .rolledOver)
        #expect(await changes.next() == .reset)
    }

    @Test func dataSurvivesARelaunch() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "wt-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let now = TestEnv.sep(24, 7)
        let reservation: Reservation
        do {
            let container = try ModelContainerFactory.make(at: url)
            let market = MarketplaceStore(modelContainer: container, seed: TestEnv.seed)
            try await market.rolloverIfNeeded(at: now)
            reservation = try await market.reserve(
                offerID: TestEnv.offerID("tpl_early_bird_breakfast", day: 24), quantity: 2, at: now)
            try await UserDataStore(modelContainer: container).setFavorite(true, restaurantID: "rst_plaza_perk")
        }
        let container = try ModelContainerFactory.make(at: url)
        let market = MarketplaceStore(modelContainer: container, seed: TestEnv.seed)
        #expect(try await market.rolloverIfNeeded(at: now) == false)
        #expect(try await market.reservations() == [reservation])
        #expect(
            try await UserDataStore(modelContainer: container).favorites().map(\.restaurantID) == ["rst_plaza_perk"])
    }
}
