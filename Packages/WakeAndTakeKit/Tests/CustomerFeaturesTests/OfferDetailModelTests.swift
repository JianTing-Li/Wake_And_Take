//
//  OfferDetailModelTests.swift
//  CustomerFeaturesTests
//

import DesignSystem
import Domain
import Foundation
import Platform
import Testing

@testable import CustomerFeatures

@MainActor
@Suite("Offer detail & reserve")
struct OfferDetailModelTests {
    static let todayID = "breakfast-2026-09-24"
    static let tomorrowID = "breakfast-2026-09-25"
    static let offers = [
        Fixture.offer("breakfast", start: (7, 30), end: (10, 0), price: 599, total: 5, reserved: 1),
        Fixture.offer("breakfast", day: 25, start: (7, 30), end: (10, 0), price: 599),
        Fixture.offer("lastone", start: (8, 0), end: (11, 0), total: 3, reserved: 2),
    ]

    struct Setup {
        let model: OfferDetailModel
        let harness: Harness
        let navigation: CustomerNavigation
    }

    func detail(
        _ offerID: String = todayID, at now: Date = Fixture.sep(24, 8), flags: FeatureFlags = Fixture.flags()
    ) async -> Setup {
        let harness = Harness(now: now, offers: Self.offers, flags: flags)
        let navigation = CustomerNavigation()
        let model = OfferDetailModel(
            offerID: offerID, origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies, navigation: navigation)
        await model.load()
        return Setup(model: model, harness: harness, navigation: navigation)
    }

    // MARK: Content

    @Test func loadedContentUsesFullDateCopy() async {
        let model = await detail().model
        #expect(model.state == .loaded)
        #expect(model.restaurantName == "Near Café")
        #expect(model.pickupText == "Pick up today, Thu Sep 24, 7:30–10:00 AM")
        #expect(model.urgencyText == "Ends at 10:00 AM")
        #expect(model.addressTitle == "Vernon Blvd & 48th Ave")
        #expect(model.addressSubtitle == "0.2 mi away · Long Island City")
        #expect(model.subtitle == "4.5 (100 ratings) · Breakfast")
        #expect(model.reserveButtonTitle == "Reserve · $5.99")
        #expect(model.canReserve)
    }

    @Test func tomorrowsOfferIsLabeledTomorrow() async {
        let model = await detail(Self.tomorrowID, at: Fixture.sep(24, 20, 30)).model
        #expect(model.pickupText == "Pick up tomorrow, Fri Sep 25, 7:30–10:00 AM")
        #expect(model.urgencyText == "Opens tomorrow at 7:30 AM")
        #expect(model.canReserve)
    }

    @Test func tomorrowBeforeEightPMCantBeReserved() async {
        let model = await detail(Self.tomorrowID, at: Fixture.sep(24, 19)).model
        #expect(!model.canReserve)
        #expect(model.reserveButtonTitle == "Opens for reservations at 8 PM")
    }

    @Test func notFound() async {
        #expect(await detail("nope-2026-09-24").model.state == .notFound)
    }

    @Test func failedLoad() async {
        let harness = Harness(now: Fixture.sep(24, 8), offers: Self.offers)
        harness.marketplace.failReads(true)
        let model = OfferDetailModel(
            offerID: Self.todayID, origin: ResolvedLocation(coordinate: Fixture.licCenter, source: .device),
            dependencies: harness.dependencies, navigation: CustomerNavigation())
        await model.load()
        guard case .failed = model.state else {
            Issue.record("expected failed")
            return
        }
    }

    @Test func reviewsFlagOffHidesRating() async {
        #expect(await detail(flags: Fixture.flags(reviews: false)).model.subtitle == "Breakfast")
    }

    // MARK: Quantity

    @Test func quantityIsCappedAtThreeOrWhatsLeft() async {
        let model = await detail().model
        #expect(model.reserve.maxQuantity == 3)  // 4 left
        let lastOne = await detail("lastone-2026-09-24").model
        #expect(lastOne.reserve.maxQuantity == 1)
        model.reserve.quantity = 3
        #expect(model.reserveButtonTitle == "Reserve · $17.97")
    }

    // MARK: Reserving

    @Test func reserveShowsConfirmation() async throws {
        let setup = await detail()
        let reserve = setup.model.reserve
        reserve.quantity = 2
        await reserve.reserve()
        let confirmation = try #require(reserve.confirmation)
        #expect(confirmation.code == "AB21")
        #expect(confirmation.bagsText == "2 × breakfast bag")
        #expect(confirmation.totalText == "$11.98")
        #expect(confirmation.pickupText == "Pick up today, Thu Sep 24, 7:30–10:00 AM")
        #expect(confirmation.pickupInstructions == "Ask at the counter.")
        #expect(confirmation.policyText.hasPrefix("Free changes and cancellation until 9:50 AM."))
        #expect(reserve.quantity == 1)
        #expect(reserve.alert == nil)
        #expect(setup.harness.marketplace.reservationCount == 1)
    }

    @Test func manageOrderFlagOffDropsTheChangePolicy() async throws {
        let reserve = await detail(flags: Fixture.flags(manageOrder: false)).model.reserve
        await reserve.reserve()
        #expect(try #require(reserve.confirmation).policyText == "Find this order anytime in the Orders tab.")
    }

    @Test(arguments: [ReservationError.soldOut, .windowClosed, .invalidQuantity, .offerNoLongerExists])
    func unavailableErrorsUseTheDraftAlert(error: ReservationError) async {
        let setup = await detail()
        setup.harness.marketplace.failNextReserve(with: error)
        await setup.model.reserve.reserve()
        #expect(setup.model.reserve.alert == .noLongerAvailable)
        #expect(setup.model.reserve.alert?.title == "This bag is no longer available")
        #expect(setup.model.reserve.confirmation == nil)
    }

    @Test func notVisibleYetExplainsEightPM() async {
        let setup = await detail()
        setup.harness.marketplace.failNextReserve(with: ReservationError.notVisibleYet)
        await setup.model.reserve.reserve()
        #expect(setup.model.reserve.alert?.title == "Opens for reservations at 8 PM")
    }

    @Test func unexpectedErrorsSaySomethingWentWrong() async {
        let setup = await detail()
        setup.harness.marketplace.failNextReserve(with: TestError())
        await setup.model.reserve.reserve()
        #expect(setup.model.reserve.alert == .failed)
    }

    @Test func viewOrderSwitchesToOrders() async throws {
        let setup = await detail()
        setup.navigation.discoverPath = [.offer(id: Self.todayID)]
        await setup.model.reserve.reserve()
        let confirmation = try #require(setup.model.reserve.confirmation)
        setup.model.viewOrder(confirmation)
        #expect(setup.model.reserve.confirmation == nil)
        #expect(setup.navigation.selectedTab == .orders)
        #expect(setup.navigation.ordersPath == [.pickup(reservationID: confirmation.id)])
        #expect(setup.navigation.discoverPath.isEmpty)
    }

    // MARK: Favorites

    @Test func favoriteToggleFollowsItsFlag() async {
        let setup = await detail()
        await setup.model.toggleFavorite()
        #expect(setup.model.isFavorite)
        #expect(setup.harness.userData.favoriteIDs == ["near"])
        let off = await detail(flags: Fixture.flags(favorites: false))
        await off.model.toggleFavorite()
        #expect(off.harness.userData.favoriteIDs.isEmpty)
    }
}
