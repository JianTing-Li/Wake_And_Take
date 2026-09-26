//
//  FeatureFlagTests.swift
//  CustomerFeaturesTests
//
//  One test per flag (§7): off hides exactly its entry points; data stays.
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Feature flags")
struct FeatureFlagTests {
    static let breakfast = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599)
    static let vegan = Fixture.offer("vegan", start: (7, 30), end: (10, 0), dietary: [.vegan])

    func discover(_ flags: FeatureFlags, prefs: UserPreferences = UserPreferences()) async -> DiscoverModel {
        let harness = Harness(
            now: Fixture.sep(24, 8), offers: [Self.breakfast, Self.vegan], preferences: prefs, flags: flags)
        let model = DiscoverModel(dependencies: harness.dependencies)
        await model.load()
        return model
    }

    func pickup(_ flags: FeatureFlags, collected: Bool) async -> PickupModel {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [Self.breakfast], flags: flags)
        let reservation = harness.marketplace.add(
            Fixture.reservation(for: Self.breakfast, collectedAt: collected ? Fixture.sep(24, 7, 45) : nil))
        let model = PickupModel(
            reservationID: reservation.id, origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies)
        await model.load()
        return model
    }

    func profile(_ flags: FeatureFlags) async -> ProfileModel {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [], flags: flags)
        let model = ProfileModel(dependencies: harness.dependencies, navigation: CustomerNavigation())
        await model.load()
        return model
    }

    @Test func mapBrowse() async {
        #expect(await discover(Fixture.flags()).showsMapToggle)
        #expect(await !discover(Fixture.flags(mapBrowse: false)).showsMapToggle)
    }

    @Test func favorites() async {
        let off = Fixture.flags(favorites: false)
        #expect(CustomerTab.visible(with: off) == [.discover, .orders, .profile])
        #expect(await !discover(off).showsFavoriteButtons)
        #expect(await discover(Fixture.flags()).showsFavoriteButtons)
        let harness = Harness(now: Fixture.sep(24, 8), offers: [Self.breakfast], flags: off)
        let detail = OfferDetailModel(
            offerID: Self.breakfast.id, origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies, navigation: CustomerNavigation())
        #expect(!detail.showsFavoriteButton)
        // Notifications depend on favorites.
        #expect(!off.alertsEnabled)
    }

    @Test func notifications() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [], flags: Fixture.flags(notifications: false))
        #expect(!FavoritesModel(dependencies: harness.dependencies).showsAlerts)
        let on = Harness(now: Fixture.sep(24, 8), offers: [])
        #expect(FavoritesModel(dependencies: on.dependencies).showsAlerts)
    }

    @Test func dietaryFilters() async {
        let vegan = UserPreferences(maxDistanceMiles: 2, dietary: [.vegan])
        #expect(await discover(Fixture.flags(), prefs: vegan).sections.flatMap(\.items).count == 1)
        #expect(await discover(Fixture.flags(dietaryFilters: false), prefs: vegan).sections.flatMap(\.items).count == 2)
        #expect(await profile(Fixture.flags()).showsDietary)
        #expect(await !profile(Fixture.flags(dietaryFilters: false)).showsDietary)
    }

    @Test func manageOrder() async {
        #expect(await pickup(Fixture.flags(), collected: false).canManage)
        #expect(await !pickup(Fixture.flags(manageOrder: false), collected: false).canManage)
    }

    @Test func reviews() async {
        let on = await pickup(Fixture.flags(), collected: true)
        #expect(on.canReview)
        let off = await pickup(Fixture.flags(reviews: false), collected: true)
        #expect(!off.canReview)
        #expect(
            await discover(Fixture.flags(reviews: false)).sections.flatMap(\.items).allSatisfy { $0.card.rating == nil }
        )
    }

    @Test func impact() async {
        #expect(await profile(Fixture.flags()).showsImpact)
        #expect(await !profile(Fixture.flags(impact: false)).showsImpact)
        let harness = Harness(now: Fixture.sep(24, 8), offers: [], flags: Fixture.flags(impact: false))
        #expect(!OrdersModel(dependencies: harness.dependencies).showsImpact)
        #expect(await pickup(Fixture.flags(impact: false), collected: true).impactText == nil)
        #expect(await pickup(Fixture.flags(), collected: true).impactText != nil)
    }

    @Test func commuteIsOffByDefaultAndOnlyGatesItsSectionAndBadge() async {
        #expect(await !profile(Fixture.flags()).showsCommute)
        #expect(await profile(Fixture.flags(commute: true)).showsCommute)
        let now = Fixture.sep(24, 7)
        for (flag, expected) in [(false, false), (true, true)] {
            let harness = Harness(now: now, offers: [Self.breakfast], flags: Fixture.flags(commute: flag))
            let model = DiscoverModel(dependencies: harness.dependencies)
            await model.load()
            #expect(model.sections.flatMap(\.items).first?.card.fitsCommute == expected)
        }
    }
}
