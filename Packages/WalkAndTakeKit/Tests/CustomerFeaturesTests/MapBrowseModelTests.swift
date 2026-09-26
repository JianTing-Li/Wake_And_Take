//
//  MapBrowseModelTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Map browse")
struct MapBrowseModelTests {
    func map(at now: Date, prefs: UserPreferences = UserPreferences(maxDistanceMiles: 2)) async -> MapBrowseModel {
        let harness = Harness(now: now, offers: DiscoverModelTests.offers, preferences: prefs)
        let model = DiscoverModel(dependencies: harness.dependencies)
        await model.load()
        await model.resolveLocation()
        return model.map
    }

    @Test func beforeEightPMThereIsNoDayPicker() async {
        let map = await map(at: Fixture.sep(24, 8))
        #expect(!map.showsDayPicker)
        #expect(map.pins.count == 4)
        #expect(map.availableCount == 3)
    }

    @Test func afterEightPMPinsFollowTheSelectedDay() async {
        let map = await map(at: Fixture.sep(24, 20, 15))
        #expect(map.showsDayPicker)
        #expect(map.pins.allSatisfy { !$0.offerID.hasSuffix("2026-09-25") })
        map.day = .tomorrow
        #expect(map.pins.map(\.offerID) == ["breakfast-2026-09-25"])
        #expect(map.pins[0].state == .opensLater)
    }

    @Test func pinStates() async {
        let map = await map(at: Fixture.sep(24, 8))
        let states = Dictionary(uniqueKeysWithValues: map.pins.map { ($0.offerID.prefix { $0 != "-" }, $0.state) })
        #expect(states["breakfast"] == .openNow)
        #expect(states["lunch"] == .opensLater)
        #expect(states["bakery"] == .gone)
    }

    @Test func selectingShowsTheCardAndSwitchingDayClearsIt() async throws {
        let map = await map(at: Fixture.sep(24, 20, 15))
        map.select("dinner-2026-09-24")
        let card = try #require(map.selectedCard)
        #expect(card.restaurantName == "Near Café")
        #expect(card.statusLine.hasPrefix("Opens at 9:00 PM · "))
        map.day = .tomorrow
        #expect(map.selectedOfferID == nil)
        #expect(map.selectedCard == nil)
    }

    @Test func circleFollowsLocationAndMaxDistance() async {
        let map = await map(at: Fixture.sep(24, 8), prefs: UserPreferences(maxDistanceMiles: 0.5))
        #expect(map.center == Fixture.licCenter)
        #expect(map.maxDistanceMiles == 0.5)
        #expect(map.maxDistanceText == "0.5")
        #expect(!map.pins.contains { $0.offerID.hasPrefix("lunch") })  // Mid Deli is ~0.54 mi
    }
}
