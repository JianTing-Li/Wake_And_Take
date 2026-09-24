//
//  RolloverServiceTests.swift
//  MockDataTests
//

import Domain
import Foundation
import Platform
import Testing

@testable import MockData

@Suite("Rollover service")
struct RolloverServiceTests {
    func service(_ stores: TestEnv.Stores, clock: AdjustableClock, spy: SpyNotificationScheduler) -> RolloverService {
        RolloverService(marketplace: stores.marketplace, userData: stores.userData, notifications: spy, clock: clock)
    }

    @Test func firstRunRollsOverAndReschedulesFavoriteAlerts() async throws {
        let stores = try await TestEnv.makeStores()
        try await stores.userData.setAlerts(true, restaurantID: "rst_night_owl_trattoria")
        try await stores.userData.setFavorite(true, restaurantID: "rst_plaza_perk")  // favorite, alerts off
        let clock = AdjustableClock(fixedAt: TestEnv.sep(24, 8))
        let spy = SpyNotificationScheduler()

        #expect(try await service(stores, clock: clock, spy: spy).run())
        // Night Owl dinner today (21:00) and tomorrow; nothing from Plaza Perk.
        #expect(
            spy.replacements == [
                [
                    TestEnv.offerID("tpl_night_owl_dinner", day: 24),
                    TestEnv.offerID("tpl_night_owl_dinner", day: 25),
                ]
            ])
    }

    @Test func repeatRunsAreNoOps() async throws {
        let stores = try await TestEnv.makeStores()
        let clock = AdjustableClock(fixedAt: TestEnv.sep(24, 8))
        let spy = SpyNotificationScheduler()
        let rollover = service(stores, clock: clock, spy: spy)
        #expect(try await rollover.run())
        #expect(try await rollover.run() == false)
        clock.advance(by: 3600)
        #expect(try await rollover.run() == false)
        #expect(spy.recorded == ["replaceAll"])
    }

    @Test func timeTravelToTheNextDayRollsOverAgain() async throws {
        let stores = try await TestEnv.makeStores()
        let clock = AdjustableClock(fixedAt: TestEnv.sep(24, 23, 50))
        let spy = SpyNotificationScheduler()
        let rollover = service(stores, clock: clock, spy: spy)
        try await rollover.run()
        clock.travel(to: TestEnv.sep(25, 0, 10))
        #expect(try await rollover.run())
        #expect(try await stores.marketplace.offer(id: TestEnv.offerID("tpl_early_bird_breakfast", day: 26)) != nil)
        #expect(spy.recorded == ["replaceAll", "replaceAll"])
    }

    @Test func offersNotYetOpenIgnoresVisibility() async throws {
        let stores = try await TestEnv.makeStores(rolloverAt: TestEnv.sep(24, 22))
        let upcoming = try await stores.marketplace.offersNotYetOpen(at: TestEnv.sep(24, 22))
        // Nothing later today at 10 PM; all 32 of tomorrow's.
        #expect(upcoming.count == 32)
        #expect(upcoming.allSatisfy { $0.id.hasSuffix("2026-09-25") })
    }
}
