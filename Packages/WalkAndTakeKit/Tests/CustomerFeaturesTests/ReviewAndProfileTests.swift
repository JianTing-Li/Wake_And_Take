//
//  ReviewAndProfileTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Rate order")
struct RateOrderModelTests {
    static let offer = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599)

    func rate(stars: Int = 4, collected: Bool = true, at now: Date = Fixture.sep(24, 9))
        async -> (RateOrderModel, Harness)
    {
        let harness = Harness(now: now, offers: [Self.offer])
        let reservation = harness.marketplace.add(
            Fixture.reservation(for: Self.offer, collectedAt: collected ? Fixture.sep(24, 8) : nil))
        let model = RateOrderModel(
            reservationID: reservation.id, initialStars: stars, dependencies: harness.dependencies)
        await model.load()
        return (model, harness)
    }

    @Test func startsWithTheTappedStars() async {
        let (model, _) = await rate(stars: 4)
        #expect(model.state == .rating)
        #expect(model.overall == 4)
        #expect(model.overallCaption == "Really good")
        #expect(model.title == "How was your bag from Near Café?")
        #expect(model.canSubmit)
    }

    @Test func submitFoldsIntoTheRestaurantRating() async throws {
        let (model, harness) = await rate(stars: 5)
        model.quality = 4
        model.tags = [.fresh, .quickPickup]
        model.comment = "  Great croissants  "
        await model.submit()
        #expect(model.state == .submitted)
        #expect(model.thanksText == "Near Café is now rated 4.5 from 101 ratings.")  // (4.5×100+5)/101 ≈ 4.50
        let saved = try #require(try await harness.marketplace.reservations().first?.review)
        #expect(saved.comment == "Great croissants")
        #expect(saved.tags == [.fresh, .quickPickup])
        #expect(saved.submittedAt == Fixture.sep(24, 9))
    }

    @Test func noStarsCantSubmit() async {
        let (model, _) = await rate(stars: 0)
        #expect(!model.canSubmit)
        #expect(model.overallCaption == "Tap a star to rate")
    }

    @Test func notEligibleShowsTheAlert() async {
        let (model, _) = await rate(collected: false)
        await model.submit()
        #expect(model.failed)
        #expect(model.state == .rating)
    }

    @Test func pastTheWindowShowsTheAlert() async {
        let (model, _) = await rate(at: Fixture.sep(26, 9))  // 49 h after pickup
        await model.submit()
        #expect(model.failed)
    }
}

@MainActor
@Suite("Profile")
struct ProfileModelTests {
    static let offer = Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599)

    func profile(flags: FeatureFlags = Fixture.flags()) async -> (ProfileModel, Harness, CustomerNavigation) {
        let harness = Harness(
            now: Fixture.sep(24, 9), offers: [Self.offer], preferences: UserPreferences(name: "Jian"), flags: flags)
        harness.marketplace.add(Fixture.reservation(for: Self.offer, quantity: 2, collectedAt: Fixture.sep(24, 8)))
        let navigation = CustomerNavigation()
        let model = ProfileModel(dependencies: harness.dependencies, navigation: navigation)
        await model.load()
        return (model, harness, navigation)
    }

    @Test func loadsPreferencesAndImpact() async {
        let (model, _, _) = await profile()
        #expect(model.state == .loaded)
        #expect(model.preferences.name == "Jian")
        #expect(model.impact.bagsRescued == 2)
        #expect(model.distanceOptions == [0.25, 0.5, 1.0, 1.5, 2.0])
        #expect(model.distanceLabel(0.25) == "0.25 mi")
    }

    @Test func editsSave() async throws {
        let (model, harness, _) = await profile()
        model.preferences.maxDistanceMiles = 0.5
        model.setDietary(.vegan, true)
        model.commute.travelMode = .bike
        await model.pendingSave?.value
        let saved = try await harness.userData.preferences()
        #expect(saved.maxDistanceMiles == 0.5)
        #expect(saved.dietary == [.vegan])
        #expect(try await harness.userData.commuteProfile().travelMode == .bike)
    }

    @Test func commuteTimesUseNewYorkWallClock() async {
        let (model, _, _) = await profile()
        let date = model.time(forMinutes: 7 * 60 + 30)
        #expect(date == Fixture.sep(24, 7, 30))
        #expect(model.minutes(from: Fixture.sep(24, 8, 45)) == 8 * 60 + 45)
    }

    @Test func resetWipesDataAndPopsEveryTab() async {
        let (model, harness, navigation) = await profile()
        navigation.discoverPath = [.offer(id: "x")]
        navigation.ordersPath = [.pickup(reservationID: UUID())]
        navigation.selectedTab = .profile
        await model.resetDemoData()
        #expect(harness.resetter.resetCount == 1)
        #expect(navigation.discoverPath.isEmpty && navigation.ordersPath.isEmpty)
        #expect(navigation.selectedTab == .profile)
        #expect(model.preferences == UserPreferences())
        #expect(model.impact == Impact())
        #expect(!model.resetFailed)
    }

    @Test func failedResetShowsTheAlertAndKeepsNavigation() async {
        let (model, harness, navigation) = await profile()
        navigation.discoverPath = [.offer(id: "x")]
        harness.resetter.failNext()
        await model.resetDemoData()
        #expect(model.resetFailed)
        #expect(navigation.discoverPath == [.offer(id: "x")])
    }

    @Test func flagsControlSections() async {
        let (model, _, _) = await profile()
        #expect(model.flags.impact && model.flags.dietaryFilters && !model.flags.commute)
        let (off, _, _) = await profile(flags: Fixture.flags(dietaryFilters: false, impact: false, commute: true))
        #expect(!off.flags.impact && !off.flags.dietaryFilters && off.flags.commute)
    }
}
