//
//  DiscoverModelTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Discover")
struct DiscoverModelTests {
    /// Today: breakfast (ends 10:00), lunch at Mid (ends 14:00), sold-out bakery, dinner (21:00–23:59);
    /// tomorrow: breakfast.
    static let offers = [
        Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599),
        Fixture.offer("lunch", restaurant: "mid", start: (12, 0), end: (14, 0), category: .meal, price: 450),
        Fixture.offer("bakery", start: (8, 0), end: (11, 0), category: .bakery, total: 3, reserved: 3),
        Fixture.offer("dinner", start: (21, 0), end: (23, 59), category: .meal, price: 899),
        Fixture.offer("breakfast", day: 25, start: (7, 30), end: (10, 0), price: 599),
    ]

    func loaded(at now: Date, _ configure: (inout Harness) -> Void = { _ in }) async -> (DiscoverModel, Harness) {
        var harness = Harness(now: now, offers: Self.offers)
        configure(&harness)
        let model = DiscoverModel(dependencies: harness.dependencies)
        await model.load()
        await model.resolveLocation()
        return (model, harness)
    }

    // MARK: States

    @Test func startsLoadingThenLoads() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: Self.offers)
        let model = DiscoverModel(dependencies: harness.dependencies)
        #expect(model.state == .loading)
        await model.load()
        #expect(model.state == .loaded)
    }

    @Test func emptyWhenNothingIsVisible() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: [])
        let model = DiscoverModel(dependencies: harness.dependencies)
        await model.load()
        #expect(model.state == .empty)
        #expect(model.isListEmpty)
    }

    @Test func failedThenRetry() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: Self.offers)
        harness.marketplace.failReads(true)
        let model = DiscoverModel(dependencies: harness.dependencies)
        await model.load()
        guard case .failed = model.state else {
            Issue.record("expected failed")
            return
        }
        harness.marketplace.failReads(false)
        await model.retry()
        #expect(model.state == .loaded)
    }

    // MARK: Sections & day labeling

    @Test func oneUntitledSectionBeforeEightPM() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 19, 59))
        #expect(model.sections.map(\.kind) == [.all])
        #expect(model.sections[0].title == nil)
        #expect(!model.sections[0].items.contains { $0.offerID.hasSuffix("2026-09-25") })
    }

    @Test func tonightThenTomorrowFromEightPM() async throws {
        let (model, _) = await loaded(at: Fixture.sep(24, 20, 15))
        #expect(model.sections.map(\.kind) == [.tonight, .tomorrow])
        #expect(model.sections.map(\.title) == ["Tonight", "Tomorrow"])
        let tomorrow = try #require(model.sections.last?.items.first)
        #expect(tomorrow.card.pickupText == "Tomorrow · 7:30–10:00 AM")
        #expect(tomorrow.card.badgeText == "Opens tomorrow at 7:30 AM")
        let dinner = try #require(model.sections[0].items.first { $0.offerID.hasPrefix("dinner") })
        #expect(dinner.card.pickupText == "Tonight · 9:00–11:59 PM")
    }

    @Test func filtersApplyToBothSections() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 20, 15))
        model.category = .breakfast
        #expect(model.sections.map(\.kind) == [.tonight, .tomorrow])
        #expect(model.sections.flatMap(\.items).allSatisfy { $0.card.category == .breakfast })
        model.category = .bakery
        // Only today's (sold-out) bakery bag is left; the empty Tomorrow section is dropped.
        #expect(model.sections.map(\.kind) == [.tonight])
    }

    @Test func midnightMovesTomorrowIntoToday() async {
        let (model, harness) = await loaded(at: Fixture.sep(24, 23, 50))
        #expect(model.sections.map(\.kind) == [.tonight, .tomorrow])
        harness.clock.travel(to: Fixture.sep(25, 0, 10))
        await model.load()
        #expect(model.sections.map(\.kind) == [.all])
        #expect(model.sections[0].items.map(\.offerID) == ["breakfast-2026-09-25"])
        #expect(model.sections[0].items[0].card.pickupText == "Today · 7:30–10:00 AM")
    }

    // MARK: Sorting

    @Test func sortOrdersKeepUnavailableLast() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 8))
        let ids = { model.sections[0].items.map { String($0.offerID.prefix { $0 != "-" }) } }
        #expect(ids() == ["breakfast", "lunch", "dinner", "bakery"])  // ending soon; sold out last
        model.sort = .cheapest
        #expect(ids() == ["lunch", "breakfast", "dinner", "bakery"])
        model.sort = .nearest
        #expect(ids().first != "lunch")  // Mid Deli is farther than Near Café
        #expect(ids().last == "bakery")
    }

    // MARK: Preferences & header

    @Test func distancePreferenceHidesFartherBagsAndCountsThem() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(
                now: Fixture.sep(24, 8), offers: Self.offers,
                preferences: UserPreferences(name: "Jian", maxDistanceMiles: 0.25))
        }
        #expect(!model.sections.flatMap(\.items).contains { $0.restaurantID == "mid" })
        #expect(model.header.availableCount == 2)  // breakfast, dinner
        #expect(model.header.hiddenByPreferencesCount == 1)  // lunch
        #expect(model.header.greetingName == "Jian")
        #expect(model.header.maxDistanceText == "0.25")
    }

    @Test func dietaryFilterFollowsItsFlag() async {
        let prefs = UserPreferences(maxDistanceMiles: 2, dietary: [.vegan])
        let (on, _) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(now: Fixture.sep(24, 8), offers: Self.offers, preferences: prefs)
        }
        #expect(on.isListEmpty)
        #expect(on.header.hiddenReasonText == "your distance or dietary preferences")
        let (off, _) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(
                now: Fixture.sep(24, 8), offers: Self.offers, preferences: prefs,
                flags: Fixture.flags(dietaryFilters: false))
        }
        #expect(off.sections[0].items.count == 4)
        #expect(off.header.hiddenReasonText == "your distance preference")
    }

    @Test func commuteBadgeOnlyWithItsFlag() async {
        let (off, _) = await loaded(at: Fixture.sep(24, 7))
        #expect(!off.sections.flatMap(\.items).contains { $0.card.fitsCommute })
        let (on, _) = await loaded(at: Fixture.sep(24, 7)) {
            $0 = Harness(now: Fixture.sep(24, 7), offers: Self.offers, flags: Fixture.flags(commute: true))
        }
        // 7:30–10:00 overlaps the default 7:30–8:30 weekday commute.
        #expect(on.sections[0].items.first { $0.offerID.hasPrefix("breakfast") }?.card.fitsCommute == true)
    }

    @Test func ratingsHiddenWhenReviewsFlagOff() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(now: Fixture.sep(24, 8), offers: Self.offers, flags: Fixture.flags(reviews: false))
        }
        #expect(model.sections[0].items.allSatisfy { $0.card.rating == nil })
    }

    // MARK: Location

    @Test func fallbackLocationShowsTheBanner() async {
        let (model, _) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(
                now: Fixture.sep(24, 8), offers: Self.offers,
                location: ServiceArea.longIslandCity.fallback(.permissionDenied))
        }
        #expect(model.fallbackReason == .permissionDenied)
        let (device, _) = await loaded(at: Fixture.sep(24, 8))
        #expect(device.fallbackReason == nil)
    }

    // MARK: Favorites & live updates

    @Test func toggleFavoriteWritesThrough() async {
        let (model, harness) = await loaded(at: Fixture.sep(24, 8))
        await model.toggleFavorite(restaurantID: "near")
        #expect(harness.userData.favoriteIDs == ["near"])
        await model.load()
        #expect(model.sections[0].items.first { $0.restaurantID == "near" }?.isFavorite == true)
        await model.toggleFavorite(restaurantID: "near")
        #expect(harness.userData.favoriteIDs.isEmpty)
    }

    @Test func favoritesFlagOffIgnoresToggles() async {
        let (model, harness) = await loaded(at: Fixture.sep(24, 8)) {
            $0 = Harness(now: Fixture.sep(24, 8), offers: Self.offers, flags: Fixture.flags(favorites: false))
        }
        await model.toggleFavorite(restaurantID: "near")
        #expect(harness.userData.favoriteIDs.isEmpty)
        #expect(!model.flags.favorites)
    }

    @Test func reloadsWhenTheMarketplaceChanges() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: Self.offers)
        let model = DiscoverModel(dependencies: harness.dependencies)
        let task = Task { await model.run() }
        defer { task.cancel() }
        #expect(await eventually { model.state == .loaded })
        harness.marketplace.set(offers: [])
        #expect(await eventually { model.state == .empty })
    }
}
